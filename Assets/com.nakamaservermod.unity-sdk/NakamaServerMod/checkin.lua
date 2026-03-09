--[[
模块职责（每日签到/补签/补领奖）：
- 维护 28 天为一个周期的签到状态（存储在 Nakama storage）。
- 提供 RPC：获取面板状态、当天签到领奖、补签、补领奖（门槛达标后的额外奖励）。
- 使用 UTC 日期字符串（YYYYMMDD）做日期计算与“跨天”判定，避免受服务器本地时区影响。

存储位置：
- collection: "checkin"
- key: "daily_status"
- value: { cycle_start_date, cycle_no, days }

28 天周期状态结构（value 字段语义）：
- cycle_start_date: 周期第 1 天对应的 UTC 日期（YYYYMMDD）。
- cycle_no: 周期编号（从 1 开始，仅用于展示/日志）。
- days[1..28]: 持久化状态枚举（注意：这是内部存储值，不是返回给客户端的 UI 状态）：
  - "empty": 未发生任何操作（可能是未来日，也可能是过去日但尚未同步为 missed）。
  - "missed": 过去日未签到（可以补签）。
  - "claimed": 已领奖（包含“门槛达标后的双倍”已一次性发放完毕的情况）。
  - "pending_bonus": 已领取基础奖励，但由于门槛未达标，额外奖励待领取（达标后可补领奖一次）。

关键错误码语义（仅解释，不改码值）：
- CHECKIN_INVALID_PAYLOAD：RPC payload 不是合法 JSON 或解析失败。
- CHECKIN_INVALID_DAY_ID：day_id 缺失/非整数/越界（1..28）。
- CHECKIN_NO_CLAIMABLE_DAY：今天不存在可领取的“当天格子”（通常是周期起始日在未来，例如第 28 天领取后周期起始被置为明天，今天不能再领一次）。
- CHECKIN_ALREADY_CLAIMED：今天已领取过（含 pending_bonus：基础奖励已发放，不能重复领取“当天签到”）。
- CHECKIN_NOT_CLAIMABLE：今天不是可领取状态（例如 Locked/Missed/等）。
- CHECKIN_NOT_MISSED：尝试补签的那天并不是 missed 状态。
- CHECKIN_INSUFFICIENT_COST：补签所需的消耗物品不足或扣除失败。
- CHECKIN_NOT_PENDING_BONUS：尝试补领奖的那天不是 pending_bonus 状态。
- CHECKIN_GATE_NOT_MET：补领奖时门槛等级不足（仍未达标）。
- CHECKIN_CONFIG_ERROR：配置缺失/格式错误（奖励表或补签消耗配置不合法）。
- CHECKIN_GRANT_FAILED：发放奖励失败（inventory.add_items 返回失败）。
--]]

local nk = require("nakama")
local config = require("config")
local inventory = require("inventory")

local M = {}

local function json_decode_payload(payload)
    if payload == nil or payload == "" then
        return true, {}
    end
    local ok, value = pcall(nk.json_decode, payload)
    if not ok then
        return false, nil
    end
    if value == nil then
        return true, {}
    end
    return true, value
end

local function normalize_wallet(wallet)
    if type(wallet) == "table" then
        return wallet
    end
    if type(wallet) == "string" and wallet ~= "" then
        local ok, decoded = pcall(nk.json_decode, wallet)
        if ok and type(decoded) == "table" then
            return decoded
        end
    end
    return {}
end

local function get_gate_info(user_id)
    local checkin_cfg = config.checkin or {}
    local mode = checkin_cfg.gating_mode
    if type(mode) ~= "string" or mode == "" then
        mode = "vip"
    end

    -- 门槛等级来源可配置（例如从钱包字段读取 VIP 等级/段位等）。
    local strat = (checkin_cfg.gate_level_strategy or {})[mode] or {}
    local source = strat.source
    local key = strat.key
    local def = tonumber(strat.default) or 0

    local level = def
    if source == "wallet" and type(key) == "string" and key ~= "" then
        local ok, account = pcall(nk.account_get_id, user_id)
        if ok and account ~= nil then
            local wallet = normalize_wallet(account.wallet)
            local v = wallet[key]
            local n = tonumber(v)
            if n ~= nil then
                level = n
            end
        end
    end

    if level < 0 then
        level = 0
    end
    return mode, level
end

local DAYS_PER_CYCLE = 28
local CHECKIN_COLLECTION = "checkin"
local CHECKIN_KEY = "daily_status"

-- 使用 UTC 日期字符串作为“今天”，所有跨天判定都基于 UTC 0 点。
local function utc_today_yyyymmdd()
    return os.date("!%Y%m%d")
end

local function parse_yyyymmdd(s)
    if type(s) ~= "string" or #s ~= 8 then
        return nil
    end
    local y = tonumber(s:sub(1, 4))
    local m = tonumber(s:sub(5, 6))
    local d = tonumber(s:sub(7, 8))
    if not y or not m or not d then
        return nil
    end
    if m < 1 or m > 12 or d < 1 or d > 31 then
        return nil
    end
    return { year = y, month = m, day = d }
end

-- 将 YYYYMMDD 对齐到 UTC 0 点的 epoch 秒数。
-- 说明：os.time 以“本地时区”解释输入表，这里通过比较同一 epoch 在本地/UTC 的日历时间来反推时区偏移，
-- 从而得到对应 UTC 0 点的 epoch，避免直接依赖服务器本地时区。
local function utc_midnight_epoch(s)
    local dt = parse_yyyymmdd(s)
    if not dt then
        return nil
    end
    local local_epoch = os.time({ year = dt.year, month = dt.month, day = dt.day, hour = 0, min = 0, sec = 0, isdst = false })
    local utc_t = os.date("!*t", local_epoch)
    local local_t = os.date("*t", local_epoch)
    local offset = os.difftime(os.time(local_t), os.time(utc_t))
    return local_epoch - offset
end

-- 计算两个 UTC 日期（YYYYMMDD）之间相差的整天数：to - from。
-- 用于推导“周期已过去多少天”，从而确定今天对应 day_id（并完成跨天判定）。
local function days_between(from_yyyymmdd, to_yyyymmdd)
    local a = utc_midnight_epoch(from_yyyymmdd)
    local b = utc_midnight_epoch(to_yyyymmdd)
    if not a or not b then
        return 0
    end
    return math.floor(os.difftime(b, a) / 86400)
end

-- 基于 UTC 0 点加减天数，返回新的 YYYYMMDD（UTC）。
local function add_days(base_yyyymmdd, days)
    local base_epoch = utc_midnight_epoch(base_yyyymmdd)
    if not base_epoch then
        return utc_today_yyyymmdd()
    end
    return os.date("!%Y%m%d", base_epoch + (days * 86400))
end

-- 创建一个新的 28 天周期状态：所有 days 初始化为 "empty"。
local function new_cycle_state(start_yyyymmdd, cycle_no)
    local days = {}
    for i = 1, DAYS_PER_CYCLE do
        days[i] = "empty"
    end
    return {
        cycle_start_date = start_yyyymmdd,
        cycle_no = cycle_no or 1,
        days = days,
    }
end

-- 规范化存储状态：
-- - 修正/兜底 cycle_start_date、cycle_no、days 数组长度与元素枚举值。
-- - 不在这里做跨天推导，跨天推导在 current_day_id / sync_missed_days 中完成。
local function normalize_state(value, today_str)
    if type(value) ~= "table" then
        value = {}
    end
    local start_date = value.cycle_start_date
    if type(start_date) ~= "string" or #start_date ~= 8 or not parse_yyyymmdd(start_date) then
        start_date = today_str
    end
    local cycle_no = tonumber(value.cycle_no) or 1
    if cycle_no < 1 then
        cycle_no = 1
    end
    local days = value.days
    if type(days) ~= "table" then
        days = {}
    end
    for i = 1, DAYS_PER_CYCLE do
        local v = days[i]
        if v ~= "claimed" and v ~= "missed" and v ~= "pending_bonus" then
            days[i] = "empty"
        end
    end
    return {
        cycle_start_date = start_date,
        cycle_no = cycle_no,
        days = days,
    }
end

-- 兼容旧版存储结构（last_checkin_date/streak）迁移到 28 天周期结构。
local function migrate_legacy_state(legacy, today_str)
    if type(legacy) ~= "table" then
        return new_cycle_state(today_str, 1)
    end
    local last = legacy.last_checkin_date
    local streak = tonumber(legacy.streak) or 0
    if streak < 0 then
        streak = 0
    end
    if streak > DAYS_PER_CYCLE then
        streak = DAYS_PER_CYCLE
    end
    if type(last) ~= "string" or #last ~= 8 or not parse_yyyymmdd(last) then
        return new_cycle_state(today_str, 1)
    end
    local diff = days_between(last, today_str)
    if diff < 0 then
        return new_cycle_state(today_str, 1)
    end
    if diff > 1 or streak == 0 then
        return new_cycle_state(today_str, 1)
    end
    local start_date = add_days(last, -(streak - 1))
    local state = new_cycle_state(start_date, 1)
    for i = 1, streak do
        state.days[i] = "claimed"
    end
    return state
end

-- 将“今天（UTC）”映射到周期内的 day_id（1..28）。
-- passed < 0 表示 cycle_start_date 在未来：今天没有可领取日（例如周期刚被重置到明天）。
local function current_day_id(state, today_str)
    local passed = days_between(state.cycle_start_date, today_str)
    if passed < 0 then
        return 0
    end
    local day_id = passed + 1
    if day_id > DAYS_PER_CYCLE then
        day_id = DAYS_PER_CYCLE
    end
    return day_id
end

-- 将今天之前仍为 "empty" 的格子补齐为 "missed"：
-- - 这样 UI 侧能明确区分“漏签可补签”。
-- - 只同步到 today_day_id - 1，避免把“今天”提前置为 missed。
local function sync_missed_days(state, today_day_id)
    local changed = false
    for i = 1, today_day_id - 1 do
        if state.days[i] == "empty" then
            state.days[i] = "missed"
            changed = true
        end
    end
    return changed
end

-- 将持久化状态映射为对外（UI/RPC）状态：
-- - "Claimable": 今天可签到领取（未领）。
-- - "Locked": 未来日锁定。
-- - "Missed": 过去日漏签（可补签）。
-- - "Pending_Bonus": 已领基础奖励，额外奖励待门槛达标后补领。
-- - "Claimed": 已全部领取完毕。
local function derive_day_status(state, today_day_id, day_id)
    local persisted = state.days[day_id] or "empty"
    if persisted == "claimed" then
        return "Claimed"
    end
    if persisted == "missed" then
        return "Missed"
    end
    if persisted == "pending_bonus" then
        return "Pending_Bonus"
    end
    if today_day_id <= 0 then
        return "Locked"
    end
    if day_id < today_day_id then
        return "Missed"
    end
    if day_id == today_day_id then
        return "Claimable"
    end
    return "Locked"
end

-- 读取并整理用户签到状态：
-- - 优先读取新结构；若为旧结构则迁移；若不存在则初始化。
-- - 根据今天推导 today_day_id，并把历史 "empty" 补齐为 "missed"（必要时标记 dirty）。
function M.checkin_load_state(user_id, today_str)
    local objects = nk.storage_read({ { collection = CHECKIN_COLLECTION, key = CHECKIN_KEY, user_id = user_id } })
    local version = nil
    local state = nil
    local migrated = false

    if #objects > 0 then
        local raw = objects[1].value or {}
        version = objects[1].version
        if raw.cycle_start_date ~= nil or raw.days ~= nil then
            state = normalize_state(raw, today_str)
        elseif raw.last_checkin_date ~= nil or raw.streak ~= nil then
            state = migrate_legacy_state(raw, today_str)
            migrated = true
        else
            state = new_cycle_state(today_str, 1)
        end
    else
        state = new_cycle_state(today_str, 1)
    end

    local today_day_id = current_day_id(state, today_str)
    local missed_changed = sync_missed_days(state, today_day_id)

    local dirty = migrated or missed_changed
    return state, version, today_day_id, dirty
end

-- 保存签到状态到 Nakama storage（带 version 以支持并发写入检测）。
function M.checkin_save_state(user_id, state, version)
    nk.storage_write({
        {
            collection = CHECKIN_COLLECTION,
            key = CHECKIN_KEY,
            user_id = user_id,
            value = state,
            version = version,
            permission_read = 1,
            permission_write = 0
        }
    })
end

-- 纯函数：将任意状态表规范化后，输出 28 天游玩周期的对外状态数组。
function M.checkin_derive_statuses(state, today_str)
    local normalized = normalize_state(state, today_str)
    local today_day_id = current_day_id(normalized, today_str)
    local statuses = {}
    for i = 1, DAYS_PER_CYCLE do
        statuses[i] = derive_day_status(normalized, today_day_id, i)
    end
    return {
        cycle_start_date = normalized.cycle_start_date,
        cycle_no = normalized.cycle_no,
        today = today_str,
        today_day_id = today_day_id,
        days = statuses,
    }
end

local function get_reward_row(day_id)
    local checkin_cfg = config.checkin or {}
    local row = (checkin_cfg.rewards or {})[day_id]
    if type(row) ~= "table" then
        return nil
    end
    local item_id = row.Reward_Item
    local num = tonumber(row.Num)
    local req = tonumber(row.VIP_Level_Req)
    if type(item_id) ~= "string" or item_id == "" or num == nil or num <= 0 or req == nil or req < 0 then
        return nil
    end
    return { item_id = item_id, num = num, required_level = req }
end

local function build_items(item_id, count)
    return { { id = item_id, count = count } }
end

-- 统一错误返回格式：{ error, error_code }。
local function make_error(code, message)
    return nk.json_encode({ error = message or code, error_code = code })
end

-- 周期重置：当领取/补签到第 28 天时，直接进入下一个周期，起始日为“明天（UTC）”。
-- 这会导致“今天”相对新的 cycle_start_date 为未来日，从而 today_day_id=0，避免同一天二次领取。
local function cycle_reset_state(prev_cycle_no, today_str)
    local next_no = (tonumber(prev_cycle_no) or 1) + 1
    return new_cycle_state(add_days(today_str, 1), next_no)
end

-- RPC：获取签到面板状态（含门槛信息、补签消耗、每一天的可操作性与奖励预览）。
function M.rpc_checkin_get_state(context, payload)
    local user_id = context.user_id
    local today_str = utc_today_yyyymmdd()

    local state, version, today_day_id, dirty = M.checkin_load_state(user_id, today_str)
    if dirty then
        pcall(M.checkin_save_state, user_id, state, version)
    end

    local gating_mode, player_level = get_gate_info(user_id)
    local checkin_cfg = config.checkin or {}
    local cost = checkin_cfg.makeup_cost or {}
    local cost_item = cost.Cost_Item
    local cost_num = tonumber(cost.Num) or 0
    if type(cost_item) ~= "string" or cost_item == "" or cost_num <= 0 then
        cost_item = nil
        cost_num = 0
    end

    local days = {}
    for day_id = 1, DAYS_PER_CYCLE do
        local status = derive_day_status(state, today_day_id, day_id)
        local reward = get_reward_row(day_id)
        local required_level = reward and reward.required_level or 0
        local meets = player_level >= required_level
        local multiplier = meets and 2 or 1
        local can_makeup = status == "Missed"
        local can_claim_bonus = status == "Pending_Bonus" and meets

        days[day_id] = {
            day_id = day_id,
            status = status,
            reward_item = reward and reward.item_id or nil,
            reward_num = reward and reward.num or 0,
            required_level = required_level,
            player_level = player_level,
            gating_mode = gating_mode,
            claim_multiplier = multiplier,
            can_makeup = can_makeup,
            can_claim_bonus = can_claim_bonus,
        }
    end

    return nk.json_encode({
        success = true,
        cycle_start_date = state.cycle_start_date,
        cycle_no = state.cycle_no,
        today = today_str,
        today_day_id = today_day_id,
        gating_mode = gating_mode,
        player_level = player_level,
        makeup_cost = cost_item and { id = cost_item, count = cost_num } or nil,
        days = days
    })
end

-- RPC：当天签到领奖流程：
-- 1) 读取/整理状态并计算今天 day_id（跨天基于 UTC）。
-- 2) 校验今天是否可领：只能在 "Claimable" 状态领取。
-- 3) 读取奖励配置并计算倍率：门槛达标则一次性发 2 倍；未达标先发 1 倍并标记 pending_bonus。
-- 4) 调用 inventory.add_items 发放奖励；成功后更新状态并落库。
-- 5) 若为第 28 天则重置周期到“明天开始的下一周期”。
function M.rpc_daily_checkin(context, payload)
    local user_id = context.user_id
    local today_str = utc_today_yyyymmdd()

    local state, version, today_day_id, dirty = M.checkin_load_state(user_id, today_str)

    if today_day_id <= 0 then
        if dirty then
            pcall(M.checkin_save_state, user_id, state, version)
        end
        return make_error("CHECKIN_NO_CLAIMABLE_DAY", "No claimable day today")
    end

    local today_status = derive_day_status(state, today_day_id, today_day_id)
    if today_status ~= "Claimable" then
        if today_status == "Claimed" or today_status == "Pending_Bonus" then
            if dirty then
                pcall(M.checkin_save_state, user_id, state, version)
            end
            return make_error("CHECKIN_ALREADY_CLAIMED", "Already checked in today")
        end
        if dirty then
            pcall(M.checkin_save_state, user_id, state, version)
        end
        return make_error("CHECKIN_NOT_CLAIMABLE", "Not claimable today")
    end

    local gating_mode, player_level = get_gate_info(user_id)
    local reward = get_reward_row(today_day_id)
    if not reward then
        if dirty then
            pcall(M.checkin_save_state, user_id, state, version)
        end
        return make_error("CHECKIN_CONFIG_ERROR", "Configuration error for day " .. tostring(today_day_id))
    end

    local meets = player_level >= reward.required_level
    local multiplier = meets and 2 or 1
    local rewards = build_items(reward.item_id, reward.num * multiplier)

    local ok, err = inventory.add_items(context, user_id, rewards, "checkin", {
        gating_mode = gating_mode,
        required_level = reward.required_level,
        player_level = player_level,
        day_id = today_day_id,
        cycle_no = state.cycle_no
    })
    if not ok then
        if dirty then
            pcall(M.checkin_save_state, user_id, state, version)
        end
        return make_error("CHECKIN_GRANT_FAILED", err or "Grant rewards failed")
    end

    local persisted = meets and "claimed" or "pending_bonus"
    local cycle_reset = false

    if today_day_id == DAYS_PER_CYCLE then
        cycle_reset = true
        state = cycle_reset_state(state.cycle_no, today_str)
    else
        state.days[today_day_id] = persisted
    end

    M.checkin_save_state(user_id, state, version)

    local vip_level_str
    if gating_mode == "vip" then
        vip_level_str = player_level > 0 and "vip" or "normal"
    else
        vip_level_str = gating_mode .. "_" .. tostring(player_level)
    end

    return nk.json_encode({
        success = true,
        rewards = rewards,
        streak = today_day_id,
        vip_level = vip_level_str,
        day_id = today_day_id,
        cycle_no = state.cycle_no,
        cycle_reset = cycle_reset,
        gating_mode = gating_mode,
        player_level = player_level,
        required_level = reward.required_level,
        status_after = cycle_reset and "Reset" or (meets and "Claimed" or "Pending_Bonus"),
        multiplier = multiplier
    })
end

-- RPC：补签流程（补签某个 missed 的历史日）：
-- 1) 校验 day_id 合法且该日对外状态为 "Missed"。
-- 2) 扣除补签消耗（inventory.consume_items）。
-- 3) 发放该日奖励：门槛达标发 2 倍；未达标发 1 倍并标记 pending_bonus（后续可补领奖 1 倍）。
-- 4) 更新状态并落库；若补签的是第 28 天则同样触发周期重置。
function M.rpc_checkin_makeup(context, payload)
    local decode_ok, req = json_decode_payload(payload)
    if not decode_ok then
        return make_error("CHECKIN_INVALID_PAYLOAD", "Invalid payload")
    end

    local day_id = tonumber(req.day_id or req.dayId)
    if day_id == nil or day_id % 1 ~= 0 then
        return make_error("CHECKIN_INVALID_DAY_ID", "Invalid Day_ID")
    end
    day_id = math.floor(day_id)
    if day_id < 1 or day_id > DAYS_PER_CYCLE then
        return make_error("CHECKIN_INVALID_DAY_ID", "Invalid Day_ID")
    end

    local user_id = context.user_id
    local today_str = utc_today_yyyymmdd()
    local state, version, today_day_id, dirty = M.checkin_load_state(user_id, today_str)
    if dirty then
        pcall(M.checkin_save_state, user_id, state, version)
        state, version, today_day_id = M.checkin_load_state(user_id, today_str)
    end

    local status = derive_day_status(state, today_day_id, day_id)
    if status ~= "Missed" then
        return make_error("CHECKIN_NOT_MISSED", "Day is not missed")
    end

    local gating_mode, player_level = get_gate_info(user_id)
    local reward = get_reward_row(day_id)
    if not reward then
        return make_error("CHECKIN_CONFIG_ERROR", "Configuration error for day " .. tostring(day_id))
    end

    local checkin_cfg = config.checkin or {}
    local cost = checkin_cfg.makeup_cost or {}
    local cost_item = cost.Cost_Item
    local cost_num = tonumber(cost.Num) or 0
    if type(cost_item) ~= "string" or cost_item == "" or cost_num <= 0 then
        return make_error("CHECKIN_CONFIG_ERROR", "Makeup cost config error")
    end

    local log_ref = {
        gating_mode = gating_mode,
        required_level = reward.required_level,
        player_level = player_level,
        day_id = day_id,
        cycle_no = state.cycle_no
    }

    local ok_cost, err_cost = inventory.consume_items(context, user_id, build_items(cost_item, cost_num), "makeup", log_ref)
    if not ok_cost then
        return make_error("CHECKIN_INSUFFICIENT_COST", err_cost or "Insufficient cost")
    end

    local meets = player_level >= reward.required_level
    local multiplier = meets and 2 or 1
    local rewards = build_items(reward.item_id, reward.num * multiplier)
    local ok_grant, err_grant = inventory.add_items(context, user_id, rewards, "makeup", log_ref)
    if not ok_grant then
        return make_error("CHECKIN_GRANT_FAILED", err_grant or "Grant rewards failed")
    end

    if day_id == DAYS_PER_CYCLE then
        state = cycle_reset_state(state.cycle_no, today_str)
    else
        state.days[day_id] = meets and "claimed" or "pending_bonus"
    end

    M.checkin_save_state(user_id, state, version)

    return nk.json_encode({
        success = true,
        day_id = day_id,
        rewards = rewards,
        cost = { id = cost_item, count = cost_num },
        gating_mode = gating_mode,
        player_level = player_level,
        required_level = reward.required_level,
        multiplier = multiplier,
        cycle_no = state.cycle_no
    })
end

-- RPC：补领奖流程（领取 pending_bonus 的额外奖励）：
-- 1) 校验 day_id 合法且该日对外状态为 "Pending_Bonus"。
-- 2) 校验门槛达标（否则返回 CHECKIN_GATE_NOT_MET）。
-- 3) 发放“额外的 1 倍奖励”（注意：当初签到/补签已发放基础 1 倍）。
-- 4) 将该日状态置为 claimed 并落库。
function M.rpc_checkin_claim_bonus(context, payload)
    local decode_ok, req = json_decode_payload(payload)
    if not decode_ok then
        return make_error("CHECKIN_INVALID_PAYLOAD", "Invalid payload")
    end

    local day_id = tonumber(req.day_id or req.dayId)
    if day_id == nil or day_id % 1 ~= 0 then
        return make_error("CHECKIN_INVALID_DAY_ID", "Invalid Day_ID")
    end
    day_id = math.floor(day_id)
    if day_id < 1 or day_id > DAYS_PER_CYCLE then
        return make_error("CHECKIN_INVALID_DAY_ID", "Invalid Day_ID")
    end

    local user_id = context.user_id
    local today_str = utc_today_yyyymmdd()
    local state, version, today_day_id, dirty = M.checkin_load_state(user_id, today_str)
    if dirty then
        pcall(M.checkin_save_state, user_id, state, version)
        state, version, today_day_id = M.checkin_load_state(user_id, today_str)
    end

    local status = derive_day_status(state, today_day_id, day_id)
    if status ~= "Pending_Bonus" then
        return make_error("CHECKIN_NOT_PENDING_BONUS", "Day is not pending bonus")
    end

    local gating_mode, player_level = get_gate_info(user_id)
    local reward = get_reward_row(day_id)
    if not reward then
        return make_error("CHECKIN_CONFIG_ERROR", "Configuration error for day " .. tostring(day_id))
    end

    if player_level < reward.required_level then
        return make_error("CHECKIN_GATE_NOT_MET", "Gate level not met")
    end

    local rewards = build_items(reward.item_id, reward.num)
    local ok_grant, err_grant = inventory.add_items(context, user_id, rewards, "checkin_bonus", {
        gating_mode = gating_mode,
        required_level = reward.required_level,
        player_level = player_level,
        day_id = day_id,
        cycle_no = state.cycle_no
    })
    if not ok_grant then
        return make_error("CHECKIN_GRANT_FAILED", err_grant or "Grant rewards failed")
    end

    state.days[day_id] = "claimed"
    M.checkin_save_state(user_id, state, version)

    return nk.json_encode({
        success = true,
        day_id = day_id,
        rewards = rewards,
        gating_mode = gating_mode,
        player_level = player_level,
        required_level = reward.required_level,
        cycle_no = state.cycle_no
    })
end

return M
