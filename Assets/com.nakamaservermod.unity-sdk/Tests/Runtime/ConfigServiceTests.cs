using NUnit.Framework;
using System;
using System.Collections.Generic;
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
        public async Task Config_GetByName_Items_Succeeds()
        {
            var client = await CreateAuthenticatedClientAsync("配置_按名称读取Items");
            var service = new ConfigService(client);

            var result = await service.GetByNameAsync("items");
            Assert.IsTrue(result.success, result.error);
            Assert.AreEqual("items", result.name);
            Assert.IsFalse(string.IsNullOrEmpty(result.json));
            Assert.IsFalse(string.IsNullOrEmpty(result.hash));
            Assert.AreEqual("items", result.config_id);
            Assert.IsTrue(result.content_length > 0);
            Assert.IsTrue(service.VerifySignature(result));
            Assert.IsTrue(service.VerifyHash(result.json, result.hash));
            Assert.AreEqual(service.GenerateHash(result.json), result.hash);

            var map = await service.GetByNameAsMapAsync("items");
            Assert.IsNotNull(map);
            Assert.IsTrue(map.Count > 0);
            Assert.IsTrue(map.ContainsKey("gold"));
        }

        [Test]
        public async Task Config_GetAll_SucceedsAndContainsExpectedKeys()
        {
            var client = await CreateAuthenticatedClientAsync("配置_读取全部");
            var service = new ConfigService(client);

            var result = await service.GetAllAsync();
            Assert.IsTrue(result.success, result.error);
            Assert.AreEqual("all", result.name);
            Assert.IsFalse(string.IsNullOrEmpty(result.json));
            Assert.AreEqual("all", result.config_id);
            Assert.IsTrue(service.VerifySignature(result));

            var map = await service.GetAllAsMapAsync();
            Assert.IsNotNull(map);
            Assert.IsTrue(map.ContainsKey("checkin"));
            Assert.IsTrue(map.ContainsKey("gift"));
            Assert.IsTrue(map.ContainsKey("items"));
            Assert.IsTrue(map.ContainsKey("shop"));
            Assert.IsTrue(map.ContainsKey("vip"));
        }

        [Test]
        public async Task Config_GetByName_InvalidName_Fails()
        {
            var client = await CreateAuthenticatedClientAsync("配置_非法名称");
            var service = new ConfigService(client);

            var result = await service.GetByNameAsync("not_exists_json");
            Assert.IsFalse(result.success);
            Assert.AreEqual(10000001, result.error_code);
            Assert.IsFalse(string.IsNullOrEmpty(result.error));
        }

        [Test]
        public async Task Config_VerifySignature_TamperedJson_Fails()
        {
            var client = await CreateAuthenticatedClientAsync("配置_篡改校验");
            var service = new ConfigService(client);
            var result = await service.GetByNameAsync("shop");
            Assert.IsTrue(result.success, result.error);

            var tampered = new ConfigGetResponse
            {
                success = result.success,
                error = result.error,
                error_code = result.error_code,
                error_detail = result.error_detail,
                name = result.name,
                json = (result.json ?? "") + " ",
                hash = result.hash,
                config_id = result.config_id,
                content_length = result.content_length
            };
            Assert.IsFalse(service.VerifySignature(tampered));
        }
    }
}
