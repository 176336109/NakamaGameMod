local nk = require("nakama")
local config = require("config")

local M = {}
local backpack_gateway = nil
local shop_domain = nil

function M.wire_item_gateway(backpack, shop)
    backpack_gateway = backpack
    shop_domain = shop
end

function M.rpc_shop_get_state(context, payload)
    if not shop_domain or type(shop_domain.get_state_data) ~= "function" then
        return nk.json_encode({ success = false, error = "Shop service not wired" })
    end
    local response = shop_domain.get_state_data(context.user_id)
    response.success = true
    return nk.json_encode(response)
end

function M.rpc_shop_refresh(context, payload)
    if not backpack_gateway or not shop_domain then
        return nk.json_encode({ success = false, error = "Shop service not wired" })
    end

    local user_id = context.user_id
    local cost_cfg = config.shop.refresh_cost
    local ok, err = backpack_gateway.consume_items(context, user_id, {{ id = cost_cfg.item_id, count = cost_cfg.count }}, "shop_refresh")
    if not ok then
        return nk.json_encode({ success = false, error = "Insufficient crystals: " .. (err or "") })
    end

    local snapshot = shop_domain.generate_special_snapshot()
    shop_domain.save_shop_snapshot(user_id, snapshot)
    return nk.json_encode({ success = true, snapshot = snapshot })
end

function M.rpc_shop_buy(context, payload)
    if not backpack_gateway or not shop_domain then
        return nk.json_encode({ success = false, error = "Shop service not wired" })
    end

    local req = nk.json_decode(payload)
    local goods_id = req.goodsId
    local user_id = context.user_id
    local cfg = config.shop.goods[goods_id]
    if not cfg then
        return nk.json_encode({ success = false, error = "Goods not found" })
    end

    local today_str = shop_domain.get_beijing_today_str()
    local week_key = shop_domain.get_beijing_week_key()
    local snapshot = shop_domain.load_shop_snapshot(user_id)
    local limit_state, limit_version = shop_domain.load_limit_state(user_id)
    local state = limit_state[goods_id] or { progress = 0 }
    local progress = shop_domain.compute_limit_progress(cfg, state, snapshot.snapshotId, today_str, week_key)
    local limit_type = cfg.limitType or "none"
    local limit_value = tonumber(cfg.limitValue) or 0

    if limit_type ~= "none" and progress >= limit_value then
        return nk.json_encode({ success = false, error = "Limit reached" })
    end

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
        ok_cost, err_cost = backpack_gateway.consume_items(context, user_id, {{ id = cost_type, count = cost_value }}, "shop_buy_" .. goods_id)
        if not ok_cost then
            return nk.json_encode({ success = false, error = "Insufficient funds: " .. (err_cost or "") })
        end
    end

    local ok_reward, err_reward = backpack_gateway.add_items(context, user_id, cfg.rewardItems, "shop_buy_" .. goods_id)
    if not ok_reward then
        nk.logger_error("Reward grant failed after cost deduction! User: " .. user_id .. " Goods: " .. goods_id)
        return nk.json_encode({ success = false, error = "Grant reward failed: " .. (err_reward or "") })
    end

    state = shop_domain.apply_limit_progress(cfg, state, snapshot.snapshotId, today_str, week_key)
    limit_state[goods_id] = state
    shop_domain.save_limit_state(user_id, limit_state, limit_version)
    return nk.json_encode({ success = true, progress = state.progress })
end

return M
