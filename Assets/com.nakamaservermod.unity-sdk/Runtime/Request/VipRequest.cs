using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 记录复活使用请求
    /// </summary>
    [Serializable]
    public class RecordReviveUsageRequest
    {
        public bool used_ad; // 是否通过广告复活
    }

    /// <summary>
    /// 记录掠夺使用请求
    /// </summary>
    [Serializable]
    public class RecordPlunderUsageRequest
    {
        public bool is_ad; // 是否使用广告次数
    }

    /// <summary>
    /// 按ID查询背包物品请求
    /// </summary>
    [Serializable]
    public class InventoryGetItemsRequest
    {
        public List<string> item_ids; // 要查询的物品ID列表
    }

    /// <summary>
    /// 背包分页列表请求
    /// </summary>
    [Serializable]
    public class InventoryListRequest
    {
        public int page_size; // 分页大小
        public string cursor; // 分页游标
        public string item_type; // 物品类型筛选（snake_case）
        public string itemType; // 物品类型筛选（camelCase）
    }

    /// <summary>
    /// 背包全量信息请求
    /// </summary>
    [Serializable]
    public class InventoryAllInfoRequest
    {
        public int page_size; // 页大小
        public int limit; // 总返回上限
        public string item_type; // 物品类型筛选（snake_case）
        public string itemType; // 物品类型筛选（camelCase）
    }

    /// <summary>
    /// 背包日志查询请求
    /// </summary>
    [Serializable]
    public class InventoryLogListRequest
    {
        public int page_size; // 分页大小
        public string cursor; // 分页游标
        public long start_ts; // 起始时间戳
        public long end_ts; // 结束时间戳
        public string source; // 来源过滤
        public string item_id; // 物品ID过滤
        public string user_id; // 发起用户ID
        public string target_user_id; // 目标用户ID
        public string admin_token; // 管理端鉴权令牌
    }

    /// <summary>
    /// 背包增删改请求
    /// </summary>
    [Serializable]
    public class BackpackMutationRequest
    {
        public List<BackpackItem> items; // 变更道具列表
        public string source; // 业务来源
        public string requestId; // 幂等请求ID
        public object @ref; // 扩展引用信息
    }

}
