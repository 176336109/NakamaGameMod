using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class GachaPullResult
    {
        public string id;
        public int count;
        public string rarity;

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
