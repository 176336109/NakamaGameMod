using System;
using System.Collections.Generic;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class RecordReviveUsageRequest
    {
        public bool used_ad;
    }

    [Serializable]
    public class RecordPlunderUsageRequest
    {
        public bool is_ad;
    }

    [Serializable]
    public class InventoryGetItemsRequest
    {
        public List<string> item_ids;
    }

    [Serializable]
    public class InventoryListRequest
    {
        public int page_size;
        public string cursor;
        public string item_type;
        public string itemType;
    }

    [Serializable]
    public class InventoryAllInfoRequest
    {
        public int page_size;
        public int limit;
        public string item_type;
        public string itemType;
    }

    [Serializable]
    public class InventoryLogListRequest
    {
        public int page_size;
        public string cursor;
        public long start_ts;
        public long end_ts;
        public string source;
        public string item_id;
        public string user_id;
        public string target_user_id;
        public string admin_token;
    }

    [Serializable]
    public class BackpackMutationRequest
    {
        public List<BackpackItem> items;
        public string source;
        public string requestId;
        public object @ref;
    }

    [Serializable]
    public class DebugSimulatePurchaseRequest
    {
        public string plan_id;
    }
}
