using System;
using System.Threading;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk
{
    public sealed class GiftService
    {
        private readonly GameClient _client;

        public GiftService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public Task<GiftGetStateResponse> GetStateAsync(string activityId = null, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(activityId))
            {
                return _client.RpcAsync<GiftGetStateResponse>("gift_get_state", cancellationToken);
            }

            return _client.RpcAsync<GiftGetStateRequest, GiftGetStateResponse>(
                "gift_get_state",
                new GiftGetStateRequest { activityId = activityId },
                cancellationToken);
        }

        public Task<GiftCreateOrderResponse> CreateOrderAsync(string packId, string activityId = null, string provider = "mock", CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(packId))
            {
                throw new ArgumentException("packId is required.", nameof(packId));
            }

            return _client.RpcAsync<GiftCreateOrderRequest, GiftCreateOrderResponse>(
                "gift_create_order",
                new GiftCreateOrderRequest
                {
                    packId = packId,
                    activityId = activityId,
                    provider = provider
                },
                cancellationToken);
        }

        public Task<GiftPayCallbackResponse> PayCallbackAsync(string orderId, string userId, string packId, string activityId = null, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(orderId))
            {
                throw new ArgumentException("orderId is required.", nameof(orderId));
            }
            if (string.IsNullOrEmpty(userId))
            {
                throw new ArgumentException("userId is required.", nameof(userId));
            }
            if (string.IsNullOrEmpty(packId))
            {
                throw new ArgumentException("packId is required.", nameof(packId));
            }

            return _client.RpcAsync<GiftPayCallbackRequest, GiftPayCallbackResponse>(
                "gift_pay_callback",
                new GiftPayCallbackRequest
                {
                    order_id = orderId,
                    user_id = userId,
                    pack_id = packId,
                    activityId = activityId
                },
                cancellationToken);
        }

        public Task<GiftClaimDayRewardResponse> ClaimDayRewardAsync(string packId, int dayIndex, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(packId))
            {
                throw new ArgumentException("packId is required.", nameof(packId));
            }
            if (dayIndex <= 0)
            {
                throw new ArgumentException("dayIndex must be greater than 0.", nameof(dayIndex));
            }

            return _client.RpcAsync<GiftClaimDayRewardRequest, GiftClaimDayRewardResponse>(
                "gift_claim_day_reward",
                new GiftClaimDayRewardRequest
                {
                    packId = packId,
                    dayIndex = dayIndex
                },
                cancellationToken);
        }

        public Task<SuccessResponse> DebugUnlockFirstRechargeAsync(bool unlocked = true, CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<GiftDebugUnlockRequest, SuccessResponse>(
                "gift_debug_unlock_first_recharge",
                new GiftDebugUnlockRequest { unlocked = unlocked },
                cancellationToken);
        }
    }
}
