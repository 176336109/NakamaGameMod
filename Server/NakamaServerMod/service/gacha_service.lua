local nk = require("nakama")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}
local gacha_domain = nil

-- 注入背包网关并完成 gacha domain 依赖装配。
function M.wire_item_gateway(backpack, gacha)
    gacha_domain = gacha
    if gacha_domain and type(gacha_domain.set_item_gateway) == "function" then
        gacha_domain.set_item_gateway(backpack)
    end
end

-- 抽卡 RPC 入口：负责调用 domain、归一错误并输出统一响应结构。
function M.rpc_gacha_pull(context, payload)
    if not gacha_domain or type(gacha_domain.rpc_gacha_pull) ~= "function" then
        local code, message = error_codes.resolve("GACHA_SERVICE_NOT_WIRED", "Gacha service not wired")
        return response.fail(code, message)
    end
    local raw = gacha_domain.rpc_gacha_pull(context, payload)
    local ok, data = pcall(nk.json_decode, raw or "")
    if not ok or type(data) ~= "table" then
        local code, message = error_codes.resolve("COMMON_INTERNAL_ERROR", "Invalid gacha response")
        return response.fail(code, message)
    end
    if data.error ~= nil then
        local err = tostring(data.error)
        local key = "COMMON_INTERNAL_ERROR"
        if err == "Invalid banner ID" then
            key = "GACHA_BANNER_NOT_FOUND"
        elseif string.find(err, "INSUFFICIENT_CURRENCY", 1, true) or string.find(err, "Insufficient", 1, true) then
            key = "GACHA_INSUFFICIENT_CURRENCY"
        elseif err == "Grant rewards failed" then
            key = "GACHA_GRANT_FAILED"
        end
        local code, message = error_codes.resolve(key, err)
        return response.fail(code, message)
    end
    return response.ok(data)
end

return M
