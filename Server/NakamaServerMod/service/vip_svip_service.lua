local nk = require("nakama")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}
local vip_domain = nil
local iap_domain = nil
local iap_service = nil

-- domain 文本错误到统一错误码的映射表。
local DOMAIN_ERROR_MAP = {
    ["Invalid benefit plan"] = "VIP_PLAN_INVALID",
    ["Exceeds maximum cumulative days"] = "VIP_EXCEEDS_MAX_CUMULATIVE_DAYS",
    ["Subscription not active or expired"] = "VIP_NOT_ACTIVE",
    ["State not found"] = "VIP_STATE_NOT_FOUND",
    ["No pending rewards"] = "VIP_NO_PENDING_REWARD",
    ["No rewards"] = "VIP_NO_PENDING_REWARD",
    ["item gateway not configured"] = "COMMON_INTERNAL_ERROR",
    ["Invalid plan_id. Must be 'vip_monthly' or 'svip_monthly'"] = "VIP_INVALID_PLAN_ID"
}

-- 注入背包网关并装配 VIP/SVIP domain。
function M.wire_item_gateway(backpack, vip_svip)
    if type(vip_svip) ~= "table" or type(vip_svip.set_item_gateway) ~= "function" then
        return
    end

    local gateway = {
        add_items = function(context, user_id, items, source, ref)
            return backpack.add_items(context, user_id, items, source, ref)
        end
    }

    vip_svip.set_item_gateway(gateway)
    vip_domain = vip_svip
end

-- 注入 iap domain，并挂接订阅激活回调到 VIP 购买链路。
function M.set_iap_domain(iap)
    iap_domain = iap
    if iap_domain and type(iap_domain.set_subscription_gateway) == "function" and vip_domain then
        iap_domain.set_subscription_gateway({
            activate_subscription = function(context, user_id, plan_id, duration_days, product_id)
                if plan_id == "vip_monthly" then
                    return vip_domain.purchase_vip(context, user_id, duration_days or 30, "IAP购买VIP:" .. tostring(product_id), { skip_immediate_reward = true })
                end
                if plan_id == "svip_monthly" then
                    return vip_domain.purchase_svip(context, user_id, duration_days or 30, "IAP购买SVIP:" .. tostring(product_id), { skip_immediate_reward = true })
                end
                return false, "Unsupported benefit_plan_id: " .. tostring(plan_id)
            end
        })
    end
end

-- 注入 iap service，用于创建支付订单。
function M.set_iap_service(service)
    iap_service = service
end

-- 解析 RPC 入参，解析失败返回空表。
local function decode_payload(payload)
    if payload and payload ~= "" then
        local ok, req = pcall(function() return nk.json_decode(payload) end)
        if ok and type(req) == "table" then
            return req
        end
    end
    return {}
end

-- 统一服务未装配错误。
local function service_not_wired()
    local code, message = error_codes.resolve("VIP_SERVICE_NOT_WIRED", "VIP service not wired")
    return response.fail(code, message)
end

-- 按错误码键构造失败响应。
local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
end

-- 统一映射 domain 错误文本到标准错误码。
local function fail_by_domain_error(err, default_key)
    local text = tostring(err or "")
    local key = DOMAIN_ERROR_MAP[text] or default_key or "COMMON_INTERNAL_ERROR"
    return fail_by_key(key, text)
end

-- 创建 VIP 购买订单。
function M.rpc_purchase_vip(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    if not iap_service or type(iap_service.rpc_create_order) ~= "function" then
        return fail_by_key("IAP_SERVICE_NOT_WIRED", "IAP service not wired")
    end
    local provider = req.provider or "mock"
    local order_payload = nk.json_encode({
        product_id = req.product_id or "com.game.monthly_card",
        provider = provider
    })
    local order_raw = iap_service.rpc_create_order(context, order_payload)
    local ok_decode, order_result = pcall(nk.json_decode, order_raw or "")
    if not ok_decode or type(order_result) ~= "table" then
        return fail_by_key("IAP_CREATE_ORDER_FAILED", "Create order failed")
    end
    if order_result.success == false then
        local err_message = order_result.error
        if type(err_message) == "table" then
            err_message = err_message.message
        end
        return fail_by_key("IAP_CREATE_ORDER_FAILED", tostring(err_message or "Create order failed"))
    end
    return response.ok({ payment_required = true, order = order_result })
end

-- 创建 SVIP 购买订单。
function M.rpc_purchase_svip(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    if not iap_service or type(iap_service.rpc_create_order) ~= "function" then
        return fail_by_key("IAP_SERVICE_NOT_WIRED", "IAP service not wired")
    end
    local provider = req.provider or "mock"
    local order_payload = nk.json_encode({
        product_id = req.product_id or "com.game.svip_monthly_card",
        provider = provider
    })
    local order_raw = iap_service.rpc_create_order(context, order_payload)
    local ok_decode, order_result = pcall(nk.json_decode, order_raw or "")
    if not ok_decode or type(order_result) ~= "table" then
        return fail_by_key("IAP_CREATE_ORDER_FAILED", "Create order failed")
    end
    if order_result.success == false then
        local err_message = order_result.error
        if type(err_message) == "table" then
            err_message = err_message.message
        end
        return fail_by_key("IAP_CREATE_ORDER_FAILED", tostring(err_message or "Create order failed"))
    end
    return response.ok({ payment_required = true, order = order_result })
end

-- 领取 VIP 每日奖励。
function M.rpc_claim_vip_daily(context, payload)
    if not vip_domain then return service_not_wired() end
    local ok, err = vip_domain.claim_vip_daily(context, context.user_id)
    if not ok then return fail_by_domain_error(err, "COMMON_INTERNAL_ERROR") end
    return response.ok()
end

-- 领取 SVIP 每日奖励。
function M.rpc_claim_svip_daily(context, payload)
    if not vip_domain then return service_not_wired() end
    local ok, err = vip_domain.claim_svip_daily(context, context.user_id)
    if not ok then return fail_by_domain_error(err, "COMMON_INTERNAL_ERROR") end
    return response.ok()
end

-- 一键领取 VIP/SVIP 每日奖励。
function M.rpc_claim_all_daily(context, payload)
    if not vip_domain then return service_not_wired() end
    local ok, err = vip_domain.claim_all_daily(context, context.user_id)
    if not ok then return fail_by_domain_error(err, "VIP_NO_PENDING_REWARD") end
    return response.ok()
end

-- 获取 VIP/SVIP 激活状态与剩余天数。
function M.rpc_get_vip_status(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.get_vip_status(context, context.user_id))
end

-- 获取运行态快照（特权与日切状态）。
function M.rpc_get_runtime_snapshot(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.get_runtime_snapshot(context, context.user_id))
end

-- 校验复活权限。
function M.rpc_check_revive_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_revive_permission(context, context.user_id))
end

-- 记录复活使用次数。
function M.rpc_record_revive_usage(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    return nk.json_encode({ success = vip_domain.record_revive_usage(context, context.user_id, req.used_ad) })
end

-- 校验扫荡权限。
function M.rpc_check_sweep_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_sweep_permission(context, context.user_id))
end

-- 记录扫荡使用次数。
function M.rpc_record_sweep_usage(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode({ success = vip_domain.record_sweep_usage(context, context.user_id) })
end

-- 校验磁铁权限。
function M.rpc_check_magnet_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_magnet_permission(context, context.user_id))
end

-- 校验掠夺权限。
function M.rpc_check_plunder_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_plunder_permission(context, context.user_id))
end

-- 记录掠夺使用次数（含广告分支）。
function M.rpc_record_plunder_usage(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    return nk.json_encode({ success = vip_domain.record_plunder_usage(context, context.user_id, req.is_ad) })
end

-- 校验额外队列权限。
function M.rpc_check_queue_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_queue_permission(context, context.user_id))
end

return M
