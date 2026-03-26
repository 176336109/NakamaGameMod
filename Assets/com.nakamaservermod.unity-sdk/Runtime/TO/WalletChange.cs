using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class WalletChange
    {
        public string id;
        public long before;
        public long after;
        public long delta;
    }
}
