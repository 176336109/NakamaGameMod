namespace NakamaServerMod.UnitySdk
{
    public sealed class ConnectionConfig
    {
        public string Host { get; }
        public int Port { get; }
        public string ServerKey { get; }
        public bool Ssl { get; }

        public string Scheme => Ssl ? "https" : "http";

        public ConnectionConfig(string host, int port, string serverKey, bool ssl)
        {
            Host = host;
            Port = port;
            ServerKey = serverKey;
            Ssl = ssl;
        }

        public static ConnectionConfig Localhost(string serverKey = "defaultkey", bool ssl = false, int port = 7350)
        {
            return new ConnectionConfig("127.0.0.1", port, serverKey, ssl);
        }
    }
}
