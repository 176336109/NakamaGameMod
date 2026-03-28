using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class CheckinConfigDto
    {
        public List<CheckinDayRewardDto> rewards;
        public CheckinCostDto makeup_cost;
    }

    [Serializable]
    public class CheckinDayRewardDto
    {
        public int dayIndex;
        public List<CheckinRewardItemDto> rewardItems;
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
