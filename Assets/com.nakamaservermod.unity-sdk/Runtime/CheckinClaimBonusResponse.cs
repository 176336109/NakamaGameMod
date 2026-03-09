using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinClaimBonusResponse
    {
        public bool success;
        public int day_id;
        public List<ItemStack> rewards;
        public string gating_mode;
        public int player_level;
        public int required_level;
        public int cycle_no;
        public string error;
        public string error_code;

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
