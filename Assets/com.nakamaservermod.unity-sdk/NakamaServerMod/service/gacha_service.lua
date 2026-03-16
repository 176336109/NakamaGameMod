local nk = require("nakama")

local M = {}
local gacha_domain = nil

function M.wire(gacha)
    gacha_domain = gacha
end

function M.rpc_gacha_pull(context, payload)
    if not gacha_domain or type(gacha_domain.rpc_gacha_pull) ~= "function" then
        return nk.json_encode({ error = "Gacha service not wired" })
    end
    return gacha_domain.rpc_gacha_pull(context, payload)
end

return M
