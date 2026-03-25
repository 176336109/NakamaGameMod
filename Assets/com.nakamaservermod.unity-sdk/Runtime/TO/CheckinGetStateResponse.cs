using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 签到状态响应
    /// </summary>
    [Serializable]
    public sealed class CheckinGetStateResponse
    {
        public int cycle_no; // 当前签到周期号
        public int current_cycle_day; // 当前周期进行到的天数
        public List<CheckinDayState> days; // 全部天状态
        public ItemStack makeup_cost; // 补签消耗
        public long timestamp; // 服务器时间戳

        public CheckinGetStateResponse()
        {
        }
    }
}
