local config = require("config")

local M = {}

local function resolve_item_id(item_id)
    if item_id == nil then
        return nil
    end
    local normalized = tostring(item_id)
    if normalized == "" then
        return nil
    end
    return normalized
end

local function normalize_level(level)
    local n = tonumber(level)
    if n == nil then
        return nil
    end
    n = math.floor(n)
    if n < 1 then
        return nil
    end
    return n
end

local function get_attr_config(item_id, level)
    local by_level = config.skill_enhancement_item_configs_by_item_id and config.skill_enhancement_item_configs_by_item_id[item_id]
    if type(by_level) ~= "table" then
        return nil
    end
    return by_level[level]
end

local function get_upgrade_config(item_id)
    local by_item = config.skill_enhancement_upgrade_configs_by_item_id or {}
    return by_item[item_id]
end

local function get_upgrade_cost(item_id, level)
    local upgrade = get_upgrade_config(item_id)
    if type(upgrade) ~= "table" then
        return nil
    end
    local by_level = upgrade.upgradeCostsByLevel or {}
    return by_level[level]
end

local function get_max_level(item_id)
    local by_item = config.skill_enhancement_max_level_by_item_id or {}
    local max_level = tonumber(by_item[item_id])
    if max_level == nil then
        return nil
    end
    return math.floor(max_level)
end

local function get_quality(item_id)
    local upgrade = get_upgrade_config(item_id)
    if type(upgrade) ~= "table" then
        return nil
    end
    local quality = tonumber(upgrade.quality)
    if quality == nil then
        return nil
    end
    return math.floor(quality)
end

function M.validate_request(item_id, level)
    local normalized_item_id = resolve_item_id(item_id)
    if normalized_item_id == nil then
        return nil, nil, "INVALID_ITEM_ID"
    end
    local normalized_level = normalize_level(level)
    if normalized_level == nil then
        return nil, nil, "INVALID_LEVEL"
    end
    return normalized_item_id, normalized_level, nil
end

function M.get_detail_meta(item_id, level)
    local normalized_item_id, normalized_level, validate_err = M.validate_request(item_id, level)
    if validate_err ~= nil then
        return nil, validate_err
    end
    local attr = get_attr_config(normalized_item_id, normalized_level)
    if attr == nil then
        return nil, "ATTR_NOT_FOUND"
    end
    local quality = get_quality(normalized_item_id)
    if quality == nil then
        return nil, "UPGRADE_NOT_FOUND"
    end
    local max_level = get_max_level(normalized_item_id)
    local is_max_level = max_level ~= nil and normalized_level >= max_level
    local upgrade_cost = nil
    if not is_max_level then
        upgrade_cost = get_upgrade_cost(normalized_item_id, normalized_level)
    end
    return {
        itemId = normalized_item_id,
        level = normalized_level,
        quality = quality,
        attr = attr,
        upgradeCost = upgrade_cost,
        maxLevel = max_level,
        isMaxLevel = is_max_level
    }, nil
end

function M.get_upgrade_plan(item_id, level)
    local detail_meta, detail_err = M.get_detail_meta(item_id, level)
    if detail_err ~= nil then
        return nil, detail_err
    end
    if detail_meta.upgradeCost == nil then
        if detail_meta.isMaxLevel then
            return nil, "MAX_LEVEL"
        end
        return nil, "UPGRADE_COST_NOT_FOUND"
    end
    return {
        itemId = detail_meta.itemId,
        fromLevel = detail_meta.level,
        toLevel = detail_meta.level + 1,
        quality = detail_meta.quality,
        fragmentItemId = detail_meta.upgradeCost.fragmentItemId,
        costItemCount = tonumber(detail_meta.upgradeCost.costItemCount) or 0
    }, nil
end

return M
