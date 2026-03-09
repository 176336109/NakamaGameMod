using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class ItemStack
    {
        public string id;
        public int count;

        public ItemStack()
        {
        }

        public ItemStack(string id, int count)
        {
            this.id = id;
            this.count = count;
        }
    }
}
