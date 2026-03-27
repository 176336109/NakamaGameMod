using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class VipConfigDto
    {
        public Dictionary<string, VipBenefitPlanDto> benefit_plans;
        public Dictionary<string, VipIapProductDto> iap_products;
    }

    [Serializable]
    public class VipBenefitPlanDto
    {
        public string id;
        public string name;
        public string desc;
        public string priceCurrency;
        public int priceAmount;
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
    public class VipIapProductDto
    {
        public List<VipRewardItemDto> rewards;
        public int duration_days;
        public string benefit_plan_id;
    }

    [Serializable]
    public class VipRewardItemDto
    {
        public string id;
        public int count;
    }
}
