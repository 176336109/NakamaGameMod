using System;
using System.Threading;
using System.Threading.Tasks;
using NakamaServerMod.UnitySdk;
using UnityEngine;

public sealed class MinimalFlowSample : MonoBehaviour
{
    [Header("Connection")]
    [SerializeField] private string host = "127.0.0.1";
    [SerializeField] private int port = 7350;
    [SerializeField] private string serverKey = "defaultkey";
    [SerializeField] private bool ssl;

    [Header("Auth")]
    [SerializeField] private string deviceId;
    [SerializeField] private string username = "unity_player";
    [SerializeField] private bool create = true;

    [Header("Gacha")]
    [SerializeField] private string bannerId = "standard";
    [SerializeField] private int gachaCount = 1;

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
        Debug.Log("Init OK");

        var resolvedDeviceId = string.IsNullOrWhiteSpace(deviceId) ? SystemInfo.deviceUniqueIdentifier : deviceId;
        await client.AuthenticateDeviceAsync(
            resolvedDeviceId,
            string.IsNullOrWhiteSpace(username) ? null : username,
            create: create,
            vars: null,
            cancellationToken: cancellationToken);
        Debug.Log("AuthenticateDevice OK");

        var checkinService = new CheckinService(client);
        var checkin = await checkinService.DailyCheckinAsync(cancellationToken);
        Debug.Log($"DailyCheckin => success={checkin?.success} streak={checkin?.streak} vip_level={checkin?.vip_level}");

        var gachaService = new GachaService(client);
        var pull = await gachaService.GachaPullAsync(bannerId, Mathf.Max(1, gachaCount), cancellationToken);
        Debug.Log($"GachaPull => results={pull?.results?.Count ?? 0}");
    }
}
