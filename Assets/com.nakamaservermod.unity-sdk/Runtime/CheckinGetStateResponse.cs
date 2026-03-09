using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinGetStateResponse
    {
        public bool success;
        public string cycle_start_date;
        public int cycle_no;
        public string today;
        public int today_day_id;
        public string gating_mode;
        public int player_level;
        public ItemStack makeup_cost;
        public List<CheckinDayState> days;
        public string error;
        public string error_code;

        public CheckinGetStateResponse()
        {
        }

        public CheckinGetStateResponse(
            bool success,
            string cycleStartDate,
            int cycleNo,
            string today,
            int todayDayId,
            string gatingMode,
            int playerLevel,
            ItemStack makeupCost,
            List<CheckinDayState> days,
            string error,
            string errorCode)
        {
            this.success = success;
            cycle_start_date = cycleStartDate;
            cycle_no = cycleNo;
            this.today = today;
            today_day_id = todayDayId;
            gating_mode = gatingMode;
            player_level = playerLevel;
            makeup_cost = makeupCost;
            this.days = days;
            this.error = error;
            error_code = errorCode;
        }
    }
}
