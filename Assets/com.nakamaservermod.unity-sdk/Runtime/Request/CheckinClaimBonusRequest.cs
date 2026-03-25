using System;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 领取签到补领奖励请求
    /// </summary>
    [Serializable]
    public sealed class CheckinClaimBonusRequest
    {
        public int day_id; // 目标签到天ID

        public CheckinClaimBonusRequest()
        {
        }

        public CheckinClaimBonusRequest(int dayId)
        {
            day_id = dayId;
        }
    }
}
