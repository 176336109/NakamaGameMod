using System;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 商店购买请求
    /// </summary>
    [Serializable]
    public sealed class ShopBuyRequest
    {
        public string goodsId; // 商品ID
    }
}
