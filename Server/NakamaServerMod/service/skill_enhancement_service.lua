local nk = require("nakama")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}
local backpack_gateway = nil
local skill_domain = nil

local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
end

function M.wire_item_gateway(backpack, domain_skill)
    backpack_gateway = backpack
    skill_domain = domain_skill
end

local function service_ready()
    return backpack_gateway ~= nil and skill_domain ~= nil
end

local function parse_payload(payload)
    local ok, req = pcall(nk.json_decode, payload or "")
    if not ok or type(req) ~= "table" then
        return nil
    end
    return req
end

local function map_domain_error(domain_err)
    if domain_err == "INVALID_ITEM_ID" then
        return "SKILL_ENHANCEMENT_INVALID_PARAM", "参数非法"
    end
    if domain_err == "INVALID_LEVEL" then
        return "SKILL_ENHANCEMENT_INVALID_LEVEL", "非法等级"
    end
    if domain_err == "ATTR_NOT_FOUND" then
        return "SKILL_ENHANCEMENT_CONFIG_MISSING", "属性配置缺失"
    end
    if domain_err == "UPGRADE_NOT_FOUND" then
        return "SKILL_ENHANCEMENT_CONFIG_MISSING", "升级配置缺失"
    end
    if domain_err == "MAX_LEVEL" then
        return "SKILL_ENHANCEMENT_MAX_LEVEL", "已满级"
    end
    if domain_err == "UPGRADE_COST_NOT_FOUND" then
        return "SKILL_ENHANCEMENT_CONFIG_MISSING", "升级配置缺失"
    end
    return "COMMON_INTERNAL_ERROR", tostring(domain_err or "unknown")
end

local function format_detail(stack_record, detail_meta)
    local upgrade = nil
    if detail_meta.isMaxLevel ~= true and type(detail_meta.upgradeCost) == "table" then
        upgrade = {
            level = tonumber(detail_meta.upgradeCost.level) or detail_meta.level,
            fragmentItemId = detail_meta.upgradeCost.fragmentItemId,
            costItemCount = tonumber(detail_meta.upgradeCost.costItemCount) or 0
        }
    end
    return {
        stackItemRecord = {
            itemId = stack_record.itemId,
            level = stack_record.level,
            count = stack_record.count,
            hasExpireAt = stack_record.expireAt ~= nil,
            expireAt = stack_record.expireAt or 0
        },
        quality = detail_meta.quality,
        attr = detail_meta.attr,
        upgrade = upgrade,
        maxLevel = detail_meta.maxLevel,
        isMaxLevel = detail_meta.isMaxLevel
    }
end

local function pick_source_record(records, explicit_expire_at)
    if type(records) ~= "table" or #records == 0 then
        return nil
    end
    if explicit_expire_at ~= nil then
        return records[1]
    end
    return records[1]
end

function M.rpc_skill_enhancement_get_detail(context, payload)
    if not service_ready() then
        return fail_by_key("SKILL_ENHANCEMENT_SERVICE_NOT_WIRED", "Skill enhancement service not wired")
    end
    local req = parse_payload(payload)
    if req == nil then
        return fail_by_key("SKILL_ENHANCEMENT_INVALID_PARAM", "参数非法")
    end
    local item_id, level, validate_err = skill_domain.validate_request(req.itemId, req.level)
    if validate_err ~= nil then
        local key, message = map_domain_error(validate_err)
        return fail_by_key(key, message)
    end
    local expire_at = tonumber(req.expireAt)
    if expire_at ~= nil and expire_at <= 0 then
        expire_at = nil
    end
    local ok_records, records_or_err = backpack_gateway.find_stack_records(context.user_id, item_id, level, expire_at)
    if not ok_records then
        return fail_by_key("COMMON_STORAGE_READ_FAILED", tostring(records_or_err))
    end
    local source_record = pick_source_record(records_or_err, expire_at)
    if source_record == nil then
        return fail_by_key("SKILL_ENHANCEMENT_NOT_FOUND", "物品不存在")
    end
    local detail_meta, detail_err = skill_domain.get_detail_meta(item_id, level)
    if detail_err ~= nil then
        local key, message = map_domain_error(detail_err)
        return fail_by_key(key, message)
    end
    local detail = format_detail(source_record, detail_meta)
    return response.ok({ detail = detail })
end

function M.rpc_skill_enhancement_upgrade(context, payload)
    if not service_ready() then
        return fail_by_key("SKILL_ENHANCEMENT_SERVICE_NOT_WIRED", "Skill enhancement service not wired")
    end
    local req = parse_payload(payload)
    if req == nil then
        return fail_by_key("SKILL_ENHANCEMENT_INVALID_PARAM", "参数非法")
    end
    local item_id, level, validate_err = skill_domain.validate_request(req.itemId, req.level)
    if validate_err ~= nil then
        local key, message = map_domain_error(validate_err)
        return fail_by_key(key, message)
    end
    local expire_at = tonumber(req.expireAt)
    if expire_at ~= nil and expire_at <= 0 then
        expire_at = nil
    end
    local ok_records, records_or_err = backpack_gateway.find_stack_records(context.user_id, item_id, level, expire_at)
    if not ok_records then
        return fail_by_key("COMMON_STORAGE_READ_FAILED", tostring(records_or_err))
    end
    local source_record = pick_source_record(records_or_err, expire_at)
    if source_record == nil then
        return fail_by_key("SKILL_ENHANCEMENT_NOT_FOUND", "物品不存在")
    end
    local plan, plan_err = skill_domain.get_upgrade_plan(item_id, level)
    if plan_err ~= nil then
        local key, message = map_domain_error(plan_err)
        return fail_by_key(key, message)
    end
    local target_detail_meta, target_detail_err = skill_domain.get_detail_meta(item_id, plan.toLevel)
    if target_detail_err ~= nil then
        return fail_by_key("SKILL_ENHANCEMENT_CONFIG_MISSING", "属性配置缺失")
    end
    if plan.costItemCount < 1 then
        return fail_by_key("SKILL_ENHANCEMENT_CONFIG_MISSING", "升级配置缺失")
    end
    local ok_fragment_count, fragment_count_or_err = backpack_gateway.get_item_total_count(context.user_id, plan.fragmentItemId)
    if not ok_fragment_count then
        return fail_by_key("COMMON_STORAGE_READ_FAILED", tostring(fragment_count_or_err))
    end
    if tonumber(fragment_count_or_err) < plan.costItemCount then
        return fail_by_key("SKILL_ENHANCEMENT_FRAGMENT_NOT_ENOUGH", "碎片不足")
    end
    local ok_consume_fragment, consume_fragment_err = backpack_gateway.consume_items(context, context.user_id, {
        {
            id = plan.fragmentItemId,
            count = plan.costItemCount
        }
    }, "skill_upgrade_consume_fragment")
    if not ok_consume_fragment then
        return fail_by_key("SKILL_ENHANCEMENT_FRAGMENT_NOT_ENOUGH", tostring(consume_fragment_err))
    end
    local ok_consume_item, consume_item_err = backpack_gateway.consume_items(context, context.user_id, {
        {
            id = item_id,
            count = 1,
            level = level,
            expireAt = source_record.expireAt
        }
    }, "skill_upgrade_consume_item")
    if not ok_consume_item then
        pcall(backpack_gateway.add_items, context, context.user_id, {
            {
                id = plan.fragmentItemId,
                count = plan.costItemCount
            }
        }, "skill_upgrade_rollback_fragment")
        return fail_by_key("SKILL_ENHANCEMENT_UPGRADE_FAILED", tostring(consume_item_err))
    end
    if req.testFailStage == "after_consume_item" then
        pcall(backpack_gateway.add_items, context, context.user_id, {
            {
                id = item_id,
                count = 1,
                level = level,
                expireAt = source_record.expireAt
            }
        }, "skill_upgrade_rollback_item")
        pcall(backpack_gateway.add_items, context, context.user_id, {
            {
                id = plan.fragmentItemId,
                count = plan.costItemCount
            }
        }, "skill_upgrade_rollback_fragment")
        return fail_by_key("SKILL_ENHANCEMENT_UPGRADE_FAILED", "升级迁移失败")
    end
    local ok_add_target, add_target_err = backpack_gateway.add_items(context, context.user_id, {
        {
            id = item_id,
            count = 1,
            level = plan.toLevel,
            expireAt = source_record.expireAt
        }
    }, "skill_upgrade_add_target")
    if not ok_add_target then
        pcall(backpack_gateway.add_items, context, context.user_id, {
            {
                id = item_id,
                count = 1,
                level = level,
                expireAt = source_record.expireAt
            }
        }, "skill_upgrade_rollback_item")
        pcall(backpack_gateway.add_items, context, context.user_id, {
            {
                id = plan.fragmentItemId,
                count = plan.costItemCount
            }
        }, "skill_upgrade_rollback_fragment")
        return fail_by_key("SKILL_ENHANCEMENT_UPGRADE_FAILED", tostring(add_target_err))
    end
    local ok_target_records, target_records_or_err = backpack_gateway.find_stack_records(context.user_id, item_id, plan.toLevel, source_record.expireAt)
    if not ok_target_records then
        return fail_by_key("COMMON_STORAGE_READ_FAILED", tostring(target_records_or_err))
    end
    local target_record = pick_source_record(target_records_or_err, source_record.expireAt)
    if target_record == nil then
        return fail_by_key("SKILL_ENHANCEMENT_UPGRADE_FAILED", "升级后目标等级记录缺失")
    end
    local detail = format_detail(target_record, target_detail_meta)
    return response.ok({
        detail = detail,
        migration = {
            fromLevel = level,
            toLevel = plan.toLevel,
            fragmentItemId = plan.fragmentItemId,
            fragmentCost = plan.costItemCount
        }
    })
end

return M
