using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Nakama.TinyJson;

namespace NakamaServerMod.UnitySdk
{
    public sealed class ConfigService
    {
        private readonly GameClient _client;

        public ConfigService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public Task<ConfigGetResponse> GetAllAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<ConfigGetResponse>("config_get", cancellationToken);
        }

        public Task<ConfigGetResponse> GetByNameAsync(string name, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                throw new ArgumentException("name is required.", nameof(name));
            }

            return _client.RpcAsync<ConfigGetRequest, ConfigGetResponse>(
                "config_get",
                new ConfigGetRequest { name = name },
                cancellationToken);
        }

        public async Task<Dictionary<string, object>> GetAllAsMapAsync(CancellationToken cancellationToken = default)
        {
            var response = await GetAllAsync(cancellationToken);
            if (!response.success)
            {
                throw new InvalidOperationException(response.error ?? "config_get failed");
            }
            EnsureValidSignature(response);
            return string.IsNullOrEmpty(response.json) ? new Dictionary<string, object>() : response.json.FromJson<Dictionary<string, object>>();
        }

        public async Task<Dictionary<string, object>> GetByNameAsMapAsync(string name, CancellationToken cancellationToken = default)
        {
            var response = await GetByNameAsync(name, cancellationToken);
            if (!response.success)
            {
                throw new InvalidOperationException(response.error ?? "config_get failed");
            }
            EnsureValidSignature(response);
            return string.IsNullOrEmpty(response.json) ? new Dictionary<string, object>() : response.json.FromJson<Dictionary<string, object>>();
        }

        public bool VerifySignature(ConfigGetResponse response)
        {
            if (response == null || !response.success)
            {
                return false;
            }
            if (string.IsNullOrEmpty(response.hash))
            {
                return false;
            }
            var json = response.json ?? string.Empty;
            if (response.content_length != Encoding.UTF8.GetByteCount(json))
            {
                return false;
            }
            var digest = GenerateHash(json);
            return string.Equals(digest, response.hash, StringComparison.OrdinalIgnoreCase);
        }

        public void EnsureValidSignature(ConfigGetResponse response)
        {
            if (!VerifySignature(response))
            {
                throw new InvalidOperationException("Config signature verification failed.");
            }
        }

        public string GenerateHash(string json)
        {
            const long mod = 2147483647;
            long hash = 0;
            var bytes = Encoding.UTF8.GetBytes(json ?? string.Empty);
            for (var i = 0; i < bytes.Length; i++)
            {
                hash = (hash * 131 + bytes[i]) % mod;
            }
            return hash.ToString("x8");
        }

        public bool VerifyHash(string json, string expectedHash)
        {
            if (string.IsNullOrEmpty(expectedHash))
            {
                return false;
            }
            var actual = GenerateHash(json);
            return string.Equals(actual, expectedHash, StringComparison.OrdinalIgnoreCase);
        }
    }
}
