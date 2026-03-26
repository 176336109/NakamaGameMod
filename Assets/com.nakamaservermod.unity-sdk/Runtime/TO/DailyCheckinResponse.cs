using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 每日签到响应
    /// </summary>
    [Serializable]
    public sealed class DailyCheckinResponse
    {
        public bool success; // 是否签到成功
        public List<ItemStack> rewards; // 签到奖励
        public int day_index; // 签到天索引
        public string status; // 签到后状态
        public List<WalletChange> wallet_changes; // 钱包变更
    }
}
