using System;

namespace NakamaServerMod.UnitySdk
{
    [Serializable]
    public class GameConfigJson
    {
        public string checkin;
        public string gift;
        public string items;
        public string shop;
        public string vip;
    }

    [Serializable]
    public class ConfigGetResponse
    {
        public bool success;
        public string error;
        public long error_code;
        public RpcErrorDetail error_detail;
        public string name;
        public string json;
        public string hash;
        public string config_id;
        public int content_length;
        public GameConfigJson game_config;
    }
}
