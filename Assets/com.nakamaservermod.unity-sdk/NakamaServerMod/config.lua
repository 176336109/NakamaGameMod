local M = {}

-- NakamaMod/config.lua
-- 职责：集中存放 Mod 的静态配置数据（道具、抽卡、签到、内购商品、管理端参数等）。
-- 使用方式：业务模块通过 require("config") 读取本表；本文件不应包含运行时逻辑。

-- 道具/货币/角色定义表
M.items = {
    ["gold"] = { type = "currency", name = "Gold Coin" },
    ["gem"] = { type = "currency", name = "Gem" },
    ["energy"] = { type = "currency", name = "Energy" },
    ["item_diamond"] = { type = "currency", name = "Diamond" },
    ["item_gold"] = { type = "currency", name = "Gold Coin" },
    ["item_vip_active"] = { type = "time_limited", name = "VIP Monthly Card", max_stack = 1 },
    ["item_svip_active"] = { type = "time_limited", name = "SVIP Monthly Card", max_stack = 1 },
    ["exp_potion"] = { type = "item", name = "EXP Potion", max_stack = 999 },
    ["hero_ssr_001"] = { type = "hero", name = "SSR Knight", rarity = "SSR" },
    ["hero_sr_001"] = { type = "hero", name = "SR Archer", rarity = "SR" },
    ["hero_r_001"] = { type = "hero", name = "R Soldier", rarity = "R" },
    ["010300001"] = { type = "item", name = "Time Hourglass", max_stack = 9999 },
    ["020100001"] = { type = "item", name = "Skill Shard (Green)", max_stack = 999 },
    ["020200001"] = { type = "item", name = "Skill Shard (Blue)", max_stack = 999 },
    ["020300001"] = { type = "item", name = "Skill Shard (Purple)", max_stack = 999 },
    ["030100001"] = { type = "item", name = "Mod Shard (Green)", max_stack = 999 },
    ["030200001"] = { type = "item", name = "Mod Shard (Blue)", max_stack = 999 },
    ["PACK_GROWTH_001"] = { type = "item", name = "Growth Gift Pack", max_stack = 1 },
}

M.backpack = {
    slot_capacity = 100
}

-- 抽卡配置
M.gacha = {
    ["standard_banner"] = {
        cost_item = "gem",
        cost_amount = 100,
        pool = {
            { item_id = "hero_ssr_001", weight = 20, rarity = "SSR" },
            { item_id = "hero_sr_001", weight = 180, rarity = "SR" },
            { item_id = "hero_r_001", weight = 800, rarity = "R" },
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
            { id = "010300001", count = 3 }
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
            shopType = "special", displayMode = "random", weight = 100,
            costType = "gold", costValue = 200,
            limitType = "per_refresh", limitValue = 1,
            rewardItems = { { id = "020100001", count = 5 } }
        },
        ["SHOP_SKILL_BLUE_3"] = {
            shopType = "special", displayMode = "random", weight = 50,
            costType = "gold", costValue = 400,
            limitType = "per_refresh", limitValue = 1,
            rewardItems = { { id = "020200001", count = 3 } }
        },
        ["SHOP_SKILL_PURPLE_1"] = {
            shopType = "special", displayMode = "random", weight = 10,
            costType = "item_diamond", costValue = 15,
            limitType = "per_refresh", limitValue = 1,
            rewardItems = { { id = "020300001", count = 1 } }
        },
        ["SHOP_MOD_GREEN_5"] = {
            shopType = "special", displayMode = "random", weight = 100,
            costType = "gold", costValue = 200,
            limitType = "per_refresh", limitValue = 1,
            rewardItems = { { id = "030100001", count = 5 } }
        },
        ["SHOP_MOD_BLUE_3"] = {
            shopType = "special", displayMode = "random", weight = 50,
            costType = "gold", costValue = 400,
            limitType = "per_refresh", limitValue = 1,
            rewardItems = { { id = "030200001", count = 3 } }
        },
        ["SHOP_TIMESAND_1"] = {
            shopType = "special", displayMode = "random", weight = 20,
            costType = "item_diamond", costValue = 5,
            limitType = "per_refresh", limitValue = 1,
            rewardItems = { { id = "010300001", count = 1 } }
        },
        
        -- 固定展示限购商品
        ["SHOP_SKILL_GOLD_WEEK"] = {
            shopType = "special", displayMode = "fixed",
            costType = "item_diamond", costValue = 30,
            limitType = "weekly", limitValue = 1,
            rewardItems = { { id = "020300001", count = 1 } } -- 示例配置，实际可能变化
        },
        ["SHOP_GROWTH_GIFT_PERM"] = {
            shopType = "special", displayMode = "fixed",
            costType = "item_diamond", costValue = 30,
            limitType = "permanent", limitValue = 1,
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
            shopType = "gold", displayMode = "exchange",
            costType = "item_diamond", costValue = 1,
            limitType = "none", limitValue = 0,
            rewardItems = { { id = "gold", count = 25 } }
        },
        ["GOLD_002"] = {
            shopType = "gold", displayMode = "exchange",
            costType = "item_diamond", costValue = 10,
            limitType = "daily", limitValue = 1,
            rewardItems = { { id = "gold", count = 250 } }
        },
        ["GOLD_003"] = {
            shopType = "gold", displayMode = "exchange",
            costType = "item_diamond", costValue = 50,
            limitType = "daily", limitValue = 1,
            rewardItems = { { id = "gold", count = 1300 } }
        },
        ["GOLD_004"] = {
            shopType = "gold", displayMode = "exchange",
            costType = "item_diamond", costValue = 100,
            limitType = "daily", limitValue = 1,
            rewardItems = { { id = "gold", count = 2800 } }
        },
        ["GOLD_005"] = {
            shopType = "gold", displayMode = "exchange",
            costType = "item_diamond", costValue = 500,
            limitType = "daily", limitValue = 1,
            rewardItems = { { id = "gold", count = 15000 } }
        },
    }
}

-- 内购商品配置（SKU -> 奖励/时长）
M.iap_products = {
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

-- 管理端相关配置
M.admin = {
    inventory_log_admin_token = "",
    inventory_log_user_whitelist = {}
}

return M
