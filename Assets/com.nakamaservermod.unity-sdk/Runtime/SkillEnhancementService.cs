using System;
using System.Threading;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk
{
    public sealed class SkillEnhancementService
    {
        private readonly GameClient _client;

        public SkillEnhancementService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public async Task<SkillEnhancementResponse> GetDetailAsync(SkillEnhancementGetDetailRequest request, CancellationToken cancellationToken = default)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }
            var response = await _client.RpcAsync<SkillEnhancementGetDetailRequest, SkillEnhancementResponse>("skill_enhancement_get_detail", request, cancellationToken);
            if (response != null && response.success && response.detail != null && response.detail.isMaxLevel)
            {
                response.detail.upgrade = null;
            }
            return response;
        }

        public async Task<SkillEnhancementResponse> UpgradeAsync(SkillEnhancementUpgradeRequest request, CancellationToken cancellationToken = default)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }
            var response = await _client.RpcAsync<SkillEnhancementUpgradeRequest, SkillEnhancementResponse>("skill_enhancement_upgrade", request, cancellationToken);
            if (response != null && response.success && response.detail != null && response.detail.isMaxLevel)
            {
                response.detail.upgrade = null;
            }
            return response;
        }
    }
}
