local nk = require("nakama")
local config = require("config")
local backpack = require("backpack")

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

-- 1. 加载限购状态
local function load_limit_state(user_id)
    local objects = nk.storage_read({{ collection = COLLECTION, key = KEY_LIMITS, user_id = user_id }})
    if #objects > 0 then
        return objects[1].value, objects[1].version
    end
    return {}, nil
end

-- 2. 保存限购状态
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

-- 3. 生成特惠商店随机商品（6个不重复）
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

-- 4. 加载/自动刷新快照
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

-- RPC: 获取商店状态
function M.rpc_shop_get_state(context, payload)
    local user_id = context.user_id
    local today_str = get_beijing_today_str()
    local week_key = get_beijing_week_key()

    -- 特惠商店快照
    local snapshot = load_shop_snapshot(user_id)
    
    -- 限购状态
    local limit_state = load_limit_state(user_id)

    -- 组装返回数据
    local response = {
        specialSnapshot = snapshot,
        fixedItems = {},
        goldItems = {},
        crystalItems = {},
        limitProgress = {} -- goodsId -> progress
    }

    -- 填充固定展示和金币/水晶商店
    for id, cfg in pairs(config.shop.goods) do
        local item = {
            goodsId = id,
            config = cfg,
            progress = 0
        }

        -- 计算限购进度
        local progress = 0
        local state = limit_state[id]
        if state then
            if cfg.limitType == "per_refresh" then
                if state.snapshotId == snapshot.snapshotId then
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
        end
        item.progress = progress
        response.limitProgress[id] = progress

        if cfg.shopType == "special" and cfg.displayMode == "fixed" then
            table.insert(response.fixedItems, item)
        elseif cfg.shopType == "gold" then
            table.insert(response.goldItems, item)
        elseif cfg.shopType == "crystal" then
            table.insert(response.crystalItems, item)
        end
    end

    return nk.json_encode(response)
end

-- RPC: 手动刷新特惠商店
function M.rpc_shop_refresh(context, payload)
    local user_id = context.user_id
    local cost_cfg = config.shop.refresh_cost
    
    -- 1. 扣除水晶
    local ok, err = backpack.consume_items(context, user_id, {{ id = cost_cfg.item_id, count = cost_cfg.count }}, "shop_refresh")
    if not ok then
        return nk.json_encode({ success = false, error = "Insufficient crystals: " .. (err or "") })
    end

    -- 2. 生成新快照
    local snapshot = generate_special_snapshot()
    nk.storage_write({{
        collection = COLLECTION,
        key = KEY_SNAPSHOT,
        user_id = user_id,
        value = snapshot,
        permission_read = 1,
        permission_write = 0
    }})

    return nk.json_encode({ success = true, snapshot = snapshot })
end

-- RPC: 购买商品
function M.rpc_shop_buy(context, payload)
    local req = nk.json_decode(payload)
    local goods_id = req.goodsId
    local user_id = context.user_id
    
    local cfg = config.shop.goods[goods_id]
    if not cfg then
        return nk.json_encode({ success = false, error = "Goods not found" })
    end

    local today_str = get_beijing_today_str()
    local week_key = get_beijing_week_key()
    
    -- 1. 加载快照（特惠商店随机商品需要）
    local snapshot = load_shop_snapshot(user_id)
    
    -- 2. 校验限购
    local limit_state, limit_version = load_limit_state(user_id)
    local state = limit_state[goods_id] or { progress = 0 }
    local progress = 0
    
    if cfg.limitType == "per_refresh" then
        if state.snapshotId == snapshot.snapshotId then
            progress = state.progress
        end
    elseif cfg.limitType == "daily" then
        if state.cycleKey == today_str then
            progress = state.progress
        end
    elseif cfg.limitType == "weekly" then
        if state.cycleKey == week_key then
            progress = state.progress
        end
    elseif cfg.limitType == "permanent" then
        progress = state.progress
    end

    if cfg.limitType ~= "none" and progress >= cfg.limitValue then
        return nk.json_encode({ success = false, error = "Limit reached" })
    end

    -- 3. 校验价格（快照锁定规则：随机商品按快照生成的锁定值）
    local cost_type = cfg.costType
    local cost_value = cfg.costValue
    if cfg.displayMode == "random" then
        local found = false
        for _, entry in ipairs(snapshot.slotEntries) do
            if entry.goodsId == goods_id then
                cost_type = entry.resolvedCostType
                cost_value = entry.resolvedCostValue
                found = true
                break
            end
        end
        if not found then
            return nk.json_encode({ success = false, error = "Item not in current snapshot" })
        end
    end

    local ok_cost, err_cost = true, nil
    if cfg.shopType ~= "crystal" then
        ok_cost, err_cost = backpack.consume_items(context, user_id, {{ id = cost_type, count = cost_value }}, "shop_buy_" .. goods_id)
        if not ok_cost then
            return nk.json_encode({ success = false, error = "Insufficient funds: " .. (err_cost or "") })
        end
    end

    local ok_reward, err_reward = backpack.add_items(context, user_id, cfg.rewardItems, "shop_buy_" .. goods_id)
    if not ok_reward then
        nk.logger_error("Reward grant failed after cost deduction! User: " .. user_id .. " Goods: " .. goods_id)
        return nk.json_encode({ success = false, error = "Grant reward failed: " .. (err_reward or "") })
    end

    -- 更新限购
    state.progress = (state.progress or 0) + 1
    state.lastBuyAt = os.time()
    
    if cfg.limitType == "per_refresh" then
        state.snapshotId = snapshot.snapshotId
    elseif cfg.limitType == "daily" then
        state.cycleKey = today_str
    elseif cfg.limitType == "weekly" then
        state.cycleKey = week_key
    end
    
    -- 将更新后的 state 写回 limit_state 表
    limit_state[goods_id] = state
    save_limit_state(user_id, limit_state, limit_version)

    return nk.json_encode({ success = true, progress = state.progress })
end

return M
