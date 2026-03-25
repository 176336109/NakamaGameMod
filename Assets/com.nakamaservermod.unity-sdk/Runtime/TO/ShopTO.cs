using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 商店状态响应
    /// </summary>
    [Serializable]
    public sealed class ShopGetStateResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        
        public ShopSnapshot specialSnapshot; // 特惠商店快照
        public List<ShopItem> fixedItems; // 固定商品列表
        public List<ShopItem> goldItems; // 金币商店列表
        public List<ShopItem> crystalItems; // 水晶商店列表
        public Dictionary<string, int> limitProgress; // 商品限购进度
    }

    /// <summary>
    /// 商店快照
    /// </summary>
    [Serializable]
    public sealed class ShopSnapshot
    {
        public string snapshotId; // 快照ID
        public string shopType; // 商店类型
        public List<ShopSlotEntry> slotEntries; // 槽位商品
        public long generatedAt; // 生成时间戳
        public string expireAtStr; // 过期时间字符串
    }

    /// <summary>
    /// 商店槽位项
    /// </summary>
    [Serializable]
    public sealed class ShopSlotEntry
    {
        public int slotIndex; // 槽位索引
        public string goodsId; // 商品ID
        public List<InventoryItem> resolvedRewardItems; // 解析后的奖励
        public string resolvedCostType; // 解析后的支付类型
        public int resolvedCostValue; // 解析后的支付数值
    }

    /// <summary>
    /// 商店商品项
    /// </summary>
    [Serializable]
    public sealed class ShopItem
    {
        public string goodsId; // 商品ID
        public ShopGoodsConfig config; // 商品配置
        public int progress; // 当前限购进度
    }

    /// <summary>
    /// 商店商品配置
    /// </summary>
    [Serializable]
    public sealed class ShopGoodsConfig
    {
        public string shopType; // 商店分类
        public string displayMode; // 展示模式
        public string costType; // 支付类型
        public int costValue; // 支付数值
        public string limitType; // 限购类型
        public int limitValue; // 限购值
        public List<InventoryItem> rewardItems; // 奖励内容
        public int weight; // 权重
    }

    /// <summary>
    /// 商店刷新响应
    /// </summary>
    [Serializable]
    public sealed class ShopRefreshResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public ShopSnapshot snapshot; // 刷新后快照
    }

    /// <summary>
    /// 商店购买响应
    /// </summary>
    [Serializable]
    public sealed class ShopBuyResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public int progress; // 限购进度
        public bool payment_required; // 是否需要先支付
        public IapOrderInfo order; // IAP订单信息
    }
}
