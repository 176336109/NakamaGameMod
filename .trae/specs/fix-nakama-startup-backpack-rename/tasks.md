# Tasks
- [x] Task 1: Update `iap.lua` to use `backpack` module
  - [x] Replace `local inventory = require("inventory")` with `local backpack = require("backpack")`
  - [x] Replace `inventory.add_items` with `backpack.add_items`
- [x] Task 2: Update `gacha.lua` to use `backpack` module
  - [x] Replace `local inventory = require("inventory")` with `local backpack = require("backpack")`
  - [x] Replace `inventory.add_items` with `backpack.add_items`
  - [x] Replace `inventory.consume_items` with `backpack.consume_items`
- [x] Task 3: Update `checkin.lua` to use `backpack` module
  - [x] Replace `local inventory = require("inventory")` with `local backpack = require("backpack")`
  - [x] Replace `inventory.add_items` with `backpack.add_items`
  - [x] Replace `inventory.consume_items` with `backpack.consume_items`
- [x] Task 4: Fix remaining `inventory` references in `backpack.lua`
  - [x] Replace `collection = "inventory"` with `collection = "backpack"`
  - [x] Replace `nk.storage_list(..., "inventory", ...)` with `nk.storage_list(..., "backpack", ...)`

# Task Dependencies
- Tasks can be done in parallel.
