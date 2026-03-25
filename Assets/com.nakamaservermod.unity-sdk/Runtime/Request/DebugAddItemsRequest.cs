using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 调试加道具请求
    /// </summary>
    [Serializable]
    public sealed class DebugAddItemsRequest
    {
        public List<ItemStack> items; // 需要添加的道具列表

        public DebugAddItemsRequest()
        {
        }

        public DebugAddItemsRequest(List<ItemStack> items)
        {
            this.items = items;
        }
    }
}
