# Tasks

- [x] Task 1: Implement MockProvider in PayGateway
    - [x] Create `Server/PayGateway/internal/provider/mock/mock.go` implementing `Provider` interface.
    - [x] Update `Server/PayGateway/cmd/paygateway/main.go` to register the mock provider.
    - [x] Verify `CreateOrder` returns dummy data.
    - [x] Verify `ParseNotify` parses simple JSON correctly.

- [x] Task 2: Implement Nakama RPCs for Payment
    - [x] Update `Server/NakamaServerMod/config.lua` to include `paygateway_api_url`.
    - [x] Edit `Server/NakamaServerMod/service/iap_service.lua`:
        - [x] Implement `rpc_create_order`: Proxy to PayGateway.
        - [x] Implement `rpc_mock_pay`: Call PayGateway mock notify endpoint.

- [x] Task 3: Update Unity SDK
    - [x] Edit `Assets/com.nakamaservermod.unity-sdk/Runtime/IapService.cs`:
        - [x] Add `CreateOrderAsync` method.
        - [x] Add `MockPayAsync` method.

- [x] Task 4: Integration Test & Documentation
    - [x] Create a `.http` test file `Server/PayGateway/Test/Test_MockFlow.http` to test the full flow via Nakama RPC (simulated).
    - [x] Update `Server/Readme.md` with new architecture diagrams and usage instructions.
