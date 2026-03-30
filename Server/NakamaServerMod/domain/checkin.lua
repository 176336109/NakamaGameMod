local nk = require("nakama")
local config = require("config")

local M = {}

local CHECKIN_COLLECTION = "checkin"
local CHECKIN_KEY = "checkin"

local function normalize_days_map_from_list(rows)
    local out = {}
    if type(rows) ~= "table" then
        return out
    end
    for _, row in ipairs(rows) do
        if type(row) == "table" then
            local day_index = tonumber(row.dayIndex)
            if day_index ~= nil and day_index >= 1 and day_index <= 7 then
                out[tostring(day_index)] = {
                    status = row.status,
                    claimAt = row.claimAt,
                    claimType = row.claimType
                }
            end
        end
    end
    return out
end

local function normalize_days_map_from_keyed(days)
    local out = {}
    if type(days) ~= "table" then
        return out
    end
    for key, row in pairs(days) do
        if type(row) == "table" then
            local day_index = tonumber(key) or tonumber(row.dayIndex)
            if day_index ~= nil and day_index >= 1 and day_index <= 7 then
                out[tostring(day_index)] = {
                    status = row.status,
                    claimAt = row.claimAt,
                    claimType = row.claimType
                }
            end
        end
    end
    return out
end

local function build_day_claim_list(days)
    local out = {}
    if type(days) ~= "table" then
        return out
    end
    for key, row in pairs(days) do
        if type(row) == "table" then
            local day_index = tonumber(key) or tonumber(row.dayIndex)
            if day_index ~= nil and day_index >= 1 and day_index <= 7 then
                out[#out + 1] = {
                    dayIndex = day_index,
                    status = row.status,
                    claimAt = row.claimAt,
                    claimType = row.claimType
                }
            end
        end
    end
    table.sort(out, function(a, b)
        return (a.dayIndex or 0) < (b.dayIndex or 0)
    end)
    return out
end

-- Beijing Time (UTC+8) offset in seconds
local TIME_OFFSET = 8 * 3600

-- Helper to get current timestamp (with debug offset support)
-- 读取当前时间戳，支持按用户写入的 time_offset 调试偏移。
local function get_timestamp(user_id)
    local objs = nk.storage_read({ { collection = CHECKIN_COLLECTION, key = CHECKIN_KEY, user_id = user_id } })
    local offset = 0
    if #objs > 0 and type(objs[1].value) == "table" then
        offset = tonumber(objs[1].value.time_offset) or 0
    end
    return os.time() + offset
end

-- Calculate global day index based on Beijing Time
-- This represents the "DateKey" concept (days since epoch shifted by timezone)
-- 把时间戳转换为北京时间自然日索引（用于跨天与周期计算）。
local function get_day_index(ts)
    return math.floor((ts + TIME_OFFSET) / 86400)
end

-- Get cycle info based on account creation time and current time (Unified Criteria)
-- 基于账号创建日与当前日计算签到周期号和周期内天序号。
local function get_cycle_info(user_id)
    local account = nk.account_get_id(user_id)
    local create_ts = 0
    
    if account and account.user and account.user.create_time then
        if type(account.user.create_time) == "table" then
            create_ts = account.user.create_time.seconds or os.time()
        else
            create_ts = account.user.create_time
        end
    else
        create_ts = os.time()
    end
    
    -- accountCreateDateKey = 00:00:00 (Beijing Time) of creation day
    local create_day = get_day_index(create_ts)
    
    -- currentDateKey = 00:00:00 (Beijing Time) of current day
    local current_ts = get_timestamp(user_id)
    local current_day = get_day_index(current_ts)
    
    -- diffDays = (currentDateKey - accountCreateDateKey)
    local days_diff = current_day - create_day
    if days_diff < 0 then days_diff = 0 end
    
    -- cycleNo = floor(diffDays / 7) + 1
    local cycle_no = math.floor(days_diff / 7) + 1
    
    -- currentDayIndex = (diffDays % 7) + 1
    local current_day_index = (days_diff % 7) + 1
    
    return cycle_no, current_day_index, current_day
end

-- Load state from storage
-- 读取用户签到状态快照与版本号。
local function load_state(user_id)
    local objects = nk.storage_read({ { collection = CHECKIN_COLLECTION, key = CHECKIN_KEY, user_id = user_id } })
    local state = {}
    local version = nil
    
    if #objects > 0 then
        state = objects[1].value
        if type(state) ~= "table" then
            state = {}
        end
        if type(state.dayClaimList) == "table" then
            state.days = normalize_days_map_from_list(state.dayClaimList)
        elseif type(state.days) == "table" then
            state.days = normalize_days_map_from_keyed(state.days)
        else
            state.days = {}
        end
        version = objects[1].version
    end
    
    return state, version
end

-- Save state to storage
-- 按 CAS 版本写回签到状态；version 为空时走新写入。
local function save_state(user_id, state, version)
    local value = {}
    if type(state) == "table" then
        for k, v in pairs(state) do
            value[k] = v
        end
    end
    value.days = nil
    value.dayClaimList = build_day_claim_list(state and state.days)
    local write_obj = {
        collection = CHECKIN_COLLECTION,
        key = CHECKIN_KEY,
        user_id = user_id,
        value = value,
        permission_read = 1,
        permission_write = 0
    }
    if version then
        write_obj.version = version
    end
    nk.storage_write({ write_obj })
end

-- 构建 7 天默认状态数组，初始全部为 unsigned。
local function build_unsigned_day_states()
    local day_states = {}
    for i = 1, 7 do
        day_states[i] = { dayIndex = i, status = "unsigned" }
    end
    return day_states
end

-- 重置到新周期快照，保留旧状态中的 time_offset 调试字段。
local function reset_cycle_state(cycle_id_str, old_state, current_day_index, current_day)
    local cycle_start_date = current_day - (current_day_index - 1)
    local cycle_end_date = cycle_start_date + 6
    local state = {
        cycleId = cycle_id_str,
        cycleStartDate = cycle_start_date,
        cycleEndDate = cycle_end_date,
        currentDayIndex = current_day_index,
        lastRefreshDate = current_day,
        days = {},
        dayStates = build_unsigned_day_states()
    }
    if type(old_state) == "table" and old_state.time_offset ~= nil then
        state.time_offset = tonumber(old_state.time_offset) or 0
    end
    return state
end

-- 修正快照中的周期派生字段，返回是否发生变更。
local function ensure_cycle_snapshot_fields(state, current_day_index, current_day)
    local cycle_start_date = current_day - (current_day_index - 1)
    local cycle_end_date = cycle_start_date + 6
    local changed = false
    if state.cycleStartDate ~= cycle_start_date then
        state.cycleStartDate = cycle_start_date
        changed = true
    end
    if state.cycleEndDate ~= cycle_end_date then
        state.cycleEndDate = cycle_end_date
        changed = true
    end
    if state.currentDayIndex ~= current_day_index then
        state.currentDayIndex = current_day_index
        changed = true
    end
    if state.lastRefreshDate ~= current_day then
        state.lastRefreshDate = current_day
        changed = true
    end
    if type(state.dayStates) ~= "table" or #state.dayStates ~= 7 then
        state.dayStates = build_unsigned_day_states()
        changed = true
    end
    return changed
end

-- Helper to make error response
-- 统一错误结构输出（供 service 层复用）。
local function make_error(code, message)
    return nk.json_encode({ error = message or code, error_code = code })
end

-- 归一化单个道具结构（兼容 id/item_id）。
local function normalize_item(item)
    if type(item) ~= "table" then
        return nil
    end
    local id = item.id or item.item_id
    local count = tonumber(item.count) or 0
    if type(id) ~= "string" or id == "" or count == 0 then
        return nil
    end
    return { id = id, count = count }
end

-- 归一化道具列表，过滤非法项。
local function normalize_items(items)
    local out = {}
    if type(items) ~= "table" then
        return out
    end
    for _, item in ipairs(items) do
        local normalized = normalize_item(item)
        if normalized then
            table.insert(out, normalized)
        end
    end
    return out
end

-- 聚合返回签到状态、每日奖励与补签成本；必要时自动刷新并落盘快照。
function M.get_state_data(user_id)
    local cycle_no, current_day_index, current_day = get_cycle_info(user_id)
    local cycle_id_str = "C" .. tostring(cycle_no)
    local state, version = load_state(user_id)
    local needs_snapshot = false
    if type(state) ~= "table" then
        state = {}
        needs_snapshot = true
    end
    if not state.cycleId or state.cycleId ~= cycle_id_str then
        state = reset_cycle_state(cycle_id_str, state, current_day_index, current_day)
        needs_snapshot = true
    end
    if type(state.days) ~= "table" then
        state.days = {}
        needs_snapshot = true
    end
    if ensure_cycle_snapshot_fields(state, current_day_index, current_day) then
        needs_snapshot = true
    end
    if needs_snapshot then
        save_state(user_id, state, version)
    end

    local days_info = {}
    local day_rewards = {}
    local checkin_cfg = config.checkin or {}
    local rewards_cfg = checkin_cfg.rewards or {}
    for i = 1, 7 do
        local status = "unsigned"
        local saved_day_data = state.days[tostring(i)]
        if saved_day_data then
            if saved_day_data.status == "makeup_signed" then
                status = "makeup_signed"
            else
                status = "signed"
            end
        else
            if i > current_day_index then
                status = "locked"
            end
        end
        local rewards = normalize_items(rewards_cfg[i] or rewards_cfg[tostring(i)] or {})
        day_rewards[i] = rewards
        table.insert(days_info, { day_index = i, status = status, rewards = rewards })
    end

    local makeup_cost_cfg = checkin_cfg.makeup_cost
    local makeup_cost_resp = nil
    if makeup_cost_cfg then
        makeup_cost_resp = normalize_item(makeup_cost_cfg)
    end

    return {
        cycle_no = cycle_no,
        cycleNo = cycle_no,
        currentDayIndex = current_day_index,
        days = days_info,
        day_rewards = day_rewards,
        makeup_cost = makeup_cost_resp,
        timestamp = os.time()
    }
end

-- 写入 dayStates 中某一天的领取结果，用于客户端展示与追踪。
function M.set_day_claimed(state, day_index, status, claim_type, claim_at)
    if type(state) ~= "table" then
        return
    end
    if type(state.dayStates) ~= "table" then
        state.dayStates = build_unsigned_day_states()
    end
    local idx = tonumber(day_index) or 0
    if idx < 1 or idx > 7 then
        return
    end
    local slot = state.dayStates[idx] or { dayIndex = idx, status = "unsigned" }
    slot.dayIndex = idx
    slot.status = status
    slot.claimAt = claim_at
    slot.claimType = claim_type
    state.dayStates[idx] = slot
end

-- 设置当前用户签到时间偏移（调试用）。
function M.set_time_offset(user_id, offset)
    local state, version = load_state(user_id)
    if type(state) ~= "table" then
        state = {}
    end
    state.time_offset = tonumber(offset) or 0
    save_state(user_id, state, version)
    return state.time_offset
end

M.make_error = make_error
M.get_cycle_info = get_cycle_info
M.load_state = load_state
M.save_state = save_state
M.reset_cycle_state = reset_cycle_state
M.normalize_items = normalize_items

return M
