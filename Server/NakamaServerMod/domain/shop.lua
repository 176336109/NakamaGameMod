local nk = require("nakama")
local config = require("config")

local M = {}

local COLLECTION = "shop"
local KEY_SNAPSHOT = "special_snapshot"
local KEY_LIMITS = "limit_state"

-- 辅助函数：获取北京时间 YYYYMMDD (UTC+8)
local function get_beijing_today_str()
    local t = os.time() + 28800 -- UTC+8
    return os.date("!%Y%m%d", t)
end

-- 辅助函数：获取北京时间 本周一 YYYYMMDD
local function get_beijing_week_key()
    local t = os.time() + 28800 -- UTC+8
    local date_table = os.date("!*t", t)
    local wday = date_table.wday -- 1 is Sunday, 2 is Monday...
    local days_to_monday = (wday == 1) and 6 or (wday - 2)
    local monday_t = t - (days_to_monday * 86400)
    return os.date("!%Y%m%d", monday_t)
end

-- 辅助函数：生成快照 ID
local function generate_snapshot_id()
    return nk.uuid_v4()
end

-- 读取用户限购状态及版本号。
local function load_limit_state(user_id)
    local objects = nk.storage_read({{ collection = COLLECTION, key = KEY_LIMITS, user_id = user_id }})
    if #objects > 0 then
        return objects[1].value, objects[1].version
    end
    return {}, nil
end

-- 写回用户限购状态。
local function save_limit_state(user_id, state, version)
    nk.storage_write({{
        collection = COLLECTION,
        key = KEY_LIMITS,
        user_id = user_id,
        value = state,
        version = version,
        permission_read = 1,
        permission_write = 0
    }})
end

-- 生成特惠商店随机快照（6个不重复）。
local function generate_special_snapshot()
    local all_random_goods = {}
    for id, cfg in pairs(config.shop.goods) do
        if cfg.shopType == "special" and cfg.displayMode == "random" then
            table.insert(all_random_goods, { id = id, weight = cfg.weight or 100 })
        end
    end

    if #all_random_goods < 6 then
        nk.logger_error("Shop random pool has less than 6 items!")
        return nil
    end

    local selected = {}
    local selected_map = {}
    
    -- 权重随机算法
    for i = 1, 6 do
        local total_weight = 0
        local pool = {}
        for _, item in ipairs(all_random_goods) do
            if not selected_map[item.id] then
                total_weight = total_weight + item.weight
                table.insert(pool, item)
            end
        end

        local r = math.random(1, total_weight)
        local current_w = 0
        for _, item in ipairs(pool) do
            current_w = current_w + item.weight
            if r <= current_w then
                table.insert(selected, item.id)
                selected_map[item.id] = true
                break
            end
        end
    end

    local today_str = get_beijing_today_str()
    local snapshot = {
        snapshotId = generate_snapshot_id(),
        shopType = "special",
        slotEntries = {},
        generatedAt = os.time(),
        expireAtStr = today_str -- 简化处理，由客户端/服务端逻辑根据日期判定过期
    }

    for i, goods_id in ipairs(selected) do
        local cfg = config.shop.goods[goods_id]
        table.insert(snapshot.slotEntries, {
            slotIndex = i,
            goodsId = goods_id,
            resolvedRewardItems = cfg.rewardItems,
            resolvedCostType = cfg.costType,
            resolvedCostValue = cfg.costValue
        })
    end

    return snapshot
end

-- 读取并按跨天规则自动刷新特惠快照。
local function load_shop_snapshot(user_id)
    local today_str = get_beijing_today_str()
    local objects = nk.storage_read({{ collection = COLLECTION, key = KEY_SNAPSHOT, user_id = user_id }})
    
    local snapshot = nil
    if #objects > 0 then
        snapshot = objects[1].value
        -- 检查是否跨天过期
        if snapshot.expireAtStr ~= today_str then
            snapshot = nil
        end
    end

    if not snapshot then
        snapshot = generate_special_snapshot()
        nk.storage_write({{
            collection = COLLECTION,
            key = KEY_SNAPSHOT,
            user_id = user_id,
            value = snapshot,
            permission_read = 1,
            permission_write = 0
        }})
    end

    return snapshot
end

-- 手动写入特惠快照。
local function save_shop_snapshot(user_id, snapshot)
    nk.storage_write({{
        collection = COLLECTION,
        key = KEY_SNAPSHOT,
        user_id = user_id,
        value = snapshot,
        permission_read = 1,
        permission_write = 0
    }})
end

-- 计算当前商品在对应限购周期内的进度值。
local function compute_limit_progress(cfg, state, snapshot_id, today_str, week_key)
    local progress = 0
    if not state then
        return progress
    end
    if cfg.limitType == "per_refresh" then
        if state.snapshotId == snapshot_id then
            progress = state.progress or 0
        end
    elseif cfg.limitType == "daily" then
        if state.cycleKey == today_str then
            progress = state.progress or 0
        end
    elseif cfg.limitType == "weekly" then
        if state.cycleKey == week_key then
            progress = state.progress or 0
        end
    elseif cfg.limitType == "permanent" then
        progress = state.progress or 0
    end
    return progress
end

-- 应用一次购买后的限购进度变更。
local function apply_limit_progress(cfg, state, snapshot_id, today_str, week_key)
    state.progress = (state.progress or 0) + 1
    state.lastBuyAt = os.time()

    if cfg.limitType == "per_refresh" then
        state.snapshotId = snapshot_id
    elseif cfg.limitType == "daily" then
        state.cycleKey = today_str
    elseif cfg.limitType == "weekly" then
        state.cycleKey = week_key
    end
    return state
end

-- 聚合商店状态：特惠快照、固定商品与各类限购进度。
function M.get_state_data(user_id)
    local today_str = get_beijing_today_str()
    local week_key = get_beijing_week_key()
    local snapshot = load_shop_snapshot(user_id)
    local limit_state = load_limit_state(user_id)
    local response = {
        specialSnapshot = snapshot,
        fixedItems = {},
        goldItems = {},
        crystalItems = {},
        limitProgress = {}
    }

    for id, cfg in pairs(config.shop.goods) do
        local item = {
            goodsId = id,
            config = cfg,
            progress = 0
        }
        local progress = compute_limit_progress(cfg, limit_state[id], snapshot.snapshotId, today_str, week_key)
        item.progress = progress
        response.limitProgress[id] = progress
        if cfg.shopType == "special" and cfg.displayMode == "fix" then
            table.insert(response.fixedItems, item)
        elseif cfg.shopType == "gold" then
            table.insert(response.goldItems, item)
        elseif cfg.shopType == "crystal" then
            table.insert(response.crystalItems, item)
        end
    end
    return response
end

M.get_beijing_today_str = get_beijing_today_str
M.get_beijing_week_key = get_beijing_week_key
M.load_limit_state = load_limit_state
M.save_limit_state = save_limit_state
M.load_shop_snapshot = load_shop_snapshot
M.save_shop_snapshot = save_shop_snapshot
M.generate_special_snapshot = generate_special_snapshot
M.compute_limit_progress = compute_limit_progress
M.apply_limit_progress = apply_limit_progress

return M
