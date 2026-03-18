# Payment Gateway Mock & RPC Integration Spec

## Why
Currently, the client (Unity) communicates directly with the PayGateway for creating orders. This exposes the PayGateway URL to the public, which is not secure. The client should instead communicate with Nakama via RPC, and Nakama acts as a proxy to the PayGateway.

Additionally, end-to-end testing of the payment flow is difficult because it requires a real payment provider callback. We need a "Mock" payment provider and a corresponding mechanism in Unity SDK and Nakama to simulate the payment callback, allowing developers to verify the entire flow (Order -> Pay -> Callback -> Delivery) without real money.

## What Changes

### 1. PayGateway (Go)
- **New Feature**: Add a `MockProvider` implementation.
    - **Name**: `mock`
    - **CreateOrder**: Returns a dummy `pay_url` and parameters.
    - **ParseNotify**: Accepts a simple JSON payload `{"order_id": "...", "status": "SUCCESS"}` and returns valid `NotifyData`.
- **Configuration**: Update `main.go` to register the `mock` provider if configured in `config.yaml`.

### 2. NakamaServerMod (Lua)
- **New RPC**: `rpc_create_order`
    - Accepts `product_id` and `provider` (optional, default to `mock` or configured default).
    - Calls PayGateway API `POST /v1/orders`.
    - Returns the PayGateway response to the client.
- **New RPC**: `rpc_mock_pay`
    - Accepts `order_id`.
    - Calls PayGateway API `POST /v1/providers/mock/notify`.
    - Payload: `{"order_id": "...", "status": "SUCCESS", "amount": 100, "currency": "CNY"}`.
- **Configuration**: Add `paygateway_api_url` to `config.lua` (or hardcode for now if config system is limited, but prefer config).

### 3. Unity SDK (C#)
- **New Method**: `IapService.CreateOrderAsync(string productId, string provider)`
    - Calls `rpc_create_order`.
- **New Method**: `IapService.MockPayAsync(string orderId)`
    - Calls `rpc_mock_pay`.
- **Update**: `IapService` needs to be more generic, not just for Apple/Google validation.

### 4. Documentation
- Update `Server/Readme.md` to reflect the new architecture (Client -> Nakama -> PayGateway) and the Mock flow.

## Impact
- **Security**: PayGateway URL is hidden from the client.
- **Testing**: Enable full integration testing of the payment system.
- **Breaking Changes**: None for existing Apple/Google IAP. New flow is additive.

## ADDED Requirements

### Requirement: Mock Provider in PayGateway
The system SHALL support a `mock` provider that allows simulating order creation and notifications without external dependencies.

#### Scenario: Mock Notification
- **WHEN** PayGateway receives `POST /v1/providers/mock/notify` with valid JSON.
- **THEN** it validates the signature (optional for mock) or just accepts it, and triggers the standard `HandleNotify` logic (update order status, create notify task).

### Requirement: RPC Proxy for Orders
The system SHALL provide an RPC `rpc_create_order` on Nakama.

#### Scenario: Create Order via RPC
- **WHEN** Client calls `rpc_create_order` with `product_id`.
- **THEN** Nakama calls PayGateway `create_order`.
- **THEN** Nakama returns the payment parameters to Client.

### Requirement: RPC for Mock Payment
The system SHALL provide an RPC `rpc_mock_pay` on Nakama.

#### Scenario: Simulate Payment
- **WHEN** Client calls `rpc_mock_pay` with `order_id`.
- **THEN** Nakama calls PayGateway `notify` endpoint for `mock` provider.
- **THEN** PayGateway processes the notification and eventually calls back Nakama `rpc_pay_callback` to deliver items.
