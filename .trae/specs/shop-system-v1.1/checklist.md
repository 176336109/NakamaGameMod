# Checklist

- [ ] `config.lua` contains all shop goods defined in the doc (Special, Gold, Crystal, Fixed).
- [ ] `shop.lua` correctly handles Beijing Time (UTC+8) for daily/weekly resets.
- [ ] `rpc_shop_get_state` returns correct snapshot and limit status.
- [ ] `rpc_shop_refresh` correctly deduces crystals, generates new snapshot, and resets "per refresh" limits.
- [ ] `rpc_shop_buy` correctly handles:
    - [ ] "Per refresh" limit for Special Shop.
    - [ ] "Daily" limit for Gold Shop.
    - [ ] "Weekly" limit for Fixed Shop.
    - [ ] "Permanent" limit.
- [ ] Transaction atomicity: Cost deduction and Reward grant are atomic (or rolled back).
- [ ] Unity SDK `ShopService` methods work as expected.
- [ ] Tests pass for all core scenarios (C01-C16).
