using System;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 签到补签请求
    /// </summary>
    [Serializable]
    public sealed class CheckinMakeupRequest
    {
        public int day_index; // 需要补签的天索引
    }
}
