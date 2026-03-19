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

local function load_items_from_json()
    local decoded = load_json_file("items.json")
    if decoded ~= nil and type(decoded.items) == "table" then
        return decoded.items
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

-- NakamaMod/config.lua
-- 职责：集中存放 Mod 的静态配置数据（道具、抽卡、签到、内购商品、管理端参数等）。
-- 使用方式：业务模块通过 require("config") 读取本表；本文件不应包含运行时逻辑。

-- 道具/货币/角色定义表
local fallback_items = {
    ["1"] = { type = "currency", name = "金币", itemDesc = "金币说明" },
    ["2"] = { type = "currency", name = "水晶", itemDesc = "水晶说明" },
    ["gold"] = { type = "currency", name = "金币", itemDesc = "金币说明" },
    ["gem"] = { type = "currency", name = "水晶", itemDesc = "水晶说明" },
    ["energy"] = { type = "currency", name = "Energy", itemDesc = "Energy说明" },
    ["item_diamond"] = { type = "currency", name = "Diamond", itemDesc = "Diamond说明" },
    ["item_gold"] = { type = "currency", name = "Gold Coin", itemDesc = "Gold Coin说明" },
    ["item_vip_active"] = { type = "time_limited", name = "VIP Monthly Card", itemDesc = "VIP Monthly Card说明", max_stack = 1 },
    ["item_svip_active"] = { type = "time_limited", name = "SVIP Monthly Card", itemDesc = "SVIP Monthly Card说明", max_stack = 1 },
    ["exp_potion"] = { type = "item", name = "EXP Potion", itemDesc = "EXP Potion说明", max_stack = 999 },
    ["hero_ssr_001"] = { type = "hero", name = "SSR Knight", itemDesc = "SSR Knight说明", rarity = "SSR" },
    ["hero_sr_001"] = { type = "hero", name = "SR Archer", itemDesc = "SR Archer说明", rarity = "SR" },
    ["hero_r_001"] = { type = "hero", name = "R Soldier", itemDesc = "R Soldier说明", rarity = "R" },
    ["010300001"] = { type = "item", name = "时光沙漏", itemDesc = "时光沙漏说明", max_stack = 9999 },
    ["020100001"] = { type = "item", name = "技能碎片1", itemDesc = "技能碎片说明", max_stack = 999 },
    ["020200001"] = { type = "item", name = "技能碎片2", itemDesc = "技能碎片说明", max_stack = 999 },
    ["020300001"] = { type = "item", name = "技能碎片3", itemDesc = "技能碎片说明", max_stack = 999 },
    ["020400001"] = { type = "item", name = "技能碎片4", itemDesc = "技能碎片说明", max_stack = 999 },
    ["020500001"] = { type = "item", name = "技能碎片5", itemDesc = "技能碎片说明", max_stack = 999 },
    ["030100001"] = { type = "item", name = "改装件碎片6", itemDesc = "改装件碎片说明", max_stack = 999 },
    ["030200001"] = { type = "item", name = "改装件碎片7", itemDesc = "改装件碎片说明", max_stack = 999 },
    ["030300001"] = { type = "item", name = "改装件碎片8", itemDesc = "改装件碎片说明", max_stack = 999 },
    ["030400001"] = { type = "item", name = "改装件碎片9", itemDesc = "改装件碎片说明", max_stack = 999 },
    ["030500001"] = { type = "item", name = "改装件碎片10", itemDesc = "改装件碎片说明", max_stack = 999 },
    ["PACK_GROWTH_001"] = { type = "item", name = "Growth Gift Pack", itemDesc = "Growth Gift Pack说明", max_stack = 1 },
}

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

-- 权益配置（月卡奖励、特权等）
M.benefit_plans = {
    ["vip_monthly"] = {
        id = "vip_monthly",
        immediateItems = { { id = "item_diamond", count = 180 } },
        dailyItems = { { id = "item_diamond", count = 30 } },
        privileges = {
            reviveLimit = 4,
            reviveNeedsAd = true,
            sweepLimit = 5,
            queueExtraEnabled = false,
            magnetNeedsAd = false,
            plunderBaseLimit = 1,
            plunderAdLimit = 1,
            svipBadgeEnabled = false
        }
    },
    ["svip_monthly"] = {
        id = "svip_monthly",
        immediateItems = { { id = "item_diamond", count = 300 } },
        dailyItems = {
            { id = "item_diamond", count = 60 },
            { id = "010300001",    count = 3 }
        },
        privileges = {
            reviveLimit = 3,
            reviveNeedsAd = false,
            sweepLimit = 50,
            queueExtraEnabled = true,
            magnetNeedsAd = true,
            plunderBaseLimit = 2,
            plunderAdLimit = 1,
            svipBadgeEnabled = true
        }
    }
}

-- 签到配置 (V1.1 - 7天循环)
M.checkin = {
    -- 7天周期奖励表
    rewards = {
        [1] = { { item_id = "gold", count = 100 } },
        [2] = { { item_id = "gem", count = 50 } },
        [3] = { { item_id = "010300001", count = 1 } },
        [4] = { { item_id = "020100001", count = 5 } }, -- 绿色技能碎片
        [5] = { { item_id = "030100001", count = 3 } }, -- 绿色改装件碎片
        [6] = { { item_id = "gold", count = 200 }, { item_id = "gem", count = 30 } },
        [7] = { { item_id = "010300001", count = 2 } },
    },
    makeup_cost = { item_id = "gem", count = 20 },
}

-- 商店配置
M.shop = {
    refresh_cost = { item_id = "item_diamond", count = 5 },
    goods = {
        -- 特惠商店（Special Shop）
        ["SHOP_SKILL_GREEN_5"] = {
            shopType = "special",
            displayMode = "random",
            weight = 100,
            costType = "gold",
            costValue = 200,
            limitType = "per_refresh",
            limitValue = 1,
            rewardItems = { { id = "020100001", count = 5 } }
        },
        ["SHOP_SKILL_BLUE_3"] = {
            shopType = "special",
            displayMode = "random",
            weight = 50,
            costType = "gold",
            costValue = 400,
            limitType = "per_refresh",
            limitValue = 1,
            rewardItems = { { id = "020200001", count = 3 } }
        },
        ["SHOP_SKILL_PURPLE_1"] = {
            shopType = "special",
            displayMode = "random",
            weight = 10,
            costType = "item_diamond",
            costValue = 15,
            limitType = "per_refresh",
            limitValue = 1,
            rewardItems = { { id = "020300001", count = 1 } }
        },
        ["SHOP_MOD_GREEN_5"] = {
            shopType = "special",
            displayMode = "random",
            weight = 100,
            costType = "gold",
            costValue = 200,
            limitType = "per_refresh",
            limitValue = 1,
            rewardItems = { { id = "030100001", count = 5 } }
        },
        ["SHOP_MOD_BLUE_3"] = {
            shopType = "special",
            displayMode = "random",
            weight = 50,
            costType = "gold",
            costValue = 400,
            limitType = "per_refresh",
            limitValue = 1,
            rewardItems = { { id = "030200001", count = 3 } }
        },
        ["SHOP_TIMESAND_1"] = {
            shopType = "special",
            displayMode = "random",
            weight = 20,
            costType = "item_diamond",
            costValue = 5,
            limitType = "per_refresh",
            limitValue = 1,
            rewardItems = { { id = "010300001", count = 1 } }
        },

        -- 固定展示限购商品
        ["SHOP_SKILL_GOLD_WEEK"] = {
            shopType = "special",
            displayMode = "fixed",
            costType = "item_diamond",
            costValue = 30,
            limitType = "weekly",
            limitValue = 1,
            rewardItems = { { id = "020300001", count = 1 } } -- 示例配置，实际可能变化
        },
        ["SHOP_GROWTH_GIFT_PERM"] = {
            shopType = "special",
            displayMode = "fixed",
            costType = "item_diamond",
            costValue = 30,
            limitType = "permanent",
            limitValue = 1,
            rewardItems = { { id = "gold", count = 500 }, { id = "010300001", count = 2 } }
        },

        -- 水晶商店（Crystal Shop）- IAP
        ["CRYSTAL_001"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 600, rewardItems = { { id = "item_diamond", count = 60 } } },
        ["CRYSTAL_002"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 1800, rewardItems = { { id = "item_diamond", count = 180 } } },
        ["CRYSTAL_003"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 3000, rewardItems = { { id = "item_diamond", count = 300 } } },
        ["CRYSTAL_004"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 6800, rewardItems = { { id = "item_diamond", count = 700 } } }, -- 含赠送
        ["CRYSTAL_005"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 9800, rewardItems = { { id = "item_diamond", count = 1030 } } },
        ["CRYSTAL_006"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 19800, rewardItems = { { id = "item_diamond", count = 2130 } } },
        ["CRYSTAL_007"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 32800, rewardItems = { { id = "item_diamond", count = 3630 } } },
        ["CRYSTAL_008"] = { shopType = "crystal", displayMode = "iap", costType = "rmb", costValue = 64800, rewardItems = { { id = "item_diamond", count = 7480 } } },

        -- 金币商店（Gold Shop）
        ["GOLD_001"] = {
            shopType = "gold",
            displayMode = "exchange",
            costType = "item_diamond",
            costValue = 1,
            limitType = "none",
            limitValue = 0,
            rewardItems = { { id = "gold", count = 25 } }
        },
        ["GOLD_002"] = {
            shopType = "gold",
            displayMode = "exchange",
            costType = "item_diamond",
            costValue = 10,
            limitType = "daily",
            limitValue = 1,
            rewardItems = { { id = "gold", count = 250 } }
        },
        ["GOLD_003"] = {
            shopType = "gold",
            displayMode = "exchange",
            costType = "item_diamond",
            costValue = 50,
            limitType = "daily",
            limitValue = 1,
            rewardItems = { { id = "gold", count = 1300 } }
        },
        ["GOLD_004"] = {
            shopType = "gold",
            displayMode = "exchange",
            costType = "item_diamond",
            costValue = 100,
            limitType = "daily",
            limitValue = 1,
            rewardItems = { { id = "gold", count = 2800 } }
        },
        ["GOLD_005"] = {
            shopType = "gold",
            displayMode = "exchange",
            costType = "item_diamond",
            costValue = 500,
            limitType = "daily",
            limitValue = 1,
            rewardItems = { { id = "gold", count = 15000 } }
        },
    }
}

-- 内购商品配置（SKU -> 奖励/时长）
M.iap_products = {
    ["gold_pack_1"] = {
        rewards = { { id = "gold", count = 100 } }
    },
    ["com.game.gem_pack_1"] = {
        rewards = { { id = "gem", count = 100 } }
    },
    ["com.game.gem_pack_2"] = {
        rewards = { { id = "gem", count = 550 } }
    },
    ["com.game.monthly_card"] = {
        rewards = { { id = "gem", count = 300 } },
        duration_days = 30,
        benefit_plan_id = "vip_monthly"
    },
    ["com.game.svip_monthly_card"] = {
        rewards = { { id = "gem", count = 300 } },
        duration_days = 30,
        benefit_plan_id = "svip_monthly"
    }
}

local shop_json = load_json_file("shop.json")
if shop_json == nil or type(shop_json.goods) ~= "table" or type(shop_json.refresh_cost) ~= "table" then
    error("FAILED_TO_LOAD_SHOP_JSON: shop.json not found/readable or invalid")
end
M.shop = shop_json

local vip_json = load_json_file("vip.json")
if vip_json == nil or type(vip_json.benefit_plans) ~= "table" or type(vip_json.iap_products) ~= "table" then
    error("FAILED_TO_LOAD_VIP_JSON: vip.json not found/readable or invalid")
end
M.benefit_plans = vip_json.benefit_plans
M.iap_products = vip_json.iap_products

local checkin_json = load_json_file("checkin.json")
if checkin_json == nil or type(checkin_json.rewards) ~= "table" or type(checkin_json.makeup_cost) ~= "table" then
    error("FAILED_TO_LOAD_CHECKIN_JSON: checkin.json not found/readable or invalid")
end
M.checkin = checkin_json
M.checkin.rewards = normalize_number_key_table(M.checkin.rewards)

-- 管理端相关配置
M.admin = {
    inventory_log_admin_token = "",
    inventory_log_user_whitelist = {}
}

M.paygateway_api_url = "http://host.docker.internal:8080"

return M
