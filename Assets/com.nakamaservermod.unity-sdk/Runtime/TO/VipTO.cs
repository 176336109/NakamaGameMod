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
        public bool vip_active; // VIP是否激活
        public bool svip_active; // SVIP是否激活
        public int vip_remaining_days; // VIP剩余天数
        public int svip_remaining_days; // SVIP剩余天数
        public int vip_unclaimed_days; // VIP待领奖天数
        public int svip_unclaimed_days; // SVIP待领奖天数
    }

    /// <summary>
    /// 复活权限响应
    /// </summary>
    [Serializable]
    public class RevivePermissionResponse
    {
        public bool can_revive; // 是否可复活
        public bool need_ad; // 是否需要看广告
        public int remaining; // 剩余次数
    }

    /// <summary>
    /// 扫荡权限响应
    /// </summary>
    [Serializable]
    public class SweepPermissionResponse
    {
        public bool can_sweep; // 是否可扫荡
        public int remaining; // 剩余次数
        public int total; // 总次数
    }

    /// <summary>
    /// 磁铁权限响应
    /// </summary>
    [Serializable]
    public class MagnetPermissionResponse
    {
        public bool can_use; // 是否可使用
        public bool need_ad; // 是否需要广告
    }

    /// <summary>
    /// 掠夺权限响应
    /// </summary>
    [Serializable]
    public class PlunderPermissionResponse
    {
        public bool can_plunder_base; // 是否可进行基础掠夺
        public bool can_plunder_ad; // 是否可进行广告掠夺
        public int base_remaining; // 基础掠夺剩余次数
        public int ad_remaining; // 广告掠夺剩余次数
    }

    /// <summary>
    /// 建造队列权限响应
    /// </summary>
    [Serializable]
    public class QueuePermissionResponse
    {
        public bool can_use_extra_queue; // 是否可使用额外队列
    }

    /// <summary>
    /// 通用成功响应
    /// </summary>
    [Serializable]
    public class SuccessResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
    }

    /// <summary>
    /// 购买物品数据响应
    /// </summary>
    [Serializable]
    public class ItemDataResponse
    {
        public bool success; // 是否成功
        public ItemData item_data; // 返回的物品数据
        public bool payment_required; // 是否需要先支付
        public IapOrderInfo order; // 支付订单信息
        public string error; // 错误信息
    }

    /// <summary>
    /// IAP订单信息
    /// </summary>
    [Serializable]
    public class IapOrderInfo
    {
        public bool success; // 下单是否成功
        public string error; // 下单错误
        public string order_id; // 订单ID
        public string provider; // 支付渠道
        public string pay_url; // 支付地址
    }

    /// <summary>
    /// 物品数据
    /// </summary>
    [Serializable]
    public class ItemData
    {
        public string itemId; // 物品ID
        public long startAt; // 生效时间
        public long expireAt; // 过期时间
        public string benefitPlanId; // 权益计划ID
    }

    [Serializable]
    public class InventoryItemsResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public InventoryItem[] items; // 物品列表
        public InventoryState state; // 背包状态
    }

    [Serializable]
    public class InventoryItem
    {
        public string id; // 物品ID
        public long count; // 数量
    }

    [Serializable]
    public class RpcErrorDetail
    {
        public long code; // 错误码
        public string message; // 错误描述
    }

    [Serializable]
    public class InventoryState
    {
        public int slotCapacity; // 背包容量
        public int usedSlotCount; // 已用格子数
        public long version; // 版本号
        public long lastCleanupAt; // 上次清理时间
    }

    [Serializable]
    public class InventoryListItem
    {
        public string key; // 存储键
        public string id; // 物品ID
        public long count; // 数量
        public string itemType; // 物品类型
        public string itemName; // 物品名
        public string itemDesc; // 物品描述
        public bool stackable; // 是否可堆叠
        public bool hasExpireAt; // 是否有时效
        public long expireAt; // 过期时间
        public string instanceId; // 实例ID
    }

    [Serializable]
    public class InventoryItemDef
    {
        public string itemId; // 物品ID
        public string itemName; // 物品名
        public string itemDesc; // 物品描述
        public string itemType; // 物品类型
        public bool stackable; // 是否可堆叠
        public bool hasExpireAt; // 是否有时效
        public long maxStackCount; // 最大堆叠数
        public bool occupySlot; // 是否占格
    }

    [Serializable]
    public class InventoryListResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public List<InventoryListItem> items; // 分页结果
        public string cursor; // 下一页游标
        public InventoryState state; // 背包状态
    }

    [Serializable]
    public class InventoryItemDefsResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public List<InventoryItemDef> items; // 物品定义列表
    }

    [Serializable]
    public class InventoryAllInfoResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public List<InventoryItemDef> itemDefs; // 物品定义
        public List<InventoryListItem> backpackItems; // 背包物品列表
        public string cursor; // 下一页游标
    }

    [Serializable]
    public class InventoryLogValue
    {
        public string source; // 日志来源
        public List<InventoryItem> items; // 变更道具列表
        public object @ref; // 扩展引用信息
        public string ts_utc; // UTC时间字符串
        public long ts; // 时间戳
    }

    [Serializable]
    public class InventoryLogEntry
    {
        public string key; // 日志键
        public string user_id; // 用户ID
        public InventoryLogValue value; // 日志值
    }

    [Serializable]
    public class InventoryLogListResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public List<InventoryLogEntry> logs; // 日志列表
        public string cursor; // 下一页游标
    }

    [Serializable]
    public class WalletGetResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public Dictionary<string, long> wallet; // 钱包数据
    }

    [Serializable]
    public class BackpackItem
    {
        public string id; // 物品ID
        public long count; // 数量
        public long expireAt; // 过期时间
        public string benefitPlanId; // 权益计划ID
    }

    [Serializable]
    public class BackpackMutationResult
    {
        public bool success; // 是否成功
        public string requestId; // 请求ID
        public bool idempotent; // 是否幂等命中
        public bool cleaned; // 是否执行清理
        public InventoryState state; // 背包状态
    }

    [Serializable]
    public class BackpackMutationResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public BackpackMutationResult result; // 变更结果
    }

    [Serializable]
    public class BackpackGetStateResponse
    {
        public bool success; // 是否成功
        public string error; // 错误信息
        public long error_code; // 错误码
        public RpcErrorDetail error_detail; // 错误详情
        public InventoryState state; // 背包状态
    }
}
