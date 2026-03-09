using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinMakeupResponse
    {
        public bool success;
        public int day_id;
        public List<ItemStack> rewards;
        public ItemStack cost;
        public string gating_mode;
        public int player_level;
        public int required_level;
        public int multiplier;
        public int cycle_no;
        public string error;
        public string error_code;

        public CheckinMakeupResponse()
        {
        }

        public CheckinMakeupResponse(
            bool success,
            int dayId,
            List<ItemStack> rewards,
            ItemStack cost,
            string gatingMode,
            int playerLevel,
            int requiredLevel,
            int multiplier,
            int cycleNo,
            string error,
            string errorCode)
        {
            this.success = success;
            day_id = dayId;
            this.rewards = rewards;
            this.cost = cost;
            gating_mode = gatingMode;
            player_level = playerLevel;
            required_level = requiredLevel;
            this.multiplier = multiplier;
            cycle_no = cycleNo;
            this.error = error;
            error_code = errorCode;
        }
    }
}
