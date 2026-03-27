using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class VipConfigDto
    {
        public List<VipBenefitPlanDto> benefit_plans;
        public List<VipMonthlyProductDto> monthly_products;
    }

    [Serializable]
    public class VipBenefitPlanDto
    {
        public string benefitPlanId;
        public List<VipRewardItemDto> immediateItems;
        public List<VipRewardItemDto> dailyItems;
        public VipPrivilegesDto privileges;
    }

    [Serializable]
    public class VipPrivilegesDto
    {
        public int reviveLimit;
        public bool reviveNeedsAd;
        public int sweepLimit;
        public bool queueExtraEnabled;
        public bool magnetNeedsAd;
        public int plunderBaseLimit;
        public int plunderAdLimit;
        public bool svipBadgeEnabled;
    }

    [Serializable]
    public class VipMonthlyProductDto
    {
        public string productId;
        public string itemId;
        public string benefitPlanId;
        public string name;
        public string desc;
        public string costType;
        public int costAmount;
        public int durationDays;
    }

    [Serializable]
    public class VipRewardItemDto
    {
        public string id;
        public int count;
    }
}
