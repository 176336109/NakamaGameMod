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
            TestContext.WriteLine("game_config.checkin json: " + (gameConfig.checkin ?? ""));
            TestContext.WriteLine("game_config.gift json: " + (gameConfig.gift ?? ""));
            TestContext.WriteLine("game_config.items json: " + (gameConfig.items ?? ""));
            TestContext.WriteLine("game_config.shop json: " + (gameConfig.shop ?? ""));
            TestContext.WriteLine("game_config.vip json: " + (gameConfig.vip ?? ""));
        }

        [Test]
        public async Task Config_GetGameConfigAsync_VipJsonContainsMonthlyPlans()
        {
            var client = await CreateAuthenticatedClientAsync("配置_VIP配置校验");
            var service = new ConfigService(client);
            var gameConfig = await service.GetGameConfigAsync();
            Assert.IsFalse(string.IsNullOrEmpty(gameConfig.vip));
            Assert.IsTrue(gameConfig.vip.Contains("\"vip_monthly\""));
            Assert.IsTrue(gameConfig.vip.Contains("\"svip_monthly\""));
        }
    }
}
