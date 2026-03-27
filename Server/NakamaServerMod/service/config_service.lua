local nk = require("nakama")
local config = require("config")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}

local SUPPORTED = {
    checkin = true,
    gift = true,
    items = true,
    shop = true,
    vip = true
}

-- 统一按错误码键构造失败响应。
local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
end

-- 解析 RPC 入参，解析失败时返回空表以便走默认分支。
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

-- 基于 UTF-8 字节流计算 rolling hash，供客户端比对篡改。
local function calc_hash(text)
    local mod = 2147483647
    local h = 0
    local len = string.len(text or "")
    for i = 1, len do
        h = (h * 131 + string.byte(text, i)) % mod
    end
    return string.format("%08x", h)
end

-- 根据配置名称返回对应配置对象。
local function build_data(name)
    if name == "checkin" then
        return config.checkin
    end
    if name == "gift" then
        return config.gift
    end
    if name == "items" then
        return config.items
    end
    if name == "shop" then
        return config.shop
    end
    if name == "vip" then
        return {
            benefit_plans = config.benefit_plans,
            iap_products = config.iap_products
        }
    end
    return nil
end

-- 统一配置读取入口：支持按名称读取，或空 name 返回全部配置。
function M.rpc_config_get(context, payload)
    local req = decode_payload(payload)
    local name = req.name
    if name == nil or name == "" then
        local all = {
            checkin = build_data("checkin"),
            gift = build_data("gift"),
            items = build_data("items"),
            shop = build_data("shop"),
            vip = build_data("vip")
        }
        local json = nk.json_encode(all)
        return response.ok({
            name = "all",
            json = json,
            hash = calc_hash(json),
            config_id = "all",
            content_length = string.len(json)
        })
    end
    if type(name) ~= "string" or not SUPPORTED[name] then
        return fail_by_key("COMMON_INVALID_PARAM", "Unsupported config name")
    end
    local data = build_data(name)
    if type(data) ~= "table" then
        return fail_by_key("COMMON_INTERNAL_ERROR", "Config data unavailable")
    end
    local json = nk.json_encode(data)
    return response.ok({
        name = name,
        json = json,
        hash = calc_hash(json),
        config_id = name,
        content_length = string.len(json)
    })
end

return M
