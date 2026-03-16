using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk
{
    public sealed class ShopService
    {
        private readonly GameClient _client;

        public ShopService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public Task<ShopGetStateResponse> GetStateAsync()
        {
            return GetStateAsync(default);
        }

        public Task<ShopGetStateResponse> GetStateAsync(CancellationToken cancellationToken)
        {
            return _client.RpcAsync<ShopGetStateResponse>("shop_get_state", cancellationToken);
        }

        public Task<ShopRefreshResponse> RefreshAsync()
        {
            return RefreshAsync(default);
        }

        public Task<ShopRefreshResponse> RefreshAsync(CancellationToken cancellationToken)
        {
            return _client.RpcAsync<ShopRefreshResponse>("shop_refresh", cancellationToken);
        }

        public Task<ShopBuyResponse> BuyAsync(string goodsId)
        {
            return BuyAsync(goodsId, default);
        }

        public Task<ShopBuyResponse> BuyAsync(string goodsId, CancellationToken cancellationToken)
        {
            if (string.IsNullOrEmpty(goodsId))
            {
                throw new ArgumentException("GoodsId cannot be null or empty.", nameof(goodsId));
            }

            var request = new ShopBuyRequest { goodsId = goodsId };
            return _client.RpcAsync<ShopBuyRequest, ShopBuyResponse>("shop_buy", request, cancellationToken);
        }
    }
}
