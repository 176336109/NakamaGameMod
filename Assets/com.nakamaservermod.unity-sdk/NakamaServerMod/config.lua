local M = {}

-- NakamaMod/config.lua
-- 职责：集中存放 Mod 的静态配置数据（道具、抽卡、签到、内购商品、管理端参数等）。
-- 使用方式：业务模块通过 require("config") 读取本表；本文件不应包含运行时逻辑。
--
-- 配置结构概览：
-- - M.items        道具/货币/角色等基础定义（用于校验、展示名、堆叠规则等）
-- - M.gacha        抽卡卡池配置（消耗、权重、保底等）
-- - M.checkin      签到配置（门槛策略、奖励表、补签消耗、兼容旧结构）
-- - M.iap_products 内购 SKU 配置（发放奖励、月卡时长等）
-- - M.admin        管理端相关参数（日志查看鉴权、白名单等）
--
-- 字段命名说明：
-- - id/item_id：统一指向 M.items 中的键
-- - count/Num：数量
-- - weight：抽取权重（相对值，按池内总权重归一化）

-- 道具/货币/角色定义表
-- - type：分类（currency/item/hero...，由业务逻辑解释）
-- - name：展示名（示例值，可按需替换为本地化文本）
-- - max_stack：最大堆叠数量（仅对可堆叠物品有意义）
-- - rarity：稀有度（示例字段，通常用于抽卡展示/掉落规则）
M.items = {
    ["gold"] = { type = "currency", name = "Gold Coin" },
    ["gem"] = { type = "currency", name = "Gem" },
    ["energy"] = { type = "currency", name = "Energy" },
    ["exp_potion"] = { type = "item", name = "EXP Potion", max_stack = 999 },
    ["hero_ssr_001"] = { type = "hero", name = "SSR Knight", rarity = "SSR" },
    ["hero_sr_001"] = { type = "hero", name = "SR Archer", rarity = "SR" },
    ["hero_r_001"] = { type = "hero", name = "R Soldier", rarity = "R" },
}

-- 抽卡配置
-- - cost_item/cost_amount：单次抽取消耗（道具与数量）
-- - pool：奖池列表
--   - item_id：产出物品 ID（指向 M.items）
--   - weight：权重（越大越容易抽中）
--   - rarity：稀有度标签（用于展示/统计/保底逻辑，具体含义由业务模块决定）
-- - pity_ssr/pity_sr：保底阈值（单位通常为“抽数”，以业务模块实现为准）
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

-- 签到配置
-- - gating_mode：奖励门槛模式（示例：vip / pass）
-- - gate_level_strategy：如何读取“等级/通行证等级”等门槛值
--   - source：数据来源（示例：wallet）
--   - key：来源内字段名（示例：vip_level）
--   - default：缺省值（当未找到字段时使用）
-- - rewards：签到日奖励表（键为天数，从 1 开始）
--   - Reward_Item：奖励物品 ID（指向 M.items）
--   - Num：奖励数量
--   - VIP_Level_Req：领取所需门槛等级（字段名保留以兼容既有逻辑）
-- - makeup_cost：补签消耗（Cost_Item/Num）
-- - legacy：旧版奖励结构（保留用于兼容历史实现或迁移）
M.checkin = {
    gating_mode = "vip",
    gate_level_strategy = {
        vip = { source = "wallet", key = "vip_level", default = 0 },
        pass = { source = "wallet", key = "pass_level", default = 0 },
    },
    rewards = {
        [1] = { Reward_Item = "gold", Num = 1000, VIP_Level_Req = 0 },
        [2] = { Reward_Item = "gem", Num = 10, VIP_Level_Req = 0 },
        [3] = { Reward_Item = "exp_potion", Num = 5, VIP_Level_Req = 0 },
        [4] = { Reward_Item = "gold", Num = 1500, VIP_Level_Req = 0 },
        [5] = { Reward_Item = "gem", Num = 15, VIP_Level_Req = 0 },
        [6] = { Reward_Item = "exp_potion", Num = 8, VIP_Level_Req = 0 },
        [7] = { Reward_Item = "hero_r_001", Num = 1, VIP_Level_Req = 1 },
        [8] = { Reward_Item = "gold", Num = 2000, VIP_Level_Req = 0 },
        [9] = { Reward_Item = "gem", Num = 20, VIP_Level_Req = 0 },
        [10] = { Reward_Item = "exp_potion", Num = 10, VIP_Level_Req = 0 },
        [11] = { Reward_Item = "gold", Num = 2500, VIP_Level_Req = 0 },
        [12] = { Reward_Item = "gem", Num = 25, VIP_Level_Req = 0 },
        [13] = { Reward_Item = "exp_potion", Num = 12, VIP_Level_Req = 0 },
        [14] = { Reward_Item = "hero_sr_001", Num = 1, VIP_Level_Req = 1 },
        [15] = { Reward_Item = "gold", Num = 3000, VIP_Level_Req = 0 },
        [16] = { Reward_Item = "gem", Num = 30, VIP_Level_Req = 0 },
        [17] = { Reward_Item = "exp_potion", Num = 15, VIP_Level_Req = 0 },
        [18] = { Reward_Item = "gold", Num = 3500, VIP_Level_Req = 0 },
        [19] = { Reward_Item = "gem", Num = 35, VIP_Level_Req = 0 },
        [20] = { Reward_Item = "exp_potion", Num = 18, VIP_Level_Req = 0 },
        [21] = { Reward_Item = "hero_sr_001", Num = 1, VIP_Level_Req = 1 },
        [22] = { Reward_Item = "gold", Num = 4000, VIP_Level_Req = 0 },
        [23] = { Reward_Item = "gem", Num = 40, VIP_Level_Req = 0 },
        [24] = { Reward_Item = "exp_potion", Num = 20, VIP_Level_Req = 0 },
        [25] = { Reward_Item = "gold", Num = 5000, VIP_Level_Req = 0 },
        [26] = { Reward_Item = "gem", Num = 50, VIP_Level_Req = 0 },
        [27] = { Reward_Item = "exp_potion", Num = 25, VIP_Level_Req = 0 },
        [28] = { Reward_Item = "hero_ssr_001", Num = 1, VIP_Level_Req = 2 },
    },
    makeup_cost = { Cost_Item = "gem", Num = 30 },
    legacy = {
        ["normal"] = {
            [1] = { { id = "gold", count = 1000 } },
            [2] = { { id = "gem", count = 10 } },
            [3] = { { id = "exp_potion", count = 5 } },
            [4] = { { id = "gold", count = 2000 } },
            [5] = { { id = "gem", count = 20 } },
            [6] = { { id = "exp_potion", count = 10 } },
            [7] = { { id = "hero_r_001", count = 1 } },
        },
        ["vip"] = {
            [1] = { { id = "gold", count = 2000 } },
            [2] = { { id = "gem", count = 50 } },
            [3] = { { id = "exp_potion", count = 10 } },
            [4] = { { id = "gold", count = 5000 } },
            [5] = { { id = "gem", count = 100 } },
            [6] = { { id = "exp_potion", count = 20 } },
            [7] = { { id = "hero_sr_001", count = 1 } },
        }
    }
}

-- 内购商品配置（SKU -> 奖励/时长）
-- - rewards：发放奖励列表（id/count）
-- - duration_days：订阅/月卡类时长（天）
M.iap_products = {
    ["com.game.gem_pack_1"] = {
        rewards = { { id = "gem", count = 100 } }
    },
    ["com.game.gem_pack_2"] = {
        rewards = { { id = "gem", count = 550 } }
    },
    ["com.game.monthly_card"] = {
        rewards = { { id = "gem", count = 300 } },
        duration_days = 30
    }
}

-- 管理端相关配置
-- - inventory_log_admin_token：查看库存日志的管理令牌（留空表示未配置）
-- - inventory_log_user_whitelist：允许查看日志的用户白名单（user_id 列表）
M.admin = {
    inventory_log_admin_token = "",
    inventory_log_user_whitelist = {}
}

return M
