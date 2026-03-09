using System;
using System.Threading;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk
{
    public sealed class GachaService
    {
        private readonly GameClient _client;

        public GachaService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public Task<GachaPullResponse> GachaPullAsync(string bannerId, int count)
        {
            return GachaPullAsync(bannerId, count, default);
        }

        public Task<GachaPullResponse> GachaPullAsync(string bannerId, int count, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(bannerId))
            {
                throw new ArgumentException("bannerId is required.", nameof(bannerId));
            }

            if (count <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(count), count, "count must be > 0.");
            }

            var request = new GachaPullRequest(bannerId, count);
            return _client.RpcAsync<GachaPullRequest, GachaPullResponse>("gacha_pull", request, cancellationToken);
        }
    }
}
