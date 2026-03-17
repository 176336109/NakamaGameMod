local nk = require("nakama")

local M = {}
local vip_domain = nil

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
    local days = req.days or 30
    local ok, item_data = vip_domain.purchase_vip(context, context.user_id, days)
    if not ok then return nk.json_encode({ error = item_data }) end
    return nk.json_encode({ success = true, item_data = item_data })
end

function M.rpc_purchase_svip(context, payload)
    if not vip_domain then return service_not_wired() end
    local req = decode_payload(payload)
    local days = req.days or 30
    local ok, item_data = vip_domain.purchase_svip(context, context.user_id, days)
    if not ok then return nk.json_encode({ error = item_data }) end
    return nk.json_encode({ success = true, item_data = item_data })
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
