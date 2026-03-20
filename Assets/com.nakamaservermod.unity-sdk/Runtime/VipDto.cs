using System;
using System.Collections.Generic;

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
        public bool payment_required;
        public IapOrderInfo order;
        public string error;
    }

    [Serializable]
    public class IapOrderInfo
    {
        public bool success;
        public string error;
        public string order_id;
        public string provider;
        public string pay_url;
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
        public bool success;
        public RpcError error;
        public InventoryItem[] items;
        public InventoryState state;
    }

    [Serializable]
    public class InventoryItem
    {
        public string id;
        public long count;
    }

    [Serializable]
    public class RpcError
    {
        public string code;
        public string message;
    }

    [Serializable]
    public class InventoryState
    {
        public int slotCapacity;
        public int usedSlotCount;
        public long version;
        public long lastCleanupAt;
    }

    [Serializable]
    public class InventoryGetItemsRequest
    {
        public List<string> item_ids;
    }

    [Serializable]
    public class InventoryListRequest
    {
        public int page_size;
        public string cursor;
        public string item_type;
        public string itemType;
    }

    [Serializable]
    public class InventoryListItem
    {
        public string key;
        public string id;
        public long count;
        public string itemType;
        public string itemName;
        public string itemDesc;
        public bool stackable;
        public bool hasExpireAt;
        public long expireAt;
        public string instanceId;
    }

    [Serializable]
    public class InventoryItemDef
    {
        public string itemId;
        public string itemName;
        public string itemDesc;
        public string itemType;
        public bool stackable;
        public bool hasExpireAt;
        public long maxStackCount;
        public bool occupySlot;
    }

    [Serializable]
    public class InventoryListResponse
    {
        public bool success;
        public RpcError error;
        public List<InventoryListItem> items;
        public string cursor;
        public InventoryState state;
    }

    [Serializable]
    public class InventoryItemDefsResponse
    {
        public bool success;
        public RpcError error;
        public List<InventoryItemDef> items;
    }

    [Serializable]
    public class InventoryAllInfoRequest
    {
        public int page_size;
        public int limit;
        public string item_type;
        public string itemType;
    }

    [Serializable]
    public class InventoryAllInfoResponse
    {
        public bool success;
        public RpcError error;
        public List<InventoryItemDef> itemDefs;
        public List<InventoryListItem> backpackItems;
        public string cursor;
    }

    [Serializable]
    public class InventoryLogListRequest
    {
        public int page_size;
        public string cursor;
        public long start_ts;
        public long end_ts;
        public string source;
        public string item_id;
        public string user_id;
        public string target_user_id;
        public string admin_token;
    }

    [Serializable]
    public class InventoryLogValue
    {
        public string source;
        public List<InventoryItem> items;
        public object @ref;
        public string ts_utc;
        public long ts;
    }

    [Serializable]
    public class InventoryLogEntry
    {
        public string key;
        public string user_id;
        public InventoryLogValue value;
    }

    [Serializable]
    public class InventoryLogListResponse
    {
        public bool success;
        public RpcError error;
        public List<InventoryLogEntry> logs;
        public string cursor;
    }

    [Serializable]
    public class WalletGetResponse
    {
        public bool success;
        public RpcError error;
        public Dictionary<string, long> wallet;
    }

    [Serializable]
    public class BackpackItem
    {
        public string id;
        public long count;
        public long expireAt;
        public string benefitPlanId;
    }

    [Serializable]
    public class BackpackMutationRequest
    {
        public List<BackpackItem> items;
        public string source;
        public string requestId;
        public object @ref;
    }

    [Serializable]
    public class BackpackMutationResult
    {
        public bool success;
        public string requestId;
        public bool idempotent;
        public bool cleaned;
        public InventoryState state;
    }

    [Serializable]
    public class BackpackMutationResponse
    {
        public bool success;
        public RpcError error;
        public BackpackMutationResult result;
    }

    [Serializable]
    public class BackpackGetStateResponse
    {
        public bool success;
        public RpcError error;
        public InventoryState state;
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
