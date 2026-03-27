using System;
using System.Threading.Tasks;
namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// VIP/SVIP服务
    /// </summary>
    public sealed class VipService
    {
        private readonly GameClient _client;

        /// <summary>
        /// 构造函数
        /// </summary>
        /// <param name="client">GameClient实例</param>
        public VipService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        /// <summary>
        /// 按商品ID创建月卡订单（推荐）
        /// </summary>
        /// <param name="productId">商品ID，如 vip/svip</param>
        /// <param name="provider">支付渠道，默认mock</param>
        /// <returns>物品数据响应</returns>
        public Task<ItemDataResponse> PurchaseByProductIdAsync(string productId, string provider = "mock")
        {
            if (string.IsNullOrWhiteSpace(productId))
            {
                throw new ArgumentException("productId is required.", nameof(productId));
            }
            var request = new VipPurchaseRequest
            {
                product_id = productId,
                provider = string.IsNullOrWhiteSpace(provider) ? "mock" : provider
            };
            return _client.RpcAsync<VipPurchaseRequest, ItemDataResponse>("purchase_vip", request);
        }

        /// <summary>
        /// 购买VIP月卡
        /// </summary>
        /// <returns>物品数据响应</returns>
        public Task<ItemDataResponse> PurchaseVipAsync()
        {
            return PurchaseByProductIdAsync("vip");
        }

        /// <summary>
        /// 购买SVIP月卡
        /// </summary>
        /// <returns>物品数据响应</returns>
        public Task<ItemDataResponse> PurchaseSvipAsync()
        {
            return PurchaseByProductIdAsync("svip");
        }

        /// <summary>
        /// 领取VIP每日奖励
        /// </summary>
        /// <returns>成功响应</returns>
        public Task<SuccessResponse> ClaimVipDailyAsync()
        {
            return _client.RpcAsync<string, SuccessResponse>("claim_vip_daily", "{}");
        }

        /// <summary>
        /// 领取SVIP每日奖励
        /// </summary>
        /// <returns>成功响应</returns>
        public Task<SuccessResponse> ClaimSvipDailyAsync()
        {
            return _client.RpcAsync<string, SuccessResponse>("claim_svip_daily", "{}");
        }

        /// <summary>
        /// 一键领取所有每日奖励
        /// </summary>
        /// <returns>成功响应</returns>
        public Task<SuccessResponse> ClaimAllDailyAsync()
        {
            return _client.RpcAsync<string, SuccessResponse>("claim_all_daily", "{}");
        }

        /// <summary>
        /// 获取VIP/SVIP状态
        /// </summary>
        /// <returns>VIP状态响应</returns>
        public Task<VipStatusResponse> GetVipStatusAsync()
        {
            return _client.RpcAsync<string, VipStatusResponse>("get_vip_status", "{}");
        }

        /// <summary>
        /// 检查复活权限
        /// </summary>
        /// <returns>复活权限响应</returns>
        public Task<RevivePermissionResponse> CheckRevivePermissionAsync()
        {
            return _client.RpcAsync<string, RevivePermissionResponse>("check_revive_permission", "{}");
        }

        /// <summary>
        /// 记录复活使用
        /// </summary>
        /// <param name="usedAd">是否使用了广告</param>
        /// <returns>成功响应</returns>
        public Task<SuccessResponse> RecordReviveUsageAsync(bool usedAd)
        {
            var request = new RecordReviveUsageRequest { used_ad = usedAd };
            return _client.RpcAsync<RecordReviveUsageRequest, SuccessResponse>("record_revive_usage", request);
        }

        /// <summary>
        /// 检查扫荡权限
        /// </summary>
        /// <returns>扫荡权限响应</returns>
        public Task<SweepPermissionResponse> CheckSweepPermissionAsync()
        {
            return _client.RpcAsync<string, SweepPermissionResponse>("check_sweep_permission", "{}");
        }

        /// <summary>
        /// 记录扫荡使用
        /// </summary>
        /// <returns>成功响应</returns>
        public Task<SuccessResponse> RecordSweepUsageAsync()
        {
            return _client.RpcAsync<string, SuccessResponse>("record_sweep_usage", "{}");
        }

        /// <summary>
        /// 检查磁铁权限
        /// </summary>
        /// <returns>磁铁权限响应</returns>
        public Task<MagnetPermissionResponse> CheckMagnetPermissionAsync()
        {
            return _client.RpcAsync<string, MagnetPermissionResponse>("check_magnet_permission", "{}");
        }

        /// <summary>
        /// 检查掠夺战权限
        /// </summary>
        /// <returns>掠夺战权限响应</returns>
        public Task<PlunderPermissionResponse> CheckPlunderPermissionAsync()
        {
            return _client.RpcAsync<string, PlunderPermissionResponse>("check_plunder_permission", "{}");
        }

        /// <summary>
        /// 记录掠夺战使用
        /// </summary>
        /// <param name="isAd">是否通过广告获得的次数</param>
        /// <returns>成功响应</returns>
        public Task<SuccessResponse> RecordPlunderUsageAsync(bool isAd)
        {
            var request = new RecordPlunderUsageRequest { is_ad = isAd };
            return _client.RpcAsync<RecordPlunderUsageRequest, SuccessResponse>("record_plunder_usage", request);
        }

        /// <summary>
        /// 检查建造队列权限
        /// </summary>
        /// <returns>建造队列权限响应</returns>
        public Task<QueuePermissionResponse> CheckQueuePermissionAsync()
        {
            return _client.RpcAsync<string, QueuePermissionResponse>("check_queue_permission", "{}");
        }

    }
}
