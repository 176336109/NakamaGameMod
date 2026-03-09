using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public sealed class PityState
    {
        public int ssr_counter;
        public int sr_counter;

        public PityState()
        {
        }

        public PityState(int ssrCounter, int srCounter)
        {
            ssr_counter = ssrCounter;
            sr_counter = srCounter;
        }
    }
}
