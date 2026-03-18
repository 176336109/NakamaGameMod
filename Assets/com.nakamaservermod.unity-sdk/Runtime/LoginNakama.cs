using System;
using System.Threading.Tasks;
using UnityEngine;

namespace NakamaServerMod.UnitySdk
{
    public class LoginNakama : MonoBehaviour
    {
        public static LoginNakama Instance { get; private set; }

        public string userName = "";
        public string host = "127.0.0.1";
        public int port = 7350;
        public string serverKey = "defaultkey";
        public bool ssl = false;

        public GameClient Client { get; private set; }
        public string LastError { get; private set; }
        public bool IsLoggedIn => Client != null && Client.HasSession;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private async void Start()
        {
            if (Instance != this)
            {
                return;
            }

            await LoginAsync(GetDeviceId(), userName);
        }

        public async Task<bool> LoginAsync(string deviceId, string username)
        {
            LastError = null;
            try
            {
                Client = await CreateAuthenticatedClientAsync(deviceId, username);
                return IsLoggedIn;
            }
            catch (Exception ex)
            {
                LastError = ex.Message;
                Debug.LogError($"Nakama 登录失败: {ex.Message}");
                return false;
            }
        }

        public void Logout()
        {
            Client = null;
        }

        public string GetDeviceId()
        {
            return SystemInfo.deviceUniqueIdentifier;
        }

        private async Task<GameClient> CreateAuthenticatedClientAsync(string deviceId, string username)
        {
            var config = new ConnectionConfig(host, port, serverKey, ssl);
            var client = new GameClient(config);
            await client.AuthenticateDeviceAsync(deviceId, username);
            return client;
        }
    }
}
