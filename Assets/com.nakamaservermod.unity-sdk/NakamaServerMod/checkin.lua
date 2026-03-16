local nk = require("nakama")
local config = require("config")
local backpack = require("backpack")

local M = {}

local CHECKIN_COLLECTION = "checkin"
local CHECKIN_KEY = "checkin"

-- Beijing Time (UTC+8) offset in seconds
local TIME_OFFSET = 8 * 3600

-- Helper to get current timestamp (with debug offset support)
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
local function get_day_index(ts)
    return math.floor((ts + TIME_OFFSET) / 86400)
end

-- Get cycle info based on account creation time and current time (Unified Criteria)
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
    local current_cycle_day = (days_diff % 7) + 1
    
    return cycle_no, current_cycle_day, current_day
end

-- Load state from storage
local function load_state(user_id)
    local objects = nk.storage_read({ { collection = CHECKIN_COLLECTION, key = CHECKIN_KEY, user_id = user_id } })
    local state = {}
    local version = nil
    
    if #objects > 0 then
        state = objects[1].value
        version = objects[1].version
    end
    
    return state, version
end

-- Save state to storage
local function save_state(user_id, state, version)
    local write_obj = {
        collection = CHECKIN_COLLECTION,
        key = CHECKIN_KEY,
        user_id = user_id,
        value = state,
        permission_read = 1,
        permission_write = 0
    }
    if version then
        write_obj.version = version
    end
    nk.storage_write({ write_obj })
end

local function reset_cycle_state(cycle_id_str, old_state)
    local state = {
        cycleId = cycle_id_str,
        days = {}
    }
    if type(old_state) == "table" and old_state.time_offset ~= nil then
        state.time_offset = tonumber(old_state.time_offset) or 0
    end
    return state
end

-- Helper to make error response
local function make_error(code, message)
    return nk.json_encode({ error = message or code, error_code = code })
end

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

-- RPC: Get Check-in State
function M.rpc_checkin_get_state(context, payload)
    local user_id = context.user_id
    local cycle_no, cycle_day, current_day_idx = get_cycle_info(user_id)
    local cycle_id_str = "C" .. tostring(cycle_no)
    
    local state, version = load_state(user_id)
    
    -- Reset state if cycle mismatch (new cycle started)
    if not state.cycleId or state.cycleId ~= cycle_id_str then
        state = reset_cycle_state(cycle_id_str, state)
    end
    
    local days_info = {}
    local checkin_cfg = config.checkin or {}
    local rewards_cfg = checkin_cfg.rewards or {}
    
    for i = 1, 7 do
        local status = "locked"
        local saved_day_data = state.days[tostring(i)]
        
        if saved_day_data then
            -- Already signed or makeup_signed
            if saved_day_data.status == "makeup_signed" then
                status = "makeup_signed"
            else
                status = "signed"
            end
        else
            if i < cycle_day then
                status = "missed"
            elseif i == cycle_day then
                status = "claimable"
            else
                status = "locked"
            end
        end
        
        local reward = normalize_items(rewards_cfg[i] or {})
        
        table.insert(days_info, {
            day_index = i,
            status = status,
            rewards = reward
        })
    end
    
    local makeup_cost_cfg = checkin_cfg.makeup_cost
    local makeup_cost_resp = nil
    if makeup_cost_cfg then
        makeup_cost_resp = {
            id = makeup_cost_cfg.item_id,
            count = makeup_cost_cfg.count
        }
    end
    
    return nk.json_encode({
        cycle_no = cycle_no,
        current_cycle_day = cycle_day,
        days = days_info,
        makeup_cost = makeup_cost_resp,
        timestamp = os.time()
    })
end

-- RPC: Daily Check-in
function M.rpc_daily_checkin(context, payload)
    local user_id = context.user_id
    local cycle_no, cycle_day, current_day_idx = get_cycle_info(user_id)
    local cycle_id_str = "C" .. tostring(cycle_no)
    
    local state, version = load_state(user_id)
    
    -- Reset/Init if needed
    if not state.cycleId or state.cycleId ~= cycle_id_str then
        state = reset_cycle_state(cycle_id_str, state)
    end
    
    local day_str = tostring(cycle_day)
    
    if state.days[day_str] then
        return make_error("CHECKIN_ALREADY_CLAIMED", "Already checked in today")
    end
    
    -- Grant Rewards
    local checkin_cfg = config.checkin or {}
    local rewards = normalize_items((checkin_cfg.rewards or {})[cycle_day])
    
    if #rewards == 0 then
        return make_error("CHECKIN_CONFIG_ERROR", "No rewards config for today")
    end
    
    -- Backpack add items
    local success, err = backpack.add_items(context, user_id, rewards, "daily_checkin", {
        cycle_no = cycle_no,
        day_index = cycle_day
    })
    
    if not success then
        return make_error("CHECKIN_GRANT_FAILED", err)
    end
    
    -- Update State
    state.days[day_str] = {
        status = "signed",
        claimAt = os.time(),
        claimType = "normal"
    }
    save_state(user_id, state, version)
    
    return nk.json_encode({
        success = true,
        rewards = rewards,
        day_index = cycle_day,
        status = "signed"
    })
end

-- RPC: Makeup Check-in
function M.rpc_checkin_makeup(context, payload)
    local user_id = context.user_id
    local req = nk.json_decode(payload)
    local target_day = req.day_index -- 1 to 7
    
    if not target_day or target_day < 1 or target_day > 7 then
        return make_error("CHECKIN_INVALID_PARAM", "Invalid day index")
    end
    
    local cycle_no, cycle_day, current_day_idx = get_cycle_info(user_id)
    local cycle_id_str = "C" .. tostring(cycle_no)
    
    if target_day >= cycle_day then
        return make_error("CHECKIN_INVALID_ACTION", "Cannot makeup for today or future")
    end
    
    local state, version = load_state(user_id)
    
    -- Check cycle
    if not state.cycleId or state.cycleId ~= cycle_id_str then
        state = reset_cycle_state(cycle_id_str, state)
    end
    
    local day_str = tostring(target_day)
    if state.days[day_str] then
        return make_error("CHECKIN_ALREADY_CLAIMED", "Day already signed")
    end
    
    -- Check Cost
    local checkin_cfg = config.checkin or {}
    local cost = checkin_cfg.makeup_cost
    if not cost then
        return make_error("CHECKIN_CONFIG_ERROR", "Makeup cost not configured")
    end
    
    -- Deduct Cost
    local consume_items = normalize_items({ { id = cost.id, item_id = cost.item_id, count = cost.count } })
    if #consume_items == 0 then
        return make_error("CHECKIN_CONFIG_ERROR", "Invalid makeup cost config")
    end
    local success_cost, err_cost = backpack.consume_items(context, user_id, consume_items, "checkin_makeup_cost", {
        cycle_no = cycle_no,
        target_day = target_day
    })
    
    if not success_cost then
        return make_error("CHECKIN_INSUFFICIENT_COST", "Insufficient crystals")
    end
    
    -- Grant Rewards
    local rewards = normalize_items((checkin_cfg.rewards or {})[target_day])
    if #rewards == 0 then
         -- Rollback cost? Nakama doesn't support transaction rollback easily across multiple calls if not using wallet update directly.
         -- But here backpack uses storage. 
         -- Ideally we should check rewards config first. We did above.
         -- But if add_items fails...
         -- We should try to refund.
         backpack.add_items(context, user_id, consume_items, "checkin_makeup_refund", {})
         return make_error("CHECKIN_CONFIG_ERROR", "No rewards config")
    end
    
    local success_grant, err_grant = backpack.add_items(context, user_id, rewards, "checkin_makeup_reward", {
        cycle_no = cycle_no,
        target_day = target_day
    })
    
    if not success_grant then
        -- Refund cost
        backpack.add_items(context, user_id, consume_items, "checkin_makeup_refund", {})
        return make_error("CHECKIN_GRANT_FAILED", err_grant)
    end
    
    -- Update State
    state.days[day_str] = {
        status = "makeup_signed",
        claimAt = os.time(),
        claimType = "makeup"
    }
    save_state(user_id, state, version)
    
    return nk.json_encode({
        success = true,
        rewards = rewards,
        day_index = target_day,
        status = "makeup_signed"
    })
end

-- DEBUG RPC: Set time offset
function M.rpc_debug_set_time_offset(context, payload)
    local user_id = context.user_id
    local req = nk.json_decode(payload)
    local offset = tonumber(req.offset) or 0

    local state, version = load_state(user_id)
    if type(state) ~= "table" then
        state = {}
    end
    state.time_offset = offset
    save_state(user_id, state, version)

    return nk.json_encode({ success = true, offset = offset })
end

return M
