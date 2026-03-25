using System;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 抽卡请求
    /// </summary>
    [Serializable]
    public sealed class GachaPullRequest
    {
        public string banner_id; // 卡池ID
        public int count; // 抽卡次数

        public GachaPullRequest()
        {
        }

        public GachaPullRequest(string bannerId, int count)
        {
            banner_id = bannerId;
            this.count = count;
        }
    }
}
