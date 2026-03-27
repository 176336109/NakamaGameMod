using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class GiftGetStateResponse
    {
        public bool success;
        public string error;
        public bool firstRechargeUnlocked;
        public List<GiftPackRuntimeState> packs;
        public Dictionary<string, GiftPackPurchaseState> purchaseStates;
        public Dictionary<string, FirstRechargeStageState> firstRechargeStageStates;
        public List<GiftPackPurchaseState> purchaseStateList;
        public List<FirstRechargeStageState> firstRechargeStageStateList;
    }

    [Serializable]
    public sealed class GiftPackRuntimeState
    {
        public string packId;
        public string packType;
        public string packName;
        public string priceCurrency;
        public int priceAmount;
        public string limitType;
        public int limitValue;
        public string activityId;
        public GiftActiveTimeRange activeTimeRange;
        public List<InventoryItem> immediateRewardItems;
        public List<FirstRecharge30DayReward> firstRecharge30DayRewards;
        public int progress;
        public string cycleKey;
        public bool canBuy;
        public bool visible;
    }

    [Serializable]
    public sealed class GiftPackPurchaseState
    {
        public string packId;
        public string packType;
        public string limitType;
        public int progress;
        public string cycleKey;
        public long lastBuyAt;
        public string lastOrderId;
    }

    [Serializable]
    public sealed class GiftActiveTimeRange
    {
        public long startAt;
        public long endAt;
    }

    [Serializable]
    public sealed class FirstRecharge30DayReward
    {
        public int dayIndex;
        public List<InventoryItem> rewardItems;
    }

    [Serializable]
    public sealed class FirstRechargeStageState
    {
        public string packId;
        public long purchaseAt;
        public List<FirstRecharge30DayReward> dayRewards;
        public List<FirstRechargeDayState> dayStates;
    }

    [Serializable]
    public sealed class FirstRechargeDayState
    {
        public int dayIndex;
        public long unlockAt;
        public string status;
        public long claimedAt;
    }

    [Serializable]
    public sealed class GiftCreateOrderResponse
    {
        public bool success;
        public string error;
        public bool payment_required;
        public string packId;
        public IapOrderInfo order;
    }

    [Serializable]
    public sealed class GiftPayCallbackResponse
    {
        public bool success;
        public string error;
        public bool idempotent;
        public string orderId;
        public string packId;
        public int progress;
    }

    [Serializable]
    public sealed class GiftClaimDayRewardResponse
    {
        public bool success;
        public string error;
        public string packId;
        public int dayIndex;
        public long claimedAt;
    }
}
