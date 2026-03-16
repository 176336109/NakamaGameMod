using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinGetStateResponse
    {
        public int cycle_no;
        public int current_cycle_day;
        public List<CheckinDayState> days;
        public ItemStack makeup_cost;
        public long timestamp;

        public CheckinGetStateResponse()
        {
        }
    }
}
