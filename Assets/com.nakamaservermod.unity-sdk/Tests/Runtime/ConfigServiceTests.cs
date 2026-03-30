using NUnit.Framework;
using System;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk.Tests
{
    [TestFixture]
    public class ConfigServiceTests
    {
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

        [Test]
        public async Task Config_GetGameConfigAsync_Succeeds()
        {
            var client = await CreateAuthenticatedClientAsync("配置_读取全部JSON");
            var service = new ConfigService(client);
            var gameConfig = await service.GetGameConfigAsync();
            Assert.IsNotNull(gameConfig);
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.checkin));
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.gift));
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.items));
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.shop));
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.vip));
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.skillEnhancementItemConfigs));
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.skillEnhancementUpgradeConfigs));
            TestContext.WriteLine("game_config.checkin json: " + (gameConfig.checkin ?? ""));
            TestContext.WriteLine("game_config.gift json: " + (gameConfig.gift ?? ""));
            TestContext.WriteLine("game_config.items json: " + (gameConfig.items ?? ""));
            TestContext.WriteLine("game_config.shop json: " + (gameConfig.shop ?? ""));
            TestContext.WriteLine("game_config.vip json: " + (gameConfig.vip ?? ""));
            TestContext.WriteLine("game_config.skillEnhancementItemConfigs json: " + (gameConfig.skillEnhancementItemConfigs ?? ""));
            TestContext.WriteLine("game_config.skillEnhancementUpgradeConfigs json: " + (gameConfig.skillEnhancementUpgradeConfigs ?? ""));
        }

        [Test]
        public async Task Config_GetGameConfigAsync_VipJsonContainsMonthlyPlans()
        {
            var client = await CreateAuthenticatedClientAsync("配置_VIP配置校验");
            var service = new ConfigService(client);
            var gameConfig = await service.GetGameConfigAsync();
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.vip));
            Assert.IsTrue(gameConfig.vip.Contains("\"monthly_products\""));
            Assert.IsTrue(gameConfig.vip.Contains("\"benefitPlanId\":\"vip\""));
            Assert.IsTrue(gameConfig.vip.Contains("\"benefitPlanId\":\"svip\""));
        }

        [Test]
        public async Task Config_GetSkillEnhancementConfigsAsync_Succeeds()
        {
            var client = await CreateAuthenticatedClientAsync("配置_技能强化配置DTO读取");
            var service = new ConfigService(client);
            var itemConfigs = await service.GetSkillEnhancementItemConfigsAsync();
            var upgradeConfigs = await service.GetSkillEnhancementUpgradeConfigsAsync();
            Assert.IsNotNull(itemConfigs);
            Assert.IsNotNull(itemConfigs.skillEnhancementItemConfigs);
            Assert.IsTrue(itemConfigs.skillEnhancementItemConfigs.Count > 0);
            Assert.IsNotNull(upgradeConfigs);
            Assert.IsNotNull(upgradeConfigs.skillEnhancementUpgradeConfigs);
            Assert.IsTrue(upgradeConfigs.skillEnhancementUpgradeConfigs.Count > 0);
        }
    }
}
