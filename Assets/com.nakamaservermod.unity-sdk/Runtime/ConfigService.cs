using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk
{
    public sealed class ConfigService
    {
        private readonly GameClient _client;

        public ConfigService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public async Task<GameConfigJson> GetGameConfigAsync(CancellationToken cancellationToken = default)
        {
            var response = await FetchAllConfigAsync(cancellationToken);
            if (!response.success)
            {
                throw new InvalidOperationException(response.error ?? "config_get failed");
            }
            EnsureValidSignature(response);
            if (response.game_config == null)
            {
                throw new InvalidOperationException("game_config missing.");
            }
            return response.game_config;
        }

        private Task<ConfigGetResponse> FetchAllConfigAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<ConfigGetResponse>("config_get", cancellationToken);
        }

        private bool VerifySignature(ConfigGetResponse response)
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

        private void EnsureValidSignature(ConfigGetResponse response)
        {
            if (!VerifySignature(response))
            {
                throw new InvalidOperationException("Config signature verification failed.");
            }
        }

        private string GenerateHash(string json)
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
    }
}
