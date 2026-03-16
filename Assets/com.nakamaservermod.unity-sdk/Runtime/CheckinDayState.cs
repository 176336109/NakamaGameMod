using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinDayState
    {
        public int day_index;
        public string status; // "locked", "missed", "claimable", "signed", "makeup_signed"
        public List<ItemStack> rewards;

        public CheckinDayState()
        {
        }
    }
}
