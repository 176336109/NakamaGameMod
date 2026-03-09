using System;
using System.Threading;
using System.Threading.Tasks;
using NakamaServerMod.UnitySdk;
using UnityEngine;

public sealed class IapValidationSample : MonoBehaviour
{
    public enum Store
    {
        Apple = 0,
        Google = 1
    }

    [Header("Connection")]
    [SerializeField] private string host = "127.0.0.1";
    [SerializeField] private int port = 7350;
    [SerializeField] private string serverKey = "defaultkey";
    [SerializeField] private bool ssl;

    [Header("Auth")]
    [SerializeField] private string deviceId;
    [SerializeField] private string username = "unity_player";
    [SerializeField] private bool create = true;

    [Header("IAP")]
    [SerializeField] private Store store = Store.Google;
    [SerializeField] private bool persist = true;

    [TextArea(3, 12)]
    [SerializeField] private string appleReceipt = "APPLE_RECEIPT_BASE64_OR_JSON";

    [TextArea(3, 12)]
    [SerializeField] private string googlePurchaseJson = "{\"purchaseToken\":\"TOKEN\",\"productId\":\"sku.example\",\"packageName\":\"com.example.game\"}";

    [TextArea(3, 6)]
    [SerializeField] private string googleSignature = "GOOGLE_SIGNATURE";

    private CancellationTokenSource _cts;

    private void Awake()
    {
        _cts = new CancellationTokenSource();
    }

    private async void Start()
    {
        try
        {
            await RunAsync(_cts.Token);
        }
        catch (Exception ex)
        {
            Debug.LogException(ex);
        }
    }

    private void OnDestroy()
    {
        if (_cts == null)
        {
            return;
        }

        _cts.Cancel();
        _cts.Dispose();
        _cts = null;
    }

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        var config = new ConnectionConfig(host, port, serverKey, ssl);
        var client = new GameClient(config);

        var resolvedDeviceId = string.IsNullOrWhiteSpace(deviceId) ? SystemInfo.deviceUniqueIdentifier : deviceId;
        await client.AuthenticateDeviceAsync(
            resolvedDeviceId,
            string.IsNullOrWhiteSpace(username) ? null : username,
            create: create,
            vars: null,
            cancellationToken: cancellationToken);

        var iap = new IapService(client);
        if (store == Store.Apple)
        {
            await iap.ValidatePurchaseAppleAsync(appleReceipt, persist: persist, cancellationToken: cancellationToken);
            Debug.Log("ValidatePurchaseApple OK");
        }
        else
        {
            await iap.ValidatePurchaseGoogleAsync(googlePurchaseJson, googleSignature, persist: persist, cancellationToken: cancellationToken);
            Debug.Log("ValidatePurchaseGoogle OK");
        }
    }
}
