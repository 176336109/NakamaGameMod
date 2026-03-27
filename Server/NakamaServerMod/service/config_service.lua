local nk = require("nakama")
local config = require("config")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}

-- 统一按错误码键构造失败响应。
local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
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
        return config.vip
    end
    return nil
end

-- 统一配置读取入口：仅返回全量配置。
function M.rpc_config_get(context, payload)
    local all = {
        checkin = build_data("checkin"),
        gift = build_data("gift"),
        items = build_data("items"),
        shop = build_data("shop"),
        vip = build_data("vip")
    }
    if type(all.checkin) ~= "table" or type(all.gift) ~= "table" or type(all.items) ~= "table" or type(all.shop) ~= "table" or type(all.vip) ~= "table" then
        return fail_by_key("COMMON_INTERNAL_ERROR", "Config data unavailable")
    end
    local json = nk.json_encode(all)
    local game_config = {
        checkin = nk.json_encode(all.checkin),
        gift = nk.json_encode(all.gift),
        items = nk.json_encode(all.items),
        shop = nk.json_encode(all.shop),
        vip = nk.json_encode(all.vip)
    }
    return response.ok({
        name = "all",
        json = json,
        hash = calc_hash(json),
        config_id = "all",
        content_length = string.len(json),
        game_config = game_config
    })
end

return M
