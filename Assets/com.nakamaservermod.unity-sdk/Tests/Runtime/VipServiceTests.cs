using NUnit.Framework;
using System;
using System.Linq;
using System.Threading.Tasks;
namespace NakamaServerMod.UnitySdk.Tests
{
    [TestFixture]
    public class VipServiceTests
    {
        // 辅助方法：创建客户端并以带有时间戳和测试名称的 DeviceID/Username 注册新账号
        private async Task<GameClient> CreateAuthenticatedClientAsync(string testName = "UnknownTest")
        {
            var config = ConnectionConfig.Localhost();
            var client = new GameClient(config);
            var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss_fff");
            var deviceId = $"device_{timestamp}_{Guid.NewGuid().ToString("N").Substring(0, 4)}";
            // 在用户名中包含测试用例的中文名称，方便在数据库中识别
            var username = $"{testName}_{timestamp}";
            
            await client.AuthenticateDeviceAsync(deviceId, username);
            return client;
        }

        /// <summary>
        /// 测试购买 VIP 月卡
        /// </summary>
        [Test]
        public async Task TestPurchaseVip()
        {
            var client = await CreateAuthenticatedClientAsync("购买VIP测试");
            var vipService = new VipService(client);
            var inventoryService = new InventoryService(client);

            // 购买 VIP
            var purchaseResult = await vipService.PurchaseVipAsync();
            Assert.IsNotNull(purchaseResult);
            Assert.IsTrue(purchaseResult.success);
            Assert.IsNotNull(purchaseResult.item_data, "Item data should not be null");
            Assert.AreEqual("item_vip_active", purchaseResult.item_data.itemId);

            // 验证 VIP 状态
            var status = await vipService.GetVipStatusAsync();
            Assert.IsNotNull(status);
            Assert.IsTrue(status.vip_active);
            Assert.IsTrue(status.vip_remaining_days >= 29); // 30天
            Assert.AreEqual(1, status.vip_unclaimed_days); // 购买当天有1天可领
            
            // 领取每日奖励
            var claimResult = await vipService.ClaimVipDailyAsync();
            Assert.IsTrue(claimResult.success);
            
            // 再次验证状态
            status = await vipService.GetVipStatusAsync();
            Assert.AreEqual(0, status.vip_unclaimed_days);
            
            // 验证钱包中有钻石
            var walletResponse = await inventoryService.GetWalletAsync();
            var wallet = walletResponse.wallet ?? new System.Collections.Generic.Dictionary<string, long>();
            Assert.IsTrue(wallet.ContainsKey("item_diamond"));
            Assert.GreaterOrEqual(wallet["item_diamond"], 210); // 至少获得210

            // 最终结果验证：
            // - VIP 状态激活 (vip_active == true)
            // - VIP 剩余天数 >= 29
            // - 今日奖励已领取 (vip_unclaimed_days == 0)
            // - 钱包中获得钻石 (立即 180 + 每日 30 = 210)
        }

        /// <summary>
        /// 测试购买 SVIP 月卡
        /// </summary>
        [Test]
        public async Task TestPurchaseSvip()
        {
            var client = await CreateAuthenticatedClientAsync("购买SVIP测试");
            var vipService = new VipService(client);
            var inventoryService = new InventoryService(client);

            // 购买 SVIP
            var purchaseResult = await vipService.PurchaseSvipAsync();
            Assert.IsNotNull(purchaseResult);
            Assert.IsTrue(purchaseResult.success);
            Assert.IsNotNull(purchaseResult.item_data, "Item data should not be null");
            Assert.AreEqual("item_svip_active", purchaseResult.item_data.itemId);

            // 验证 SVIP 状态
            var status = await vipService.GetVipStatusAsync();
            Assert.IsNotNull(status);
            Assert.IsTrue(status.svip_active);
            Assert.IsTrue(status.svip_remaining_days >= 29); // 30天
            Assert.AreEqual(1, status.svip_unclaimed_days); // 购买当天有1天可领
            
            // 领取每日奖励
            var claimResult = await vipService.ClaimSvipDailyAsync();
            Assert.IsTrue(claimResult.success);
            
            // 再次验证状态
            status = await vipService.GetVipStatusAsync();
            Assert.AreEqual(0, status.svip_unclaimed_days);
            
            // 验证钱包中有钻石
            var walletResponse = await inventoryService.GetWalletAsync();
            var wallet = walletResponse.wallet ?? new System.Collections.Generic.Dictionary<string, long>();
            Assert.IsTrue(wallet.ContainsKey("item_diamond"));
            Assert.GreaterOrEqual(wallet["item_diamond"], 360); // 至少获得360
            
            // 验证背包中有沙漏 (3)
            var items = await inventoryService.GetItemsAsync();
            if (items.items != null)
            {
                var hourglass = items.items.FirstOrDefault(i => i.id == "010300001");
                Assert.IsNotNull(hourglass);
                Assert.GreaterOrEqual(hourglass.count, 3);
            }
            else
            {
                Assert.Fail("Items list is null");
            }

            // 最终结果验证：
            // - SVIP 状态激活 (svip_active == true)
            // - SVIP 剩余天数 >= 29
            // - 今日奖励已领取 (svip_unclaimed_days == 0)
            // - 钱包中获得钻石 (立即 300 + 每日 60 = 360)
            // - 背包中获得沙漏 (每日 3 个)
        }
        
        /// <summary>
        /// 测试一键领取所有每日奖励
        /// </summary>
        [Test]
        public async Task TestClaimAllDaily()
        {
            var client = await CreateAuthenticatedClientAsync("一键领取测试");
            var vipService = new VipService(client);
            var inventoryService = new InventoryService(client);

            // 购买 VIP 和 SVIP
            await vipService.PurchaseVipAsync();
            await vipService.PurchaseSvipAsync();
            
            var status = await vipService.GetVipStatusAsync();
            // 购买后，vip_active 应该为 true
            Assert.IsTrue(status.vip_active, "VIP should be active after purchase");
            Assert.IsTrue(status.svip_active, "SVIP should be active after purchase");
            
            // 注意：购买后立即获得一次领取机会
            // VIP: 1次 (pendingClaimDays=1)
            // SVIP: 1次 (pendingClaimDays=1)
            Assert.AreEqual(1, status.vip_unclaimed_days, $"VIP unclaimed days mismatch. Active: {status.vip_active}");
            Assert.AreEqual(1, status.svip_unclaimed_days, $"SVIP unclaimed days mismatch. Active: {status.svip_active}");
            
            // 一键领取
            var claimResult = await vipService.ClaimAllDailyAsync();
            Assert.IsTrue(claimResult.success);
            
            // 验证状态
            status = await vipService.GetVipStatusAsync();
            // 领取后，可领取天数应为0
            Assert.AreEqual(0, status.vip_unclaimed_days);
            Assert.AreEqual(0, status.svip_unclaimed_days);
            
            // 验证钱包中有钻石
            var walletResponse = await inventoryService.GetWalletAsync();
            var wallet = walletResponse.wallet ?? new System.Collections.Generic.Dictionary<string, long>();
            Assert.IsTrue(wallet.ContainsKey("item_diamond"));
            Assert.GreaterOrEqual(wallet["item_diamond"], 570); // 至少获得570
            
            // 验证背包中有沙漏 (3)
            var items = await inventoryService.GetItemsAsync();
            if (items.items != null)
            {
                var hourglass = items.items.FirstOrDefault(i => i.id == "010300001");
                Assert.IsNotNull(hourglass);
                Assert.GreaterOrEqual(hourglass.count, 3);
            }
            else
            {
                Assert.Fail("Items list is null");
            }

            // 最终结果验证：
            // - VIP 和 SVIP 均激活
            // - 今日所有奖励均已领取 (unclaimed_days == 0)
            // - 钱包中获得钻石 (VIP 210 + SVIP 360 = 570)
            // - 背包中获得沙漏 (3 个)
        }

        /// <summary>
        /// 测试获取 VIP/SVIP 状态（初始状态应为未激活）
        /// </summary>
        [Test]
        public async Task TestGetVipStatus()
        {
            var client = await CreateAuthenticatedClientAsync("获取状态测试");
            var vipService = new VipService(client);

            var status = await vipService.GetVipStatusAsync();
            Assert.IsNotNull(status);
            Assert.IsFalse(status.vip_active);
            Assert.IsFalse(status.svip_active);
            Assert.AreEqual(0, status.vip_remaining_days);
            Assert.AreEqual(0, status.svip_remaining_days);
            Assert.AreEqual(0, status.vip_unclaimed_days);
            Assert.AreEqual(0, status.svip_unclaimed_days);

            // 最终结果验证：
            // - 所有状态均未激活 (active == false)
            // - 剩余天数为 0
            // - 可领取天数为 0
        }

        /// <summary>
        /// 测试检查复活权限（初始免费玩家状态）
        /// </summary>
        [Test]
        public async Task TestCheckRevivePermission()
        {
            var client = await CreateAuthenticatedClientAsync("复活权限测试");
            var vipService = new VipService(client);

            var permission = await vipService.CheckRevivePermissionAsync();
            Assert.IsNotNull(permission);
            Assert.IsTrue(permission.can_revive);
            Assert.IsTrue(permission.need_ad);
            Assert.AreEqual(3, permission.remaining); // 免费玩家3次

            // 最终结果验证：
            // - 可复活 (can_revive == true)
            // - 需要看广告 (need_ad == true)
            // - 剩余次数 3 次
        }

        /// <summary>
        /// 测试检查扫荡权限（初始免费玩家状态）
        /// </summary>
        [Test]
        public async Task TestCheckSweepPermission()
        {
            var client = await CreateAuthenticatedClientAsync("扫荡权限测试");
            var vipService = new VipService(client);

            var permission = await vipService.CheckSweepPermissionAsync();
            Assert.IsNotNull(permission);
            Assert.IsTrue(permission.can_sweep);
            Assert.AreEqual(3, permission.remaining); // 免费玩家3次
            Assert.AreEqual(3, permission.total);

            // 最终结果验证：
            // - 可扫荡 (can_sweep == true)
            // - 剩余次数 3 次
            // - 总次数 3 次
        }

        /// <summary>
        /// 测试检查磁铁权限（初始免费玩家状态）
        /// </summary>
        [Test]
        public async Task TestCheckMagnetPermission()
        {
            var client = await CreateAuthenticatedClientAsync("磁铁权限测试");
            var vipService = new VipService(client);

            var permission = await vipService.CheckMagnetPermissionAsync();
            Assert.IsNotNull(permission);
            Assert.IsTrue(permission.can_use);
            Assert.IsTrue(permission.need_ad); // 免费玩家需要广告

            // 最终结果验证：
            // - 可使用磁铁 (can_use == true)
            // - 需要看广告 (need_ad == true)
        }

        /// <summary>
        /// 测试检查掠夺战权限（初始免费玩家状态）
        /// </summary>
        [Test]
        public async Task TestCheckPlunderPermission()
        {
            var client = await CreateAuthenticatedClientAsync("掠夺战权限测试");
            var vipService = new VipService(client);

            var permission = await vipService.CheckPlunderPermissionAsync();
            Assert.IsNotNull(permission);
            Assert.IsTrue(permission.can_plunder_base);
            Assert.IsTrue(permission.can_plunder_ad);
            Assert.AreEqual(1, permission.base_remaining); // 免费玩家1次基础
            Assert.AreEqual(1, permission.ad_remaining); // 免费玩家1次广告

            // 最终结果验证：
            // - 基础掠夺可用 (can_plunder_base == true)
            // - 广告掠夺可用 (can_plunder_ad == true)
            // - 基础剩余 1 次
            // - 广告剩余 1 次
        }

        /// <summary>
        /// 测试检查额外建造队列权限（初始免费玩家状态）
        /// </summary>
        [Test]
        public async Task TestCheckQueuePermission()
        {
            var client = await CreateAuthenticatedClientAsync("建造队列测试");
            var vipService = new VipService(client);

            var permission = await vipService.CheckQueuePermissionAsync();
            Assert.IsNotNull(permission);
            Assert.IsFalse(permission.can_use_extra_queue); // 免费玩家无额外队列

            // 最终结果验证：
            // - 不可使用额外队列 (can_use_extra_queue == false)
        }

        [Test]
        public async Task TestRecordReviveUsage()
        {
            var client = await CreateAuthenticatedClientAsync("记录复活次数测试");
            var vipService = new VipService(client);

            var before = await vipService.CheckRevivePermissionAsync();
            Assert.IsNotNull(before);
            Assert.AreEqual(3, before.remaining);

            var recordResult = await vipService.RecordReviveUsageAsync(true);
            Assert.IsTrue(recordResult.success);

            var after = await vipService.CheckRevivePermissionAsync();
            Assert.IsNotNull(after);
            Assert.AreEqual(2, after.remaining);
        }

        [Test]
        public async Task TestRecordSweepUsage()
        {
            var client = await CreateAuthenticatedClientAsync("记录扫荡次数测试");
            var vipService = new VipService(client);

            var before = await vipService.CheckSweepPermissionAsync();
            Assert.IsNotNull(before);
            Assert.AreEqual(3, before.remaining);

            var recordResult = await vipService.RecordSweepUsageAsync();
            Assert.IsTrue(recordResult.success);

            var after = await vipService.CheckSweepPermissionAsync();
            Assert.IsNotNull(after);
            Assert.AreEqual(2, after.remaining);
        }

        [Test]
        public async Task TestRecordPlunderUsage()
        {
            var client = await CreateAuthenticatedClientAsync("记录掠夺次数测试");
            var vipService = new VipService(client);

            var before = await vipService.CheckPlunderPermissionAsync();
            Assert.IsNotNull(before);
            Assert.AreEqual(1, before.base_remaining);
            Assert.AreEqual(1, before.ad_remaining);

            var baseRecordResult = await vipService.RecordPlunderUsageAsync(false);
            Assert.IsTrue(baseRecordResult.success);

            var afterBase = await vipService.CheckPlunderPermissionAsync();
            Assert.IsNotNull(afterBase);
            Assert.AreEqual(0, afterBase.base_remaining);
            Assert.AreEqual(1, afterBase.ad_remaining);

            var adRecordResult = await vipService.RecordPlunderUsageAsync(true);
            Assert.IsTrue(adRecordResult.success);

            var afterAd = await vipService.CheckPlunderPermissionAsync();
            Assert.IsNotNull(afterAd);
            Assert.AreEqual(0, afterAd.base_remaining);
            Assert.AreEqual(0, afterAd.ad_remaining);
        }

        [Test]
        public async Task TestDebugSimulatePurchase()
        {
            var client = await CreateAuthenticatedClientAsync("模拟IAP购买测试");
            var vipService = new VipService(client);

            var vipResult = await vipService.DebugSimulatePurchaseAsync("vip_monthly");
            Assert.IsNotNull(vipResult);
            Assert.IsTrue(vipResult.success);
            Assert.IsNotNull(vipResult.item_data);
            Assert.AreEqual("item_vip_active", vipResult.item_data.itemId);

            var svipResult = await vipService.DebugSimulatePurchaseAsync("svip_monthly");
            Assert.IsNotNull(svipResult);
            Assert.IsTrue(svipResult.success);
            Assert.IsNotNull(svipResult.item_data);
            Assert.AreEqual("item_svip_active", svipResult.item_data.itemId);

            var status = await vipService.GetVipStatusAsync();
            Assert.IsNotNull(status);
            Assert.IsTrue(status.vip_active);
            Assert.IsTrue(status.svip_active);
        }
    }
}
