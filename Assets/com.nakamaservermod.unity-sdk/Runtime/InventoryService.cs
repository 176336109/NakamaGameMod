using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace NakamaServerMod.UnitySdk
{
    public sealed class InventoryService
    {
        private readonly GameClient _client;

        public InventoryService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public Task<DebugAddItemsResponse> DebugAddItemsAsync(List<ItemStack> items, CancellationToken cancellationToken = default)
        {
            if (items == null)
            {
                throw new ArgumentNullException(nameof(items));
            }

            var payload = SerializeItemStacks(items);
            return _client.RpcAsync<string, DebugAddItemsResponse>("debug_add_items", payload, cancellationToken);
        }

        public Task<InventoryItemsResponse> GetItemsAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<InventoryItemsResponse>("inventory_get_items", cancellationToken);
        }

        public Task<InventoryItemsResponse> GetItemsAsync(IReadOnlyList<string> itemIds, CancellationToken cancellationToken = default)
        {
            var request = new InventoryGetItemsRequest
            {
                item_ids = itemIds == null ? null : new List<string>(itemIds)
            };
            return _client.RpcAsync<InventoryGetItemsRequest, InventoryItemsResponse>("inventory_get_items", request, cancellationToken);
        }

        public Task<InventoryListResponse> ListAsync(int pageSize = 100, string cursor = null, CancellationToken cancellationToken = default)
        {
            var request = new InventoryListRequest
            {
                page_size = pageSize,
                cursor = cursor
            };
            return _client.RpcAsync<InventoryListRequest, InventoryListResponse>("inventory_list", request, cancellationToken);
        }

        public Task<InventoryLogListResponse> GetLogsAsync(InventoryLogListRequest request, CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<InventoryLogListRequest, InventoryLogListResponse>("inventory_log_list", request ?? new InventoryLogListRequest(), cancellationToken);
        }

        public Task<WalletGetResponse> GetWalletAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<WalletGetResponse>("wallet_get", cancellationToken);
        }

        public Task<BackpackMutationResponse> GrantAsync(BackpackMutationRequest request, CancellationToken cancellationToken = default)
        {
            ValidateMutationRequest(request);
            return _client.RpcAsync<BackpackMutationRequest, BackpackMutationResponse>("backpack_grant", request, cancellationToken);
        }

        public Task<BackpackMutationResponse> ConsumeAsync(BackpackMutationRequest request, CancellationToken cancellationToken = default)
        {
            ValidateMutationRequest(request);
            return _client.RpcAsync<BackpackMutationRequest, BackpackMutationResponse>("backpack_consume", request, cancellationToken);
        }

        public Task<BackpackMutationResponse> UseAsync(BackpackMutationRequest request, CancellationToken cancellationToken = default)
        {
            ValidateMutationRequest(request);
            return _client.RpcAsync<BackpackMutationRequest, BackpackMutationResponse>("backpack_use", request, cancellationToken);
        }

        public Task<BackpackMutationResponse> CleanupAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<BackpackMutationResponse>("backpack_cleanup", cancellationToken);
        }

        public Task<BackpackGetStateResponse> GetBackpackStateAsync(CancellationToken cancellationToken = default)
        {
            return _client.RpcAsync<BackpackGetStateResponse>("backpack_get_state", cancellationToken);
        }

        private static void ValidateMutationRequest(BackpackMutationRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            if (request.items == null)
            {
                throw new ArgumentException("request.items cannot be null.", nameof(request));
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
