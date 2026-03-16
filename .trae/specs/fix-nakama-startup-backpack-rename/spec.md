# Fix Nakama Startup Spec

## Why
Nakama fails to start because `inventory` module was renamed to `backpack`, but `iap.lua`, `gacha.lua`, and `checkin.lua` still try to `require("inventory")`.

## What Changes
- Update `iap.lua` to require `backpack` and replace usage of `inventory` with `backpack`.
- Update `gacha.lua` to require `backpack` and replace usage of `inventory` with `backpack`.
- Update `checkin.lua` to require `backpack` and replace usage of `inventory` with `backpack`.

## Impact
- Affected files: `iap.lua`, `gacha.lua`, `checkin.lua`.
- Nakama server should start successfully after this fix.

## ADDED Requirements
N/A

## MODIFIED Requirements
N/A

## REMOVED Requirements
N/A
