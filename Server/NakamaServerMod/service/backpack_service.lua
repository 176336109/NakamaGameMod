local nk = require("nakama")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}
local backpack_domain = nil
local IDEMP_COLLECTION = "backpack_idempotency"

-- 注入背包领域依赖。
function M.wire(backpack)
    backpack_domain = backpack
end

-- 按错误码键统一构造失败响应。
local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
end

-- 判断服务是否已完成依赖装配。
local function service_ready()
    return backpack_domain ~= nil
end

-- 把背包旧错误码/文本映射到统一错误码。
local function map_backpack_error(legacy_code, legacy_message)
    if legacy_code == "INVALID_PAYLOAD" then
        return "BACKPACK_INVALID_PARAM"
    end
    if legacy_code == "LOAD_FAILED" then
        return "COMMON_STORAGE_READ_FAILED"
    end
    if legacy_code == "GRANT_FAILED" then
        return "BACKPACK_GRANT_FAILED"
    end
    if legacy_code == "CONSUME_FAILED" then
        return "BACKPACK_CONSUME_FAILED"
    end
    if legacy_code == "CLEANUP_FAILED" then
        return "COMMON_STORAGE_WRITE_FAILED"
    end
    if legacy_code == "ACCOUNT_NOT_FOUND" then
        return "COMMON_INTERNAL_ERROR"
    end
    if type(legacy_message) ~= "string" then
        return "COMMON_INTERNAL_ERROR"
    end
    if string.find(legacy_message, "INSUFFICIENT_ITEM:", 1, true) == 1 then
        return "BACKPACK_INSUFFICIENT_ITEM"
    end
    if legacy_message == "BAG_CAPACITY_EXCEEDED" then
        return "BACKPACK_CAPACITY_EXCEEDED"
    end
    if string.find(legacy_message, "INSUFFICIENT_CURRENCY:", 1, true) == 1 then
        return "WALLET_INSUFFICIENT_GEM"
    end
    if string.find(legacy_message, "MISSING_EXPIRE_AT:", 1, true) == 1 then
        return "BACKPACK_INVALID_PARAM"
    end
    if string.find(legacy_message, "INVALID_ITEMS", 1, true) == 1 then
        return "BACKPACK_INVALID_PARAM"
    end
    return "COMMON_INTERNAL_ERROR"
end

-- 归一化 domain 响应为统一 success/error 结构。
local function normalize_domain_response(raw)
    local ok, data = pcall(nk.json_decode, raw or "")
    if not ok or type(data) ~= "table" then
        return fail_by_key("COMMON_INTERNAL_ERROR", "Invalid backpack response")
    end
    if data.success == false then
        local legacy_code = nil
        local legacy_message = nil
        if type(data.error) == "table" then
            legacy_code = data.error.code
            legacy_message = data.error.message
        else
            legacy_message = data.error
        end
        local key = map_backpack_error(legacy_code, legacy_message)
        local code, message = error_codes.resolve(key, tostring(legacy_message or "Backpack request failed"))
        return response.fail(code, message)
    end
    return response.ok(data)
end

-- 透传调用 domain RPC 并进行统一封装。
local function forward_rpc(handler, context, payload)
    local raw = handler(context, payload)
    return normalize_domain_response(raw)
end

-- 读取某次幂等请求的回放结果。
local function read_idempotent_result(user_id, operation, request_id)
    local ok, records = pcall(nk.storage_read, {
        {
            collection = IDEMP_COLLECTION,
            key = operation .. ":" .. request_id,
            user_id = user_id
        }
    })
    if not ok or type(records) ~= "table" or #records == 0 then
        return nil
    end
    local value = records[1] and records[1].value
    if type(value) ~= "table" then
        return nil
    end
    if type(value.result) ~= "table" then
        return {}
    end
    return value.result
end

-- 写入幂等请求结果，用于重复请求直接回放。
local function write_idempotent_result(user_id, operation, request_id, result)
    pcall(nk.storage_write, {
        {
            collection = IDEMP_COLLECTION,
            key = operation .. ":" .. request_id,
            user_id = user_id,
            value = {
                result = result or {}
            },
            permission_read = 0,
            permission_write = 0
        }
    })
end

-- 处理带 requestId 的变更请求幂等逻辑。
local function handle_mutation_with_idempotency(operation, handler, context, payload)
    local request_id = nil
    local ok_req, req = pcall(nk.json_decode, payload or "")
    if ok_req and type(req) == "table" and type(req.requestId) == "string" and req.requestId ~= "" then
        request_id = req.requestId
    end
    if request_id ~= nil then
        local replay_result = read_idempotent_result(context.user_id, operation, request_id)
        if replay_result ~= nil then
            replay_result.idempotent = true
            return response.ok({ result = replay_result })
        end
    end
    local unified = forward_rpc(handler, context, payload)
    if request_id == nil then
        return unified
    end
    local ok_data, data = pcall(nk.json_decode, unified or "")
    if not ok_data or type(data) ~= "table" or data.success ~= true then
        return unified
    end
    if type(data.result) ~= "table" then
        data.result = {}
    end
    if data.result.idempotent == nil then
        data.result.idempotent = false
    end
    write_idempotent_result(context.user_id, operation, request_id, data.result)
    return nk.json_encode(data)
end

-- 调试入口：直接为用户追加道具。
function M.rpc_debug_add_items(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    local user_id = context.user_id
    local ok_decode, items = pcall(nk.json_decode, payload or "")
    if not ok_decode or type(items) ~= "table" then
        return fail_by_key("BACKPACK_INVALID_PARAM", "Invalid payload")
    end
    local success, result_or_err = backpack_domain.add_items(context, user_id, items, "debug", { rpc = "debug_add_items" })
    if not success then
        local key = map_backpack_error(nil, tostring(result_or_err))
        local code, message = error_codes.resolve(key, tostring(result_or_err))
        return response.fail(code, message)
    end
    return response.ok({ result = result_or_err })
end

-- 查询钱包余额。
function M.rpc_wallet_get(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_wallet_get, context, payload)
end

-- 查询指定道具明细。
function M.rpc_inventory_get_items(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_inventory_get_items, context, payload)
end

-- 分页查询背包列表。
function M.rpc_inventory_list(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_inventory_list, context, payload)
end

-- 查询道具定义。
function M.rpc_inventory_get_item_defs(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_inventory_get_item_defs, context, payload)
end

-- 一次性查询定义、背包、日志等聚合信息。
function M.rpc_inventory_get_all_info(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_inventory_get_all_info, context, payload)
end

-- 分页查询背包变更日志。
function M.rpc_inventory_log_list(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_inventory_log_list, context, payload)
end

-- 发放道具（带 requestId 幂等支持）。
function M.rpc_backpack_grant(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return handle_mutation_with_idempotency("grant", backpack_domain.rpc_backpack_grant, context, payload)
end

-- 消耗道具（带 requestId 幂等支持）。
function M.rpc_backpack_consume(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return handle_mutation_with_idempotency("consume", backpack_domain.rpc_backpack_consume, context, payload)
end

-- 使用道具（带 requestId 幂等支持）。
function M.rpc_backpack_use(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return handle_mutation_with_idempotency("use", backpack_domain.rpc_backpack_use, context, payload)
end

-- 清理过期道具。
function M.rpc_backpack_cleanup(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_backpack_cleanup, context, payload)
end

-- 获取背包聚合状态。
function M.rpc_backpack_get_state(context, payload)
    if not service_ready() then
        return fail_by_key("BACKPACK_SERVICE_NOT_WIRED", "Backpack service not wired")
    end
    return forward_rpc(backpack_domain.rpc_backpack_get_state, context, payload)
end

return M
