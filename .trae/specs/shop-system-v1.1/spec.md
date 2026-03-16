# Shop System v1.1 Spec

## Why
Implement the v1.1 Shop System design to provide a comprehensive resource acquisition channel, supporting Special Shop (with random rotation), Crystal Shop (IAP), and Gold Shop (exchange). This system is crucial for the game's economy and monetization.

## What Changes
- **Lua Backend**:
    - Create `shop.lua` to handle shop logic (Special, Crystal, Gold).
    - Implement shop configuration in `config.lua`.
    - Implement "Special Shop" logic:
        - Random 6 items refresh daily (Beijing Time 00:00).
        - Manual refresh support (cost 5 crystals).
        - Snapshot mechanism for random items.
        - "Per refresh" purchase limits.
    - Implement "Gold Shop" logic:
        - Daily purchase limits (reset at Beijing Time 00:00).
    - Implement "Crystal Shop" logic:
        - Interface for IAP callback/validation (mock/placeholder for now as per previous context, or use `debug_simulate_purchase` pattern if needed, but spec says "Crystal Shop purchasing uses IAP domain capabilities"). *Self-correction: The prompt asks to implement based on the doc. The doc says "Crystal Shop purchasing uses IAP domain capabilities". I will implement the necessary RPCs to list these items and handle any server-side logic if required, or clarify if it's purely client-side IAP trigger.*
    - Implement "Fixed/Perm" items logic (Weekly/Permanent limits).
- **Unity SDK**:
    - Create `ShopService` and DTOs.
    - Implement methods for `GetShopState`, `RefreshShop`, `BuyItem`.
- **Tests**:
    - Create `ShopServiceTests` covering the core scenarios (C01-C16) and boundary cases (B01-B15).

## Impact
- **Affected Specs**: Shop System.
- **Affected Code**:
    - `NakamaServerMod/shop.lua` (New)
    - `NakamaServerMod/config.lua` (Update)
    - `NakamaServerMod/main.lua` (Update to register RPCs)
    - `NakamaServerMod.UnitySdk/Runtime/Shop*.cs` (New)
    - `NakamaServerMod.UnitySdk/Tests/Runtime/ShopServiceTests.cs` (New)

## ADDED Requirements
### Requirement: Special Shop (Random Rotation)
The system SHALL generate a snapshot of 6 random items for the user.
The snapshot SHALL refresh automatically at 00:00 Beijing Time.
The snapshot SHALL be refreshable manually for 5 crystals.
Items in the snapshot SHALL have a "1 per refresh" purchase limit.

### Requirement: Gold Shop
The system SHALL provide gold exchange options.
Some options SHALL have a daily purchase limit (reset at 00:00 Beijing Time).

### Requirement: Crystal Shop
The system SHALL list crystal recharge options (IAP products).

### Requirement: Fixed/Limited Items
The system SHALL support Weekly Limited items (reset Monday 00:00 Beijing Time).
The system SHALL support Permanent Limited items.

## MODIFIED Requirements
### Requirement: Config Structure
`config.lua` will be expanded to include `M.shop` with `goods`, `refresh_cost`, etc.

## REMOVED Requirements
N/A
