# PayGateway Production Readiness Spec

## Why
目前 PayGateway 服务在数据库初始化和日志记录方面还不够完善。需要明确 PostgreSQL 数据库表的创建方式（支持自动迁移），并加入完整且有助于排查错误的日志记录（Logging），以满足生产环境的需求。

## What Changes
- 在程序启动时，如果配置了 PostgreSQL，使用 GORM 的 `AutoMigrate` 自动创建/更新数据库表结构。
- 更新 `README.md`，明确说明数据库表会自动建立，并提供相关配置说明。
- 引入结构化日志库（如 `zap`），替换标准库的 `log`。
- 在 API 请求入口、Service 核心逻辑（下单、回调处理）、Provider 交互处添加详细的上下文日志（包含 OrderID、Provider 等关键信息）。
- 配置日志记录，支持控制台输出，包含时间戳、日志级别和调用位置。

## Impact
- Affected specs: N/A
- Affected code:
  - `PayGateway/cmd/paygateway/main.go`
  - `PayGateway/internal/api/api.go`
  - `PayGateway/internal/service/service.go`
  - `PayGateway/internal/provider/custom/myprovider.go`
  - `PayGateway/internal/provider/gopay/wechat.go`
  - `PayGateway/pkg/logger/logger.go` (新建)
  - `PayGateway/README.md`

## ADDED Requirements
### Requirement: Database Auto-Migration
The system SHALL automatically create or update necessary database tables (Order, Refund, CallbackLog) when starting up with a PostgreSQL database connection.

### Requirement: Structured Logging
The system SHALL provide structured logging with distinct levels (INFO, WARN, ERROR, DEBUG) to facilitate troubleshooting in production.

## MODIFIED Requirements
N/A

## REMOVED Requirements
N/A
