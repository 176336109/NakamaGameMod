local nk = require("nakama")
local config = require("config")
local error_codes = require("domain.error_codes")
local response = require("service.response")

local M = {}
local iap_domain = nil

-- 统一按错误码键构造失败响应。
local function fail_by_key(key, fallback_message)
    local code, message = error_codes.resolve(key, fallback_message)
    return response.fail(code, message)
end

-- 注入背包网关到 iap domain，用于发货阶段加物品。
function M.wire_item_gateway(backpack, iap)
    if type(iap) ~= "table" or type(iap.set_item_gateway) ~= "function" then
        return
    end

    local gateway = {
        add_items = function(context, user_id, items, source, ref)
            return backpack.add_items(context, user_id, items, source, ref)
        end
    }

    iap.set_item_gateway(gateway)
    iap_domain = iap
end

-- 支付回调入口：做参数校验、幂等检查、发货并落 processed_orders。
function M.rpc_pay_callback(context, payload)
    nk.logger_info("RPC pay_callback called. Payload: " .. (payload or "nil"))

    if not payload or payload == "" then
        nk.logger_error("Pay callback failed: Empty payload")
        return fail_by_key("IAP_INVALID_PAYLOAD", "Empty payload")
    end

    local status, decoded = pcall(nk.json_decode, payload)
    if not status then
        nk.logger_error("Pay callback failed: Invalid JSON. Error: " .. tostring(decoded))
        return fail_by_key("IAP_INVALID_PAYLOAD", "Invalid JSON payload")
    end

    nk.logger_debug("Pay callback decoded: " .. nk.json_encode(decoded))

    if not decoded.order_id or not decoded.user_id or not decoded.product_id then
        nk.logger_error("Pay callback failed: Missing required fields (order_id, user_id, product_id)")
        return fail_by_key("IAP_INVALID_PAYLOAD", "Missing required fields: order_id, user_id, product_id")
    end

    local order_id = decoded.order_id
    local user_id = decoded.user_id
    local product_id = decoded.product_id
    local amount = decoded.amount
    local currency = decoded.currency
    local provider_order_no = decoded.provider_order_no

    -- Idempotency check: check if order_id exists in processed_orders collection
    local objects = nk.storage_read({
        {
            collection = "processed_orders",
            key = order_id,
            user_id = user_id
        }
    })

    if #objects > 0 then
        nk.logger_warn("Order already processed: " .. order_id)
        return response.ok({ note = "Already processed" })
    end

    -- Construct mock context to ensure user_id is set (especially for S2S calls)
    local mock_context = {}
    for k, v in pairs(context) do
        mock_context[k] = v
    end
    mock_context.user_id = user_id

    -- Construct purchase_mock
    local purchase_mock = {
        product_id = product_id,
        provider = "custom",
        store = "custom",
        transaction_id = order_id,
        environment = "production"
    }

    if not iap_domain then
        nk.logger_error("iap_domain not wired in iap_service")
        return fail_by_key("IAP_SERVICE_NOT_WIRED", "Service not initialized")
    end

    -- Call domain logic to grant items
    local success = iap_domain.on_purchase_complete(mock_context, purchase_mock)

    if success then
        -- Write order_id to storage to mark it as processed
        nk.storage_write({
            {
                collection = "processed_orders",
                key = order_id,
                user_id = user_id,
                value = {
                    product_id = product_id,
                    amount = amount,
                    currency = currency,
                    provider_order_no = provider_order_no,
                    processed_at = nk.time()
                },
                permission_read = 0,
                permission_write = 0
            }
        })
        return response.ok()
    else
        return fail_by_key("IAP_PROCESS_REWARD_FAILED", "Failed to process purchase rewards")
    end
end

-- 创建支付订单：mock 渠道本地生成订单，其它渠道转发 PayGateway。
function M.rpc_create_order(context, payload)
    nk.logger_info("RPC create_order called. Payload: " .. (payload or "nil"))

    local status, decoded = pcall(nk.json_decode, payload)
    if not status or not decoded then
        return fail_by_key("IAP_INVALID_PAYLOAD", "Invalid payload")
    end

    local product_id = decoded.product_id
    local provider = decoded.provider or "mock"

    if not product_id then
        return fail_by_key("IAP_MISSING_PRODUCT", "Missing product_id")
    end

    local user_id = context.user_id
    if not user_id then
        return fail_by_key("IAP_USER_NOT_FOUND", "User not found")
    end

    if provider == "mock" then
        return response.ok({
            order_id = "mock_" .. nk.uuid_v4(),
            provider = provider,
            pay_url = ""
        })
    end

    -- Call PayGateway to create order
    local url = config.paygateway_api_url .. "/v1/orders"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Accept"] = "application/json"
    }
    local body = nk.json_encode({
        app_id = "nakama_game",
        user_id = user_id,
        product_id = product_id,
        amount = 100, -- In real world, look up price from config.iap_products
        currency = "CNY",
        provider = provider,
        subject = "IAP Purchase: " .. product_id
    })

    local success, code, response_headers, response_body = pcall(nk.http_request, url, "POST", headers, body)
    if not success or code >= 400 then
        nk.logger_error("Failed to create order in PayGateway: " .. (response_body or "unknown"))
        return fail_by_key("IAP_PAYGATEWAY_FAILED", "Failed to create order")
    end
    local ok_decode, order_result = pcall(nk.json_decode, response_body or "")
    if not ok_decode or type(order_result) ~= "table" then
        return fail_by_key("IAP_PAYGATEWAY_FAILED", "Invalid PayGateway response")
    end
    order_result.success = true
    if type(order_result.provider) ~= "string" or order_result.provider == "" then
        order_result.provider = provider
    end
    return nk.json_encode(order_result)
end

-- 触发 mock 渠道支付通知，便于联调支付回调链路。
function M.rpc_mock_pay(context, payload)
    nk.logger_info("RPC mock_pay called. Payload: " .. (payload or "nil"))

    local status, decoded = pcall(nk.json_decode, payload)
    if not status or not decoded then
        return fail_by_key("IAP_INVALID_PAYLOAD", "Invalid payload")
    end

    local order_id = decoded.order_id
    if not order_id then
        return fail_by_key("IAP_INVALID_PAYLOAD", "Missing order_id")
    end

    -- Call PayGateway Mock Notify
    local url = config.paygateway_api_url .. "/v1/providers/mock/notify"
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local body = nk.json_encode({
        order_id = order_id,
        status = "SUCCESS"
    })

    local success, code, response_headers, response_body = pcall(nk.http_request, url, "POST", headers, body)
    if not success or code >= 400 then
        nk.logger_error("Failed to call mock notify: " .. (response_body or "unknown"))
        return fail_by_key("IAP_PAYGATEWAY_FAILED", "Failed to mock pay")
    end

    return response.ok({ msg = "Mock payment triggered" })
end

return M
