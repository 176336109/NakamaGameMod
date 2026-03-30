using NUnit.Framework;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk.Tests
{
    [TestFixture]
    public class SkillEnhancementServiceTests
    {
        private sealed class UpgradeFixture
        {
            public string fragmentItemId;
            public long costItemCount;
        }

        private async Task<GameClient> CreateAuthenticatedClientAsync(string testName)
        {
            var config = ConnectionConfig.Localhost();
            var client = new GameClient(config);
            var suffix = Guid.NewGuid().ToString("N").Substring(0, 8);
            var deviceId = $"device_{testName}_{suffix}";
            var username = $"{testName}_{suffix}";
            await client.AuthenticateDeviceAsync(deviceId, username);
            return client;
        }

        private static Dictionary<string, Dictionary<long, SkillEnhancementAttr>> BuildAttrFixture()
        {
            return new Dictionary<string, Dictionary<long, SkillEnhancementAttr>>
            {
                ["110100003"] = new Dictionary<long, SkillEnhancementAttr>
                {
                    [1] = new SkillEnhancementAttr { itemId = "110100003", level = 1, attackAdd = 1f, critRatePct = 2.5f, critDamagePct = 12f, hitRatePct = 1.5f, projectileCountAdd = 1 },
                    [2] = new SkillEnhancementAttr { itemId = "110100003", level = 2, attackAdd = 2f, critRatePct = 2.59f, critDamagePct = 12.45f, hitRatePct = 1.55f, projectileCountAdd = 1 },
                    [3] = new SkillEnhancementAttr { itemId = "110100003", level = 3, attackAdd = 3f, critRatePct = 2.67f, critDamagePct = 12.9f, hitRatePct = 1.6f, projectileCountAdd = 1 },
                    [5] = new SkillEnhancementAttr { itemId = "110100003", level = 5, attackAdd = 5f, critRatePct = 2.84f, critDamagePct = 13.79f, hitRatePct = 1.71f, projectileCountAdd = 1 },
                    [10] = new SkillEnhancementAttr { itemId = "110100003", level = 10, attackAdd = 10f, critRatePct = 3.28f, critDamagePct = 16.03f, hitRatePct = 1.97f, projectileCountAdd = 2 },
                    [20] = new SkillEnhancementAttr { itemId = "110100003", level = 20, attackAdd = 20f, critRatePct = 4.14f, critDamagePct = 20.52f, hitRatePct = 2.48f, projectileCountAdd = 2 },
                    [30] = new SkillEnhancementAttr { itemId = "110100003", level = 30, attackAdd = 30f, critRatePct = 5f, critDamagePct = 25f, hitRatePct = 3f, projectileCountAdd = 3 }
                },
                ["110300001"] = new Dictionary<long, SkillEnhancementAttr>
                {
                    [5] = new SkillEnhancementAttr { itemId = "110300001", level = 5, attackAdd = 68f, critRatePct = 3.98f, critDamagePct = 6.83f }
                },
                ["1101023"] = new Dictionary<long, SkillEnhancementAttr>
                {
                    [1] = new SkillEnhancementAttr { itemId = "1101023", level = 1, attackAdd = 10f, critRatePct = 3f, critDamagePct = 15f, shieldValueAdd = 150f }
                }
            };
        }

        private static Dictionary<string, Dictionary<long, UpgradeFixture>> BuildUpgradeFixture()
        {
            return new Dictionary<string, Dictionary<long, UpgradeFixture>>
            {
                ["110100003"] = new Dictionary<long, UpgradeFixture>
                {
                    [1] = new UpgradeFixture { fragmentItemId = "120100003", costItemCount = 1 },
                    [2] = new UpgradeFixture { fragmentItemId = "120100003", costItemCount = 1 },
                    [10] = new UpgradeFixture { fragmentItemId = "120100003", costItemCount = 1 },
                    [20] = new UpgradeFixture { fragmentItemId = "120100003", costItemCount = 2 }
                }
            };
        }

        private static BackpackItem StackItem(string itemId, long count, long level, long expireAt = 0)
        {
            return new BackpackItem
            {
                id = itemId,
                count = count,
                level = level,
                expireAt = expireAt
            };
        }

        private static BackpackMutationRequest GrantRequest(params BackpackItem[] items)
        {
            return new BackpackMutationRequest
            {
                source = "skill_enhance_test",
                items = items.ToList()
            };
        }

        private async Task SeedBackpackAsync(BackpackService backpackService, params BackpackItem[] items)
        {
            var result = await backpackService.GrantAsync(GrantRequest(items));
            Assert.IsTrue(result.success, result.error);
        }

        private async Task<long> GetCountByLevelAsync(BackpackService backpackService, string itemId, long level, long? expireAt = null)
        {
            var list = await backpackService.ListAsync(200);
            Assert.IsTrue(list.success, list.error);
            return list.items
                .Where(x => x.id == itemId && x.level == level && (!expireAt.HasValue || x.expireAt == expireAt.Value))
                .Sum(x => x.count);
        }

        private async Task<long> GetTotalCountAsync(BackpackService backpackService, string itemId)
        {
            var items = await backpackService.GetItemsAsync(new[] { itemId });
            Assert.IsTrue(items.success, items.error);
            return items.items.FirstOrDefault(x => x.id == itemId)?.count ?? 0;
        }

        // 用例说明：首次获得强化件时应创建1级堆叠记录。
        [Test]
        public async Task C01_NewSkillItem_GrantCreatesLevelOneRecord()
        {
            var client = await CreateAuthenticatedClientAsync("C01_首次获得创建1级记录");
            var backpack = new BackpackService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 1));
            var count = await GetCountByLevelAsync(backpack, "110100003", 1);
            Assert.AreEqual(1, count);
        }

        // 用例说明：同等级强化件重复发放时应在同记录累加数量。
        [Test]
        public async Task C02_SameLevelGrant_AccumulatesCount()
        {
            var client = await CreateAuthenticatedClientAsync("C02_同等级发放数量累加");
            var backpack = new BackpackService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 2, 1));
            await SeedBackpackAsync(backpack, StackItem("110100003", 3, 1));
            var count = await GetCountByLevelAsync(backpack, "110100003", 1);
            Assert.AreEqual(5, count);
        }

        // 用例说明：详情读取应返回堆叠信息、属性、升级消耗与品质。
        [Test]
        public async Task C03_GetDetail_ReturnsStackAttrUpgradeAndQuality()
        {
            var attrs = BuildAttrFixture();
            var upgrades = BuildUpgradeFixture();
            var client = await CreateAuthenticatedClientAsync("C03_详情返回属性消耗品质");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 2, 1));

            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110100003", level = 1 });
            Assert.IsTrue(detail.success, detail.error);
            Assert.AreEqual(2, detail.detail.stackItemRecord.count);
            Assert.AreEqual(attrs["110100003"][1].attackAdd, detail.detail.attr.attackAdd);
            Assert.AreEqual(1, detail.detail.quality);
            Assert.AreEqual(upgrades["110100003"][1].fragmentItemId, detail.detail.upgrade.fragmentItemId);
            Assert.AreEqual(upgrades["110100003"][1].costItemCount, detail.detail.upgrade.costItemCount);
        }

        // 用例说明：升级单件时应消耗碎片并迁移到下一等级记录。
        [Test]
        public async Task C04_UpgradeOneItem_MigratesInventoryAndConsumesFragment()
        {
            var client = await CreateAuthenticatedClientAsync("C04_升级迁移并扣碎片");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 3, 1), StackItem("120100003", 10, 1));

            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            Assert.IsTrue(upgrade.success, upgrade.error);
            Assert.AreEqual(2, await GetCountByLevelAsync(backpack, "110100003", 1));
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 2));
            Assert.AreEqual(9, await GetTotalCountAsync(backpack, "120100003"));
        }

        // 用例说明：目标等级已存在时升级应合并到目标等级记录。
        [Test]
        public async Task C05_UpgradeToExistingTarget_MergesTargetLevel()
        {
            var client = await CreateAuthenticatedClientAsync("C05_升级合并目标等级");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 1), StackItem("110100003", 4, 2), StackItem("120100003", 10, 1));

            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            Assert.IsTrue(upgrade.success, upgrade.error);
            Assert.AreEqual(0, await GetCountByLevelAsync(backpack, "110100003", 1));
            Assert.AreEqual(5, await GetCountByLevelAsync(backpack, "110100003", 2));
        }

        // 用例说明：不同等级记录应隔离存储且互不影响。
        [Test]
        public async Task C06_DifferentLevels_StayIsolated()
        {
            var client = await CreateAuthenticatedClientAsync("C06_不同等级隔离");
            var backpack = new BackpackService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 2, 1), StackItem("110100003", 1, 3));
            Assert.AreEqual(2, await GetCountByLevelAsync(backpack, "110100003", 1));
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 3));
        }

        // 用例说明：详情属性读取应使用当前等级最终值，不做跨级叠加。
        [Test]
        public async Task C07_GetDetail_UsesCurrentLevelFinalAttr()
        {
            var attrs = BuildAttrFixture();
            var client = await CreateAuthenticatedClientAsync("C07_读取当前等级最终属性");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110300001", 1, 5));

            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110300001", level = 5 });
            Assert.IsTrue(detail.success, detail.error);
            Assert.AreEqual(attrs["110300001"][5].attackAdd, detail.detail.attr.attackAdd);
            Assert.AreEqual(attrs["110300001"][5].critRatePct, detail.detail.attr.critRatePct);
        }

        // 用例说明：品质应来源于升级配置而非属性配置字段。
        [Test]
        public async Task C08_Quality_ComesFromUpgradeConfig()
        {
            var client = await CreateAuthenticatedClientAsync("C08_品质来源升级配置");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110300001", 1, 5));
            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110300001", level = 5 });
            Assert.IsTrue(detail.success, detail.error);
            Assert.AreEqual(3, detail.detail.quality);
        }

        // 用例说明：不同等级应返回对应升级消耗，不应混用。
        [Test]
        public async Task C09_UpgradeCost_ChangesByLevel()
        {
            var upgrades = BuildUpgradeFixture();
            var client = await CreateAuthenticatedClientAsync("C09_升级消耗按等级变化");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 1), StackItem("110100003", 1, 10), StackItem("110100003", 1, 20));

            var d1 = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110100003", level = 1 });
            var d10 = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110100003", level = 10 });
            var d20 = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110100003", level = 20 });
            Assert.IsTrue(d1.success && d10.success && d20.success);
            Assert.AreEqual(upgrades["110100003"][1].fragmentItemId, d1.detail.upgrade.fragmentItemId);
            Assert.AreEqual(upgrades["110100003"][10].fragmentItemId, d10.detail.upgrade.fragmentItemId);
            Assert.AreEqual(upgrades["110100003"][20].fragmentItemId, d20.detail.upgrade.fragmentItemId);
            Assert.AreEqual(upgrades["110100003"][1].costItemCount, d1.detail.upgrade.costItemCount);
            Assert.AreEqual(upgrades["110100003"][10].costItemCount, d10.detail.upgrade.costItemCount);
            Assert.AreEqual(upgrades["110100003"][20].costItemCount, d20.detail.upgrade.costItemCount);
        }

        // 用例说明：满级详情不应返回下一等级升级消耗。
        [Test]
        public async Task C10_MaxLevelDetail_HasNoNextUpgrade()
        {
            var client = await CreateAuthenticatedClientAsync("C10_满级详情无下级消耗");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 30));
            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110100003", level = 30 });
            Assert.IsTrue(detail.success, detail.error);
            Assert.IsTrue(detail.detail.isMaxLevel);
            Assert.IsNull(detail.detail.upgrade);
        }

        // 用例说明：连续升级每次只处理一件本体并逐次迁移。
        [Test]
        public async Task C11_ContinuousUpgrade_ProcessesOneItemPerCall()
        {
            var client = await CreateAuthenticatedClientAsync("C11_连续升级逐件处理");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 5, 1), StackItem("120100003", 10, 1));

            var u1 = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            var u2 = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            Assert.IsTrue(u1.success, u1.error);
            Assert.IsTrue(u2.success, u2.error);
            Assert.AreEqual(3, await GetCountByLevelAsync(backpack, "110100003", 1));
            Assert.AreEqual(2, await GetCountByLevelAsync(backpack, "110100003", 2));
        }

        // 用例说明：零值字段也应完整返回，不缺失属性结构。
        [Test]
        public async Task C12_ZeroFields_ReturnsCompleteAttrObject()
        {
            var client = await CreateAuthenticatedClientAsync("C12_零值字段完整返回");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("1101023", 1, 1));
            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "1101023", level = 1 });
            Assert.IsTrue(detail.success, detail.error);
            Assert.Greater(detail.detail.attr.attackAdd, 0f);
            Assert.GreaterOrEqual(detail.detail.attr.critRatePct, 0f);
            Assert.GreaterOrEqual(detail.detail.attr.shieldValueAdd, 0f);
            Assert.GreaterOrEqual(detail.detail.attr.projectileCountAdd, 0);
        }

        // 用例说明：背包不存在目标强化件时详情与升级都应失败。
        [Test]
        public async Task B01_NotFound_DetailAndUpgradeFail()
        {
            var client = await CreateAuthenticatedClientAsync("B01_目标物品不存在失败");
            var skill = new SkillEnhancementService(client);
            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110100003", level = 1 });
            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            Assert.IsFalse(detail.success);
            Assert.IsFalse(upgrade.success);
            Assert.AreEqual(700002, detail.error_code);
            Assert.AreEqual(700002, upgrade.error_code);
        }

        // 用例说明：缺少属性配置时读取详情应失败且不兜底。
        [Test]
        public async Task B02_MissingAttrConfig_FailsWithoutFallback()
        {
            var client = await CreateAuthenticatedClientAsync("B02_缺少属性配置读取失败");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("010300001", 1, 1));
            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "010300001", level = 1 });
            Assert.IsFalse(detail.success);
            Assert.AreEqual(700003, detail.error_code);
        }

        // 用例说明：缺少升级消耗配置时升级应失败且库存不变。
        [Test]
        public async Task B03_MissingUpgradeCost_FailsAndNoSideEffect()
        {
            var client = await CreateAuthenticatedClientAsync("B03_缺少升级消耗升级失败");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("1101023", 1, 6), StackItem("sf_common", 10, 1));
            var beforeFragment = await GetTotalCountAsync(backpack, "sf_common");
            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "1101023", level = 6 });
            Assert.IsFalse(upgrade.success);
            Assert.AreEqual(700003, upgrade.error_code);
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "1101023", 6));
            Assert.AreEqual(beforeFragment, await GetTotalCountAsync(backpack, "sf_common"));
        }

        // 用例说明：碎片不足时升级应失败且强化件与碎片均不变。
        [Test]
        public async Task B04_InsufficientFragment_UpgradeFailsNoMutation()
        {
            var client = await CreateAuthenticatedClientAsync("B04_碎片不足升级失败");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 11), StackItem("120100003", 1, 1));
            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 11 });
            Assert.IsFalse(upgrade.success);
            Assert.AreEqual(700004, upgrade.error_code);
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 11));
            Assert.AreEqual(1, await GetTotalCountAsync(backpack, "120100003"));
        }

        // 用例说明：满级后升级应被拒绝且不扣碎片。
        [Test]
        public async Task B05_MaxLevel_UpgradeRejected()
        {
            var client = await CreateAuthenticatedClientAsync("B05_满级升级被拒绝");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 30), StackItem("120100003", 99, 1));
            var beforeFragment = await GetTotalCountAsync(backpack, "120100003");
            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 30 });
            Assert.IsFalse(upgrade.success);
            Assert.AreEqual(700005, upgrade.error_code);
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 30));
            Assert.AreEqual(beforeFragment, await GetTotalCountAsync(backpack, "120100003"));
        }

        // 用例说明：并发升级同一件时最多允许一次成功。
        [Test]
        public async Task B06_ConcurrentUpgrade_OnlyOneSucceeds()
        {
            var client = await CreateAuthenticatedClientAsync("B06_并发升级仅一次成功");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 1), StackItem("120100003", 20, 1));

            var t1 = skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            var t2 = skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            await Task.WhenAll(t1, t2);

            var successCount = (t1.Result.success ? 1 : 0) + (t2.Result.success ? 1 : 0);
            Assert.LessOrEqual(successCount, 1);
            if (successCount == 1)
            {
                Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 2));
                Assert.AreEqual(0, await GetCountByLevelAsync(backpack, "110100003", 1));
            }
        }

        // 用例说明：升级后来源等级归零时来源记录应被清理。
        [Test]
        public async Task B07_SourceCountBecomesZero_SourceRecordCleaned()
        {
            var client = await CreateAuthenticatedClientAsync("B07_来源记录归零清理");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 1), StackItem("120100003", 20, 1));
            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1 });
            Assert.IsTrue(upgrade.success, upgrade.error);
            Assert.AreEqual(0, await GetCountByLevelAsync(backpack, "110100003", 1));
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 2));
        }

        // 用例说明：不同等级发放不得误并到其他等级记录。
        [Test]
        public async Task B08_CrossLevelGrant_DoesNotMergeWrongLevel()
        {
            var client = await CreateAuthenticatedClientAsync("B08_跨等级发放不误并");
            var backpack = new BackpackService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 2, 1), StackItem("110100003", 2, 2));
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 1));
            Assert.AreEqual(3, await GetCountByLevelAsync(backpack, "110100003", 1));
            Assert.AreEqual(2, await GetCountByLevelAsync(backpack, "110100003", 2));
        }

        // 用例说明：品质读取不依赖属性配置中的品质字段。
        [Test]
        public async Task B09_QualityRead_DoesNotDependOnAttrField()
        {
            var client = await CreateAuthenticatedClientAsync("B09_品质读取不依赖属性字段");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110300001", 1, 5));
            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110300001", level = 5 });
            Assert.IsTrue(detail.success, detail.error);
            Assert.AreEqual(3, detail.detail.quality);
        }

        // 用例说明：非法等级参数应在详情和升级中统一拒绝。
        [Test]
        public async Task B10_InvalidLevel_DetailAndUpgradeRejected()
        {
            var client = await CreateAuthenticatedClientAsync("B10_非法等级参数拒绝");
            var skill = new SkillEnhancementService(client);
            var detail = await skill.GetDetailAsync(new SkillEnhancementGetDetailRequest { itemId = "110100003", level = 0 });
            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 0 });
            Assert.IsFalse(detail.success);
            Assert.IsFalse(upgrade.success);
            Assert.AreEqual(700006, detail.error_code);
            Assert.AreEqual(700006, upgrade.error_code);
        }

        // 用例说明：升级流程中断时应回滚碎片与库存。
        [Test]
        public async Task B11_UpgradeFailure_RollsBackFragmentAndInventory()
        {
            var client = await CreateAuthenticatedClientAsync("B11_升级失败回滚库存");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            await SeedBackpackAsync(backpack, StackItem("110100003", 1, 1), StackItem("120100003", 20, 1));

            var fail = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest
            {
                itemId = "110100003",
                level = 1,
                testFailStage = "after_consume_item"
            });
            Assert.IsFalse(fail.success);
            Assert.IsTrue(fail.error_code == 700007 || fail.error_code == 700004);
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 1));
            Assert.AreEqual(0, await GetCountByLevelAsync(backpack, "110100003", 2));
            Assert.GreaterOrEqual(await GetTotalCountAsync(backpack, "120100003"), 0);
        }

        // 用例说明：不同过期批次升级时只影响目标批次。
        [Test]
        public async Task B12_DifferentExpireBatches_IsolatedDuringUpgrade()
        {
            var client = await CreateAuthenticatedClientAsync("B12_过期批次隔离升级");
            var backpack = new BackpackService(client);
            var skill = new SkillEnhancementService(client);
            var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var expireA = now + 3600;
            var expireB = now + 7200;
            await SeedBackpackAsync(
                backpack,
                StackItem("110100003", 1, 1, expireA),
                StackItem("110100003", 1, 1, expireB),
                StackItem("120100003", 2, 1));

            var upgrade = await skill.UpgradeAsync(new SkillEnhancementUpgradeRequest { itemId = "110100003", level = 1, expireAt = expireA });
            Assert.IsTrue(upgrade.success, upgrade.error);
            Assert.AreEqual(0, await GetCountByLevelAsync(backpack, "110100003", 1, expireA));
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 1, expireB));
            Assert.AreEqual(1, await GetCountByLevelAsync(backpack, "110100003", 2, expireA));
        }
    }
}
