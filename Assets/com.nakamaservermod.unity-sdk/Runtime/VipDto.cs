using System;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// VIP/SVIP状态响应
    /// </summary>
    [Serializable]
    public class VipStatusResponse
    {
        public bool vip_active;
        public bool svip_active;
        public int vip_remaining_days;
        public int svip_remaining_days;
        public int vip_unclaimed_days;
        public int svip_unclaimed_days;
    }

    /// <summary>
    /// 复活权限响应
    /// </summary>
    [Serializable]
    public class RevivePermissionResponse
    {
        public bool can_revive;
        public bool need_ad;
        public int remaining;
    }

    /// <summary>
    /// 扫荡权限响应
    /// </summary>
    [Serializable]
    public class SweepPermissionResponse
    {
        public bool can_sweep;
        public int remaining;
        public int total;
    }

    /// <summary>
    /// 磁铁权限响应
    /// </summary>
    [Serializable]
    public class MagnetPermissionResponse
    {
        public bool can_use;
        public bool need_ad;
    }

    /// <summary>
    /// 掠夺战权限响应
    /// </summary>
    [Serializable]
    public class PlunderPermissionResponse
    {
        public bool can_plunder_base;
        public bool can_plunder_ad;
        public int base_remaining;
        public int ad_remaining;
    }

    /// <summary>
    /// 建造队列权限响应
    /// </summary>
    [Serializable]
    public class QueuePermissionResponse
    {
        public bool can_use_extra_queue;
    }

    /// <summary>
    /// 记录复活使用请求
    /// </summary>
    [Serializable]
    public class RecordReviveUsageRequest
    {
        public bool used_ad;
    }

    /// <summary>
    /// 记录掠夺战使用请求
    /// </summary>
    [Serializable]
    public class RecordPlunderUsageRequest
    {
        public bool is_ad;
    }

    /// <summary>
    /// 通用成功响应
    /// </summary>
    [Serializable]
    public class SuccessResponse
    {
        public bool success;
        public string error;
    }

    /// <summary>
    /// 物品数据响应
    /// </summary>
    [Serializable]
    public class ItemDataResponse
    {
        public bool success;
        public ItemData item_data;
        public string error;
    }

    /// <summary>
    /// 物品数据
    /// </summary>
    [Serializable]
    public class ItemData
    {
        public string itemId;
        public long startAt;
        public long expireAt;
        public string benefitPlanId;
    }

    [Serializable]
    public class InventoryItemsResponse
    {
        public InventoryItem[] items;
    }

    [Serializable]
    public class InventoryItem
    {
        public string id;
        public long count;
    }

    /// <summary>
    /// 模拟购买请求
    /// </summary>
    [Serializable]
    public class DebugSimulatePurchaseRequest
    {
        public string plan_id;
    }
}