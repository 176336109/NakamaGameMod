local nk = require("nakama")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}
local gift_domain = nil
local iap_service = nil

local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
end

local function fail_by_gift_error(err, default_key)
    local text = tostring(err or "")
    local key = default_key or "COMMON_INTERNAL_ERROR"
    if string.find(text, "礼包不存在", 1, true) then
        key = "GIFT_NOT_FOUND"
    elseif string.find(text, "限购", 1, true) or string.find(text, "上限", 1, true) then
        key = "GIFT_LIMIT_REACHED"
    elseif string.find(text, "已领取", 1, true) then
        key = "GIFT_ALREADY_CLAIMED"
    elseif string.find(text, "条件", 1, true) then
        key = "GIFT_NOT_ELIGIBLE"
    elseif string.find(text, "发放", 1, true) then
        key = "GIFT_GRANT_FAILED"
    end
    return fail_by_key(key, text)
end

function M.wire_item_gateway(backpack, gift)
    if type(gift) ~= "table" or type(gift.set_item_gateway) ~= "function" then
        return
    end
    gift.set_item_gateway({
        add_items = function(context, user_id, items, source, ref)
            return backpack.add_items(context, user_id, items, source, ref)
        end,
        consume_items = function(context, user_id, items, source, ref)
            return backpack.consume_items(context, user_id, items, source, ref)
        end
    })
    gift_domain = gift
end

function M.set_iap_service(service)
    iap_service = service
end

local function decode_payload(payload)
    if payload and payload ~= "" then
        local ok, req = pcall(function()
            return nk.json_decode(payload)
        end)
        if ok and type(req) == "table" then
            return req
        end
    end
    return {}
end

local function service_not_wired()
    return fail_by_key("GIFT_SERVICE_NOT_WIRED", "Gift service not wired")
end

function M.rpc_gift_get_state(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    local req = decode_payload(payload)
    local state = gift_domain.get_state_data(context.user_id, req.activityId)
    return response.ok(state)
end

function M.rpc_gift_create_order(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    if not iap_service or type(iap_service.rpc_create_order) ~= "function" then
        return fail_by_key("IAP_SERVICE_NOT_WIRED", "IAP service not wired")
    end
    local req = decode_payload(payload)
    local pack_id = req.packId or req.pack_id
    if type(pack_id) ~= "string" or pack_id == "" then
        return fail_by_key("COMMON_INVALID_PARAM", "Missing packId")
    end
    local ok_eligibility, err_eligibility = gift_domain.check_purchase_eligibility(context.user_id, pack_id, req.activityId)
    if not ok_eligibility then
        return fail_by_gift_error(err_eligibility, "GIFT_NOT_ELIGIBLE")
    end
    local order_payload = nk.json_encode({
        product_id = pack_id,
        provider = req.provider or "mock"
    })
    local order_raw = iap_service.rpc_create_order(context, order_payload)
    local ok_decode, order_result = pcall(nk.json_decode, order_raw or "")
    if not ok_decode or type(order_result) ~= "table" then
        return fail_by_key("GIFT_CREATE_ORDER_FAILED", "Create order failed")
    end
    if order_result.success == false then
        local err_message = order_result.error
        if type(err_message) == "table" then
            err_message = err_message.message
        end
        return fail_by_key("GIFT_CREATE_ORDER_FAILED", tostring(err_message or "Create order failed"))
    end
    return response.ok({
        payment_required = true,
        packId = pack_id,
        order = order_result
    })
end

function M.rpc_gift_pay_callback(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    local req = decode_payload(payload)
    local order_id = req.order_id or req.orderId
    local user_id = req.user_id or req.userId
    local pack_id = req.pack_id or req.packId or req.product_id
    if type(order_id) ~= "string" or order_id == "" then
        return fail_by_key("COMMON_INVALID_PARAM", "Missing order_id")
    end
    if type(user_id) ~= "string" or user_id == "" then
        return fail_by_key("COMMON_INVALID_PARAM", "Missing user_id")
    end
    if type(pack_id) ~= "string" or pack_id == "" then
        return fail_by_key("COMMON_INVALID_PARAM", "Missing pack_id")
    end
    local ok, result_or_err = gift_domain.process_paid_purchase(context, user_id, order_id, pack_id, req.activityId)
    if not ok then
        return fail_by_gift_error(result_or_err, "GIFT_GRANT_FAILED")
    end
    return response.ok(result_or_err)
end

function M.rpc_gift_claim_day_reward(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    local req = decode_payload(payload)
    local pack_id = req.packId or req.pack_id
    local day_index = tonumber(req.dayIndex)
    if type(pack_id) ~= "string" or pack_id == "" then
        return fail_by_key("COMMON_INVALID_PARAM", "Missing packId")
    end
    if day_index == nil then
        return fail_by_key("COMMON_INVALID_PARAM", "Missing dayIndex")
    end
    local ok, result_or_err = gift_domain.claim_day_reward(context, context.user_id, pack_id, day_index)
    if not ok then
        return fail_by_gift_error(result_or_err, "GIFT_NOT_ELIGIBLE")
    end
    return response.ok(result_or_err)
end

function M.rpc_gift_debug_unlock_first_recharge(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    local req = decode_payload(payload)
    local unlocked = req.unlocked ~= false
    local result = gift_domain.set_first_recharge_unlocked(context.user_id, unlocked)
    return response.ok(result)
end

return M
