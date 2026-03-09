using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class DebugAddItemsRequest
    {
        public List<ItemStack> items;

        public DebugAddItemsRequest()
        {
        }

        public DebugAddItemsRequest(List<ItemStack> items)
        {
            this.items = items;
        }
    }
}
