using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class DailyCheckinResponse
    {
        public bool success;
        public List<ItemStack> rewards;
        public int day_index;
        public string status;
    }
}
