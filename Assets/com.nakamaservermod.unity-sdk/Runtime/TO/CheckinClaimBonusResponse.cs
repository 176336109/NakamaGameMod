using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 签到补领响应
    /// </summary>
    [Serializable]
    public sealed class CheckinClaimBonusResponse
    {
        public bool success; // 是否成功
        public int day_id; // 补领天ID
        public List<ItemStack> rewards; // 奖励列表
        public string gating_mode; // 开放条件模式
        public int player_level; // 玩家当前等级
        public int required_level; // 所需等级
        public int cycle_no; // 周期编号
        public string error; // 错误信息
        public string error_code; // 错误码

        public CheckinClaimBonusResponse()
        {
        }

        public CheckinClaimBonusResponse(
            bool success,
            int dayId,
            List<ItemStack> rewards,
            string gatingMode,
            int playerLevel,
            int requiredLevel,
            int cycleNo,
            string error,
            string errorCode)
        {
            this.success = success;
            day_id = dayId;
            this.rewards = rewards;
            gating_mode = gatingMode;
            player_level = playerLevel;
            required_level = requiredLevel;
            cycle_no = cycleNo;
            this.error = error;
            error_code = errorCode;
        }
    }
}
