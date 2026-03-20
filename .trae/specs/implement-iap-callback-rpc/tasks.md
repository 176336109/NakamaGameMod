# Tasks
- [x] Task 1: Create IAP Service and Wire Dependencies
  - [x] SubTask 1.1: Create `service/iap_service.lua` adhering to the DDD rules (do not let domain layers cross-call inappropriately).
  - [x] SubTask 1.2: Implement `wire_item_gateway` in `iap_service.lua` to inject `backpack` and `iap` domain logic.

- [x] Task 2: Implement the `pay_callback` RPC logic
  - [x] SubTask 2.1: In `iap_service.lua`, implement `rpc_pay_callback(context, payload)`.
  - [x] SubTask 2.2: Parse the incoming JSON payload (`order_id`, `user_id`, `product_id`, `amount`, `currency`, `provider_order_no`).
  - [x] SubTask 2.3: Implement idempotency check using Nakama's `storage_read` to see if `order_id` exists in a specific collection (e.g., `processed_orders`).
  - [x] SubTask 2.4: If not processed, call `iap.on_purchase_complete(context, purchase_mock)` or a new dedicated method in `iap.lua` to grant items based on `config.iap_products`.
  - [x] SubTask 2.5: Write the `order_id` to storage via `storage_write` to mark it as processed.

- [x] Task 3: Register the RPC in main.lua
  - [x] SubTask 3.1: Require `iap_service` in `main.lua`.
  - [x] SubTask 3.2: Call `iap_service.wire_item_gateway(backpack, iap)`.
  - [x] SubTask 3.3: Register the RPC: `nk.register_rpc(iap_service.rpc_pay_callback, "pay_callback")`.

# Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 2
