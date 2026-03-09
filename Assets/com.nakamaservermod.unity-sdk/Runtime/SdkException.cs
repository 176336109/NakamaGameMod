using System;

namespace NakamaServerMod.UnitySdk
{
    public sealed class SdkException : Exception
    {
        public SdkErrorKind Kind { get; }
        public int? StatusCode { get; }
        public string RpcId { get; }
        public string RawPayload { get; }

        public SdkException(
            SdkErrorKind kind,
            string message,
            Exception innerException = null,
            int? statusCode = null,
            string rpcId = null,
            string rawPayload = null) : base(message, innerException)
        {
            Kind = kind;
            StatusCode = statusCode;
            RpcId = rpcId;
            RawPayload = rawPayload;
        }

        public static SdkException InvalidSession(string message = "Session is not set.")
        {
            return new SdkException(SdkErrorKind.InvalidSession, message);
        }

        public static SdkException Serialization(string message, Exception innerException, string rpcId = null, string rawPayload = null)
        {
            return new SdkException(SdkErrorKind.Serialization, message, innerException, rpcId: rpcId, rawPayload: rawPayload);
        }

        public static SdkException Api(string message, Exception innerException, int? statusCode = null, string rpcId = null, string rawPayload = null)
        {
            return new SdkException(SdkErrorKind.Api, message, innerException, statusCode: statusCode, rpcId: rpcId, rawPayload: rawPayload);
        }

        public static SdkException Network(string message, Exception innerException, string rpcId = null)
        {
            return new SdkException(SdkErrorKind.Network, message, innerException, rpcId: rpcId);
        }

        public static SdkException Unexpected(string message, Exception innerException, string rpcId = null)
        {
            return new SdkException(SdkErrorKind.Unexpected, message, innerException, rpcId: rpcId);
        }
    }
}
