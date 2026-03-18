# PayGateway -> Nakama IAP Callback RPC Spec

## Why
目前 `PayGateway` 已实现了可靠的“本地消息表+定时重试”机制，并在支付成功后通过 HTTP POST 调用业务服回调地址 (`nakama_notify_url`)。但 `NakamaServerMod` 中尚未实现接收此回调并处理发货逻辑的 RPC 接口。我们需要在 Nakama 中增加一个对应的 RPC 供网关调用，以闭环整个支付发货流程。

## What Changes
- 在 `NakamaServerMod/domain/iap.lua` 中复用现有的 `on_purchase_complete` 逻辑，提供一个专门处理网关发货请求的方法。
- 新增 `NakamaServerMod/service/iap_service.lua`，按照 DDD 规范暴露 `rpc_pay_callback`。
- 在 `NakamaServerMod/main.lua` 中注册新的 `pay_callback` RPC。
- RPC 内需实现幂等校验：同一 `order_id` 不能重复发货（可以基于 `Nakama` 的 storage 记录已处理订单）。
- RPC 内需要处理网关发来的签名校验或简单的 `ServerKey` 鉴权（根据 PayGateway 发送的 `Authorization` 头或自定义头）。

## Impact
- Affected specs: 闭环了支付发货流程。
- Affected code:
  - `NakamaServerMod/domain/iap.lua`
  - `NakamaServerMod/service/iap_service.lua` (New)
  - `NakamaServerMod/main.lua`

## ADDED Requirements
### Requirement: IAP Callback RPC
The system SHALL provide an RPC endpoint `pay_callback` that accepts JSON payloads from `PayGateway`.

#### Scenario: Success case
- **WHEN** PayGateway calls `pay_callback` with a valid payload (including `order_id`, `product_id`, `user_id`, etc.) and correct authentication.
- **THEN** the system verifies if the `order_id` has been processed.
- **IF** not processed, it grants the rewards configured in `config.iap_products[product_id]` to the user via `backpack_service` or `iap` domain logic.
- **AND** records the `order_id` in storage to prevent duplicate delivery.
- **AND** returns an HTTP 200 equivalent response (success JSON).

#### Scenario: Duplicate order
- **WHEN** PayGateway calls `pay_callback` with an already processed `order_id`.
- **THEN** the system detects the duplicate in storage and safely returns success without granting items again (Idempotency).

## MODIFIED Requirements
N/A

## REMOVED Requirements
N/A
