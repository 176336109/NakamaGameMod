using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class ItemsConfigDto
    {
        public Dictionary<string, ItemConfigDto> items;
    }

    [Serializable]
    public class ItemConfigDto
    {
        public string type;
        public string name;
        public string itemDesc;
        public string rarity;
        public int max_stack;
    }
}
