using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class ShopConfigDto
    {
        public ShopCostDto refresh_cost;
        public Dictionary<string, ShopGoodsConfigDto> goods;
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
        public string shopType;
        public string displayMode;
        public int weight;
        public string costType;
        public int costValue;
        public string limitType;
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
