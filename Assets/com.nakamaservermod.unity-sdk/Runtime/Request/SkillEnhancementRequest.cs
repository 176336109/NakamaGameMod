using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class SkillEnhancementGetDetailRequest
    {
        public string itemId;
        public long level;
        public long expireAt;
    }

    [Serializable]
    public class SkillEnhancementUpgradeRequest
    {
        public string itemId;
        public long level;
        public long expireAt;
        public string testFailStage;
    }
}
