using System;
using System.Threading;
using System.Threading.Tasks;
using Nakama;

namespace NakamaServerMod.UnitySdk
{
    public sealed class IapService
    {
        [Serializable]
        private sealed class GoogleReceiptPayload
        {
            public string json;
            public string signature;

            public GoogleReceiptPayload()
            {
            }

            public GoogleReceiptPayload(string json, string signature)
            {
                this.json = json;
                this.signature = signature;
            }
        }

        [Serializable]
        private sealed class CreateOrderPayload
        {
            public string product_id;
            public string provider;
        }

        [Serializable]
        private sealed class MockPayPayload
        {
            public string order_id;
        }

        private readonly GameClient _client;

        public IapService(GameClient client)
        {
            _client = client ?? throw new ArgumentNullException(nameof(client));
        }

        public Task<IApiValidatePurchaseResponse> ValidatePurchaseAppleAsync(string receipt)
        {
            return ValidatePurchaseAppleAsync(receipt, persist: true, cancellationToken: default);
        }

        public async Task<IApiValidatePurchaseResponse> ValidatePurchaseAppleAsync(
            string receipt,
            bool persist,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(receipt))
            {
                throw new ArgumentException("receipt is required.", nameof(receipt));
            }

            if (_client.Session == null)
            {
                throw SdkException.InvalidSession();
            }

            try
            {
                return await _client.Client.ValidatePurchaseAppleAsync(
                    _client.Session,
                    receipt,
                    persist,
                    retryConfiguration: null,
                    canceller: cancellationToken);
            }
            catch (ApiResponseException ex)
            {
                throw SdkException.Api(ex.Message, ex, statusCode: (int)ex.StatusCode);
            }
            catch (TaskCanceledException ex)
            {
                throw SdkException.Network("ValidatePurchaseAppleAsync cancelled.", ex);
            }
            catch (Exception ex)
            {
                throw SdkException.Unexpected("ValidatePurchaseAppleAsync failed.", ex);
            }
        }

        public Task<IApiValidatePurchaseResponse> ValidatePurchaseGoogleAsync(string purchaseJson, string signature)
        {
            return ValidatePurchaseGoogleAsync(purchaseJson, signature, persist: true, cancellationToken: default);
        }

        public async Task<IApiValidatePurchaseResponse> ValidatePurchaseGoogleAsync(
            string purchaseJson,
            string signature,
            bool persist,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrEmpty(purchaseJson))
            {
                throw new ArgumentException("purchaseJson is required.", nameof(purchaseJson));
            }

            if (string.IsNullOrEmpty(signature))
            {
                throw new ArgumentException("signature is required.", nameof(signature));
            }

            if (_client.Session == null)
            {
                throw SdkException.InvalidSession();
            }

            string receipt;
            try
            {
                receipt = _client.Json.ToJson(new GoogleReceiptPayload(purchaseJson, signature));
            }
            catch (Exception ex)
            {
                throw SdkException.Serialization("Google receipt payload serialization failed.", ex);
            }

            try
            {
                return await _client.Client.ValidatePurchaseGoogleAsync(
                    _client.Session,
                    receipt,
                    persist,
                    retryConfiguration: null,
                    canceller: cancellationToken);
            }
            catch (ApiResponseException ex)
            {
                throw SdkException.Api(ex.Message, ex, statusCode: (int)ex.StatusCode);
            }
            catch (TaskCanceledException ex)
            {
                throw SdkException.Network("ValidatePurchaseGoogleAsync cancelled.", ex);
            }
            catch (Exception ex)
            {
                throw SdkException.Unexpected("ValidatePurchaseGoogleAsync failed.", ex);
            }
        }

        public async Task<string> CreateOrderAsync(string productId, string provider = "mock")
        {
            if (string.IsNullOrEmpty(productId))
            {
                throw new ArgumentException("productId is required.", nameof(productId));
            }

            if (_client.Session == null)
            {
                throw SdkException.InvalidSession();
            }

            try
            {
                var payload = _client.Json.ToJson(new CreateOrderPayload { product_id = productId, provider = provider });
                var rpcResult = await _client.Client.RpcAsync(_client.Session, "create_order", payload);
                return rpcResult.Payload;
            }
            catch (ApiResponseException ex)
            {
                throw SdkException.Api(ex.Message, ex, statusCode: (int)ex.StatusCode);
            }
            catch (Exception ex)
            {
                throw SdkException.Unexpected("CreateOrderAsync failed.", ex);
            }
        }

        public async Task<string> MockPayAsync(string orderId)
        {
            if (string.IsNullOrEmpty(orderId))
            {
                throw new ArgumentException("orderId is required.", nameof(orderId));
            }

            if (_client.Session == null)
            {
                throw SdkException.InvalidSession();
            }

            try
            {
                var payload = _client.Json.ToJson(new MockPayPayload { order_id = orderId });
                var rpcResult = await _client.Client.RpcAsync(_client.Session, "mock_pay", payload);
                return rpcResult.Payload;
            }
            catch (ApiResponseException ex)
            {
                throw SdkException.Api(ex.Message, ex, statusCode: (int)ex.StatusCode);
            }
            catch (Exception ex)
            {
                throw SdkException.Unexpected("MockPayAsync failed.", ex);
            }
        }
    }
}
