using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 签到补签响应
    /// </summary>
    [Serializable]
    public sealed class CheckinMakeupResponse
    {
        public bool success; // 是否成功
        public List<ItemStack> rewards; // 补签奖励
        public int day_index; // 补签天索引
        public string status; // 补签后状态
    }
}
