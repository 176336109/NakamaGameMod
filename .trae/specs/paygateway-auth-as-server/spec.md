# PayGateway Authenticate as Server Spec

## Why
目前 `PayGateway` 调用 `Nakama` RPC 时使用的是 `HTTP Key` (Client API Key)，这虽然能跑通，但在权限模型上不够严谨。为了符合官方 Server-to-Server 最佳实践，应改为“网关作为系统用户登录，获取 Token，再以该 Token 调用 RPC”的模式。这样可以利用 `context.user_id` 追踪操作来源，且无需将 `HTTP Key` 暴露给网关。

## What Changes
- 修改 `config.yaml` 及其加载逻辑，废弃 `nakama_http_key`，恢复使用 `nakama_server_key`。
- 修改 `PayGateway` 的 `notifyBusiness` 逻辑：
  1. 先调用 `/v2/account/authenticate/custom`，使用 `server_key` 进行 Basic Auth，传入系统用户 ID（如 `pay_gateway_system_user`）。
  2. 获取响应中的 `token` (JWT)。
  3. 使用该 Token 作为 `Authorization: Bearer <token>` 头，调用 `/v2/rpc/pay_callback`。
- 优化 Token 管理：由于频繁登录开销较大，且 Token 有效期较长，建议在内存中缓存该 Token，仅在过期或 401 时重新登录。

## Impact
- Affected specs: N/A
- Affected code:
  - `PayGateway/pkg/config/config.go`
  - `PayGateway/internal/service/service.go`
  - `PayGateway/config.yaml`

## ADDED Requirements
### Requirement: Server-Side Authentication
The system SHALL authenticate with Nakama using the `server_key` to obtain a session token for a designated system user before making RPC calls.

#### Scenario: Token Acquisition
- **WHEN** the system needs to call Nakama RPC and has no valid token.
- **THEN** it calls `/v2/account/authenticate/custom` with `{"id": "pay_gateway_system_user", "create": true}`.
- **AND** uses the returned token for subsequent requests.

### Requirement: Token Caching
The system SHOULD cache the authentication token to minimize overhead, refreshing it only when necessary (e.g., on 401 response or near expiration).

## MODIFIED Requirements
### Requirement: RPC Authorization
**OLD**: The system uses `Authorization: Basic <base64(http_key:)>` to call RPC.
**NEW**: The system uses `Authorization: Bearer <session_token>` to call RPC.

## REMOVED Requirements
N/A