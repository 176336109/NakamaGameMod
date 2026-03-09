using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;

namespace NakamaServerMod.UnitySdk
{
    public sealed class UnityJsonCodec : IJsonCodec
    {
        public string ToJson<T>(T value)
        {
            if (value == null)
            {
                return null;
            }

            if (value is string s)
            {
                return s;
            }

            if (value is DebugAddItemsRequest debugAddItemsRequest)
            {
                return SerializeItemStacks(debugAddItemsRequest.items ?? new List<ItemStack>());
            }

            return JsonUtility.ToJson(value);
        }

        public T FromJson<T>(string json)
        {
            if (typeof(T) == typeof(string))
            {
                return (T)(object)json;
            }

            if (string.IsNullOrEmpty(json))
            {
                return default;
            }

            try
            {
                return JsonUtility.FromJson<T>(json);
            }
            catch (Exception)
            {
                throw;
            }
        }

        private static string SerializeItemStacks(List<ItemStack> items)
        {
            var sb = new StringBuilder();
            sb.Append('[');

            for (var i = 0; i < items.Count; i++)
            {
                if (i > 0)
                {
                    sb.Append(',');
                }

                var item = items[i];
                if (item == null)
                {
                    throw new ArgumentException("items contains null element.", nameof(items));
                }

                if (string.IsNullOrEmpty(item.id))
                {
                    throw new ArgumentException("items contains element with empty id.", nameof(items));
                }

                sb.Append("{\"id\":\"");
                AppendJsonEscapedString(sb, item.id);
                sb.Append("\",\"count\":");
                sb.Append(item.count);
                sb.Append('}');
            }

            sb.Append(']');
            return sb.ToString();
        }

        private static void AppendJsonEscapedString(StringBuilder sb, string value)
        {
            for (var i = 0; i < value.Length; i++)
            {
                var c = value[i];
                switch (c)
                {
                    case '"':
                        sb.Append("\\\"");
                        break;
                    case '\\':
                        sb.Append("\\\\");
                        break;
                    case '\b':
                        sb.Append("\\b");
                        break;
                    case '\f':
                        sb.Append("\\f");
                        break;
                    case '\n':
                        sb.Append("\\n");
                        break;
                    case '\r':
                        sb.Append("\\r");
                        break;
                    case '\t':
                        sb.Append("\\t");
                        break;
                    default:
                        if (c < 32)
                        {
                            sb.Append("\\u");
                            sb.Append(((int)c).ToString("x4"));
                        }
                        else
                        {
                            sb.Append(c);
                        }

                        break;
                }
            }
        }
    }
}
