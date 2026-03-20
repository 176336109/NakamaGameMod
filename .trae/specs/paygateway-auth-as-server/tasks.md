# Tasks
- [x] Task 1: Update Configuration
  - [x] SubTask 1.1: Revert `config.yaml` to use `nakama_server_key` instead of `http_key`.
  - [x] SubTask 1.2: Add `nakama_api_url` (base URL) to config if not already present/adaptable from `nakama_notify_url`.

- [x] Task 2: Implement Token Management in Service
  - [x] SubTask 2.1: Add `token` and `tokenExpiry` fields to `PayService` struct (with mutex).
  - [x] SubTask 2.2: Implement `getNakamaToken(ctx)` method:
    - Checks if cached token is valid.
    - If not, calls `/v2/account/authenticate/custom` using `server_key`.
    - Parses response, updates cache.

- [x] Task 3: Refactor notifyBusiness
  - [x] SubTask 3.1: Modify `notifyBusiness` to call `getNakamaToken` first.
  - [x] SubTask 3.2: Change HTTP request header to `Authorization: Bearer <token>`.
  - [x] SubTask 3.3: Handle 401 response in `notifyBusiness` by clearing cached token and retrying once.

# Task Dependencies
- Task 3 depends on Task 2
- Task 2 depends on Task 1