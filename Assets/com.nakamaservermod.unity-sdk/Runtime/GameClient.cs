using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Nakama;

namespace NakamaServerMod.UnitySdk
{
    public sealed class GameClient
    {
        public ConnectionConfig Config { get; }
        public IClient Client { get; }
        public ISession Session { get; private set; }
        public IJsonCodec Json { get; }

        public GameClient(ConnectionConfig config, IJsonCodec jsonCodec = null, IClient client = null)
        {
            Config = config;
            Json = jsonCodec ?? new UnityJsonCodec();
            Client = client ?? new Client(config.Scheme, config.Host, config.Port, config.ServerKey, UnityWebRequestAdapter.Instance);
        }

        public bool HasSession => Session != null && !Session.IsExpired;

        public void SetSession(ISession session)
        {
            Session = session;
        }

        public void RestoreSession(string authToken, string refreshToken = null)
        {
            Session = refreshToken == null ? Nakama.Session.Restore(authToken) : Nakama.Session.Restore(authToken, refreshToken);
        }

        public async Task<ISession> AuthenticateDeviceAsync(
            string deviceId,
            string username = null,
            bool create = true,
            Dictionary<string, string> vars = null,
            CancellationToken cancellationToken = default)
        {
            try
            {
                var session = await Client.AuthenticateDeviceAsync(
                    deviceId,
                    username,
                    create,
                    vars,
                    retryConfiguration: null,
                    canceller: cancellationToken);
                Session = session;
                return session;
            }
            catch (ApiResponseException ex)
            {
                throw SdkException.Api(ex.Message, ex, statusCode: (int)ex.StatusCode);
            }
            catch (TaskCanceledException ex)
            {
                throw SdkException.Network("AuthenticateDeviceAsync cancelled.", ex);
            }
            catch (Exception ex)
            {
                throw SdkException.Unexpected("AuthenticateDeviceAsync failed.", ex);
            }
        }

        public Task<TResponse> RpcAsync<TResponse>(string rpcId, CancellationToken cancellationToken = default)
        {
            return RpcAsync<string, TResponse>(rpcId, null, cancellationToken);
        }

        public Task RpcAsync<TRequest>(string rpcId, TRequest request, CancellationToken cancellationToken = default)
        {
            return RpcAsync<TRequest, string>(rpcId, request, cancellationToken);
        }

        public async Task<TResponse> RpcAsync<TRequest, TResponse>(string rpcId, TRequest request, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(rpcId))
            {
                throw new ArgumentException("rpcId is required.", nameof(rpcId));
            }

            if (Session == null)
            {
                throw SdkException.InvalidSession();
            }

            string requestPayload = null;
            if (request != null)
            {
                try
                {
                    requestPayload = Json.ToJson(request);
                }
                catch (Exception ex)
                {
                    throw SdkException.Serialization("RPC request serialization failed.", ex, rpcId: rpcId);
                }
            }

            try
            {
                IApiRpc rpc;
                if (requestPayload == null)
                {
                    rpc = await Client.RpcAsync(Session, rpcId, retryConfiguration: null, canceller: cancellationToken);
                }
                else
                {
                    rpc = await Client.RpcAsync(Session, rpcId, requestPayload, retryConfiguration: null, canceller: cancellationToken);
                }

                var responsePayload = rpc?.Payload;
                try
                {
                    return Json.FromJson<TResponse>(responsePayload);
                }
                catch (Exception ex)
                {
                    throw SdkException.Serialization("RPC response deserialization failed.", ex, rpcId: rpcId, rawPayload: responsePayload);
                }
            }
            catch (ApiResponseException ex)
            {
                throw SdkException.Api(ex.Message, ex, statusCode: (int)ex.StatusCode, rpcId: rpcId);
            }
            catch (TaskCanceledException ex)
            {
                throw SdkException.Network("RPC cancelled.", ex, rpcId: rpcId);
            }
            catch (Exception ex)
            {
                throw SdkException.Unexpected("RPC failed.", ex, rpcId: rpcId);
            }
        }
    }
}
