local nk = require("nakama")
local config = require("config")

local M = {}
local backpack_gateway = nil
local checkin_domain = nil

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
    local rewards = checkin_domain.normalize_items((checkin_cfg.rewards or {})[current_day_index])
    if #rewards == 0 then
        return checkin_domain.make_error("CHECKIN_CONFIG_ERROR", "No rewards config for today")
    end

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
    return nk.json_encode({ success = true, rewards = rewards, day_index = current_day_index, status = "signed" })
end

function M.rpc_checkin_makeup(context, payload)
    if not checkin_domain or not backpack_gateway then
        return nk.json_encode({ error = "Checkin service not wired", error_code = "CHECKIN_SERVICE_ERROR" })
    end
    local user_id = context.user_id
    local req = nk.json_decode(payload)
    local target_day = req.day_index

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

    local success_cost, _ = backpack_gateway.consume_items(context, user_id, consume_items, "checkin_makeup_cost", {
        cycle_no = cycle_no,
        target_day = target_day
    })
    if not success_cost then
        return checkin_domain.make_error("CHECKIN_INSUFFICIENT_COST", "Insufficient crystals")
    end

    local rewards = checkin_domain.normalize_items((checkin_cfg.rewards or {})[target_day])
    if #rewards == 0 then
        backpack_gateway.add_items(context, user_id, consume_items, "checkin_makeup_refund", {})
        return checkin_domain.make_error("CHECKIN_CONFIG_ERROR", "No rewards config")
    end

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
    return nk.json_encode({ success = true, rewards = rewards, day_index = target_day, status = "makeup_signed" })
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
