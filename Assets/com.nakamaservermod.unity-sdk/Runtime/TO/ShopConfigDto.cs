using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class ShopConfigDto
    {
        public ShopCostDto refresh_cost;
        public List<ShopGoodsConfigDto> goods;
    }

    public enum ShopType
    {
        Unknown = 0,
        special = 1,
        crystal = 2,
        gold = 3
    }

    public enum ShopDisplayMode
    {
        Unknown = 0,
        random = 1,
        fix = 2,
        iap = 3,
        exchange = 4
    }

    public enum ShopCostType
    {
        Unknown = 0,
        gold = 1,
        gem = 2,
        rmb = 3
    }

    public enum ShopLimitType
    {
        Unknown = 0,
        per_refresh = 1,
        weekly = 2,
        permanent = 3,
        none = 4,
        daily = 5
    }

    [Serializable]
    public class ShopCostDto
    {
        public string item_id;
        public int count;
    }

    [Serializable]
    public class ShopGoodsConfigDto
    {
        public string goodsId;
        public ShopType shopType;
        public ShopDisplayMode displayMode;
        public int weight;
        public ShopCostType costType;
        public int costValue;
        public ShopLimitType limitType;
        public int limitValue;
        public List<ShopRewardItemDto> rewardItems;
    }

    [Serializable]
    public class ShopRewardItemDto
    {
        public string id;
        public int count;
    }
}
