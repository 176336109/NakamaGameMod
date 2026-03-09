using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class DailyCheckinResponse
    {
        public bool success;
        public List<ItemStack> rewards;
        public int streak;
        public string vip_level;
        public string error;
        public int day_id;
        public int cycle_no;
        public bool cycle_reset;
        public string gating_mode;
        public int player_level;
        public int required_level;
        public string status_after;
        public int multiplier;
        public string error_code;

        public DailyCheckinResponse()
        {
        }

        public DailyCheckinResponse(bool success, List<ItemStack> rewards, int streak, string vipLevel, string error)
        {
            this.success = success;
            this.rewards = rewards;
            this.streak = streak;
            vip_level = vipLevel;
            this.error = error;
        }
    }
}
