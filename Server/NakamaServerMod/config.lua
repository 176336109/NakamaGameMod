local nk = require("nakama")
local M = {}

local function read_file_text(path)
    if type(nk) == "table" and type(nk.file_read) == "function" then
        local ok_read_nk, text_nk = pcall(nk.file_read, path)
        if ok_read_nk and type(text_nk) == "string" and text_nk ~= "" then
            return text_nk
        end
        local win_path = string.gsub(path, "/", "\\")
        if win_path ~= path then
            local ok_read_nk_win, text_nk_win = pcall(nk.file_read, win_path)
            if ok_read_nk_win and type(text_nk_win) == "string" and text_nk_win ~= "" then
                return text_nk_win
            end
        end
    end
    if type(io) ~= "table" or type(io.open) ~= "function" then
        return nil
    end
    local ok_open, file = pcall(io.open, path, "r")
    if not ok_open then
        return nil
    end
    if file == nil then
        return nil
    end
    local ok_read, text = pcall(file.read, file, "*a")
    pcall(file.close, file)
    if not ok_read then
        return nil
    end
    return text
end

local function build_json_paths(file_name)
    local source_dir = nil
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local ok_info, info = pcall(debug.getinfo, 1, "S")
        if ok_info and type(info) == "table" and type(info.source) == "string" then
            local source = info.source
            if source:sub(1, 1) == "@" then
                source = source:sub(2)
            end
            source_dir = source:match("^(.*[\\/])[^\\/]-$")
        end
    end
    local paths = {
        "data/" .. file_name,
        "./data/" .. file_name,
        "data/modules/data/" .. file_name,
        "./data/modules/data/" .. file_name,
        "data\\modules\\data\\" .. file_name,
        ".\\data\\modules\\data\\" .. file_name,
        "modules/data/" .. file_name,
        "./modules/data/" .. file_name,
        "Server/NakamaServerMod/data/" .. file_name
    }
    if source_dir ~= nil then
        paths[#paths + 1] = source_dir .. "data/" .. file_name
        paths[#paths + 1] = source_dir .. "../data/" .. file_name
    end
    return paths
end

local function load_json_file(file_name)
    local paths = build_json_paths(file_name)
    for _, path in ipairs(paths) do
        local text = read_file_text(path)
        if text ~= nil and text ~= "" then
            local ok, decoded = pcall(nk.json_decode, text)
            if ok and type(decoded) == "table" then
                if type(nk.logger_info) == "function" then
                    nk.logger_info("Loaded " .. file_name .. " from path: " .. path)
                end
                return decoded
            end
        end
    end
    return nil
end

local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = deep_copy(v)
    end
    return out
end

local function is_array(value)
    return type(value) == "table" and #value > 0
end

local function map_by_field(list, key_field)
    local out = {}
    for _, row in ipairs(list or {}) do
        if type(row) == "table" then
            local key = row[key_field]
            if type(key) == "string" and key ~= "" then
                out[key] = row
            end
        end
    end
    return out
end

local function normalize_items(items)
    if not is_array(items) then
        return items or {}
    end
    return map_by_field(items, "itemId")
end

local function normalize_checkin_rewards(rewards)
    if not is_array(rewards) then
        local out = {}
        for k, v in pairs(rewards or {}) do
            local nkv = tonumber(k)
            if nkv ~= nil then
                out[nkv] = v
            else
                out[k] = v
            end
        end
        return out
    end
    local out = {}
    for _, day in ipairs(rewards) do
        if type(day) == "table" then
            local day_index = tonumber(day.dayIndex)
            if day_index ~= nil then
                out[day_index] = day.rewardItems or {}
            end
        end
    end
    return out
end

local function load_items_from_json()
    local decoded = load_json_file("items.json")
    if decoded ~= nil and type(decoded.items) == "table" then
        M.items_raw = deep_copy(decoded)
        return normalize_items(decoded.items)
    end
    return nil
end

local function ensure_item_desc(items)
    for item_id, item_def in pairs(items or {}) do
        if type(item_def) == "table" and item_def.itemDesc == nil then
            item_def.itemDesc = (item_def.name or tostring(item_id) or "item") .. "说明"
        end
    end
end

local function normalize_number_key_table(data)
    local out = {}
    for k, v in pairs(data or {}) do
        local nkv = tonumber(k)
        if nkv ~= nil then
            out[nkv] = v
        else
            out[k] = v
        end
    end
    return out
end

local function normalize_skill_item_configs(rows)
    local by_item = {}
    local max_level_by_item = {}
    for _, row in ipairs(rows or {}) do
        if type(row) == "table" then
            local item_id = tostring(row.itemId or "")
            local level = tonumber(row.level)
            if item_id ~= "" and level ~= nil then
                local normalized_level = math.floor(level)
                if normalized_level > 0 then
                    if type(by_item[item_id]) ~= "table" then
                        by_item[item_id] = {}
                    end
                    by_item[item_id][normalized_level] = row
                    local current_max = tonumber(max_level_by_item[item_id]) or 0
                    if normalized_level > current_max then
                        max_level_by_item[item_id] = normalized_level
                    end
                end
            end
        end
    end
    return by_item, max_level_by_item
end

local function normalize_skill_upgrade_configs(rows)
    local by_item = {}
    for _, row in ipairs(rows or {}) do
        if type(row) == "table" then
            local item_id = tostring(row.itemId or "")
            if item_id ~= "" then
                local copied = deep_copy(row)
                copied.upgradeCostsByLevel = {}
                for _, cost in ipairs(copied.upgradeCosts or {}) do
                    local level = tonumber(cost and cost.level)
                    if level ~= nil then
                        local normalized_level = math.floor(level)
                        if normalized_level > 0 then
                            copied.upgradeCostsByLevel[normalized_level] = cost
                        end
                    end
                end
                by_item[item_id] = copied
            end
        end
    end
    return by_item
end

-- NakamaMod/config.lua
-- 职责：集中存放 Mod 的静态配置数据（道具、抽卡、签到、内购商品、管理端参数等）。
-- 使用方式：业务模块通过 require("config") 读取本表；本文件不应包含运行时逻辑。

M.items = load_items_from_json()
if M.items == nil then
    local has_nk_file_read = type(nk) == "table" and type(nk.file_read) == "function"
    local has_io_open = type(io) == "table" and type(io.open) == "function"
    error("FAILED_TO_LOAD_ITEMS_JSON: items.json not found/readable; nk.file_read=" .. tostring(has_nk_file_read) .. ", io.open=" .. tostring(has_io_open))
end
ensure_item_desc(M.items)

M.backpack = {
    slot_capacity = 100
}

-- 抽卡配置
M.gacha = {
    ["standard_banner"] = {
        cost_item = "gem",
        cost_amount = 100,
        pool = {
            { item_id = "hero_ssr_001", weight = 20,  rarity = "SSR" },
            { item_id = "hero_sr_001",  weight = 180, rarity = "SR" },
            { item_id = "hero_r_001",   weight = 800, rarity = "R" },
        },
        pity_ssr = 90,
        pity_sr = 10,
    }
}

-- 权益配置统一由 data/vip.json 加载，避免使用测试默认值。
M.benefit_plans = {}

-- 商品配置统一由 data/vip.json 与 data/gift.json 构建。
M.iap_products = {}

local shop_json = load_json_file("shop.json")
if shop_json == nil or type(shop_json.goods) ~= "table" or type(shop_json.refresh_cost) ~= "table" then
    error("FAILED_TO_LOAD_SHOP_JSON: shop.json not found/readable or invalid")
end
M.shop_raw = deep_copy(shop_json)
M.shop = deep_copy(shop_json)
if is_array(M.shop.goods) then
    M.shop.goods = map_by_field(M.shop.goods, "goodsId")
end

local vip_json = load_json_file("vip.json")
if vip_json == nil or type(vip_json.benefit_plans) ~= "table" or type(vip_json.monthly_products) ~= "table" then
    error("FAILED_TO_LOAD_VIP_JSON: vip.json not found/readable or invalid")
end
M.vip = vip_json
M.monthly_products = vip_json.monthly_products
M.monthly_products_by_product_id = {}
M.benefit_plans = {}

for _, plan in ipairs(vip_json.benefit_plans) do
    if type(plan) == "table" and type(plan.benefitPlanId) == "string" and plan.benefitPlanId ~= "" then
        M.benefit_plans[plan.benefitPlanId] = plan
    end
end

M.iap_products = {}
for _, product in ipairs(vip_json.monthly_products) do
    if type(product) == "table" and type(product.productId) == "string" and product.productId ~= "" then
        M.monthly_products_by_product_id[product.productId] = product
        M.iap_products[product.productId] = {
            duration_days = product.durationDays,
            benefit_plan_id = product.benefitPlanId,
            item_id = product.itemId,
            cost_type = product.costType,
            cost_amount = product.costAmount,
            name = product.name,
            desc = product.desc
        }
    end
end

local checkin_json = load_json_file("checkin.json")
if checkin_json == nil or type(checkin_json.rewards) ~= "table" or type(checkin_json.makeup_cost) ~= "table" then
    error("FAILED_TO_LOAD_CHECKIN_JSON: checkin.json not found/readable or invalid")
end
M.checkin_raw = deep_copy(checkin_json)
M.checkin = deep_copy(checkin_json)
M.checkin.rewards = normalize_checkin_rewards(M.checkin.rewards)

local gift_json = load_json_file("gift.json")
if gift_json == nil or type(gift_json.packs) ~= "table" then
    error("FAILED_TO_LOAD_GIFT_JSON: gift.json not found/readable or invalid")
end
M.gift_raw = deep_copy(gift_json)
M.gift = deep_copy(gift_json)
if is_array(M.gift.packs) then
    M.gift.packs = map_by_field(M.gift.packs, "packId")
end

for pack_id, pack_cfg in pairs(M.gift.packs) do
    if type(M.iap_products[pack_id]) ~= "table" then
        M.iap_products[pack_id] = {
            rewards = pack_cfg.immediateRewardItems or {}
        }
    end
end

local skill_item_json = load_json_file("skillEnhancementItemConfigs.json")
local skill_upgrade_json = load_json_file("skillEnhancementUpgradeConfigs.json")
if skill_item_json == nil or type(skill_item_json.skillEnhancementItemConfigs) ~= "table" then
    error("FAILED_TO_LOAD_SKILL_ITEM_CONFIGS_JSON: skillEnhancementItemConfigs.json not found/readable or invalid")
end
if skill_upgrade_json == nil or type(skill_upgrade_json.skillEnhancementUpgradeConfigs) ~= "table" then
    error("FAILED_TO_LOAD_SKILL_UPGRADE_CONFIGS_JSON: skillEnhancementUpgradeConfigs.json not found/readable or invalid")
end
M.skill_enhancement_raw = {
    skillEnhancementItemConfigs = deep_copy(skill_item_json.skillEnhancementItemConfigs),
    skillEnhancementUpgradeConfigs = deep_copy(skill_upgrade_json.skillEnhancementUpgradeConfigs)
}
M.skill_enhancement = deep_copy(M.skill_enhancement_raw)
M.skill_enhancement_item_configs_by_item_id, M.skill_enhancement_max_level_by_item_id = normalize_skill_item_configs(M.skill_enhancement.skillEnhancementItemConfigs)
M.skill_enhancement_upgrade_configs_by_item_id = normalize_skill_upgrade_configs(M.skill_enhancement.skillEnhancementUpgradeConfigs)

-- 管理端相关配置
M.admin = {
    inventory_log_admin_token = "",
    inventory_log_user_whitelist = {}
}

M.paygateway_api_url = "http://host.docker.internal:8080"

return M
