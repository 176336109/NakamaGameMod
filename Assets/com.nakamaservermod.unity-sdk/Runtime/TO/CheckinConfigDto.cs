using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class CheckinConfigDto
    {
        public Dictionary<string, List<CheckinRewardItemDto>> rewards;
        public CheckinCostDto makeup_cost;
    }

    [Serializable]
    public class CheckinRewardItemDto
    {
        public string item_id;
        public int count;
    }

    [Serializable]
    public class CheckinCostDto
    {
        public string item_id;
        public int count;
    }
}
