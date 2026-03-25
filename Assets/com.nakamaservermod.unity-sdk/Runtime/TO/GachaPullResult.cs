using System;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 单次抽卡结果
    /// </summary>
    [Serializable]
    public sealed class GachaPullResult
    {
        public string id; // 结果对象ID
        public int count; // 数量
        public string rarity; // 稀有度

        public GachaPullResult()
        {
        }

        public GachaPullResult(string id, int count, string rarity)
        {
            this.id = id;
            this.count = count;
            this.rarity = rarity;
        }
    }
}
