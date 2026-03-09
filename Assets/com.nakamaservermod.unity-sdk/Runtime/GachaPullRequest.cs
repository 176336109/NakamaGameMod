using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class GachaPullRequest
    {
        public string banner_id;
        public int count;

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
