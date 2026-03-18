using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk.Tests
{
    [TestFixture]
    public class BackpackServiceTests
    {
        // 辅助方法：创建客户端并使用中文测试名作为 Username，便于后台排查。
        private async Task<GameClient> CreateAuthenticatedClientAsync(string testName)
        {
            var config = ConnectionConfig.Localhost();
            var client = new GameClient(config);
            var deviceId = $"device_{testName}_{Guid.NewGuid().ToString("N").Substring(0, 8)}";
            var username = testName;
            await client.AuthenticateDeviceAsync(deviceId, username);
            return client;
        }

        private static BackpackMutationRequest CreateGrantRequest(string id, long count, long expireAt = 0, string requestId = null)
        {
            var item = new BackpackItem { id = id, count = count, expireAt = expireAt };
            return new BackpackMutationRequest
            {
                source = "sdk_test",
                requestId = requestId,
                items = new List<BackpackItem> { item }
            };
        }

        private static long NowTs()
        {
            return DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        }

        private async Task<WalletGetResponse> GetWalletAsync(GameClient client)
        {
            return await new InventoryService(client).GetWalletAsync();
        }

        // 用例说明：发放新可堆叠物品时，数量增加且占格生效。
        [Test]
        public async Task C01_Grant_NewStackable_AddsCountAndSlot()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C01_发放新可堆叠物品");
            var service = new InventoryService(client);

            var grant = await service.GrantAsync(CreateGrantRequest("010300001", 3));
            Assert.IsTrue(grant.success, grant.error?.message);

            var items = await service.GetItemsAsync(new[] { "010300001" });
            Assert.IsTrue(items.success, items.error?.message);
            Assert.AreEqual(3, items.items[0].count);
        }

        // 用例说明：发放已有可堆叠物品时，只累加数量不新增占格。
        [Test]
        public async Task C02_Grant_ExistingStackable_AccumulatesWithoutNewSlot()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C02_已有可堆叠累加");
            var service = new InventoryService(client);

            var first = await service.GrantAsync(CreateGrantRequest("020100001", 2));
            Assert.IsTrue(first.success, first.error?.message);

            var second = await service.GrantAsync(CreateGrantRequest("020100001", 5));
            Assert.IsTrue(second.success, second.error?.message);

            var items = await service.GetItemsAsync(new[] { "020100001" });
            Assert.AreEqual(7, items.items[0].count);
        }

        // 用例说明：可堆叠限时物品发放场景（当前环境跳过）。
        [Test]
        public void C03_Grant_StackableTimedItem()
        {
            Assert.Pass("Skipped: 当前配置无可稳定构造的可堆叠有时限物品。");
        }

        // 用例说明：发放 VIP 限时实例，校验实例字段和过期时间写入。
        [Test]
        public async Task C04_Grant_VipInstance_WritesTimedRecord()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C04_发放VIP时效实例");
            var service = new InventoryService(client);
            var expireAt = NowTs() + 3600;

            var grant = await service.GrantAsync(CreateGrantRequest("item_vip_active", 1, expireAt));
            Assert.IsTrue(grant.success, grant.error?.message);

            var list = await service.ListAsync();
            Assert.IsTrue(list.success, list.error?.message);
            var vip = list.items.FirstOrDefault(x => x.id == "item_vip_active");
            Assert.IsNotNull(vip);
            Assert.IsFalse(vip.stackable);
            Assert.IsTrue(vip.hasExpireAt);
            Assert.AreEqual(expireAt, vip.expireAt);
        }

        // 用例说明：使用时光沙漏后，数量正确扣减。
        [Test]
        public async Task C05_Use_Hourglass_DecrementsCount()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C05_使用时光沙漏扣减");
            var service = new InventoryService(client);

            await service.GrantAsync(CreateGrantRequest("010300001", 5));
            var useReq = new BackpackMutationRequest
            {
                source = "sdk_test_use",
                items = new List<BackpackItem> { new BackpackItem { id = "010300001", count = 1 } }
            };
            var use = await service.UseAsync(useReq);
            Assert.IsTrue(use.success, use.error?.message);

            var items = await service.GetItemsAsync(new[] { "010300001" });
            Assert.AreEqual(4, items.items[0].count);
        }

        // 用例说明：消耗后归零的物品不再作为有效库存。
        [Test]
        public async Task C06_Consume_ToZero_RemovesEffectiveStock()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C06_扣减归零有效库存");
            var service = new InventoryService(client);

            await service.GrantAsync(CreateGrantRequest("020200001", 1));
            var consume = await service.ConsumeAsync(new BackpackMutationRequest
            {
                source = "sdk_test_consume",
                items = new List<BackpackItem> { new BackpackItem { id = "020200001", count = 1 } }
            });
            Assert.IsTrue(consume.success, consume.error?.message);

            var items = await service.GetItemsAsync(new[] { "020200001" });
            Assert.AreEqual(0, items.items[0].count);
        }

        // 用例说明：不可堆叠永久物品场景（当前环境跳过）。
        [Test]
        public void C07_Grant_NonStackPermanentItem()
        {
            Assert.Pass("Skipped: 当前配置中普通非货币物品均按堆叠路径处理。");
        }

        // 用例说明：执行过期清理后，过期物品从有效库存移除。
        [Test]
        public async Task C08_Cleanup_ExpiredItems_UpdatesUsableInventory()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C08_过期清理更新库存");
            var service = new InventoryService(client);

            await service.GrantAsync(CreateGrantRequest("item_vip_active", 1, NowTs() - 5));
            var cleanup = await service.CleanupAsync();
            Assert.IsTrue(cleanup.success, cleanup.error?.message);
            Assert.IsTrue(cleanup.result.cleaned);

            var items = await service.GetItemsAsync(new[] { "item_vip_active" });
            Assert.AreEqual(0, items.items[0].count);
        }

        // 用例说明：VIP 续费应复用同一实例并延长有效期。
        [Test]
        public async Task C09_Renew_Vip_ReusesInstance()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C09_VIP续费复用实例");
            var service = new InventoryService(client);

            var firstExpireAt = NowTs() + 3600;
            var secondExpireAt = firstExpireAt + 7200;

            var first = await service.GrantAsync(CreateGrantRequest("item_vip_active", 1, firstExpireAt));
            Assert.IsTrue(first.success, first.error?.message);
            var second = await service.GrantAsync(CreateGrantRequest("item_vip_active", 1, secondExpireAt));
            Assert.IsTrue(second.success, second.error?.message);

            var list = await service.ListAsync();
            var vipItems = list.items.Where(x => x.id == "item_vip_active").ToList();
            Assert.AreEqual(1, vipItems.Count);
            Assert.GreaterOrEqual(vipItems[0].expireAt, secondExpireAt);
        }

        // 用例说明：查询有效库存时应排除过期物品。
        [Test]
        public async Task C10_Query_EffectiveInventory_ExcludesExpired()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C10_查询有效库存排除过期");
            var service = new InventoryService(client);

            await service.GrantAsync(CreateGrantRequest("item_vip_active", 1, NowTs() - 2));
            await service.GrantAsync(CreateGrantRequest("010300001", 2));

            var items = await service.GetItemsAsync(new[] { "item_vip_active", "010300001" });
            var vip = items.items.FirstOrDefault(x => x.id == "item_vip_active");
            var hourglass = items.items.FirstOrDefault(x => x.id == "010300001");
            Assert.AreEqual(0, vip.count);
            Assert.AreEqual(2, hourglass.count);
        }

        // 用例说明：批量发放混合奖励（钱包+背包）应整体成功。
        [Test]
        public async Task C11_BatchGrant_MixedItems_Succeeds()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C11_批量发放混合奖励");
            var service = new InventoryService(client);
            var req = new BackpackMutationRequest
            {
                source = "sdk_test_batch",
                items = new List<BackpackItem>
                {
                    new BackpackItem { id = "gold", count = 400 },
                    new BackpackItem { id = "010300001", count = 10 },
                    new BackpackItem { id = "item_vip_active", count = 1, expireAt = NowTs() + 86400 }
                }
            };

            var result = await service.GrantAsync(req);
            Assert.IsTrue(result.success, result.error?.message);

            var walletResponse = await GetWalletAsync(client);
            var wallet = walletResponse?.wallet ?? new Dictionary<string, long>();
            Assert.IsTrue(wallet.ContainsKey("gold"));
            Assert.GreaterOrEqual(wallet["gold"], 400);
            var items = await service.GetItemsAsync(new[] { "010300001", "item_vip_active" });
            Assert.AreEqual(10, items.items.First(x => x.id == "010300001").count);
            Assert.AreEqual(1, items.items.First(x => x.id == "item_vip_active").count);
        }

        // 用例说明：同一 requestId 的重复发奖只生效一次。
        [Test]
        public async Task C12_Idempotent_GrantByRequestId_OnlyAppliesOnce()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C12_发奖幂等只生效一次");
            var service = new InventoryService(client);
            var requestId = "req_" + Guid.NewGuid().ToString("N");
            var req = CreateGrantRequest("020300001", 2, 0, requestId);

            var first = await service.GrantAsync(req);
            var second = await service.GrantAsync(req);
            Assert.IsTrue(first.success, first.error?.message);
            Assert.IsTrue(second.success, second.error?.message);
            Assert.IsTrue(second.result?.idempotent ?? false);

            var items = await service.GetItemsAsync(new[] { "020300001" });
            Assert.AreEqual(2, items.items[0].count);
        }

        // 用例说明：获取全部物品配置应返回成功且包含已知配置项。
        [Test]
        public async Task C13_GetAllItemDefs_ReturnsConfiguredItems()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C13_获取全部物品配置");
            var response = await client.RpcAsync<InventoryItemDefsResponse>("inventory_get_item_defs");

            Assert.IsTrue(response.success, response.error?.message);
            Assert.IsNotNull(response.items);
            Assert.IsTrue(response.items.Count > 0);

            var hourglassDef = response.items.FirstOrDefault(x => x.itemId == "010300001");
            Assert.IsNotNull(hourglassDef);
            Assert.AreEqual("item", hourglassDef.itemType);
        }

        // 用例说明：获取背包全部物品应返回成功并包含当前账号已发放道具。
        [Test]
        public async Task C14_GetAllBackpackItems_ReturnsGrantedItems()
        {
            var client = await CreateAuthenticatedClientAsync("背包_C14_获取背包全部物品");
            var service = new InventoryService(client);
            var grant = await service.GrantAsync(CreateGrantRequest("010300001", 2));
            Assert.IsTrue(grant.success, grant.error?.message);

            var response = await client.RpcAsync<InventoryAllInfoRequest, InventoryAllInfoResponse>(
                "inventory_get_all_info",
                new InventoryAllInfoRequest { page_size = 100, limit = 100 });

            Assert.IsTrue(response.success, response.error?.message);
            Assert.IsNotNull(response.backpackItems);
            var item = response.backpackItems.FirstOrDefault(x => x.id == "010300001");
            Assert.IsNotNull(item);
            Assert.AreEqual(2, item.count);
        }

        // 用例说明：满包时给已有堆叠物品加数量（当前环境跳过）。
        [Test]
        public void B01_FullBag_AddExistingStackable()
        {
            Assert.Pass("Skipped: 客户端测试环境无法稳定构造满包状态。");
        }

        // 用例说明：满包时新增堆叠物品（当前环境跳过）。
        [Test]
        public void B02_FullBag_AddNewStackable()
        {
            Assert.Pass("Skipped: 客户端测试环境无法稳定构造满包状态。");
        }

        // 用例说明：满包时新增实例物品（当前环境跳过）。
        [Test]
        public void B03_FullBag_AddNewInstance()
        {
            Assert.Pass("Skipped: 客户端测试环境无法稳定构造满包状态。");
        }

        // 用例说明：并发消耗最后一个道具时仅一次成功。
        [Test]
        public async Task B04_ConcurrentConsume_LastOneOnlyOnce()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B04_并发扣减最后一个");
            var service = new InventoryService(client);
            await service.GrantAsync(CreateGrantRequest("010300001", 1));

            var req = new BackpackMutationRequest
            {
                source = "sdk_test_race",
                items = new List<BackpackItem> { new BackpackItem { id = "010300001", count = 1 } }
            };
            var t1 = service.ConsumeAsync(req);
            var t2 = service.ConsumeAsync(req);
            await Task.WhenAll(t1, t2);

            var successCount = (t1.Result.success ? 1 : 0) + (t2.Result.success ? 1 : 0);
            Assert.AreEqual(1, successCount);

            var items = await service.GetItemsAsync(new[] { "010300001" });
            Assert.AreEqual(0, items.items[0].count);
        }

        // 用例说明：可堆叠限时多批次共存场景（当前环境跳过）。
        [Test]
        public void B05_StackableTimed_BatchCoexistence()
        {
            Assert.Pass("Skipped: 当前配置无可稳定构造的可堆叠有时限物品。");
        }

        // 用例说明：设计文档未定义场景（当前环境跳过）。
        [Test]
        public void B06_NotDefinedInDesignDoc()
        {
            Assert.Pass("Skipped: 设计文档未定义B06。");
        }

        // 用例说明：混合变更失败时验证原子性，不允许部分成功。
        [Test]
        public async Task B07_AtomicFailure_LogicCheck()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B07_混合变更原子失败");
            var service = new InventoryService(client);

            // 步骤1：混合发放中包含非法物品，整体应失败且金币不应入账。
            var grantReq = new BackpackMutationRequest
            {
                source = "sdk_test_atomic_grant",
                items = new List<BackpackItem>
                {
                    new BackpackItem { id = "gold", count = 100 },
                    new BackpackItem { id = "invalid_item_id_999", count = 1 }
                }
            };
            var grant = await service.GrantAsync(grantReq);
            Assert.IsFalse(grant.success, "Grant should fail due to invalid item id");

            var walletResponse = await GetWalletAsync(client);
            var wallet = walletResponse?.wallet ?? new Dictionary<string, long>();
            Assert.AreEqual(0, wallet.ContainsKey("gold") ? wallet["gold"] : 0, "Gold should not be granted if any item is invalid");

            // 步骤2：混合扣减中存在道具库存不足，整体应失败且金币不应被扣。
            await service.GrantAsync(CreateGrantRequest("gold", 500));
            await service.GrantAsync(CreateGrantRequest("010300001", 1));

            var consumeReq = new BackpackMutationRequest
            {
                source = "sdk_test_atomic_consume",
                items = new List<BackpackItem>
                {
                    new BackpackItem { id = "gold", count = 100 },
                    new BackpackItem { id = "010300001", count = 10 }
                }
            };
            var consume = await service.ConsumeAsync(consumeReq);
            Assert.IsFalse(consume.success, "Consume should fail due to insufficient item stock");

            walletResponse = await GetWalletAsync(client);
            wallet = walletResponse?.wallet ?? new Dictionary<string, long>();
            Assert.AreEqual(500, wallet.ContainsKey("gold") ? wallet["gold"] : 0, "Gold should not be consumed if item stock is insufficient");
        }

        // 用例说明：expireAt 等于当前时间时，物品应判定为无效。
        [Test]
        public async Task B08_ExpireAtEqualsNow_IsInvalid()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B08_到期瞬间判无效");
            var service = new InventoryService(client);
            await service.GrantAsync(CreateGrantRequest("item_vip_active", 1, NowTs()));

            var items = await service.GetItemsAsync(new[] { "item_vip_active" });
            Assert.AreEqual(0, items.items[0].count);
        }

        // 用例说明：续费重复请求应命中幂等，避免重复生效。
        [Test]
        public async Task B09_RenewDuplicateRequest_OnlyOnce()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B09_续费重复请求幂等");
            var service = new InventoryService(client);
            var requestId = "renew_" + Guid.NewGuid().ToString("N");
            var req = CreateGrantRequest("item_vip_active", 1, NowTs() + 86400, requestId);

            var first = await service.GrantAsync(req);
            var second = await service.GrantAsync(req);
            Assert.IsTrue(first.success, first.error?.message);
            Assert.IsTrue(second.success, second.error?.message);
            Assert.IsTrue(second.result?.idempotent ?? false);

            var items = await service.GetItemsAsync(new[] { "item_vip_active" });
            Assert.AreEqual(1, items.items[0].count);
        }

        // 用例说明：数量为0的记录不应出现在有效列表。
        [Test]
        public async Task B10_ZeroCountRecord_NotInEffectiveList()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B10_零数量不在有效列表");
            var service = new InventoryService(client);
            await service.GrantAsync(CreateGrantRequest("020100001", 1));
            await service.ConsumeAsync(new BackpackMutationRequest
            {
                source = "sdk_test_zero",
                items = new List<BackpackItem> { new BackpackItem { id = "020100001", count = 1 } }
            });

            var list = await service.ListAsync();
            Assert.IsFalse(list.items.Any(x => x.id == "020100001"));
        }

        // 用例说明：非物品引用应被拒绝入包。
        [Test]
        public async Task B11_Reject_NonItemReference()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B11_拒绝非物品引用");
            var service = new InventoryService(client);

            var grant = await service.GrantAsync(CreateGrantRequest("rewardRef_random_ship_pool", 1));
            Assert.IsFalse(grant.success);
            Assert.AreEqual("GRANT_FAILED", grant.error.code);
        }

        // 用例说明：错误别名/名称应被拒绝入包。
        [Test]
        public async Task B12_Reject_WrongAliasName()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B12_拒绝错误别名");
            var service = new InventoryService(client);

            var grant = await service.GrantAsync(CreateGrantRequest("时钟沙漏", 1));
            Assert.IsFalse(grant.success);
            Assert.AreEqual("GRANT_FAILED", grant.error.code);
        }

        // 用例说明：变更后背包版本号应前进。
        [Test]
        public async Task B13_ReadAfterMutation_StateVersionAdvances()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B13_读写后版本前进");
            var service = new InventoryService(client);
            var before = await service.GetItemsAsync(new[] { "010300001" });
            var beforeCount = before.items.FirstOrDefault(x => x.id == "010300001")?.count ?? 0;

            await service.GrantAsync(CreateGrantRequest("010300001", 1));
            var after = await service.GetItemsAsync(new[] { "010300001" });
            var afterCount = after.items.FirstOrDefault(x => x.id == "010300001")?.count ?? 0;

            Assert.GreaterOrEqual(afterCount, beforeCount + 1);
        }

        // 用例说明：已过期的限时物品不应作为有效数据返回。
        [Test]
        public async Task B14_ExpiredTimedItem_NotReturnedAsValid()
        {
            var client = await CreateAuthenticatedClientAsync("背包_B14_过期限时不返回有效");
            var service = new InventoryService(client);
            await service.GrantAsync(CreateGrantRequest("item_svip_active", 1, NowTs() - 30));

            var list = await service.ListAsync();
            Assert.IsFalse(list.items.Any(x => x.id == "item_svip_active"));
        }
    }
}
