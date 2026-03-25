using System;

namespace NakamaServerMod.UnitySdk
{
    /// <summary>
    /// 调试加道具响应
    /// </summary>
    [Serializable]
    public sealed class DebugAddItemsResponse
    {
        public bool success; // 是否成功
        public string error; // 失败原因
    }
}
