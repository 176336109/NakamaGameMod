using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class GiftConfigDto
    {
        public List<GiftPackConfigDto> packs;
    }

    public enum GiftPackType
    {
        Unknown = -1,
        All = 0,
        daily = 1,
        activity = 2,
        first_recharge = 3
    }

    public enum GiftLimitType
    {
        Unknown = -1,
        All = 0,
        daily = 1,
        activity_once = 2,
        permanent = 3
    }

    [Serializable]
    public class GiftPackConfigDto
    {
        public string packId;
        public GiftPackType packType;
        public string packName;
        public string priceCurrency;
        public int priceAmount;
        public GiftLimitType limitType;
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
