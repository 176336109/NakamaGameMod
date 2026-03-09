using System;
using System.Threading;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk
{
    public sealed class CheckinService
    {
        private readonly GameClient _client;

        public CheckinService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public Task<DailyCheckinResponse> DailyCheckinAsync()
        {
            return DailyCheckinAsync(default);
        }

        public Task<DailyCheckinResponse> DailyCheckinAsync(CancellationToken cancellationToken)
        {
            return _client.RpcAsync<DailyCheckinResponse>("daily_checkin", cancellationToken);
        }

        public Task<CheckinGetStateResponse> GetStateAsync()
        {
            return GetStateAsync(default);
        }

        public Task<CheckinGetStateResponse> GetStateAsync(CancellationToken cancellationToken)
        {
            return _client.RpcAsync<CheckinGetStateResponse>("checkin_get_state", cancellationToken);
        }

        public Task<CheckinMakeupResponse> MakeupAsync(int dayId)
        {
            return MakeupAsync(dayId, default);
        }

        public Task<CheckinMakeupResponse> MakeupAsync(int dayId, CancellationToken cancellationToken)
        {
            if (dayId < 1 || dayId > 28)
            {
                throw new ArgumentOutOfRangeException(nameof(dayId), dayId, "dayId must be in range [1, 28].");
            }

            var request = new CheckinMakeupRequest(dayId);
            return _client.RpcAsync<CheckinMakeupRequest, CheckinMakeupResponse>("checkin_makeup", request, cancellationToken);
        }

        public Task<CheckinClaimBonusResponse> ClaimBonusAsync(int dayId)
        {
            return ClaimBonusAsync(dayId, default);
        }

        public Task<CheckinClaimBonusResponse> ClaimBonusAsync(int dayId, CancellationToken cancellationToken)
        {
            if (dayId < 1 || dayId > 28)
            {
                throw new ArgumentOutOfRangeException(nameof(dayId), dayId, "dayId must be in range [1, 28].");
            }

            var request = new CheckinClaimBonusRequest(dayId);
            return _client.RpcAsync<CheckinClaimBonusRequest, CheckinClaimBonusResponse>("checkin_claim_bonus", request, cancellationToken);
        }
    }
}
