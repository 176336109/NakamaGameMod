local nk = require("nakama")

local M = {}

function M.ok(data)
    local payload = { success = true }
    if type(data) == "table" then
        for k, v in pairs(data) do
            payload[k] = v
        end
    end
    return nk.json_encode(payload)
end

function M.fail(code, message, extra)
    local payload = {
        success = false,
        error = message,
        error_code = code,
        error_detail = {
            code = code,
            message = message
        }
    }
    if type(extra) == "table" then
        for k, v in pairs(extra) do
            payload[k] = v
        end
    end
    return nk.json_encode(payload)
end

return M
