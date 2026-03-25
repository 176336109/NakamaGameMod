using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 单日签到状态
    /// </summary>
    [Serializable]
    public sealed class CheckinDayState
    {
        public int day_index; // 天序号
        public string status; // 状态值（unsigned/signed/makeup_signed/locked）
        public List<ItemStack> rewards; // 当日奖励列表

        public CheckinDayState()
        {
        }
    }
}
