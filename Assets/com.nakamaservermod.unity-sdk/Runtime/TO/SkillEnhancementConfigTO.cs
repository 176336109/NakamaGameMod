using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class SkillEnhancementItemConfigDto
    {
        public string itemId;
        public long level;
        public float attackAdd;
        public float critRatePct;
        public float critDamagePct;
        public float hitRatePct;
        public float skillCooldownAdd;
        public long projectileCountAdd;
        public float dodgePct;
        public float executeThresholdPct;
        public float lifeStealPct;
        public float shieldValueAdd;
        public float auraDamageAdd;
        public float auraDurationAdd;
        public float auraRadiusAdd;
        public float buffDurationAdd;
        public long summonCountAdd;
        public float summonAttackAdd;
        public float summonDurationAdd;
    }

    [Serializable]
    public class SkillEnhancementItemConfigListDto
    {
        public List<SkillEnhancementItemConfigDto> skillEnhancementItemConfigs;
    }

    [Serializable]
    public class SkillEnhancementUpgradeCostConfigDto
    {
        public long level;
        public string fragmentItemId;
        public long costItemCount;
    }

    [Serializable]
    public class SkillEnhancementUpgradeConfigDto
    {
        public string itemId;
        public long quality;
        public List<SkillEnhancementUpgradeCostConfigDto> upgradeCosts;
    }

    [Serializable]
    public class SkillEnhancementUpgradeConfigListDto
    {
        public List<SkillEnhancementUpgradeConfigDto> skillEnhancementUpgradeConfigs;
    }
}
