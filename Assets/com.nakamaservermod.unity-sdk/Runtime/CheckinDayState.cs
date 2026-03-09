using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class CheckinDayState
    {
        public int day_id;
        public string status;
        public string reward_item;
        public int reward_num;
        public int required_level;
        public int player_level;
        public string gating_mode;
        public int claim_multiplier;
        public bool can_makeup;
        public bool can_claim_bonus;

        public CheckinDayState()
        {
        }

        public CheckinDayState(
            int dayId,
            string status,
            string rewardItem,
            int rewardNum,
            int requiredLevel,
            int playerLevel,
            string gatingMode,
            int claimMultiplier,
            bool canMakeup,
            bool canClaimBonus)
        {
            day_id = dayId;
            this.status = status;
            reward_item = rewardItem;
            reward_num = rewardNum;
            required_level = requiredLevel;
            player_level = playerLevel;
            gating_mode = gatingMode;
            claim_multiplier = claimMultiplier;
            can_makeup = canMakeup;
            can_claim_bonus = canClaimBonus;
        }
    }
}
