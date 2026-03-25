using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 抽卡响应
    /// </summary>
    [Serializable]
    public sealed class GachaPullResponse
    {
        public List<GachaPullResult> results; // 抽卡结果列表
        public PityState pity_state; // 保底状态
        public string error; // 错误信息

        public GachaPullResponse()
        {
        }

        public GachaPullResponse(List<GachaPullResult> results, PityState pityState, string error)
        {
            this.results = results;
            pity_state = pityState;
            this.error = error;
        }
    }
}
