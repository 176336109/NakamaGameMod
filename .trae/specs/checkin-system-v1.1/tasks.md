# Tasks

- [ ] Task 1: Update Lua Configuration (`config.lua`)
  - [ ] Update `M.checkin.rewards` to match the new 7-day reward table in the spec.
  - [ ] Ensure `makeup_cost` is set to 20 gems.

- [ ] Task 2: Implement Server Logic (`checkin.lua`)
  - [ ] Implement `get_cycle_info` using account creation time logic (Unified Criteria).
  - [ ] Implement `rpc_checkin_get_state` to return full cycle state and unified day status (`signed`, `missed`, `claimable`, `locked`, `makeup_signed`).
  - [ ] Implement `rpc_daily_checkin` for "today" check-in with duplicate claim prevention.
  - [ ] Implement `rpc_checkin_makeup` for "history" check-in with cost deduction and validation.
  - [ ] Ensure `rpc_debug_set_time_offset` is available for testing.

- [ ] Task 3: Register RPCs (`main.lua`)
  - [ ] Verify/Add registration for `checkin_get_state`, `daily_checkin`, `checkin_makeup`, `debug_set_time_offset`.

- [ ] Task 4: Update Unity SDK (`CheckinService.cs`)
  - [ ] Ensure methods exist for `GetStateAsync`, `DailyCheckinAsync`, `MakeupAsync`.
  - [ ] Update response models if fields changed (e.g., `makeup_signed` status).

- [ ] Task 5: Implement Test Cases (`CheckinServiceTests.cs`)
  - [ ] Create/Update `CreateAuthenticatedClientAsync` to use Chinese username format: `TestName_Timestamp`.
  - [ ] Implement Core Scenarios C01-C12.
  - [ ] Implement Boundary Scenarios B01-B16.
  - [ ] Add Chinese comments for each step.
  - [ ] Add "Final Result Verification" comment block at the end of each test.

- [ ] Task 6: Verification
  - [ ] Run all tests in `CheckinServiceTests.cs`.
  - [ ] Verify "RPC cancelled" error is gone (should be fixed by proper Lua implementation).

- [ ] Task 7: Repair checklist gaps found in verification
  - [ ] Add missing "Final Result Verification" blocks to every remaining checkin test case.
  - [ ] Execute full `CheckinServiceTests.cs` in CI/Unity runner and attach pass evidence.
  - [ ] Investigate and fix any remaining "RPC cancelled" failure if it appears during rerun.
