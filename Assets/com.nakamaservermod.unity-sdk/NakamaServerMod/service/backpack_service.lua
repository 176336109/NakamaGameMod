local nk = require("nakama")

local M = {}
local backpack_domain = nil

function M.wire(backpack)
    backpack_domain = backpack
end

function M.rpc_debug_add_items(context, payload)
    local user_id = context.user_id
    local items = nk.json_decode(payload)
    local success, err = backpack_domain.add_items(context, user_id, items, "debug", { rpc = "debug_add_items" })
    if not success then
        return nk.json_encode({ error = err })
    end
    return nk.json_encode({ success = true })
end

function M.rpc_wallet_get(context, payload) return backpack_domain.rpc_wallet_get(context, payload) end
function M.rpc_inventory_get_items(context, payload) return backpack_domain.rpc_inventory_get_items(context, payload) end
function M.rpc_inventory_list(context, payload) return backpack_domain.rpc_inventory_list(context, payload) end

return M
