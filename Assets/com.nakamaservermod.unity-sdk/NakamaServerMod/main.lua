local nk = require("nakama")
local backpack = require("backpack")
local gacha = require("gacha")
local checkin = require("checkin")
local iap = require("iap")
local vip_svip = require("vip_svip")

-- NakamaMod/main.lua
-- Nakama Lua runtime 使用顶层代码直接注册 RPC，不需要 InitModule / initializer。
-- 参考：https://heroiclabs.com/docs/nakama/server-framework/lua-runtime/function-reference/#register_rpc

nk.logger_info("----> [NakamaServerMod] Registering RPCs... <----")

-- 1) Backpack RPCs
nk.register_rpc(function(context, payload)
    local user_id = context.user_id
    local items = nk.json_decode(payload)
    local s, e = backpack.add_items(context, user_id, items, "debug", { rpc = "debug_add_items" })
    if not s then return nk.json_encode({ error = e }) end
    return nk.json_encode({ success = true })
end, "debug_add_items")

nk.register_rpc(backpack.rpc_wallet_get, "wallet_get")
nk.register_rpc(backpack.rpc_inventory_get_items, "inventory_get_items")
nk.register_rpc(backpack.rpc_inventory_list, "inventory_list")

-- 2) Gacha RPC
nk.register_rpc(gacha.rpc_gacha_pull, "gacha_pull")

-- 3) Check-in RPCs
nk.register_rpc(checkin.rpc_daily_checkin, "daily_checkin")
nk.register_rpc(checkin.rpc_checkin_get_state, "checkin_get_state")
nk.register_rpc(checkin.rpc_checkin_makeup, "checkin_makeup")
nk.register_rpc(checkin.rpc_checkin_claim_bonus, "checkin_claim_bonus")

-- 4) VIP/SVIP RPCs
nk.register_rpc(vip_svip.rpc_purchase_vip, "purchase_vip")
nk.register_rpc(vip_svip.rpc_purchase_svip, "purchase_svip")
nk.register_rpc(vip_svip.rpc_claim_vip_daily, "claim_vip_daily")
nk.register_rpc(vip_svip.rpc_claim_svip_daily, "claim_svip_daily")
nk.register_rpc(vip_svip.rpc_claim_all_daily, "claim_all_daily")
nk.register_rpc(vip_svip.rpc_get_vip_status, "get_vip_status")
nk.register_rpc(vip_svip.rpc_check_revive_permission, "check_revive_permission")
nk.register_rpc(vip_svip.rpc_record_revive_usage, "record_revive_usage")
nk.register_rpc(vip_svip.rpc_check_sweep_permission, "check_sweep_permission")
nk.register_rpc(vip_svip.rpc_record_sweep_usage, "record_sweep_usage")
nk.register_rpc(vip_svip.rpc_check_magnet_permission, "check_magnet_permission")
nk.register_rpc(vip_svip.rpc_check_plunder_permission, "check_plunder_permission")
nk.register_rpc(vip_svip.rpc_record_plunder_usage, "record_plunder_usage")
nk.register_rpc(vip_svip.rpc_check_queue_permission, "check_queue_permission")
nk.register_rpc(vip_svip.rpc_debug_simulate_purchase, "debug_simulate_purchase")

-- 5) IAP：Lua runtime 没有 register_purchase_validate_* hook API。
--    Apple/Google 收据校验需通过客户端调用 Nakama 原生 API，
--    如需服务端发货逻辑，可通过 register_req_after 挂钩在校验完成后触发。
--    示例（如需启用请取消注释）：
-- nk.register_req_after(function(context, payload)
--     if payload and payload.validated_purchases then
--         for _, purchase in ipairs(payload.validated_purchases) do
--             iap.on_purchase_complete(context, purchase)
--         end
--     end
-- end, "ValidatePurchaseApple")

nk.logger_info("----> [NakamaServerMod] All RPCs registered OK <----")

