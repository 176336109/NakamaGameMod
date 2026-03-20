local nk = require("nakama")

local M = {}
local vip_domain = nil
local iap_domain = nil
local iap_service = nil

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

function M.set_iap_service(service)
    iap_service = service
end

local function decode_payload(payload)
    if payload and payload ~= "" then
        local ok, req = pcall(function() return nk.json_decode(payload) end)
        if ok and type(req) == "table" then
            return req
        end
    end
    return {}
end

local function service_not_wired()
    return nk.json_encode({ error = "VIP service not wired" })
end

function M.rpc_purchase_vip(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    if not iap_service or type(iap_service.rpc_create_order) ~= "function" then
        return nk.json_encode({ error = "IAP service not wired" })
    end
    local provider = req.provider or "mock"
    local order_payload = nk.json_encode({
        product_id = req.product_id or "com.game.monthly_card",
        provider = provider
    })
    local order_raw = iap_service.rpc_create_order(context, order_payload)
    local ok_decode, order_result = pcall(nk.json_decode, order_raw or "")
    if not ok_decode or type(order_result) ~= "table" then
        return nk.json_encode({ success = false, error = "Create order failed" })
    end
    if order_result.success == false then
        return nk.json_encode({ success = false, error = order_result.error or "Create order failed" })
    end
    return nk.json_encode({ success = true, payment_required = true, order = order_result })
end

function M.rpc_purchase_svip(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    if not iap_service or type(iap_service.rpc_create_order) ~= "function" then
        return nk.json_encode({ error = "IAP service not wired" })
    end
    local provider = req.provider or "mock"
    local order_payload = nk.json_encode({
        product_id = req.product_id or "com.game.svip_monthly_card",
        provider = provider
    })
    local order_raw = iap_service.rpc_create_order(context, order_payload)
    local ok_decode, order_result = pcall(nk.json_decode, order_raw or "")
    if not ok_decode or type(order_result) ~= "table" then
        return nk.json_encode({ success = false, error = "Create order failed" })
    end
    if order_result.success == false then
        return nk.json_encode({ success = false, error = order_result.error or "Create order failed" })
    end
    return nk.json_encode({ success = true, payment_required = true, order = order_result })
end

function M.rpc_claim_vip_daily(context, payload)
    if not vip_domain then return service_not_wired() end
    local ok, err = vip_domain.claim_vip_daily(context, context.user_id)
    if not ok then return nk.json_encode({ error = err }) end
    return nk.json_encode({ success = true })
end

function M.rpc_claim_svip_daily(context, payload)
    if not vip_domain then return service_not_wired() end
    local ok, err = vip_domain.claim_svip_daily(context, context.user_id)
    if not ok then return nk.json_encode({ error = err }) end
    return nk.json_encode({ success = true })
end

function M.rpc_claim_all_daily(context, payload)
    if not vip_domain then return service_not_wired() end
    local ok, err = vip_domain.claim_all_daily(context, context.user_id)
    if not ok then return nk.json_encode({ error = err }) end
    return nk.json_encode({ success = true })
end

function M.rpc_get_vip_status(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.get_vip_status(context, context.user_id))
end

function M.rpc_check_revive_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_revive_permission(context, context.user_id))
end

function M.rpc_record_revive_usage(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    return nk.json_encode({ success = vip_domain.record_revive_usage(context, context.user_id, req.used_ad) })
end

function M.rpc_check_sweep_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_sweep_permission(context, context.user_id))
end

function M.rpc_record_sweep_usage(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode({ success = vip_domain.record_sweep_usage(context, context.user_id) })
end

function M.rpc_check_magnet_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_magnet_permission(context, context.user_id))
end

function M.rpc_check_plunder_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_plunder_permission(context, context.user_id))
end

function M.rpc_record_plunder_usage(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    return nk.json_encode({ success = vip_domain.record_plunder_usage(context, context.user_id, req.is_ad) })
end

function M.rpc_check_queue_permission(context, payload)
    if not vip_domain then return service_not_wired() end
    return nk.json_encode(vip_domain.check_queue_permission(context, context.user_id))
end

function M.rpc_debug_simulate_purchase(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    local ok, result = vip_domain.debug_simulate_purchase(context, context.user_id, req.plan_id)
    if not ok then
        return nk.json_encode({ error = result })
    end
    return nk.json_encode(result)
end

return M
