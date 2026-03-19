using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using NUnit.Framework;
using NakamaServerMod.UnitySdk;

namespace NakamaServerMod.UnitySdk.Tests
{
    [TestFixture]
    public class GameLogicTests
    {
        // 辅助方法：创建客户端并以随机 DeviceID 强制注册新账号，确保环境干净
        private async Task<GameClient> CreateAuthenticatedClientAsync()
        {
            var config = ConnectionConfig.Localhost();
            var client = new GameClient(config);
            var deviceId = Guid.NewGuid().ToString();
            var username = "test_user_" + Guid.NewGuid().ToString("N").Substring(0, 8);
            
            await client.AuthenticateDeviceAsync(deviceId, username);
            return client;
        }

        [Test]
        public async Task Auth_Should_Create_Session()
        {
            var client = await CreateAuthenticatedClientAsync();
            
            Assert.IsTrue(client.HasSession, "应该成功获取 Session");
            Assert.IsNotNull(client.Session.UserId, "UserId 不应为空");
        }

        [Test]
        public async Task Checkin_Flow_Should_Succeed()
        {
            var client = await CreateAuthenticatedClientAsync();
            var checkinService = new CheckinService(client);

            // 1. 获取签到全局状态
            var state = await checkinService.GetStateAsync();
            Assert.IsNotNull(state);
            Assert.Greater(state.cycle_no, 0);
            Assert.IsNotNull(state.days);

            // 2. 执行今日签到
            var checkinResp = await checkinService.DailyCheckinAsync();
            Assert.IsTrue(checkinResp.success, "每日签到应该成功");
            Assert.IsNotNull(checkinResp.rewards, "请求成功后应当返回奖励");
            Assert.Greater(checkinResp.day_index, 0, "签到天数不应为0");
        }

        [Test]
        public async Task Gacha_Pull_Should_Succeed_After_Adding_Currency()
        {
            var client = await CreateAuthenticatedClientAsync();

            // 1. 先通过 Debug 接口增加代币，以免报 Insufficient currency 错误
            var inventoryService = new BackpackService(client);
            var itemsToAdd = new List<ItemStack>
            {
                new ItemStack { id = "gem", count = 10000 },
                new ItemStack { id = "gold", count = 10000 }
            };
            
            var addResp = await inventoryService.DebugAddItemsAsync(itemsToAdd);
            Assert.IsTrue(addResp.success, "发放测试道具应该成功");

            // 2. 执行十连抽
            var gachaService = new GachaService(client);
            // 注意: bannerId 必须与服务端 gacha_config 中配置的卡池一致，例如 "standard_banner"
            var pullResp = await gachaService.GachaPullAsync("standard_banner", 10);

            Assert.IsNotNull(pullResp);
            Assert.IsNotNull(pullResp.results, "应返回抽卡结果数组");
            Assert.AreEqual(10, pullResp.results.Count, "十连抽应返回10项掉落（合并前基础次数）或者符合掉落堆叠规律");
            Assert.IsNotNull(pullResp.pity_state, "应返回保底状态更新");
        }
    }
}
