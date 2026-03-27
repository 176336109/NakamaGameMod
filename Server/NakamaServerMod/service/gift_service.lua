local nk = require("nakama")

local M = {}
local gift_domain = nil
local iap_service = nil

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
    return nk.json_encode({ success = false, error = "Gift service not wired" })
end

function M.rpc_gift_get_state(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    local req = decode_payload(payload)
    local state = gift_domain.get_state_data(context.user_id, req.activityId)
    return nk.json_encode(state)
end

function M.rpc_gift_create_order(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    if not iap_service or type(iap_service.rpc_create_order) ~= "function" then
        return nk.json_encode({ success = false, error = "IAP service not wired" })
    end
    local req = decode_payload(payload)
    local pack_id = req.packId or req.pack_id
    if type(pack_id) ~= "string" or pack_id == "" then
        return nk.json_encode({ success = false, error = "Missing packId" })
    end
    local ok_eligibility, err_eligibility = gift_domain.check_purchase_eligibility(context.user_id, pack_id, req.activityId)
    if not ok_eligibility then
        return nk.json_encode({ success = false, error = err_eligibility })
    end
    local order_payload = nk.json_encode({
        product_id = pack_id,
        provider = req.provider or "mock"
    })
    local order_raw = iap_service.rpc_create_order(context, order_payload)
    local ok_decode, order_result = pcall(nk.json_decode, order_raw or "")
    if not ok_decode or type(order_result) ~= "table" then
        return nk.json_encode({ success = false, error = "Create order failed" })
    end
    if order_result.success == false then
        return nk.json_encode({ success = false, error = order_result.error or "Create order failed" })
    end
    return nk.json_encode({
        success = true,
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
        return nk.json_encode({ success = false, error = "Missing order_id" })
    end
    if type(user_id) ~= "string" or user_id == "" then
        return nk.json_encode({ success = false, error = "Missing user_id" })
    end
    if type(pack_id) ~= "string" or pack_id == "" then
        return nk.json_encode({ success = false, error = "Missing pack_id" })
    end
    local ok, result_or_err = gift_domain.process_paid_purchase(context, user_id, order_id, pack_id, req.activityId)
    if not ok then
        return nk.json_encode({ success = false, error = result_or_err })
    end
    return nk.json_encode(result_or_err)
end

function M.rpc_gift_claim_day_reward(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    local req = decode_payload(payload)
    local pack_id = req.packId or req.pack_id
    local day_index = tonumber(req.dayIndex)
    if type(pack_id) ~= "string" or pack_id == "" then
        return nk.json_encode({ success = false, error = "Missing packId" })
    end
    if day_index == nil then
        return nk.json_encode({ success = false, error = "Missing dayIndex" })
    end
    local ok, result_or_err = gift_domain.claim_day_reward(context, context.user_id, pack_id, day_index)
    if not ok then
        return nk.json_encode({ success = false, error = result_or_err })
    end
    return nk.json_encode(result_or_err)
end

function M.rpc_gift_debug_unlock_first_recharge(context, payload)
    if not gift_domain then
        return service_not_wired()
    end
    local req = decode_payload(payload)
    local unlocked = req.unlocked ~= false
    local result = gift_domain.set_first_recharge_unlocked(context.user_id, unlocked)
    return nk.json_encode(result)
end

return M
