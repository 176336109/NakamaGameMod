using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class SkillEnhancementStackItemRecord
    {
        public string itemId;
        public long level;
        public long count;
        public bool hasExpireAt;
        public long expireAt;
    }

    [Serializable]
    public class SkillEnhancementAttr
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
    public class SkillEnhancementUpgradeCost
    {
        public long level;
        public string fragmentItemId;
        public long costItemCount;
    }

    [Serializable]
    public class SkillEnhancementDetail
    {
        public SkillEnhancementStackItemRecord stackItemRecord;
        public long quality;
        public SkillEnhancementAttr attr;
        public SkillEnhancementUpgradeCost upgrade;
        public long maxLevel;
        public bool isMaxLevel;
    }

    [Serializable]
    public class SkillEnhancementMigration
    {
        public long fromLevel;
        public long toLevel;
        public string fragmentItemId;
        public long fragmentCost;
    }

    [Serializable]
    public class SkillEnhancementResponse
    {
        public bool success;
        public string error;
        public long error_code;
        public RpcErrorDetail error_detail;
        public SkillEnhancementDetail detail;
        public SkillEnhancementMigration migration;
    }
}
