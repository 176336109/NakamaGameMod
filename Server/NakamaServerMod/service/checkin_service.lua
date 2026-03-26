local nk = require("nakama")
local config = require("config")

local M = {}
local backpack_gateway = nil
local checkin_domain = nil

local function decode_wallet_value(wallet_value)
    if type(wallet_value) == "table" then
        return wallet_value
    end
    if type(wallet_value) == "string" and wallet_value ~= "" then
        local ok, decoded = pcall(nk.json_decode, wallet_value)
        if ok and type(decoded) == "table" then
            return decoded
        end
    end
    return {}
end

local function collect_currency_ids(items)
    local ids = {}
    if type(items) ~= "table" then
        return ids
    end
    local item_defs = config.items or {}
    for _, item in ipairs(items) do
        local item_id = item and item.id
        if type(item_id) == "string" and item_id ~= "" then
            local item_def = item_defs[item_id]
            if type(item_def) == "table" and item_def.type == "currency" then
                ids[item_id] = true
            end
        end
    end
    return ids
end

local function merge_currency_ids(target, source)
    for item_id, enabled in pairs(source or {}) do
        if enabled then
            target[item_id] = true
        end
    end
    return target
end

local function read_wallet_amounts(user_id, currency_ids)
    local has_currency = false
    for _ in pairs(currency_ids or {}) do
        has_currency = true
        break
    end
    if not has_currency then
        return {}
    end
    local ok, account = pcall(nk.account_get_id, user_id)
    if not ok or type(account) ~= "table" then
        return {}
    end
    local wallet = decode_wallet_value(account.wallet)
    local out = {}
    for item_id, _ in pairs(currency_ids) do
        out[item_id] = tonumber(wallet[item_id]) or 0
    end
    return out
end

local function build_wallet_changes(currency_ids, before_wallet, after_wallet)
    local out = {}
    for item_id, _ in pairs(currency_ids or {}) do
        local before_count = tonumber(before_wallet and before_wallet[item_id]) or 0
        local after_count = tonumber(after_wallet and after_wallet[item_id]) or 0
        table.insert(out, {
            id = item_id,
            before = before_count,
            after = after_count,
            delta = after_count - before_count
        })
    end
    table.sort(out, function(a, b)
        return a.id < b.id
    end)
    return out
end

function M.wire_item_gateway(backpack, checkin)
    backpack_gateway = backpack
    checkin_domain = checkin
end

function M.rpc_checkin_get_state(context, payload)
    if not checkin_domain then
        return nk.json_encode({ error = "Checkin service not wired", error_code = "CHECKIN_SERVICE_ERROR" })
    end
    return nk.json_encode(checkin_domain.get_state_data(context.user_id))
end

function M.rpc_daily_checkin(context, payload)
    if not checkin_domain or not backpack_gateway then
        return nk.json_encode({ error = "Checkin service not wired", error_code = "CHECKIN_SERVICE_ERROR" })
    end
    local user_id = context.user_id
    local cycle_no, current_day_index, current_day = checkin_domain.get_cycle_info(user_id)
    local cycle_id_str = "C" .. tostring(cycle_no)
    local state, version = checkin_domain.load_state(user_id)

    if not state.cycleId or state.cycleId ~= cycle_id_str then
        state = checkin_domain.reset_cycle_state(cycle_id_str, state, current_day_index, current_day)
    end

    local day_str = tostring(current_day_index)
    if state.days[day_str] then
        return checkin_domain.make_error("CHECKIN_ALREADY_CLAIMED", "Already checked in today")
    end

    local checkin_cfg = config.checkin or {}
    local rewards_cfg = checkin_cfg.rewards or {}
    local rewards = checkin_domain.normalize_items(rewards_cfg[current_day_index] or rewards_cfg[tostring(current_day_index)])
    if #rewards == 0 then
        return checkin_domain.make_error("CHECKIN_CONFIG_ERROR", "No rewards config for today")
    end
    local currency_ids = collect_currency_ids(rewards)
    local wallet_before = read_wallet_amounts(user_id, currency_ids)

    local success, err = backpack_gateway.add_items(context, user_id, rewards, "daily_checkin", {
        cycle_no = cycle_no,
        day_index = current_day_index
    })
    if not success then
        return checkin_domain.make_error("CHECKIN_GRANT_FAILED", err)
    end

    local claim_at = os.time()
    state.days[day_str] = { status = "signed", claimAt = claim_at, claimType = "normal" }
    checkin_domain.set_day_claimed(state, current_day_index, "signed", "normal", claim_at)
    checkin_domain.save_state(user_id, state, version)
    local wallet_after = read_wallet_amounts(user_id, currency_ids)
    local wallet_changes = build_wallet_changes(currency_ids, wallet_before, wallet_after)
    return nk.json_encode({
        success = true,
        rewards = rewards,
        day_index = current_day_index,
        status = "signed",
        wallet_changes = wallet_changes
    })
end

function M.rpc_checkin_makeup(context, payload)
    if not checkin_domain or not backpack_gateway then
        return nk.json_encode({ error = "Checkin service not wired", error_code = "CHECKIN_SERVICE_ERROR" })
    end
    local user_id = context.user_id
    local req = nk.json_decode(payload)
    local target_day = tonumber(req.day_index)

    if not target_day or target_day < 1 or target_day > 7 then
        return checkin_domain.make_error("CHECKIN_INVALID_PARAM", "Invalid day index")
    end

    local cycle_no, current_day_index, current_day = checkin_domain.get_cycle_info(user_id)
    local cycle_id_str = "C" .. tostring(cycle_no)
    if target_day >= current_day_index then
        return checkin_domain.make_error("CHECKIN_INVALID_ACTION", "Cannot makeup for today or future")
    end

    local state, version = checkin_domain.load_state(user_id)
    if not state.cycleId or state.cycleId ~= cycle_id_str then
        state = checkin_domain.reset_cycle_state(cycle_id_str, state, current_day_index, current_day)
    end

    local day_str = tostring(target_day)
    if state.days[day_str] then
        return checkin_domain.make_error("CHECKIN_ALREADY_CLAIMED", "Day already signed")
    end

    local checkin_cfg = config.checkin or {}
    local cost = checkin_cfg.makeup_cost
    if not cost then
        return checkin_domain.make_error("CHECKIN_CONFIG_ERROR", "Makeup cost not configured")
    end

    local consume_items = checkin_domain.normalize_items({ { id = cost.id, item_id = cost.item_id, count = cost.count } })
    if #consume_items == 0 then
        return checkin_domain.make_error("CHECKIN_CONFIG_ERROR", "Invalid makeup cost config")
    end
    local currency_ids = collect_currency_ids(consume_items)
    local wallet_before = read_wallet_amounts(user_id, currency_ids)

    local success_cost, _ = backpack_gateway.consume_items(context, user_id, consume_items, "checkin_makeup_cost", {
        cycle_no = cycle_no,
        target_day = target_day
    })
    if not success_cost then
        return checkin_domain.make_error("CHECKIN_INSUFFICIENT_COST", "Insufficient crystals")
    end

    local rewards_cfg = checkin_cfg.rewards or {}
    local rewards = checkin_domain.normalize_items(rewards_cfg[target_day] or rewards_cfg[tostring(target_day)])
    if #rewards == 0 then
        backpack_gateway.add_items(context, user_id, consume_items, "checkin_makeup_refund", {})
        return checkin_domain.make_error("CHECKIN_CONFIG_ERROR", "No rewards config")
    end
    merge_currency_ids(currency_ids, collect_currency_ids(rewards))

    local success_grant, err_grant = backpack_gateway.add_items(context, user_id, rewards, "checkin_makeup_reward", {
        cycle_no = cycle_no,
        target_day = target_day
    })
    if not success_grant then
        backpack_gateway.add_items(context, user_id, consume_items, "checkin_makeup_refund", {})
        return checkin_domain.make_error("CHECKIN_GRANT_FAILED", err_grant)
    end

    local claim_at = os.time()
    state.days[day_str] = { status = "makeup_signed", claimAt = claim_at, claimType = "makeup" }
    checkin_domain.set_day_claimed(state, target_day, "makeup_signed", "makeup", claim_at)
    checkin_domain.save_state(user_id, state, version)
    local wallet_after = read_wallet_amounts(user_id, currency_ids)
    local wallet_changes = build_wallet_changes(currency_ids, wallet_before, wallet_after)
    return nk.json_encode({
        success = true,
        rewards = rewards,
        day_index = target_day,
        status = "makeup_signed",
        wallet_changes = wallet_changes
    })
end

function M.rpc_debug_set_time_offset(context, payload)
    if not checkin_domain then
        return nk.json_encode({ error = "Checkin service not wired", error_code = "CHECKIN_SERVICE_ERROR" })
    end
    local req = nk.json_decode(payload)
    local offset = checkin_domain.set_time_offset(context.user_id, req.offset)
    return nk.json_encode({ success = true, offset = offset })
end

return M
