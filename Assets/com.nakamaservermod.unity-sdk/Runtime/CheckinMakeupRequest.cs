using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinMakeupRequest
    {
        public int day_id;

        public CheckinMakeupRequest()
        {
        }

        public CheckinMakeupRequest(int dayId)
        {
            day_id = dayId;
        }
    }
}
