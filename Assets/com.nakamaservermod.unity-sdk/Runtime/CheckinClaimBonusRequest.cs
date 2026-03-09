using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinClaimBonusRequest
    {
        public int day_id;

        public CheckinClaimBonusRequest()
        {
        }

        public CheckinClaimBonusRequest(int dayId)
        {
            day_id = dayId;
        }
    }
}
