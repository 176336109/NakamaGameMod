local nk = require("nakama")

local M = {}
local backpack_domain = nil

function M.wire(backpack)
    backpack_domain = backpack
end

local function fail(code, message)
    return nk.json_encode({
        success = false,
        error = {
            code = code,
            message = message
        }
    })
end

local function service_ready()
    return backpack_domain ~= nil
end

function M.rpc_debug_add_items(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    local user_id = context.user_id
    local items = nk.json_decode(payload)
    local success, result_or_err = backpack_domain.add_items(context, user_id, items, "debug", { rpc = "debug_add_items" })
    if not success then
        return fail("DEBUG_ADD_FAILED", tostring(result_or_err))
    end
    return nk.json_encode({ success = true, result = result_or_err })
end

function M.rpc_wallet_get(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_wallet_get(context, payload)
end

function M.rpc_inventory_get_items(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_inventory_get_items(context, payload)
end

function M.rpc_inventory_list(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_inventory_list(context, payload)
end

function M.rpc_inventory_get_item_defs(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_inventory_get_item_defs(context, payload)
end

function M.rpc_inventory_get_all_info(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_inventory_get_all_info(context, payload)
end

function M.rpc_inventory_log_list(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_inventory_log_list(context, payload)
end

function M.rpc_backpack_grant(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_backpack_grant(context, payload)
end

function M.rpc_backpack_consume(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_backpack_consume(context, payload)
end

function M.rpc_backpack_use(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_backpack_use(context, payload)
end

function M.rpc_backpack_cleanup(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_backpack_cleanup(context, payload)
end

function M.rpc_backpack_get_state(context, payload)
    if not service_ready() then
        return fail("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return backpack_domain.rpc_backpack_get_state(context, payload)
end

return M
