using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class ItemsConfigDto
    {
        public List<ItemConfigDto> items;
    }

    public enum ItemType
    {
        Unknown = -1,
        All = 0,
        currency = 1,
        entitlement = 2,
        hero = 3,
        special = 4,
        skill_fragment = 5,
        mod_fragment = 6
    }

    [Serializable]
    public class ItemConfigDto
    {
        public string itemId;
        public ItemType type;
        public string name;
        public string itemDesc;
        public string rarity;
        public int max_stack;
    }
}
