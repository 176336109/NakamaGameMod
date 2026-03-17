# PayGateway Reliable Notification Spec

## Why
目前 PayGateway 向业务服（Nakama）发送支付成功回调采用的是“发后即忘 (Fire-and-Forget)”的异步调用模式。如果此时网络抖动或 Nakama 服务不可用，将导致玩家付款后无法收到商品（掉单），且网关不会重试。为了保证最终一致性，必须引入基于本地消息表和定时任务的可靠重试机制。

## What Changes
- **新增数据库表 `NotifyTask`**：用于持久化记录待通知的业务发货任务，包含订单ID、状态、重试次数、下次重试时间等。
- **引入事务机制**：在处理支付渠道成功回调时，将更新订单状态（改为 PAID）、记录 CallbackLog 以及创建 `NotifyTask` 这三步操作放在同一个数据库事务中。
- **改造通知逻辑**：
  - 发送通知前更新任务状态。
  - 根据 HTTP 响应结果更新 `NotifyTask` 状态为 `SUCCESS`，或在失败时增加重试次数并计算下次重试时间（采用简单的指数退避策略）。
- **新增定时重试器 (Cron/Ticker)**：在网关后台启动一个常驻协程，定期（例如每隔 30 秒）扫描 `NotifyTask` 表中状态为 `PENDING` 且到达重试时间的记录，并重新发起通知请求。

## Impact
- Affected specs: N/A
- Affected code:
  - `PayGateway/internal/model/model.go` (新增 NotifyTask 模型)
  - `PayGateway/internal/repo/repo.go` (增加 NotifyTask 相关的 CURD 方法和事务支持)
  - `PayGateway/internal/service/service.go` (改造 HandleNotify 引入事务，重构 notifyBusiness)
  - `PayGateway/internal/service/retryer.go` (新建，实现定时重试逻辑)
  - `PayGateway/cmd/paygateway/main.go` (启动时注册并运行 Retryer)

## ADDED Requirements
### Requirement: Reliable Business Notification
The system SHALL ensure that successful payment notifications are reliably delivered to the business server (Nakama) using a local message table and background retry mechanism.

#### Scenario: Success case
- **WHEN** payment provider sends a valid PAID callback
- **THEN** system creates a NotifyTask in PENDING state within the same transaction as the Order status update.
- **AND** immediately attempts to notify the business server.
- **IF** business server responds with HTTP 2xx, the NotifyTask is marked as SUCCESS.

#### Scenario: Retry case
- **WHEN** business server is unreachable or responds with a non-2xx status
- **THEN** the NotifyTask remains PENDING, its retry count is incremented, and next retry time is set.
- **AND** a background worker picks it up after the next retry time and attempts delivery again.

## MODIFIED Requirements
N/A

## REMOVED Requirements
N/A