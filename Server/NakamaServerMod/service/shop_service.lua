local nk = require("nakama")
local config = require("config")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}
local backpack_gateway = nil
local shop_domain = nil
local iap_service = nil

local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
end

function M.wire_item_gateway(backpack, shop)
    backpack_gateway = backpack
    shop_domain = shop
end

function M.set_iap_service(service)
    iap_service = service
end

local function handle_payment(context, user_id, goods_id, cost_type, cost_value, req)
    if cost_type == "rmb" then
        if not iap_service or type(iap_service.rpc_create_order) ~= "function" then
            return false, fail_by_key("IAP_SERVICE_NOT_WIRED", "IAP service not wired")
        end
        local provider = req.provider or "mock"
        local order_payload = nk.json_encode({
            product_id = req.product_id or goods_id,
            provider = provider
        })
        local order_raw = iap_service.rpc_create_order(context, order_payload)
        local ok_decode, order_result = pcall(nk.json_decode, order_raw or "")
        if not ok_decode or type(order_result) ~= "table" then
            return false, fail_by_key("SHOP_CREATE_ORDER_FAILED", "Create order failed")
        end
        if order_result.success == false then
            local err_message = order_result.error
            if type(err_message) == "table" then
                err_message = err_message.message
            end
            return false, fail_by_key("SHOP_CREATE_ORDER_FAILED", tostring(err_message or "Create order failed"))
        end
        return false, response.ok({
            payment_required = true,
            goodsId = goods_id,
            order = order_result
        })
    end

    local ok_cost, err_cost = backpack_gateway.consume_items(context, user_id, {{ id = cost_type, count = cost_value }}, "shop_buy_" .. goods_id)
    if not ok_cost then
        return false, fail_by_key("WALLET_INSUFFICIENT_GEM", "Insufficient funds: " .. (err_cost or ""))
    end

    return true, nil
end

function M.rpc_shop_get_state(context, payload)
    if not shop_domain or type(shop_domain.get_state_data) ~= "function" then
        return fail_by_key("SHOP_SERVICE_NOT_WIRED", "Shop service not wired")
    end
    local state_data = shop_domain.get_state_data(context.user_id)
    return response.ok(state_data)
end

function M.rpc_shop_refresh(context, payload)
    if not backpack_gateway or not shop_domain then
        return fail_by_key("SHOP_SERVICE_NOT_WIRED", "Shop service not wired")
    end

    local user_id = context.user_id
    local cost_cfg = config.shop.refresh_cost
    local ok, err = backpack_gateway.consume_items(context, user_id, {{ id = cost_cfg.item_id, count = cost_cfg.count }}, "shop_refresh")
    if not ok then
        return fail_by_key("WALLET_INSUFFICIENT_GEM", "Insufficient crystals: " .. (err or ""))
    end

    local snapshot = shop_domain.generate_special_snapshot()
    shop_domain.save_shop_snapshot(user_id, snapshot)
    return response.ok({ snapshot = snapshot })
end

function M.rpc_shop_buy(context, payload)
    if not backpack_gateway or not shop_domain then
        return fail_by_key("SHOP_SERVICE_NOT_WIRED", "Shop service not wired")
    end

    local req = nk.json_decode(payload)
    local goods_id = req.goodsId
    local user_id = context.user_id
    local cfg = config.shop.goods[goods_id]
    if not cfg then
        return fail_by_key("SHOP_GOODS_NOT_FOUND", "Goods not found")
    end

    local today_str = shop_domain.get_beijing_today_str()
    local week_key = shop_domain.get_beijing_week_key()
    local snapshot = shop_domain.load_shop_snapshot(user_id)
    local limit_state, limit_version = shop_domain.load_limit_state(user_id)
    local state = limit_state[goods_id] or { progress = 0 }
    local progress = shop_domain.compute_limit_progress(cfg, state, snapshot.snapshotId, today_str, week_key)
    local limit_type = cfg.limitType or "none"
    local limit_value = tonumber(cfg.limitValue) or 0

    if limit_type ~= "none" and progress >= limit_value then
        return fail_by_key("SHOP_LIMIT_REACHED", "Limit reached")
    end

    local cost_type = cfg.costType
    local cost_value = cfg.costValue
    if cfg.displayMode == "random" then
        local found = false
        for _, entry in ipairs(snapshot.slotEntries) do
            if entry.goodsId == goods_id then
                cost_type = entry.resolvedCostType
                cost_value = entry.resolvedCostValue
                found = true
                break
            end
        end
        if not found then
            return fail_by_key("SHOP_INVALID_PARAM", "Item not in current snapshot")
        end
    end

    local paid, payment_response = handle_payment(context, user_id, goods_id, cost_type, cost_value, req)
    if not paid then
        return payment_response
    end

    local ok_reward, err_reward = backpack_gateway.add_items(context, user_id, cfg.rewardItems, "shop_buy_" .. goods_id)
    if not ok_reward then
        nk.logger_error("Reward grant failed after cost deduction! User: " .. user_id .. " Goods: " .. goods_id)
        return fail_by_key("SHOP_GRANT_FAILED", "Grant reward failed: " .. (err_reward or ""))
    end

    state = shop_domain.apply_limit_progress(cfg, state, snapshot.snapshotId, today_str, week_key)
    limit_state[goods_id] = state
    shop_domain.save_limit_state(user_id, limit_state, limit_version)
    return response.ok({ progress = state.progress })
end

return M
