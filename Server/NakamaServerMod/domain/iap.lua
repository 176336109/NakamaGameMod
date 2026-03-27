--[[
本文件职责：
1) 提供 Nakama IAP（Apple / Google）回调入口：平台侧校验通过后、事务提交前触发
2) 做幂等拦截与发货：避免同一笔交易重复发货（基于 purchase.seen_before）
3) 按商品配置发放奖励，并在需要时写入订阅到期信息
4) 记录关键日志点：Unknown 商品、重复交易、发货失败、发货成功

说明：
- Apple/Google 的“与平台通讯校验收据/签名”由 Nakama 按服务器配置自动完成；本文件只处理校验通过后的业务发货
- 返回值语义：true 表示允许继续提交并落库该笔交易；false 表示拒绝本次处理（通常用于异常/幂等拦截）
]]
local nk = require("nakama")
local config = require("config")
local M = {}
local backpack_gateway = nil
local subscription_gateway = nil

-- 注入背包网关，用于发放IAP奖励道具。
function M.set_item_gateway(gateway)
    backpack_gateway = gateway
end

-- 注入订阅网关，用于激活月卡等订阅权益。
function M.set_subscription_gateway(gateway)
    subscription_gateway = gateway
end

-- 发货主流程：在平台校验通过后执行，负责道具/权益发放与订阅状态写入
function M.on_purchase_complete(context, purchase)
    -- context.user_id：购买用户
    -- purchase.product_id：商品 ID（用于查找配置与发货）
    -- purchase.provider/store/transaction_id/environment：对账/追踪字段（会写入 ref 交给 backpack 侧使用）
    local user_id = context.user_id
    local product_id = purchase.product_id
    
    local product_config = nil
    if type(config.iap_products) == "table" then
        product_config = config.iap_products[product_id]
    end
    if not product_config and config.shop and config.shop.goods and config.shop.goods[product_id] then
        local goods = config.shop.goods[product_id]
        local is_iap_goods = goods.costType == "rmb" or goods.shopType == "crystal"
        if is_iap_goods then
            product_config = {
                rewards = goods.rewardItems
            }
        end
    end
    
    if not product_config then
        -- Unknown product：通常是客户端传了未配置商品，或服务端配置缺失
        -- 日志字段语义：仅包含 product_id，便于快速定位缺失配置的商品键
        nk.logger_warn("Unknown product ID purchased: " .. product_id)
        return false -- Or handle as fallback
    end
    
    -- 发放奖励：按配置表 iap_products[product_id].rewards 进行道具/货币等增发
    -- ref：作为“幂等/对账”上下文，尽量带齐交易来源字段（backpack 模块可据此做审计或二次幂等）
    if type(product_config.rewards) == "table" and #product_config.rewards > 0 then
        local ref = { product_id = product_id }
        if purchase.provider ~= nil then ref.provider = purchase.provider end
        if purchase.store ~= nil then ref.store = purchase.store end
        if purchase.transaction_id ~= nil then ref.transaction_id = purchase.transaction_id end
        if purchase.environment ~= nil then ref.environment = purchase.environment end
        
        if not backpack_gateway then
            nk.logger_error("backpack_gateway not wired in iap domain")
            return false
        end

        local ok, err = backpack_gateway.add_items(context, user_id, product_config.rewards, "iap", ref)
        if not ok then
            -- 异常分支：发货失败，拒绝提交该笔交易，避免出现“交易记录已写入但未发货”的不一致
            -- 日志字段语义：tostring(err) 由 backpack 返回，通常包含失败原因/堆栈/下游错误描述
            nk.logger_error("Failed to grant purchase rewards: " .. tostring(err))
            return false
        end
    end
    
    if product_config.benefit_plan_id and product_config.duration_days then
        if not subscription_gateway or type(subscription_gateway.activate_subscription) ~= "function" then
            nk.logger_error("subscription_gateway not wired in iap domain")
            return false
        end
        local ok_sub, err_sub = subscription_gateway.activate_subscription(context, user_id, product_config.benefit_plan_id, product_config.duration_days, product_id)
        if not ok_sub then
            nk.logger_error("Failed to activate subscription: " .. tostring(err_sub))
            return false
        end
    end

    -- 成功日志：用于确认已执行到发货末尾（包含 user_id 与 product_id，便于按人/商品检索）
    nk.logger_info("Purchase processed for user: " .. user_id .. ", Product: " .. product_id)
    return true
end

-- Google 校验入口：由 Nakama IAP 管线在“Google 校验通过后”调用
-- 注意：此处不做 Google 校验请求；只决定是否继续处理与发货
function M.google_purchase_validate(context, purchase)
    -- 触发时机：平台校验成功后、事务提交前
    -- 返回值语义：true 继续处理并最终提交；false 拒绝本次购买处理
    
    -- 幂等键语义：purchase.seen_before=true 表示 Nakama 认为该笔交易已被处理过
    -- 发货流程：先拦截重复交易，再进入 on_purchase_complete 发放奖励/写订阅
    if purchase.seen_before then
        -- 重复交易日志：用于定位客户端重试或重放导致的二次回调
        nk.logger_warn("Duplicate purchase attempt: " .. purchase.product_id)
        return false
    end
    
    return M.on_purchase_complete(context, purchase)
end

-- Apple 校验入口：由 Nakama IAP 管线在“App Store 校验通过后”调用
function M.apple_purchase_validate(context, purchase)
    -- 幂等键语义同上：seen_before 用于避免重复发货
    if purchase.seen_before then
        return false
    end
    return M.on_purchase_complete(context, purchase)
end

return M
