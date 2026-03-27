using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class GiftConfigDto
    {
        public Dictionary<string, GiftPackConfigDto> packs;
    }

    [Serializable]
    public class GiftPackConfigDto
    {
        public string packId;
        public string packType;
        public string packName;
        public string priceCurrency;
        public int priceAmount;
        public string limitType;
        public int limitValue;
        public string activityId;
        public GiftActiveTimeRangeDto activeTimeRange;
        public List<GiftRewardItemDto> immediateRewardItems;
        public List<GiftDailyRewardSlotDto> firstRecharge30DayRewards;
    }

    [Serializable]
    public class GiftActiveTimeRangeDto
    {
        public long startAt;
        public long endAt;
    }

    [Serializable]
    public class GiftRewardItemDto
    {
        public string id;
        public int count;
    }

    [Serializable]
    public class GiftDailyRewardSlotDto
    {
        public int dayIndex;
        public List<GiftRewardItemDto> rewardItems;
    }
}
