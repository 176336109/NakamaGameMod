local nk = require("nakama")
local config = require("config")

local M = {}
local iap_domain = nil

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

function M.rpc_pay_callback(context, payload)
    nk.logger_info("RPC pay_callback called. Payload: " .. (payload or "nil"))

    if not payload or payload == "" then
        nk.logger_error("Pay callback failed: Empty payload")
        return nk.json_encode({ success = false, error = "Empty payload" })
    end

    local status, decoded = pcall(nk.json_decode, payload)
    if not status then
        nk.logger_error("Pay callback failed: Invalid JSON. Error: " .. tostring(decoded))
        return nk.json_encode({ success = false, error = "Invalid JSON payload" })
    end

    nk.logger_debug("Pay callback decoded: " .. nk.json_encode(decoded))

    if not decoded.order_id or not decoded.user_id or not decoded.product_id then
        nk.logger_error("Pay callback failed: Missing required fields (order_id, user_id, product_id)")
        return nk.json_encode({ success = false, error = "Missing required fields: order_id, user_id, product_id" })
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
        return nk.json_encode({ success = true, note = "Already processed" })
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
        return nk.json_encode({ success = false, error = "Service not initialized" })
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
        return nk.json_encode({ success = true })
    else
        return nk.json_encode({ success = false, error = "Failed to process purchase rewards" })
    end
end

function M.rpc_create_order(context, payload)
    nk.logger_info("RPC create_order called. Payload: " .. (payload or "nil"))

    local status, decoded = pcall(nk.json_decode, payload)
    if not status or not decoded then
        return nk.json_encode({ success = false, error = "Invalid payload" })
    end

    local product_id = decoded.product_id
    local provider = decoded.provider or "mock"

    if not product_id then
        return nk.json_encode({ success = false, error = "Missing product_id" })
    end

    local user_id = context.user_id
    if not user_id then
        return nk.json_encode({ success = false, error = "User not found" })
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

    local success, code, headers, response = pcall(nk.http_request, url, "POST", headers, body)
    if not success or code >= 400 then
        nk.logger_error("Failed to create order in PayGateway: " .. (response or "unknown"))
        return nk.json_encode({ success = false, error = "Failed to create order" })
    end

    return response -- Return the PayGateway response (contains order_id, pay_url, etc.)
end

function M.rpc_mock_pay(context, payload)
    nk.logger_info("RPC mock_pay called. Payload: " .. (payload or "nil"))

    local status, decoded = pcall(nk.json_decode, payload)
    if not status or not decoded then
        return nk.json_encode({ success = false, error = "Invalid payload" })
    end

    local order_id = decoded.order_id
    if not order_id then
        return nk.json_encode({ success = false, error = "Missing order_id" })
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

    local success, code, headers, response = pcall(nk.http_request, url, "POST", headers, body)
    if not success or code >= 400 then
        nk.logger_error("Failed to call mock notify: " .. (response or "unknown"))
        return nk.json_encode({ success = false, error = "Failed to mock pay" })
    end

    return nk.json_encode({ success = true, msg = "Mock payment triggered" })
end

return M
