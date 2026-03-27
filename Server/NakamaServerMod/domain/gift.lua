local nk = require("nakama")
local config = require("config")

local M = {}

local COLLECTION = "gift_pack"
local KEY_STATE = "gift_state"
local BEIJING_OFFSET_SECONDS = 8 * 3600

local item_gateway = {
    add_items = function()
        return false, "item gateway not configured"
    end,
    consume_items = function()
        return false, "item gateway not configured"
    end
}

function M.set_item_gateway(gateway)
    if type(gateway) ~= "table" then
        return
    end
    if type(gateway.add_items) == "function" then
        item_gateway.add_items = gateway.add_items
    end
    if type(gateway.consume_items) == "function" then
        item_gateway.consume_items = gateway.consume_items
    end
end

local function now_ts()
    return os.time()
end

local function deep_copy(v)
    if type(v) ~= "table" then
        return v
    end
    local out = {}
    for k, iv in pairs(v) do
        out[k] = deep_copy(iv)
    end
    return out
end

local function get_beijing_date_key(ts)
    return os.date("!%Y%m%d", ts + BEIJING_OFFSET_SECONDS)
end

local function get_next_beijing_midnight(ts)
    local beijing_day = math.floor((ts + BEIJING_OFFSET_SECONDS) / 86400)
    local next_day_start_beijing = (beijing_day + 1) * 86400
    return next_day_start_beijing - BEIJING_OFFSET_SECONDS
end

local function normalize_reward_items(items)
    local out = {}
    if type(items) ~= "table" then
        return out
    end
    for _, item in ipairs(items) do
        if type(item) == "table" then
            local id = item.id or item.itemId or item.item_id
            local count = math.floor(tonumber(item.count) or 0)
            if type(id) == "string" and id ~= "" and count > 0 then
                out[#out + 1] = { id = id, count = count }
            end
        end
    end
    return out
end

local function ensure_state_shape(state)
    if type(state) ~= "table" then
        state = {}
    end
    if type(state.purchaseStates) ~= "table" then
        state.purchaseStates = {}
    end
    if type(state.firstRechargeStageStates) ~= "table" then
        state.firstRechargeStageStates = {}
    end
    if type(state.processedOrders) ~= "table" then
        state.processedOrders = {}
    end
    if state.firstRechargeUnlocked ~= true then
        state.firstRechargeUnlocked = false
    end
    return state
end

local function load_state(user_id)
    local objects = nk.storage_read({
        {
            collection = COLLECTION,
            key = KEY_STATE,
            user_id = user_id
        }
    })
    if #objects > 0 then
        return ensure_state_shape(objects[1].value), objects[1].version
    end
    return ensure_state_shape({}), nil
end

local function save_state(user_id, state, version)
    local obj = {
        collection = COLLECTION,
        key = KEY_STATE,
        user_id = user_id,
        value = state,
        permission_read = 1,
        permission_write = 0
    }
    if version ~= nil then
        obj.version = version
    end
    nk.storage_write({ obj })
end

local function get_pack_config(pack_id)
    if type(config.gift) ~= "table" or type(config.gift.packs) ~= "table" then
        return nil
    end
    return config.gift.packs[pack_id]
end

local function is_pack_active(pack_cfg, now)
    local range = pack_cfg and pack_cfg.activeTimeRange
    if type(range) ~= "table" then
        return true
    end
    local start_at = tonumber(range.startAt)
    local end_at = tonumber(range.endAt)
    if start_at ~= nil and now < start_at then
        return false
    end
    if end_at ~= nil and now > end_at then
        return false
    end
    return true
end

local function resolve_cycle_key(pack_cfg, activity_id, now)
    if pack_cfg.limitType == "daily" then
        return get_beijing_date_key(now)
    end
    if pack_cfg.limitType == "activity_once" then
        return activity_id or pack_cfg.activityId or ""
    end
    return nil
end

local function compute_limit_progress(pack_cfg, purchase_state, cycle_key)
    local progress = 0
    if type(purchase_state) ~= "table" then
        return progress
    end
    if pack_cfg.limitType == "permanent" then
        progress = tonumber(purchase_state.progress) or 0
    elseif pack_cfg.limitType == "daily" or pack_cfg.limitType == "activity_once" then
        if purchase_state.cycleKey == cycle_key then
            progress = tonumber(purchase_state.progress) or 0
        end
    end
    return progress
end

local function validate_purchase(state, pack_id, activity_id, now)
    local pack_cfg = get_pack_config(pack_id)
    if type(pack_cfg) ~= "table" then
        return false, "礼包不存在"
    end
    if not is_pack_active(pack_cfg, now) then
        return false, "礼包已下架/活动已结束"
    end
    if pack_cfg.packType == "first_recharge" and state.firstRechargeUnlocked ~= true then
        return false, "未解锁首充礼包"
    end
    if pack_cfg.limitType == "activity_once" and activity_id ~= nil and pack_cfg.activityId ~= nil and activity_id ~= pack_cfg.activityId then
        return false, "活动礼包活动ID不匹配"
    end
    local cycle_key = resolve_cycle_key(pack_cfg, activity_id, now)
    local purchase_state = state.purchaseStates[pack_id]
    local progress = compute_limit_progress(pack_cfg, purchase_state, cycle_key)
    local limit_value = math.floor(tonumber(pack_cfg.limitValue) or 0)
    if limit_value > 0 and progress >= limit_value then
        return false, "限购已达上限"
    end
    return true, nil, pack_cfg, cycle_key, progress
end

local function make_purchase_state(pack_cfg, previous_state, cycle_key, order_id, now)
    local next_state = deep_copy(previous_state or {})
    next_state.packId = pack_cfg.packId
    next_state.packType = pack_cfg.packType
    next_state.limitType = pack_cfg.limitType
    local base_progress = 0
    if pack_cfg.limitType == "permanent" then
        base_progress = tonumber(next_state.progress) or 0
    elseif next_state.cycleKey ~= nil and next_state.cycleKey == cycle_key then
        base_progress = tonumber(next_state.progress) or 0
    end
    next_state.progress = base_progress + 1
    next_state.cycleKey = cycle_key
    next_state.lastBuyAt = now
    next_state.lastOrderId = order_id
    if pack_cfg.activityId ~= nil then
        next_state.activityId = pack_cfg.activityId
    end
    return next_state
end

local function sort_day_rewards(day_rewards)
    table.sort(day_rewards, function(a, b)
        return (a.dayIndex or 0) < (b.dayIndex or 0)
    end)
end

local function build_first_recharge_stage_state(pack_cfg, purchase_at)
    local day_rewards_raw = deep_copy(pack_cfg.firstRecharge30DayRewards or {})
    local day_rewards = {}
    for _, slot in ipairs(day_rewards_raw) do
        if type(slot) == "table" then
            local day_index = math.floor(tonumber(slot.dayIndex) or 0)
            if day_index > 0 then
                day_rewards[#day_rewards + 1] = {
                    dayIndex = day_index,
                    rewardItems = normalize_reward_items(slot.rewardItems or {})
                }
            end
        end
    end
    sort_day_rewards(day_rewards)
    local day_states = {}
    local first_midnight = get_next_beijing_midnight(purchase_at)
    for _, day_reward in ipairs(day_rewards) do
        local day_index = day_reward.dayIndex
        local unlock_at = purchase_at
        if day_index > 1 then
            unlock_at = first_midnight + (day_index - 2) * 86400
        end
        day_states[#day_states + 1] = {
            dayIndex = day_index,
            unlockAt = unlock_at,
            status = unlock_at <= purchase_at and "claimable" or "locked",
            claimedAt = nil
        }
    end
    return {
        packId = pack_cfg.packId,
        purchaseAt = purchase_at,
        dayRewards = day_rewards,
        dayStates = day_states
    }
end

local function refresh_day_states(stage_state, now)
    local changed = false
    for _, slot in ipairs(stage_state.dayStates or {}) do
        if slot.status == "locked" and tonumber(slot.unlockAt) and now >= tonumber(slot.unlockAt) then
            slot.status = "claimable"
            changed = true
        end
    end
    return changed
end

local function find_day_state(stage_state, day_index)
    for _, slot in ipairs(stage_state.dayStates or {}) do
        if tonumber(slot.dayIndex) == tonumber(day_index) then
            return slot
        end
    end
    return nil
end

local function find_day_rewards(stage_state, day_index)
    for _, slot in ipairs(stage_state.dayRewards or {}) do
        if tonumber(slot.dayIndex) == tonumber(day_index) then
            return normalize_reward_items(slot.rewardItems or {})
        end
    end
    return {}
end

function M.check_purchase_eligibility(user_id, pack_id, activity_id)
    local state = ensure_state_shape(select(1, load_state(user_id)))
    local now = now_ts()
    local ok, err, pack_cfg, cycle_key, progress = validate_purchase(state, pack_id, activity_id, now)
    if not ok then
        return false, err
    end
    return true, nil, {
        packId = pack_id,
        cycleKey = cycle_key,
        progress = progress,
        limitValue = tonumber(pack_cfg.limitValue) or 0
    }
end

function M.process_paid_purchase(context, user_id, order_id, pack_id, activity_id)
    local now = now_ts()
    local state, version = load_state(user_id)
    if state.processedOrders[order_id] then
        return true, {
            success = true,
            idempotent = true,
            orderId = order_id,
            packId = state.processedOrders[order_id].packId
        }
    end
    local ok, err, pack_cfg, cycle_key = validate_purchase(state, pack_id, activity_id, now)
    if not ok then
        return false, err
    end
    local immediate_rewards = normalize_reward_items(pack_cfg.immediateRewardItems or {})
    if #immediate_rewards > 0 then
        local ok_add, err_add = item_gateway.add_items(context, user_id, immediate_rewards, "gift_purchase_" .. pack_id, {
            order_id = order_id,
            pack_id = pack_id
        })
        if not ok_add then
            return false, tostring(err_add)
        end
    end
    local previous_purchase_state = state.purchaseStates[pack_id]
    local next_purchase_state = make_purchase_state(pack_cfg, previous_purchase_state, cycle_key, order_id, now)
    state.purchaseStates[pack_id] = next_purchase_state
    if pack_cfg.packType == "first_recharge" and type(pack_cfg.firstRecharge30DayRewards) == "table" and #pack_cfg.firstRecharge30DayRewards > 0 then
        state.firstRechargeStageStates[pack_id] = build_first_recharge_stage_state(pack_cfg, now)
    end
    if pack_cfg.packType ~= "first_recharge" then
        state.firstRechargeUnlocked = true
    end
    state.processedOrders[order_id] = {
        packId = pack_id,
        processedAt = now
    }
    local ok_save, save_err = pcall(save_state, user_id, state, version)
    if not ok_save then
        if #immediate_rewards > 0 then
            pcall(item_gateway.consume_items, context, user_id, immediate_rewards, "gift_purchase_" .. pack_id .. "_rollback", {
                order_id = order_id,
                pack_id = pack_id
            })
        end
        return false, tostring(save_err)
    end
    return true, {
        success = true,
        idempotent = false,
        orderId = order_id,
        packId = pack_id,
        progress = next_purchase_state.progress
    }
end

function M.claim_day_reward(context, user_id, pack_id, day_index)
    local now = now_ts()
    local state, version = load_state(user_id)
    local stage_state = state.firstRechargeStageStates[pack_id]
    if type(stage_state) ~= "table" then
        return false, "分天奖励不存在"
    end
    refresh_day_states(stage_state, now)
    local day_state = find_day_state(stage_state, day_index)
    if type(day_state) ~= "table" then
        return false, "奖励天数不存在"
    end
    if day_state.status == "claimed" then
        return false, "已领取"
    end
    if day_state.status ~= "claimable" then
        return false, "未解锁"
    end
    local rewards = find_day_rewards(stage_state, day_index)
    if #rewards == 0 then
        return false, "奖励配置为空"
    end
    local ok_add, err_add = item_gateway.add_items(context, user_id, rewards, "gift_claim_" .. pack_id .. "_day" .. tostring(day_index), {
        pack_id = pack_id,
        day_index = day_index
    })
    if not ok_add then
        return false, tostring(err_add)
    end
    day_state.status = "claimed"
    day_state.claimedAt = now
    local ok_save, save_err = pcall(save_state, user_id, state, version)
    if not ok_save then
        pcall(item_gateway.consume_items, context, user_id, rewards, "gift_claim_" .. pack_id .. "_rollback", {
            pack_id = pack_id,
            day_index = day_index
        })
        return false, tostring(save_err)
    end
    return true, {
        success = true,
        packId = pack_id,
        dayIndex = day_index,
        claimedAt = now
    }
end

local function build_pack_runtime_state(state, pack_id, pack_cfg, activity_id, now)
    local cycle_key = resolve_cycle_key(pack_cfg, activity_id, now)
    local purchase_state = state.purchaseStates[pack_id]
    local progress = compute_limit_progress(pack_cfg, purchase_state, cycle_key)
    local limit_value = math.floor(tonumber(pack_cfg.limitValue) or 0)
    local unlocked = true
    if pack_cfg.packType == "first_recharge" and state.firstRechargeUnlocked ~= true then
        unlocked = false
    end
    local active = is_pack_active(pack_cfg, now)
    local can_buy = unlocked and active and (limit_value <= 0 or progress < limit_value)
    return {
        packId = pack_cfg.packId,
        packType = pack_cfg.packType,
        packName = pack_cfg.packName,
        priceCurrency = pack_cfg.priceCurrency,
        priceAmount = pack_cfg.priceAmount,
        limitType = pack_cfg.limitType,
        limitValue = limit_value,
        activityId = pack_cfg.activityId,
        activeTimeRange = pack_cfg.activeTimeRange,
        immediateRewardItems = normalize_reward_items(pack_cfg.immediateRewardItems or {}),
        firstRecharge30DayRewards = deep_copy(pack_cfg.firstRecharge30DayRewards or {}),
        progress = progress,
        cycleKey = cycle_key,
        canBuy = can_buy,
        visible = pack_cfg.packType ~= "first_recharge" or unlocked
    }
end

function M.get_state_data(user_id, activity_id)
    local now = now_ts()
    local state, version = load_state(user_id)
    local packs = {}
    local stage_states = deep_copy(state.firstRechargeStageStates)
    local purchase_state_list = {}
    local first_recharge_stage_state_list = {}
    local stage_state_changed = false
    for _, stage_state in pairs(stage_states) do
        if refresh_day_states(stage_state, now) then
            stage_state_changed = true
        end
    end
    local pack_ids = {}
    for pack_id, _ in pairs(config.gift.packs or {}) do
        pack_ids[#pack_ids + 1] = pack_id
    end
    table.sort(pack_ids)
    for _, pack_id in ipairs(pack_ids) do
        local pack_cfg = get_pack_config(pack_id)
        packs[#packs + 1] = build_pack_runtime_state(state, pack_id, pack_cfg, activity_id, now)
    end
    for pack_id, purchase_state in pairs(state.purchaseStates) do
        local row = deep_copy(purchase_state)
        if row.packId == nil then
            row.packId = pack_id
        end
        purchase_state_list[#purchase_state_list + 1] = row
    end
    table.sort(purchase_state_list, function(a, b)
        return tostring(a.packId or "") < tostring(b.packId or "")
    end)
    for pack_id, stage_state in pairs(stage_states) do
        local row = deep_copy(stage_state)
        if row.packId == nil then
            row.packId = pack_id
        end
        first_recharge_stage_state_list[#first_recharge_stage_state_list + 1] = row
    end
    table.sort(first_recharge_stage_state_list, function(a, b)
        return tostring(a.packId or "") < tostring(b.packId or "")
    end)
    if stage_state_changed then
        state.firstRechargeStageStates = stage_states
        pcall(save_state, user_id, state, version)
    end
    return {
        success = true,
        firstRechargeUnlocked = state.firstRechargeUnlocked == true,
        packs = packs,
        purchaseStates = deep_copy(state.purchaseStates),
        firstRechargeStageStates = stage_states,
        purchaseStateList = purchase_state_list,
        firstRechargeStageStateList = first_recharge_stage_state_list
    }
end

function M.set_first_recharge_unlocked(user_id, unlocked)
    local state, version = load_state(user_id)
    state.firstRechargeUnlocked = unlocked == true
    save_state(user_id, state, version)
    return {
        success = true,
        firstRechargeUnlocked = state.firstRechargeUnlocked
    }
end

return M
