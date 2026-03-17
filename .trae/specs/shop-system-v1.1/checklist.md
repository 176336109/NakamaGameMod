# Checklist

- [x] `config.lua` contains all shop goods defined in the doc (Special, Gold, Crystal, Fixed).
- [x] `shop.lua` correctly handles Beijing Time (UTC+8) for daily/weekly resets.
- [x] `rpc_shop_get_state` returns correct snapshot and limit status.
- [x] `rpc_shop_refresh` correctly deduces crystals, generates new snapshot, and resets "per refresh" limits.
- [x] `rpc_shop_buy` correctly handles:
    - [x] "Per refresh" limit for Special Shop.
    - [x] "Daily" limit for Gold Shop.
    - [x] "Weekly" limit for Fixed Shop.
    - [x] "Permanent" limit.
- [ ] Transaction atomicity: Cost deduction and Reward grant are atomic (or rolled back).
- [x] Unity SDK `ShopService` methods work as expected.
- [ ] Tests pass for all core scenarios (C01-C16).
