using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class GachaPullResponse
    {
        public List<GachaPullResult> results;
        public PityState pity_state;
        public string error;

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
