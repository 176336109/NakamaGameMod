# Fix ShopServiceTests Failures

## Problem Analysis
The user reported 4 test failures in `ShopServiceTests`:
1. `TestC04_ManualRefresh`: Expected `True`, was `False`. This likely means `response.success` is false.
2. `TestC05_SpecialShop_BuySuccess`: Expected `True`, was `False`.
3. `TestC06_SpecialShop_LimitReached`: Expected `True`, was `False`.
4. `TestC14_GoldShop_DailyLimit`: Expected `True`, was `False`.

All failures suggest that the underlying operations (Refresh, Buy) are failing, likely due to:
- **Insufficient Funds**: The test user is created fresh in `CreateAuthenticatedClientAsync`, but the `debug_add_items` RPC call to grant initial currency might be failing or not completing before the tests run.
- **RPC Logic**: The `shop.lua` logic might have bugs (e.g., cost check, inventory consumption).
- **Setup Timing**: The `SetUp` logic was moved to `Test` methods, but if `debug_add_items` fails or is asynchronous in a way that the client doesn't see the funds immediately, subsequent calls fail.

**Key Observation**:
In the previous turn, I moved `debug_add_items` into the test methods.
`await _client.RpcAsync<string, string>("debug_add_items", "{\"gold\": 10000, \"item_diamond\": 1000}");`
If this call succeeds, the user *should* have funds.
However, `shop.lua` uses `backpack.consume_items`.
`backpack.consume_items` checks `nk.wallet_update` for currency.
The `debug_add_items` implementation in `main.lua` calls `backpack.add_items`.
`backpack.add_items` calls `nk.wallet_update`.

**Potential Issue**:
The `debug_add_items` payload uses `"item_diamond"`.
The `config.lua` defines:
```lua
["item_diamond"] = { type = "currency", name = "Diamond" },
```
The `shop.lua` refresh cost is:
```lua
refresh_cost = { item_id = "item_diamond", count = 5 },
```
The `shop.lua` goods costs are e.g. `costType = "gold"`, `costType = "item_diamond"`.

If the tests are failing with `False`, it's likely returning `{ success = false, error = ... }`.
I need to see the error message to be sure, but I can't interactively debug.
However, I can improve the tests to output the error message in the Assertion failure message.

**Hypothesis**:
The issue might be related to how `backpack.consume_items` handles the "check" flag or how `debug_add_items` works.
Or, it could be that `CreateAuthenticatedClientAsync` creates a new user, but `debug_add_items` is not correctly adding items to *that* user (it uses `context.user_id`, which should be correct).

Wait, I noticed in `ShopServiceTests.cs`:
```csharp
await _client.RpcAsync<string, string>("debug_add_items", "{\"gold\": 10000, \"item_diamond\": 1000}");
```
The RPC `debug_add_items` in `main.lua`:
```lua
nk.register_rpc(function(context, payload)
    local user_id = context.user_id
    local items = nk.json_decode(payload)
    local s, e = backpack.add_items(context, user_id, items, "debug", { rpc = "debug_add_items" })
    -- ...
```
`backpack.add_items` iterates input items.
Input JSON: `{"gold": 10000, "item_diamond": 1000}`.
This iterates `pairs`.
`backpack.add_items` expects `items_to_add` to be a **list of objects** `{{id="...", count=...}}`?
Let's check `backpack.lua` -> `add_items`:
```lua
function M.add_items(context, user_id, items_to_add, log_source, log_ref)
    -- ...
    for _, item in ipairs(items_to_add) do
        local item_def = config.items[item.id]
```
**CRITICAL BUG FOUND**: `backpack.add_items` expects an **array** of items `[{ "id": "gold", "count": 10000 }]`, but `debug_add_items` RPC passes the decoded payload directly.
If the payload is `{"gold": 10000}`, `nk.json_decode` returns a table `t` where `t.gold = 10000`.
`ipairs(t)` will be empty because it's a dictionary (hash map), not a sequence!
So `backpack.add_items` does **nothing**, and the user has 0 funds.

**Fix**:
Update `ShopServiceTests.cs` to send the correct JSON structure for `debug_add_items`.
It should be `[{"id": "gold", "count": 10000}, {"id": "item_diamond", "count": 1000}]`.

Also, I will add Chinese comments as requested.

## Plan Steps
1.  **Modify `ShopServiceTests.cs`**:
    *   Fix the `debug_add_items` payload structure to be a list of objects: `[{"id":"gold","count":10000}, {"id":"item_diamond","count":1000}]`.
    *   Add detailed Chinese comments to each step in the test methods.
    *   Improve Assertions to print `response.error` when `response.success` is false, to aid future debugging.

## Verification
- Run the tests again. They should pass now that funds are actually added.
