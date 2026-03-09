--[[
inventory.lua

职责：
- 提供“背包/货币”的统一读写入口：货币走 Nakama Wallet；非货币物品走 Storage(collection="inventory")。
- 封装物品增减（加物品/消耗物品）的读写与一致性策略，并在必要时写入变更流水(collection="inventory_log")。
- 对外暴露一组 RPC：查询钱包、查询指定物品数量、列出背包、查询变更流水（带权限控制）。

数据约定：
- Storage(collection="inventory", key=item_id, user_id=玩家) 的 value 形如：
  - count: number，数量（可为 0；写入时会直接覆盖/更新）
  - type: string，物品类型（来自 config.items[item_id].type）
- Wallet：仅用于 config.items[item_id].type == "currency" 的条目，余额由 nk.wallet_update 原子更新。

一致性/权限要点：
- Wallet 更新通过 nk.wallet_update(..., check=true) 在服务端做“余额不足”原子校验。
- Storage 更新使用 version 做乐观并发控制；加物品会在冲突时重读并重试一次。
- inventory 对象 permission_read=1、permission_write=1（当前实现允许客户端读写同用户记录；如需更严可在外层 RPC/服务端逻辑限制）。
- inventory_log 对象 permission_read=1、permission_write=0（仅服务端写；客户端可读同用户日志，跨用户需管理员权限）。
]]

local nk = require("nakama")
local config = require("config")

local M = {}

local function json_decode_payload(payload)
    -- payload 允许为空：nil/"" 会被视为 {}
    -- 返回值：(decode_ok:boolean, table_or_nil)
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

local function aggregate_item_delta(items, multiplier)
    -- 将 items 数组按 id 聚合为“增量列表”，并按 id 排序：
    -- - items: { {id=string, count=number|string}, ... }
    -- - multiplier: 1 表示增加，-1 表示消耗（用于写 inventory_log）
    local agg = {}
    for _, item in ipairs(items or {}) do
        local id = item.id
        local count = tonumber(item.count) or 0
        if type(id) == "string" and id ~= "" and count ~= 0 then
            agg[id] = (agg[id] or 0) + (count * multiplier)
        end
    end

    local delta = {}
    for id, count in pairs(agg) do
        if count ~= 0 then
            table.insert(delta, { id = id, count = count })
        end
    end
    table.sort(delta, function(a, b) return a.id < b.id end)
    return delta
end

local function safe_uuid()
    -- 优先使用 nk.uuid_v4；若运行时不可用则退化为随机字符串（仅用于日志 key 去重）
    if nk.uuid_v4 ~= nil then
        local ok, value = pcall(nk.uuid_v4)
        if ok and type(value) == "string" and value ~= "" then
            return value
        end
    end
    return tostring(math.random(1000000000, 2147483647)) .. tostring(math.random(1000000000, 2147483647))
end

local function make_inventory_log_key(ts_sec)
    -- 日志 key 设计为：YYYYMMDD_秒级时间戳_uuid
    -- 目的：按 key 的字典序近似时间有序，且同秒内可去重
    local day = os.date("!%Y%m%d", ts_sec)
    return day .. "_" .. string.format("%010d", ts_sec) .. "_" .. safe_uuid()
end

function M.write_inventory_log(context, user_id, source, items_delta, ref)
    -- 写入背包变更流水（collection="inventory_log"）
    --
    -- 语义：
    -- - source: 变更来源（字符串，必填；用于按系统/功能归因与筛选）
    -- - items_delta: 变更明细数组（必填；count 为正表示增加，为负表示消耗）
    -- - ref: 可选扩展字段（table）；会自动补充 request_id/username（若 context 中存在）
    --
    -- 存储字段（value）：
    -- - source: string
    -- - items: items_delta 原样存储
    -- - ref: table（可能包含 request_id/username）
    -- - ts_utc: ISO-8601 UTC 时间字符串（便于人工阅读）
    -- - ts: 秒级时间戳（便于范围查询/过滤）
    --
    -- 权限：
    -- - permission_write=0：禁止客户端写入；仅服务端逻辑调用
    -- - permission_read=1：允许读取同 user_id 的日志；跨用户读取由 rpc_inventory_log_list 额外做权限校验
    if type(source) ~= "string" or source == "" then
        return false, "invalid source"
    end
    if type(items_delta) ~= "table" or #items_delta == 0 then
        return false, "invalid items_delta"
    end

    local ts_sec = os.time()
    local value = {
        source = source,
        items = items_delta,
        ref = ref,
        ts_utc = os.date("!%Y-%m-%dT%H:%M:%SZ", ts_sec),
        ts = ts_sec
    }

    if value.ref == nil or type(value.ref) ~= "table" then
        value.ref = {}
    end
    if type(context) == "table" then
        if context.request_id ~= nil then
            value.ref.request_id = context.request_id
        end
        if context.username ~= nil then
            value.ref.username = context.username
        end
    end

    local key = make_inventory_log_key(ts_sec)
    nk.storage_write({
        {
            collection = "inventory_log",
            key = key,
            user_id = user_id,
            value = value,
            permission_read = 1,
            permission_write = 0
        }
    })
    return true, key
end

-- Helper to add items to user
function M.add_items(context, user_id, items_to_add, log_source, log_ref)
    -- 加物品流程：
    -- 1) 遍历 items_to_add，按 config.items[item_id].type 分流：
    --    - currency：累计到 wallet_changes，最终使用 nk.wallet_update 原子更新
    --    - 非 currency：累计到 storage_adds，并记录 type（写入 inventory 的 value.type）
    -- 2) Wallet 更新：nk.wallet_update(..., check=true)（这里是“加钱”，通常不会失败；check 仍保持一致）
    -- 3) Storage 更新：先读出当前 count/version，再写入新 count，并带 version 做并发控制；
    --    若发生写入冲突/异常则重读并重试一次，以提高成功率。
    -- 4) 记流水：当 log_source 非空时，聚合增量（count>0）写入 inventory_log；失败不影响主流程（pcall）。
    local wallet_changes = {}
    local wallet_updated = false
    local storage_adds = {}
    local storage_types = {}

    for _, item in ipairs(items_to_add) do
        local item_def = config.items[item.id]
        if not item_def then
            nk.logger_error("Item definition not found: " .. item.id)
            goto continue
        end

        if item_def.type == "currency" then
            -- Wallet 变更会累加后一次性提交
            wallet_changes[item.id] = (wallet_changes[item.id] or 0) + item.count
            wallet_updated = true
        else
            storage_adds[item.id] = (storage_adds[item.id] or 0) + item.count
            storage_types[item.id] = item_def.type
        end
        
        ::continue::
    end

    -- 写入 Wallet（货币）
    if wallet_updated then
        local metadata = { source = "game_logic" }
        nk.wallet_update(user_id, wallet_changes, metadata, true)
    end

    -- 写入 Storage（非货币背包）
    if next(storage_adds) ~= nil then
        local storage_reads = {}
        for item_id, _ in pairs(storage_adds) do
            table.insert(storage_reads, { collection = "inventory", key = item_id, user_id = user_id })
        end

        local function build_storage_writes(objects)
            local current_counts = {}
            local versions = {}
            local current_types = {}

            for _, obj in ipairs(objects) do
                current_counts[obj.key] = (obj.value and obj.value.count) or 0
                versions[obj.key] = obj.version
                current_types[obj.key] = (obj.value and obj.value.type) or storage_types[obj.key]
            end

            local writes = {}
            for item_id, add_count in pairs(storage_adds) do
                local new_count = (current_counts[item_id] or 0) + add_count
                table.insert(writes, {
                    collection = "inventory",
                    key = item_id,
                    user_id = user_id,
                    value = { count = new_count, type = current_types[item_id] or storage_types[item_id] },
                    version = versions[item_id],
                    permission_read = 1,
                    permission_write = 1
                })
            end

            return writes
        end

        local objects = nk.storage_read(storage_reads)
        local storage_writes = build_storage_writes(objects)

        local ok, err = pcall(nk.storage_write, storage_writes)
        if not ok then
            -- 典型原因：version 冲突（并发写）；此处重读再重算一次写入
            objects = nk.storage_read(storage_reads)
            storage_writes = build_storage_writes(objects)
            ok, err = pcall(nk.storage_write, storage_writes)
            if not ok then
                return false, tostring(err)
            end
        end
    end
    
    if log_source ~= nil then
        local delta = aggregate_item_delta(items_to_add, 1)
        if #delta > 0 then
            pcall(M.write_inventory_log, context, user_id, log_source, delta, log_ref)
        end
    end

    return true
end

-- Helper to consume items (cost check)
function M.consume_items(context, user_id, items_to_consume, log_source, log_ref)
    -- 消耗物品流程（带“余额/库存不足”校验）：
    -- 1) 分流：
    --    - currency：构造负数 wallet_changes，交由 nk.wallet_update(check=true) 做原子扣减与不足校验
    --    - 非 currency：先 storage_read 取出当前 count/version，手动校验不足则直接失败
    -- 2) 应用变更：
    --    - Wallet：先扣（原子校验）；失败返回 "Insufficient currency"
    --    - Storage：再写入扣减后的 count（带 version）
    -- 注意：Wallet 与 Storage 不在同一个原子事务里；若需要跨两类资产的强一致，可在上层设计“仅一种资产作为成本”或引入补偿/事务化方案。
    -- 1. Check if user has enough
    -- This requires reading wallet and storage first.
    -- For simplicity, wallet_update with negative values will fail if insufficient funds (if check is true)
    
    local wallet_changes = {}
    local storage_reads = {}
    local items_map = {} -- Map for quick lookup of non-currency items

    for _, item in ipairs(items_to_consume) do
        local item_def = config.items[item.id]
        if item_def.type == "currency" then
            wallet_changes[item.id] = -(item.count) -- Negative for deduction
        else
            table.insert(storage_reads, { collection = "inventory", key = item.id, user_id = user_id })
            items_map[item.id] = item.count
        end
    end

    -- Process Storage Items first (manual check)
    local storage_writes = {}
    if #storage_reads > 0 then
        local objects = nk.storage_read(storage_reads)
        for _, obj in ipairs(objects) do
            local required = items_map[obj.key]
            if required then
                local current = obj.value.count or 0
                if current < required then
                    return false, "Insufficient item: " .. obj.key
                end
                
                -- Prepare update
                table.insert(storage_writes, {
                    collection = "inventory",
                    key = obj.key,
                    user_id = user_id,
                    value = { count = current - required, type = obj.value.type },
                    version = obj.version,
                    permission_read = 1,
                    permission_write = 1
                })
                items_map[obj.key] = nil -- Mark as found
            end
        end
        
        -- Check if any required item was not found in storage at all
        for k, v in pairs(items_map) do
            return false, "Item not found in inventory: " .. k
        end
    end

    -- Apply Changes
    -- 1. Wallet (Atomic check)
    if next(wallet_changes) ~= nil then
        local success, err = pcall(nk.wallet_update, user_id, wallet_changes, {}, true)
        if not success then
            return false, "Insufficient currency"
        end
    end

    -- 2. Storage
    if #storage_writes > 0 then
        nk.storage_write(storage_writes)
    end

    local source = log_source
    if type(source) ~= "string" or source == "" then
        source = "consume"
    end
    local delta = aggregate_item_delta(items_to_consume, -1)
    if #delta > 0 then
        pcall(M.write_inventory_log, context, user_id, source, delta, log_ref)
    end

    return true
end

function M.rpc_wallet_get(context, payload)
    -- RPC：获取当前用户 Wallet（货币余额）
    -- - 请求：payload 可为空
    -- - 响应：wallet 对象（key 为货币 id，value 为余额）
    local user_id = context.user_id
    local ok, account = pcall(nk.account_get_id, user_id)
    if not ok or account == nil then
        return nk.json_encode({ error = "Account not found" })
    end

    local wallet = account.wallet or {}
    if type(wallet) == "string" then
        local decode_ok, decoded = pcall(nk.json_decode, wallet)
        if decode_ok and decoded ~= nil then
            wallet = decoded
        else
            wallet = {}
        end
    end

    return nk.json_encode(wallet)
end

function M.rpc_inventory_get_items(context, payload)
    -- RPC：查询指定物品数量（仅查询 Storage 背包；货币请用 rpc_wallet_get）
    -- - 请求：{ item_ids: ["id1","id2",...] } 或直接传数组
    -- - 响应：{ items: [ {id="id1", count=number}, ... ] }（保持请求顺序；未找到返回 0）
    local decode_ok, req = json_decode_payload(payload)
    if not decode_ok then
        return nk.json_encode({ error = "Invalid payload" })
    end

    local item_ids = req.item_ids or req
    if type(item_ids) ~= "table" then
        return nk.json_encode({ error = "item_ids must be an array" })
    end

    local user_id = context.user_id
    local reads = {}
    local seen = {}

    for _, item_id in ipairs(item_ids) do
        if type(item_id) == "string" and item_id ~= "" and not seen[item_id] then
            seen[item_id] = true
            table.insert(reads, { collection = "inventory", key = item_id, user_id = user_id })
        end
    end

    local counts = {}
    if #reads > 0 then
        local objects = nk.storage_read(reads)
        for _, obj in ipairs(objects) do
            local value = obj.value or {}
            local count = value.count or 0
            if type(count) ~= "number" then
                count = tonumber(count) or 0
            end
            counts[obj.key] = count
        end
    end

    local items = {}
    for _, item_id in ipairs(item_ids) do
        if type(item_id) == "string" and item_id ~= "" then
            table.insert(items, { id = item_id, count = counts[item_id] or 0 })
        end
    end

    return nk.json_encode({ items = items })
end

function M.rpc_inventory_list(context, payload)
    -- RPC：列出背包（Storage(collection="inventory") 全量分页）
    -- - 请求：{ page_size|limit: number, cursor?: string }
    -- - 响应：{ items: [ {id=key, count=number, type=string}, ... ], cursor: next_cursor }
    local decode_ok, req = json_decode_payload(payload)
    if not decode_ok then
        return nk.json_encode({ error = "Invalid payload" })
    end

    local limit = tonumber(req.page_size or req.limit) or 100
    if limit < 1 then
        limit = 1
    elseif limit > 1000 then
        limit = 1000
    end

    local cursor = req.cursor
    if cursor ~= nil and type(cursor) ~= "string" then
        cursor = nil
    end

    local user_id = context.user_id
    local ok, objects, next_cursor = pcall(nk.storage_list, user_id, "inventory", limit, cursor)
    if not ok then
        ok, objects, next_cursor = pcall(nk.storage_list, "inventory", user_id, limit, cursor)
    end
    if not ok then
        return nk.json_encode({ error = tostring(objects) })
    end

    local items = {}
    for _, obj in ipairs(objects or {}) do
        local value = obj.value or {}
        local count = value.count or 0
        if type(count) ~= "number" then
            count = tonumber(count) or 0
        end
        table.insert(items, { id = obj.key, count = count, type = value.type })
    end

    return nk.json_encode({ items = items, cursor = next_cursor })
end

local function is_inventory_log_admin(context, req)
    -- inventory_log 管理权限判定：
    -- - admin_token：与 config.admin.inventory_log_admin_token 完全匹配则放行
    -- - 白名单：context.user_id 在 config.admin.inventory_log_user_whitelist 中则放行
    local admin = config.admin or {}
    local expected = admin.inventory_log_admin_token
    local token = req.admin_token
    if type(expected) == "string" and expected ~= "" and type(token) == "string" and token ~= "" and token == expected then
        return true
    end

    local wl = admin.inventory_log_user_whitelist
    local uid = context and context.user_id
    if type(wl) == "table" and type(uid) == "string" and uid ~= "" then
        for _, v in ipairs(wl) do
            if v == uid then
                return true
            end
        end
    end

    return false
end

local function normalize_item_id_filter(req)
    local item_id = req.item_id or req.itemId
    if type(item_id) == "string" then
        if item_id == "" then
            return nil
        end
        return { item_id }, true
    end
    if type(item_id) == "table" then
        local out = {}
        local seen = {}
        for _, v in ipairs(item_id) do
            if type(v) == "string" and v ~= "" and not seen[v] then
                seen[v] = true
                table.insert(out, v)
            end
        end
        if #out == 0 then
            return nil
        end
        return out, true
    end

    local item_ids = req.item_ids or req.itemIds
    if type(item_ids) == "table" then
        local out = {}
        local seen = {}
        for _, v in ipairs(item_ids) do
            if type(v) == "string" and v ~= "" and not seen[v] then
                seen[v] = true
                table.insert(out, v)
            end
        end
        if #out == 0 then
            return nil
        end
        return out, true
    end

    return nil
end

local function matches_item_filter(items, item_set)
    if item_set == nil then
        return true
    end
    if type(items) ~= "table" then
        return false
    end
    for _, it in ipairs(items) do
        local id = it and it.id
        if type(id) == "string" and item_set[id] then
            return true
        end
    end
    return false
end

function M.rpc_inventory_log_list(context, payload)
    -- RPC：查询背包变更流水（Storage(collection="inventory_log") 分页 + 服务端过滤）
    --
    -- 权限：
    -- - 默认只能查自己（target_user_id/user_id 缺省为 context.user_id）
    -- - 若查询他人，则必须通过 is_inventory_log_admin 校验，否则返回 {error="forbidden"}
    --
    -- 请求字段（支持多种别名，便于兼容不同客户端）：
    -- - page_size|limit：单页数量（1..1000）
    -- - cursor：分页游标
    -- - start_ts|from_ts|ts_start|start：起始时间戳（秒，含）
    -- - end_ts|to_ts|ts_end|end：结束时间戳（秒，含）
    -- - source：按写入时的 value.source 精确匹配过滤
    -- - item_id|itemId：单个物品 id
    -- - item_ids|itemIds：多个物品 id（数组）
    -- - user_id|target_user_id：目标用户（缺省为自己）
    -- - admin_token：管理员令牌（用于跨用户查询）
    --
    -- 响应字段：
    -- - logs：{ key, user_id, source, items, ref, ts_utc, ts }
    -- - cursor：下一页游标（为空表示结束）
    --
    -- 实现说明：
    -- - 先按 storage_list 取日志，再在服务端做 source/时间范围/item 过滤；
    --   过滤可能导致“取回的对象不足 limit”，因此最多循环 50 次补齐（防止长时间扫描）。
    local decode_ok, req = json_decode_payload(payload)
    if not decode_ok then
        return nk.json_encode({ error = "Invalid payload" })
    end

    local limit = tonumber(req.page_size or req.limit) or 100
    if limit < 1 then
        limit = 1
    elseif limit > 1000 then
        limit = 1000
    end

    local cursor = req.cursor
    if cursor ~= nil and type(cursor) ~= "string" then
        cursor = nil
    end

    local start_ts = req.start_ts or req.from_ts or req.ts_start or req.start
    if start_ts ~= nil then
        start_ts = tonumber(start_ts)
        if start_ts == nil then
            return nk.json_encode({ error = "start_ts must be a number" })
        end
    end

    local end_ts = req.end_ts or req.to_ts or req.ts_end or req["end"]
    if end_ts ~= nil then
        end_ts = tonumber(end_ts)
        if end_ts == nil then
            return nk.json_encode({ error = "end_ts must be a number" })
        end
    end

    if start_ts ~= nil and end_ts ~= nil and start_ts > end_ts then
        return nk.json_encode({ error = "start_ts must be <= end_ts" })
    end

    local source = req.source
    if source ~= nil and type(source) ~= "string" then
        return nk.json_encode({ error = "source must be a string" })
    end
    if source == "" then
        source = nil
    end

    local item_ids = normalize_item_id_filter(req)
    local item_set = nil
    if item_ids ~= nil then
        item_set = {}
        for _, v in ipairs(item_ids) do
            item_set[v] = true
        end
    end

    local target_user_id = req.user_id or req.target_user_id or context.user_id
    if type(target_user_id) ~= "string" or target_user_id == "" then
        return nk.json_encode({ error = "user_id is required" })
    end

    if target_user_id ~= context.user_id and not is_inventory_log_admin(context, req) then
        return nk.json_encode({ error = "forbidden" })
    end

    local logs = {}
    local next_cursor = cursor
    local rounds = 0
    while #logs < limit do
        rounds = rounds + 1
        if rounds > 50 then
            break
        end

        local remaining = limit - #logs
        local ok, objects, c = pcall(nk.storage_list, target_user_id, "inventory_log", remaining, next_cursor)
        if not ok then
            ok, objects, c = pcall(nk.storage_list, "inventory_log", target_user_id, remaining, next_cursor)
        end
        if not ok then
            return nk.json_encode({ error = tostring(objects) })
        end

        for _, obj in ipairs(objects or {}) do
            local value = obj.value or {}
            local include = true

            if source ~= nil and value.source ~= source then
                include = false
            end

            local ts = value.ts
            if ts ~= nil and type(ts) ~= "number" then
                ts = tonumber(ts)
            end

            if include and start_ts ~= nil and (ts == nil or ts < start_ts) then
                include = false
            end

            if include and end_ts ~= nil and (ts == nil or ts > end_ts) then
                include = false
            end

            if include and not matches_item_filter(value.items, item_set) then
                include = false
            end

            if include then
                table.insert(logs, {
                    key = obj.key,
                    user_id = obj.user_id or target_user_id,
                    source = value.source,
                    items = value.items,
                    ref = value.ref,
                    ts_utc = value.ts_utc,
                    ts = ts
                })
            end
        end

        next_cursor = c
        if next_cursor == nil or next_cursor == "" then
            break
        end
        if objects == nil or #objects == 0 then
            break
        end
    end

    return nk.json_encode({ logs = logs, cursor = next_cursor })
end

return M
