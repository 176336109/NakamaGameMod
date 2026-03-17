# Tasks

- [ ] Task 1: Update `config.lua` with Shop configuration.
    - [ ] Define `M.shop.goods` with all goods from the design doc (Special, Gold, Crystal, Fixed).
    - [ ] Define `M.shop.refresh_cost` (5 crystals).
    - [ ] Define `M.shop.random_pool` logic/weights if not implicit in goods config.
- [ ] Task 2: Implement `shop.lua` backend logic.
    - [ ] Implement `shop_load_state` and snapshot generation logic (Random 6 items).
    - [ ] Implement `rpc_shop_get_state`: Return snapshots, limits, and fixed items.
    - [ ] Implement `rpc_shop_refresh`: Manual refresh of Special Shop.
    - [ ] Implement `rpc_shop_buy`: Handle purchasing (Special, Gold, Fixed).
        - [ ] Verify limits (Refresh/Daily/Weekly/Perm).
        - [ ] Verify cost.
        - [ ] Deduct cost & Grant rewards (Atomic).
        - [ ] Update limits.
    - [ ] Register RPCs in `main.lua`.
- [ ] Task 3: Implement Unity SDK `ShopService`.
    - [ ] Create DTOs (`ShopState`, `ShopItem`, `ShopBuyRequest`, etc.).
    - [ ] Implement `GetShopStateAsync`, `RefreshShopAsync`, `BuyItemAsync`.
- [ ] Task 4: Implement Tests.
    - [ ] `ShopServiceTests.cs`: Cover C01-C16 and boundary cases.

- [ ] Task 5: Fix verification failures from checklist
    - [ ] Implement atomic rollback in `rpc_shop_buy` when reward grant fails after cost deduction.
    - [ ] Add deterministic time-control test hook for shop day/week reset verification.
    - [ ] Execute and pass all core C01-C16 scenarios with runnable automation evidence.

# Task Dependencies
- Task 2 depends on Task 1.
- Task 4 depends on Task 2 and Task 3.
