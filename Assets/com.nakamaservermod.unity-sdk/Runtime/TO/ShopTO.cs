using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class ShopGetStateResponse
    {
        public bool success;
        public string error;
        
        public ShopSnapshot specialSnapshot;
        public List<ShopItem> fixedItems;
        public List<ShopItem> goldItems;
        public List<ShopItem> crystalItems;
        public Dictionary<string, int> limitProgress;
    }

    [Serializable]
    public sealed class ShopSnapshot
    {
        public string snapshotId;
        public string shopType;
        public List<ShopSlotEntry> slotEntries;
        public long generatedAt;
        public string expireAtStr;
    }

    [Serializable]
    public sealed class ShopSlotEntry
    {
        public int slotIndex;
        public string goodsId;
        public List<InventoryItem> resolvedRewardItems;
        public string resolvedCostType;
        public int resolvedCostValue;
    }

    [Serializable]
    public sealed class ShopItem
    {
        public string goodsId;
        public ShopGoodsConfig config;
        public int progress;
    }

    [Serializable]
    public sealed class ShopGoodsConfig
    {
        public string shopType;
        public string displayMode;
        public string costType;
        public int costValue;
        public string limitType;
        public int limitValue;
        public List<InventoryItem> rewardItems;
        public int weight;
    }

    [Serializable]
    public sealed class ShopRefreshResponse
    {
        public bool success;
        public string error;
        public ShopSnapshot snapshot;
    }

    [Serializable]
    public sealed class ShopBuyResponse
    {
        public bool success;
        public string error;
        public int progress;
        public bool payment_required;
        public IapOrderInfo order;
    }
}
