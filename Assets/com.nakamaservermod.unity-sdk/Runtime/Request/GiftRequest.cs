using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class GiftCreateOrderRequest
    {
        public string packId;
        public string activityId;
        public string provider;
    }

    [Serializable]
    public sealed class GiftPayCallbackRequest
    {
        public string order_id;
        public string user_id;
        public string pack_id;
        public string activityId;
    }

    [Serializable]
    public sealed class GiftClaimDayRewardRequest
    {
        public string packId;
        public int dayIndex;
    }

    [Serializable]
    public sealed class GiftGetStateRequest
    {
        public string activityId;
    }

    [Serializable]
    public sealed class GiftDebugUnlockRequest
    {
        public bool unlocked = true;
    }
}
