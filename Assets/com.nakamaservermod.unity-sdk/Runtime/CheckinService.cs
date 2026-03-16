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

        public Task<DailyCheckinResponse> DailyCheckinAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<DailyCheckinResponse>("daily_checkin", cancellationToken);
        }

        public Task<CheckinGetStateResponse> GetStateAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<CheckinGetStateResponse>("checkin_get_state", cancellationToken);
        }

        public Task<CheckinMakeupResponse> MakeupAsync(int dayIndex, CancellationToken cancellationToken = default)
        {
            if (dayIndex < 1 || dayIndex > 7)
            {
                throw new ArgumentOutOfRangeException(nameof(dayIndex), dayIndex, "dayIndex must be in range [1, 7].");
            }

            var request = new CheckinMakeupRequest { day_index = dayIndex };
            return _client.RpcAsync<CheckinMakeupRequest, CheckinMakeupResponse>("checkin_makeup", request, cancellationToken);
        }
    }
}
