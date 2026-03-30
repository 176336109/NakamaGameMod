--[[
inventory.lua

职责：
- 提供“背包/货币”的统一读写入口：货币走 Nakama Wallet；非货币物品走 Storage(collection="backpack")。
- 封装物品增减（加物品/消耗物品）的读写与一致性策略，并在必要时写入变更流水(collection="inventory_log")。
- 对外暴露一组 RPC：查询钱包、查询指定物品数量、列出背包、查询变更流水（带权限控制）。

数据约定：
- Storage(collection="backpack", key=item_id, user_id=玩家) 的 value 形如：
  - count: number，数量（可为 0；写入时会直接覆盖/更新）
  - type: string，物品类型（来自 config.items[item_id].type）
- Wallet：仅用于 config.items[item_id].type == "currency" 的条目，余额由 nk.wallet_update 原子更新。

一致性/权限要点：
- Wallet 更新通过 nk.wallet_update(..., check=true) 在服务端做“余额不足”原子校验。
- Storage 更新使用 version 做乐观并发控制；加物品会在冲突时重读并重试一次。
- backpack 对象 permission_read=1、permission_write=1（当前实现允许客户端读写同用户记录；如需更严可在外层 RPC/服务端逻辑限制）。
- inventory_log 对象 permission_read=1、permission_write=0（仅服务端写；客户端可读同用户日志，跨用户需管理员权限）。
]]

local nk = require("nakama")
local config = require("config")

local M = {}

local BACKPACK_COLLECTION = "backpack"
local NORMAL_ITEM_KEY = "normalItem"
local VIP_ITEM_ID = "item_vip_active"
local SVIP_ITEM_ID = "item_svip_active"

-- 生成安全唯一ID，优先使用 nk.uuid_v4，失败时退回随机串。
local function safe_uuid()
    if nk.uuid_v4 ~= nil then
        local ok, value = pcall(nk.uuid_v4)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end
    return tostring(math.random(1000000000, 2147483647)) .. tostring(math.random(1000000000, 2147483647))
end

-- 安全数值转换，失败返回默认值。
local function to_number(v, default_value)
    local n = tonumber(v)
    if n == nil then
        return default_value
    end
    return n
end

local function normalize_expire_at(v)
    local n = to_number(v, nil)
    if n == nil then
        return nil
    end
    if n <= 0 then
        return nil
    end
    return n
end

local function normalize_level(level)
    local n = to_number(level, 1)
    if n == nil then
        return 1
    end
    n = math.floor(n)
    if n < 1 then
        return 1
    end
    return n
end

-- 当前秒级时间戳。
local function now_ts()
    return os.time()
end

-- 解析 RPC 入参 JSON。
local function decode_payload(payload)
    if payload == nil or payload == "" then
        return true, {}
    end
    local ok, value = pcall(nk.json_decode, payload)
    if not ok then
        return false, nil
    end
    if type(value) ~= "table" then
        return false, nil
    end
    return true, value
end

-- 统一道具 ID 规范化。
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

local function clone_row(row)
    local out = {}
    if type(row) ~= "table" then
        return out
    end
    for k, v in pairs(row) do
        out[k] = v
    end
    return out
end

local function parse_item_id_from_stack_key(stack_key)
    if type(stack_key) ~= "string" or stack_key == "" then
        return nil
    end
    local matched = string.match(stack_key, "^stack:(.-):L%d+:")
    if matched ~= nil and matched ~= "" then
        return resolve_item_id(matched)
    end
    if string.find(stack_key, ":", 1, true) == nil then
        return resolve_item_id(stack_key)
    end
    return nil
end

local function build_stack_key_for_normal_item(item_data, fallback_key)
    local item_id = resolve_item_id(item_data and item_data.itemId)
    if item_id == nil then
        item_id = parse_item_id_from_stack_key(fallback_key)
    end
    local level = normalize_level(item_data and item_data.level)
    local expire_at = to_number(item_data and item_data.expireAt, nil)
    if item_id == nil then
        if type(fallback_key) == "string" and fallback_key ~= "" then
            return fallback_key
        end
        return nil
    end
    if expire_at == nil then
        return "stack:" .. tostring(item_id) .. ":L" .. tostring(level) .. ":P"
    end
    return "stack:" .. tostring(item_id) .. ":L" .. tostring(level) .. ":E" .. tostring(expire_at)
end

local function decode_normal_item_value(raw_value)
    local out = {}
    if type(raw_value) ~= "table" then
        return out
    end
    local source_rows = raw_value
    if type(raw_value.normalItemList) == "table" then
        source_rows = raw_value.normalItemList
    end
    for key, row in pairs(source_rows) do
        if type(row) == "table" then
            local map_key = build_stack_key_for_normal_item(row, key)
            if map_key ~= nil then
                local copied = clone_row(row)
                copied.itemId = resolve_item_id(copied.itemId) or parse_item_id_from_stack_key(map_key)
                out[map_key] = copied
            end
        end
    end
    return out
end

local function encode_normal_item_value(raw_value)
    local rows = {}
    if type(raw_value) ~= "table" then
        return rows
    end
    for key, row in pairs(raw_value) do
        if type(row) == "table" then
            local copied = clone_row(row)
            copied.itemId = resolve_item_id(copied.itemId) or parse_item_id_from_stack_key(key)
            rows[#rows + 1] = copied
        end
    end
    table.sort(rows, function(a, b)
        local ak = build_stack_key_for_normal_item(a, "")
        local bk = build_stack_key_for_normal_item(b, "")
        return tostring(ak or "") < tostring(bk or "")
    end)
    return { normalItemList = rows }
end

-- 解析钱包字段为 table。
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

-- 执行钱包原子更新（可启用余额检查）。
local function apply_wallet_update(user_id, wallet_changes, source, strict)
    local ok, updated = pcall(nk.wallet_update, user_id, wallet_changes, { source = source }, strict)
    if not ok then
        return false, tostring(updated)
    end
    return true, updated or {}
end

-- 判断过期时间是否仍生效。
local function is_effective(expire_at, now)
    if expire_at == nil then
        return true
    end
    return expire_at > now
end

-- 读取背包槽位上限配置。
local function get_slot_capacity()
    local backpack_cfg = config.backpack or {}
    local slot_capacity = to_number(backpack_cfg.slotCapacity, nil)
    if slot_capacity == nil then
        slot_capacity = to_number(backpack_cfg.slot_capacity, 100)
    end
    if slot_capacity < 1 then
        slot_capacity = 1
    end
    return math.floor(slot_capacity)
end

-- 读取并组装道具配置元信息。
local function get_item_config(item_id)
    local item_def = config.items and config.items[item_id]
    if not item_def then
        return nil
    end
    local is_currency = item_def.type == "currency"
    local is_entitlement = item_def.type == "entitlement"
    local is_vip_like = item_id == VIP_ITEM_ID or item_id == SVIP_ITEM_ID
    local stackable = not is_vip_like and not is_currency and not is_entitlement
    if item_def.max_stack ~= nil and tonumber(item_def.max_stack) == 1 and (item_def.type == "time_limited" or item_def.type == "entitlement") then
        stackable = false
    end
    local require_expire_at = is_vip_like or is_entitlement or item_def.type == "time_limited"
    local has_expire_at = require_expire_at or item_def.hasExpireAt == true or item_def.has_expire_at == true
    local occupy_slot = not is_currency
    local max_stack_count = to_number(item_def.max_stack, 999999999)
    return {
        itemId = item_id,
        itemName = item_def.name or item_id,
        itemDesc = item_def.itemDesc or ((item_def.name or item_id) .. "说明"),
        itemType = item_def.type,
        stackable = stackable,
        hasExpireAt = has_expire_at,
        requireExpireAt = require_expire_at,
        occupySlot = occupy_slot,
        maxStackCount = max_stack_count
    }
end

-- 生成对外返回的道具定义结构。
local function build_item_definition(item_id)
    local item_cfg = get_item_config(item_id)
    if not item_cfg then
        return nil
    end
    return {
        itemId = item_cfg.itemId,
        itemName = item_cfg.itemName,
        itemDesc = item_cfg.itemDesc,
        itemType = item_cfg.itemType,
        stackable = item_cfg.stackable,
        hasExpireAt = item_cfg.hasExpireAt,
        maxStackCount = item_cfg.maxStackCount,
        occupySlot = item_cfg.occupySlot
    }
end

-- 分页拉取用户某集合全部对象。
local function list_all_objects(user_id, collection)
    local all = {}
    local cursor = nil
    local rounds = 0
    while true do
        rounds = rounds + 1
        if rounds > 100 then
            break
        end
        local ok, objects, next_cursor = pcall(nk.storage_list, user_id, collection, 100, cursor)
        if not ok then
            ok, objects, next_cursor = pcall(nk.storage_list, collection, user_id, 100, cursor)
        end
        if not ok then
            return false, tostring(objects)
        end
        for _, obj in ipairs(objects or {}) do
            all[#all + 1] = obj
        end
        if next_cursor == nil or next_cursor == "" then
            break
        end
        cursor = next_cursor
    end
    return true, all
end

-- 加载用户背包快照（key->object 映射）。
local function load_snapshot(user_id)
    local ok, objects_or_err = list_all_objects(user_id, BACKPACK_COLLECTION)
    if not ok then
        return false, objects_or_err
    end
    local by_key = {}
    for _, obj in ipairs(objects_or_err) do
        local value = obj.value or {}
        if obj.key == NORMAL_ITEM_KEY then
            value = decode_normal_item_value(value)
        end
        by_key[obj.key] = {
            key = obj.key,
            value = value,
            version = obj.version
        }
    end
    return true, by_key
end

-- 判断是否为可堆叠记录。
local function is_stack_record(value)
    return type(value) == "table" and value.recordType == "stack"
end

-- 获取 normalItem 聚合对象，不存在则创建。
local function get_normal_item_object(snapshot)
    local obj = snapshot[NORMAL_ITEM_KEY]
    if not obj then
        obj = {
            key = NORMAL_ITEM_KEY,
            version = nil,
            value = {}
        }
        snapshot[NORMAL_ITEM_KEY] = obj
    end
    if type(obj.value) ~= "table" then
        obj.value = {}
    end
    return obj
end

-- 判断是否为实例型记录（VIP/SVIP 或 instance:*）。
local function is_instance_record(key, value)
    if type(value) ~= "table" then
        return false
    end
    if value.recordType == "instance" then
        return true
    end
    if key == VIP_ITEM_ID or key == SVIP_ITEM_ID then
        return true
    end
    return false
end

-- 重算当前已占用槽位数。
local function recalc_used_slots(snapshot, now)
    local used = 0
    for key, obj in pairs(snapshot) do
        local value = obj.value or {}
        if is_stack_record(value) then
            local count = to_number(value.count, 0)
            local has_expire = value.hasExpireAt == true
            local expire_at = to_number(value.expireAt, nil)
            if count > 0 and ((not has_expire) or is_effective(expire_at, now)) then
                used = used + 1
            end
        elseif is_instance_record(key, value) then
            local expire_at = to_number(value.expireAt, nil)
            if is_effective(expire_at, now) then
                used = used + 1
            end
        elseif key == NORMAL_ITEM_KEY and type(value) == "table" then
            for _, v in pairs(value) do
                if type(v) == "table" and to_number(v.count, 0) > 0 then
                    local has_expire = v.hasExpireAt == true
                    local expire_at = to_number(v.expireAt, nil)
                    if (not has_expire) or is_effective(expire_at, now) then
                        used = used + 1
                    end
                end
            end
        end
    end
    return used
end

-- 清理快照中过期或无效记录。
local function cleanup_expired(snapshot, now, touched)
    for key, obj in pairs(snapshot) do
        local value = obj.value or {}
        if is_stack_record(value) then
            local has_expire = value.hasExpireAt == true
            local expire_at = to_number(value.expireAt, nil)
            local count = to_number(value.count, 0)
            if count <= 0 then
                value.count = 0
                touched[key] = true
            elseif has_expire and not is_effective(expire_at, now) then
                value.count = 0
                touched[key] = true
            end
        elseif is_instance_record(key, value) then
            local expire_at = to_number(value.expireAt, nil)
            if expire_at ~= nil and not is_effective(expire_at, now) then
                value.expired = true
                touched[key] = true
            end
        elseif key == NORMAL_ITEM_KEY and type(value) == "table" then
            local changed = false
            for _, item_data in pairs(value) do
                if type(item_data) == "table" then
                    local count = to_number(item_data.count, 0)
                    local has_expire = item_data.hasExpireAt == true
                    local expire_at = to_number(item_data.expireAt, nil)
                    if count <= 0 then
                        item_data.count = 0
                        changed = true
                    elseif has_expire and not is_effective(expire_at, now) then
                        item_data.count = 0
                        changed = true
                    end
                end
            end
            if changed then
                touched[key] = true
            end
        end
    end
end

-- 把 touched 标记的对象批量写回 storage。
local function write_objects(user_id, snapshot, touched)
    local writes = {}
    for key, _ in pairs(touched) do
        local obj = snapshot[key]
        if obj then
            local write_value = obj.value
            if key == NORMAL_ITEM_KEY then
                write_value = encode_normal_item_value(obj.value)
            end
            writes[#writes + 1] = {
                collection = BACKPACK_COLLECTION,
                key = key,
                user_id = user_id,
                value = write_value,
                version = obj.version,
                permission_read = 1,
                permission_write = 1
            }
        end
    end
    if #writes == 0 then
        return true
    end
    local ok, err = pcall(nk.storage_write, writes)
    if not ok then
        return false, tostring(err)
    end
    return true
end

-- 预留：背包变更流水写入（当前关闭）。
local function write_change_record(context, user_id, change_type, source, request_id, item_changes, ref)
    -- 取消 bag_change_record 的写入
end

-- 归一化输入道具数组并校验合法性。
local function normalize_items(raw_items)
    if type(raw_items) ~= "table" then
        return nil, "INVALID_ITEMS"
    end
    local out = {}
    for _, item in ipairs(raw_items) do
        local item_id = resolve_item_id(item and item.id)
        local count = to_number(item and item.count, nil)
        if item_id == nil or count == nil or count <= 0 then
            return nil, "INVALID_ITEM_PARAM"
        end
        local item_cfg = get_item_config(item_id)
        if not item_cfg then
            return nil, "ITEM_NOT_FOUND:" .. tostring(item_id)
        end
        out[#out + 1] = {
            id = item_id,
            count = math.floor(count),
            expireAt = normalize_expire_at(item.expireAt),
            level = normalize_level(item.level),
            benefitPlanId = item.benefitPlanId
        }
    end
    return out, nil
end

local function build_stack_map_key(item_id, level, expire_at)
    if expire_at == nil then
        return "stack:" .. tostring(item_id) .. ":L" .. tostring(level) .. ":P"
    end
    return "stack:" .. tostring(item_id) .. ":L" .. tostring(level) .. ":E" .. tostring(expire_at)
end

-- 聚合快照中当前有效道具数量。
local function aggregate_inventory(snapshot, now)
    local counts = {}
    for key, obj in pairs(snapshot) do
        local value = obj.value or {}
        if is_stack_record(value) then
            local count = to_number(value.count, 0)
            local has_expire = value.hasExpireAt == true
            local expire_at = to_number(value.expireAt, nil)
            if count > 0 and ((not has_expire) or is_effective(expire_at, now)) then
                counts[value.itemId] = (counts[value.itemId] or 0) + count
            end
        elseif is_instance_record(key, value) then
            local expire_at = to_number(value.expireAt, nil)
            if is_effective(expire_at, now) then
                local item_id = value.itemId or key
                counts[item_id] = (counts[item_id] or 0) + 1
            end
        elseif key == NORMAL_ITEM_KEY and type(value) == "table" then
            for map_key, item_data in pairs(value) do
                local count = to_number(item_data and item_data.count, 0)
                local has_expire = item_data and item_data.hasExpireAt == true
                local expire_at = to_number(item_data and item_data.expireAt, nil)
                if count > 0 and ((not has_expire) or is_effective(expire_at, now)) then
                    local item_id = resolve_item_id(item_data and item_data.itemId) or resolve_item_id(map_key)
                    if item_id ~= nil then
                        counts[item_id] = (counts[item_id] or 0) + count
                    end
                end
            end
        end
    end
    return counts
end

function M.get_item_total_count(user_id, item_id)
    local ok, snapshot = load_snapshot(user_id)
    if not ok then
        return false, snapshot
    end
    local now = now_ts()
    local touched = {}
    cleanup_expired(snapshot, now, touched)
    local counts = aggregate_inventory(snapshot, now)
    local normalized_item_id = resolve_item_id(item_id)
    if normalized_item_id == nil then
        return true, 0
    end
    return true, counts[normalized_item_id] or 0
end

function M.find_stack_records(user_id, item_id, level, expire_at)
    local ok, snapshot = load_snapshot(user_id)
    if not ok then
        return false, snapshot
    end
    local out = {}
    local now = now_ts()
    local target_level = normalize_level(level)
    local target_expire = to_number(expire_at, nil)
    local normal_obj = snapshot[NORMAL_ITEM_KEY]
    if normal_obj and type(normal_obj.value) == "table" then
        for _, item_data in pairs(normal_obj.value) do
            if type(item_data) == "table" and resolve_item_id(item_data.itemId) == resolve_item_id(item_id) then
                local count = to_number(item_data.count, 0)
                if count > 0 then
                    local item_level = normalize_level(item_data.level)
                    local item_expire = to_number(item_data.expireAt, nil)
                    local has_expire = item_data.hasExpireAt == true
                    local effective = (not has_expire) or is_effective(item_expire, now)
                    local same_level = item_level == target_level
                    local same_expire = target_expire == nil or item_expire == target_expire
                    if effective and same_level and same_expire then
                        out[#out + 1] = {
                            itemId = item_id,
                            level = item_level,
                            count = count,
                            expireAt = item_expire
                        }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local ae = a.expireAt
        local be = b.expireAt
        if ae == nil and be == nil then
            return false
        end
        if ae == nil then
            return false
        end
        if be == nil then
            return true
        end
        return ae < be
    end)
    return true, out
end

-- 发放道具主流程：校验、占槽检查、钱包更新、落盘回滚。
function M.add_items(context, user_id, items_to_add, log_source, log_ref)
    local items, err = normalize_items(items_to_add or {})
    if not items then
        return false, err
    end
    local ok, snapshot = load_snapshot(user_id)
    if not ok then
        return false, snapshot
    end
    local touched = {}
    local now = now_ts()
    cleanup_expired(snapshot, now, touched)
    local slot_capacity = get_slot_capacity()
    local wallet_changes = {}
    local required_slots = 0
    for _, item in ipairs(items) do
        local item_cfg = get_item_config(item.id)
        if item_cfg.itemType == "currency" then
            wallet_changes[item.id] = (wallet_changes[item.id] or 0) + item.count
        elseif item_cfg.stackable then
            local normal_obj = get_normal_item_object(snapshot)
            local normal_map = normal_obj.value
            local item_level = normalize_level(item.level)
            local target_expire = normalize_expire_at(item.expireAt)
            if item_cfg.requireExpireAt then
                if target_expire == nil then
                    return false, "MISSING_EXPIRE_AT:" .. item.id
                end
            end
            local current = nil
            for _, stack_record in pairs(normal_map) do
                if type(stack_record) == "table" and resolve_item_id(stack_record.itemId) == resolve_item_id(item.id) then
                    local record_level = normalize_level(stack_record.level)
                    local has_expire = stack_record.hasExpireAt == true
                    local record_expire = to_number(stack_record.expireAt, nil)
                    local same_level = record_level == item_level
                    local same_expire_batch = ((not has_expire) and (target_expire == nil)) or (has_expire and record_expire == target_expire)
                    if same_level and same_expire_batch then
                        current = stack_record
                        break
                    end
                end
            end
            if current == nil then
                current = {
                    itemId = item.id,
                    itemType = item_cfg.itemType,
                    level = item_level,
                    stackable = true,
                    hasExpireAt = target_expire ~= nil,
                    count = 0
                }
                current.expireAt = target_expire
                local map_key = build_stack_map_key(item.id, item_level, target_expire)
                normal_map[map_key] = current
            end
            local current_count = to_number(current.count, 0)
            local exists_effective = current_count > 0 and ((current.hasExpireAt ~= true) or is_effective(to_number(current.expireAt, nil), now))
            if not exists_effective and item_cfg.occupySlot then
                required_slots = required_slots + 1
            end
            current.count = current_count + item.count
            current.itemType = item_cfg.itemType
            current.stackable = true
            current.hasExpireAt = target_expire ~= nil
            current.level = item_level
            if target_expire ~= nil then
                current.expireAt = target_expire
            else
                current.expireAt = nil
            end
            touched[NORMAL_ITEM_KEY] = true
        else
            local key = (item.id == VIP_ITEM_ID or item.id == SVIP_ITEM_ID) and item.id or ("instance:" .. item.id)
            local obj = snapshot[key]
            local current = obj and obj.value or nil
            local current_expire = current and to_number(current.expireAt, nil) or nil
            local active = current ~= nil and is_effective(current_expire, now)
            if not active and item_cfg.occupySlot then
                required_slots = required_slots + 1
            end
            local expire_at = item.expireAt
            if item_cfg.hasExpireAt and expire_at == nil then
                if active and current_expire ~= nil then
                    expire_at = current_expire
                else
                    expire_at = now + 30 * 86400
                end
            end
            local next_expire = expire_at
            if active and current_expire ~= nil and expire_at ~= nil then
                next_expire = math.max(current_expire, expire_at)
            end
            if not obj then
                obj = {
                    key = key,
                    version = nil,
                    value = {}
                }
                snapshot[key] = obj
            end
            obj.value = {
                recordType = "instance",
                instanceId = (current and current.instanceId) or safe_uuid(),
                itemId = item.id,
                type = "entitlement",
                subType = item.id == VIP_ITEM_ID and "vip" or (item.id == SVIP_ITEM_ID and "svip" or "generic"),
                description = current and current.description or nil,
                stackable = false,
                usable = false,
                startAt = active and (current.startAt or now) or now,
                expireAt = next_expire,
                benefitPlanId = item.benefitPlanId or current and current.benefitPlanId or nil,
                count = 1
            }
            touched[key] = true
        end
    end

    local used_slot_count = recalc_used_slots(snapshot, now)
    if used_slot_count + required_slots > slot_capacity then
        return false, "BAG_CAPACITY_EXCEEDED"
    end
    local wallet_applied = false
    if next(wallet_changes) ~= nil then
        local ok_wallet, err_wallet = apply_wallet_update(user_id, wallet_changes, log_source or "grant", true)
        if not ok_wallet then
            return false, tostring(err_wallet)
        end
        wallet_applied = true
    end

    local write_ok, write_err = write_objects(user_id, snapshot, touched)
    if not write_ok then
        if wallet_applied then
            local rollback = {}
            for k, v in pairs(wallet_changes) do
                rollback[k] = -v
            end
            pcall(apply_wallet_update, user_id, rollback, (log_source or "grant") .. "_rollback", false)
        end
        return false, write_err
    end

    return true, { success = true }
end

-- 消耗道具主流程：校验、扣减、钱包更新、落盘回滚。
function M.consume_items(context, user_id, items_to_consume, log_source, log_ref)
    local items, err = normalize_items(items_to_consume or {})
    if not items then
        return false, err
    end
    local ok, snapshot = load_snapshot(user_id)
    if not ok then
        return false, snapshot
    end
    local touched = {}
    local now = now_ts()
    cleanup_expired(snapshot, now, touched)
    local wallet_changes = {}
    for _, item in ipairs(items) do
        local item_cfg = get_item_config(item.id)
        if item_cfg.itemType == "currency" then
            wallet_changes[item.id] = (wallet_changes[item.id] or 0) - item.count
        elseif item_cfg.stackable then
            local required = item.count
            local candidates = {}
            local normal_obj = snapshot[NORMAL_ITEM_KEY]
            local target_expire = normalize_expire_at(item.expireAt)
            if normal_obj and type(normal_obj.value) == "table" then
                local target_level = normalize_level(item.level)
                for _, normal_item in pairs(normal_obj.value) do
                    if type(normal_item) == "table" and resolve_item_id(normal_item.itemId) == resolve_item_id(item.id) then
                        local item_level = normalize_level(normal_item.level)
                        local normal_count = to_number(normal_item.count, 0)
                        local item_expire = to_number(normal_item.expireAt, nil)
                        local same_expire = target_expire == nil or item_expire == target_expire
                        if item_level == target_level and normal_count > 0 and same_expire then
                            candidates[#candidates + 1] = {
                                expireAt = item_expire,
                                count = normal_count,
                                value = normal_item
                            }
                        end
                    end
                end
            end
            table.sort(candidates, function(a, b)
                local ae = a.expireAt
                local be = b.expireAt
                if ae == nil and be == nil then
                    return false
                end
                if ae == nil then
                    return false
                end
                if be == nil then
                    return true
                end
                return ae < be
            end)
            local total = 0
            for _, c in ipairs(candidates) do
                total = total + c.count
            end
            if total < required then
                return false, "INSUFFICIENT_ITEM:" .. item.id
            end
            local remain = required
            for _, c in ipairs(candidates) do
                if remain <= 0 then
                    break
                end
                local take = math.min(remain, c.count)
                if c.value then
                    c.value.count = to_number(c.value.count, 0) - take
                end
                touched[NORMAL_ITEM_KEY] = true
                remain = remain - take
            end
        else
            local key = (item.id == VIP_ITEM_ID or item.id == SVIP_ITEM_ID) and item.id or ("instance:" .. item.id)
            local obj = snapshot[key]
            local value = obj and obj.value or nil
            local expire_at = value and to_number(value.expireAt, nil) or nil
            local active = value ~= nil and is_effective(expire_at, now)
            if not active then
                return false, "INSUFFICIENT_ITEM:" .. item.id
            end
            value.expireAt = now
            value.expired = true
            touched[key] = true
        end
    end

    local wallet_applied = false
    if next(wallet_changes) ~= nil then
        local ok_wallet, err_wallet = apply_wallet_update(user_id, wallet_changes, log_source or "consume", true)
        if not ok_wallet then
            return false, "INSUFFICIENT_CURRENCY:" .. tostring(err_wallet)
        end
        wallet_applied = true
    end

    local write_ok, write_err = write_objects(user_id, snapshot, touched)
    if not write_ok then
        if wallet_applied then
            local rollback = {}
            for k, v in pairs(wallet_changes) do
                rollback[k] = -v
            end
            pcall(apply_wallet_update, user_id, rollback, (log_source or "consume") .. "_rollback", false)
        end
        return false, write_err
    end

    return true, { success = true }
end

-- 清理过期道具并持久化。
function M.cleanup_expired_items(context, user_id, source, ref)
    local ok, snapshot = load_snapshot(user_id)
    if not ok then
        return false, snapshot
    end
    local touched = {}
    local now = now_ts()
    cleanup_expired(snapshot, now, touched)
    local write_ok, write_err = write_objects(user_id, snapshot, touched)
    if not write_ok then
        return false, write_err
    end
    return true, { success = true, cleaned = true }
end

-- 判断单个道具数据是否已过期。
function M.is_item_expired(item_data)
    if not item_data then
        return true
    end
    local expire_at = to_number(item_data.expireAt, nil)
    if expire_at == nil then
        return false
    end
    return expire_at <= now_ts()
end

-- 计算单个时效道具剩余天数。
function M.get_remaining_days(item_data)
    if not item_data or M.is_item_expired(item_data) then
        return 0
    end
    local expire_at = to_number(item_data.expireAt, nil)
    if expire_at == nil then
        return 0
    end
    local remain = expire_at - now_ts()
    if remain <= 0 then
        return 0
    end
    return math.ceil(remain / 86400)
end

-- RPC：查询钱包余额。
function M.rpc_wallet_get(context, payload)
    local user_id = context.user_id
    local ok, account = pcall(nk.account_get_id, user_id)
    if not ok or account == nil then
        return nk.json_encode({ success = false, error = { code = "ACCOUNT_NOT_FOUND", message = "Account not found" } })
    end
    local wallet = decode_wallet_value(account.wallet or {})
    return nk.json_encode({ success = true, wallet = wallet })
end

-- RPC：查询指定道具数量（或全部）。
function M.rpc_inventory_get_items(context, payload)
    local ok_decode, req = decode_payload(payload)
    if not ok_decode then
        return nk.json_encode({ success = false, error = { code = "INVALID_PAYLOAD", message = "Invalid payload" } })
    end
    local item_ids = req.item_ids or req
    if type(item_ids) ~= "table" then
        item_ids = {}
    end
    local ok, snapshot = load_snapshot(context.user_id)
    if not ok then
        return nk.json_encode({ success = false, error = { code = "LOAD_FAILED", message = snapshot } })
    end
    local now = now_ts()
    local touched = {}
    cleanup_expired(snapshot, now, touched)
    local counts = aggregate_inventory(snapshot, now)
    local out = {}
    if #item_ids == 0 then
        for item_id, count in pairs(counts) do
            out[#out + 1] = { id = item_id, count = count }
        end
        table.sort(out, function(a, b) return a.id < b.id end)
    else
        for _, raw_id in ipairs(item_ids) do
            local item_id = resolve_item_id(raw_id) or raw_id
            out[#out + 1] = { id = item_id, count = counts[item_id] or 0 }
        end
    end
    return nk.json_encode({
        success = true,
        items = out
    })
end

-- 规范化 item_type 过滤参数。
local function normalize_item_type_filter(v)
    if v == nil then
        return nil
    end
    local s = tostring(v)
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then
        return nil
    end
    if string.lower(s) == "all" then
        return nil
    end
    return s
end

-- 判断道具类型是否匹配过滤条件。
local function item_type_matches(filter_type, item_type)
    if filter_type == nil then
        return true
    end
    return item_type == filter_type
end

-- 获取道具展示元数据（类型/名称/描述）。
local function get_item_meta(item_id, fallback_type)
    local item_cfg = get_item_config(item_id)
    local item_type = fallback_type
    local item_name = item_id
    local item_desc = ""
    if item_cfg ~= nil then
        item_type = item_cfg.itemType or item_type
        item_name = item_cfg.itemName or item_name
        item_desc = item_cfg.itemDesc or item_desc
    end
    return item_type, item_name, item_desc
end

-- 收集背包列表分页结果。
local function collect_backpack_items(snapshot, now, limit, item_type_filter)
    local items = {}
    for key, obj in pairs(snapshot) do
        local value = obj.value or {}
        if is_stack_record(value) then
            local count = to_number(value.count, 0)
            local expire_at = to_number(value.expireAt, nil)
            if count > 0 and ((value.hasExpireAt ~= true) or is_effective(expire_at, now)) then
                local item_type, item_name, item_desc = get_item_meta(value.itemId, value.itemType)
                if item_type_matches(item_type_filter, item_type) then
                items[#items + 1] = {
                    key = key,
                    id = value.itemId,
                    count = count,
                    level = normalize_level(value.level),
                    itemType = item_type,
                    itemName = item_name,
                    itemDesc = item_desc,
                    stackable = true,
                    hasExpireAt = value.hasExpireAt == true,
                    expireAt = expire_at or 0
                }
                end
            end
        elseif key == NORMAL_ITEM_KEY and type(value) == "table" then
            for map_key, item_data in pairs(value) do
                local count = to_number(item_data and item_data.count, 0)
                local expire_at = to_number(item_data and item_data.expireAt, nil)
                local has_expire_at = item_data and item_data.hasExpireAt == true
                if count > 0 and ((not has_expire_at) or is_effective(expire_at, now)) then
                    local item_id = resolve_item_id(item_data and item_data.itemId) or resolve_item_id(map_key)
                    local item_type, item_name, item_desc = get_item_meta(item_id, item_data and item_data.itemType or nil)
                    if item_type_matches(item_type_filter, item_type) then
                    items[#items + 1] = {
                        key = NORMAL_ITEM_KEY,
                        id = item_id,
                        count = count,
                        level = normalize_level(item_data and item_data.level),
                        itemType = item_type,
                        itemName = item_name,
                        itemDesc = item_desc,
                        stackable = true,
                        hasExpireAt = has_expire_at,
                        expireAt = expire_at or 0,
                    }
                    end
                end
            end
        elseif is_instance_record(key, value) then
            local expire_at = to_number(value.expireAt, nil)
            if is_effective(expire_at, now) then
                local item_id = value.itemId or key
                local item_type, item_name, item_desc = get_item_meta(item_id, "entitlement")
                if item_type_matches(item_type_filter, item_type) then
                items[#items + 1] = {
                    key = key,
                    id = item_id,
                    count = 1,
                    itemType = item_type,
                    itemName = item_name,
                    itemDesc = item_desc,
                    stackable = false,
                    hasExpireAt = expire_at ~= nil,
                    expireAt = expire_at or 0,
                    instanceId = value.instanceId
                }
                end
            end
        end
    end
    table.sort(items, function(a, b) return a.id < b.id end)
    local out = {}
    for i = 1, math.min(limit, #items) do
        out[#out + 1] = items[i]
    end
    return out
end

-- RPC：分页列出背包。
function M.rpc_inventory_list(context, payload)
    local ok_decode, req = decode_payload(payload)
    if not ok_decode then
        return nk.json_encode({ success = false, error = { code = "INVALID_PAYLOAD", message = "Invalid payload" } })
    end
    local limit = to_number(req.page_size or req.limit, 100)
    if limit < 1 then
        limit = 1
    elseif limit > 1000 then
        limit = 1000
    end
    local item_type_filter = normalize_item_type_filter(req.item_type or req.itemType)
    local ok, snapshot = load_snapshot(context.user_id)
    if not ok then
        return nk.json_encode({ success = false, error = { code = "LOAD_FAILED", message = snapshot } })
    end
    local now = now_ts()
    local touched = {}
    cleanup_expired(snapshot, now, touched)
    local out = collect_backpack_items(snapshot, now, limit, item_type_filter)
    return nk.json_encode({
        success = true,
        items = out,
        cursor = nil
    })
end

-- RPC：查询背包流水（当前返回空列表）。
function M.rpc_inventory_log_list(context, payload)
    return nk.json_encode({ success = true, logs = {}, cursor = nil })
end

-- RPC：查询全部道具定义。
function M.rpc_inventory_get_item_defs(context, payload)
    local out = {}
    local item_defs = config.items or {}
    for raw_item_id, _ in pairs(item_defs) do
        local item_id = tostring(raw_item_id)
        local item_def = build_item_definition(item_id)
        if item_def ~= nil then
            out[#out + 1] = item_def
        end
    end
    table.sort(out, function(a, b) return a.itemId < b.itemId end)
    return nk.json_encode({ success = true, items = out })
end

-- RPC：聚合返回定义+背包列表。
function M.rpc_inventory_get_all_info(context, payload)
    local ok_decode, req = decode_payload(payload)
    if not ok_decode then
        return nk.json_encode({ success = false, error = { code = "INVALID_PAYLOAD", message = "Invalid payload" } })
    end
    local limit = to_number(req.page_size or req.limit, 1000)
    if limit < 1 then
        limit = 1
    elseif limit > 10000 then
        limit = 10000
    end
    local item_type_filter = normalize_item_type_filter(req.item_type or req.itemType)
    local ok, snapshot = load_snapshot(context.user_id)
    if not ok then
        return nk.json_encode({ success = false, error = { code = "LOAD_FAILED", message = snapshot } })
    end
    local now = now_ts()
    local touched = {}
    cleanup_expired(snapshot, now, touched)
    local backpack_items = collect_backpack_items(snapshot, now, limit, item_type_filter)
    local item_defs = {}
    local defs = config.items or {}
    for raw_item_id, _ in pairs(defs) do
        local item_id = tostring(raw_item_id)
        local item_def = build_item_definition(item_id)
        if item_def ~= nil then
            item_defs[#item_defs + 1] = item_def
        end
    end
    table.sort(item_defs, function(a, b) return a.itemId < b.itemId end)
    return nk.json_encode({
        success = true,
        itemDefs = item_defs,
        backpackItems = backpack_items,
        cursor = nil
    })
end

-- RPC：发放道具。
function M.rpc_backpack_grant(context, payload)
    local ok_decode, req = decode_payload(payload)
    if not ok_decode then
        return nk.json_encode({ success = false, error = { code = "INVALID_PAYLOAD", message = "Invalid payload" } })
    end
    local items = req.items or {}
    local source = req.source or "rpc_backpack_grant"
    local ok, result_or_err = M.add_items(context, context.user_id, items, source, req.ref or {})
    if not ok then
        return nk.json_encode({ success = false, error = { code = "GRANT_FAILED", message = tostring(result_or_err) } })
    end
    return nk.json_encode({ success = true, result = result_or_err })
end

-- RPC：消耗道具。
function M.rpc_backpack_consume(context, payload)
    local ok_decode, req = decode_payload(payload)
    if not ok_decode then
        return nk.json_encode({ success = false, error = { code = "INVALID_PAYLOAD", message = "Invalid payload" } })
    end
    local items = req.items or {}
    local source = req.source or "rpc_backpack_consume"
    local ok, result_or_err = M.consume_items(context, context.user_id, items, source, req.ref or {})
    if not ok then
        return nk.json_encode({ success = false, error = { code = "CONSUME_FAILED", message = tostring(result_or_err) } })
    end
    return nk.json_encode({ success = true, result = result_or_err })
end

-- RPC：使用道具（复用 consume）。
function M.rpc_backpack_use(context, payload)
    return M.rpc_backpack_consume(context, payload)
end

-- RPC：清理过期道具。
function M.rpc_backpack_cleanup(context, payload)
    local ok, result_or_err = M.cleanup_expired_items(context, context.user_id, "rpc_backpack_cleanup", {})
    if not ok then
        return nk.json_encode({ success = false, error = { code = "CLEANUP_FAILED", message = tostring(result_or_err) } })
    end
    return nk.json_encode({ success = true, result = result_or_err })
end

-- RPC：背包状态聚合（旧接口占位）。
function M.rpc_backpack_get_state(context, payload)
    return nk.json_encode({
        success = true,
        state = nil,
        message = "BACKPACK_STATE_REMOVED"
    })
end

return M
