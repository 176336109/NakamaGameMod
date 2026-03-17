package gopay_provider

import (
	"context"
	"io"
	"net/http"
	"paygateway/internal/model"
	"paygateway/internal/provider"
	"paygateway/pkg/config"
	"paygateway/pkg/logger"

	"github.com/go-pay/gopay/wechat/v3"
	"go.uber.org/zap"
)

type WechatProvider struct {
	cli    *wechat.ClientV3
	config config.ProviderConfig
}

func NewWechatProvider(cfg config.ProviderConfig) (*WechatProvider, error) {
	// Initialize GoPay WeChat V3 Client
	// Note: In a real scenario, you need to read the private key from file
	// Here we assume cfg.PrivateKeyPath is valid or handle it appropriately.
	// For demo purposes, we might skip actual file reading if not present.

	// Example: client, err := wechat.NewClientV3(mchid, serialNo, apiV3Key, privateKeyContent)
	// We'll just return a struct with config for now as we don't have real keys.

	logger.Log.Info("Initializing Wechat Provider", zap.String("MchID", cfg.MchID))

	// In production:
	// pk, err := os.ReadFile(cfg.PrivateKeyPath)
	// if err != nil { return nil, err }
	// client, err := wechat.NewClientV3(cfg.MchID, cfg.SerialNo, cfg.ApiV3Key, string(pk))

	return &WechatProvider{
		config: cfg,
		// cli: client,
	}, nil
}

func (p *WechatProvider) Name() string {
	return "wechat"
}

func (p *WechatProvider) CreateOrder(ctx context.Context, req *provider.CreateOrderReq) (*provider.CreateOrderResp, error) {
	// Example implementation
	logger.Log.Info("Wechat CreateOrder", zap.Any("req", req))

	// bm := make(gopay.BodyMap)
	// bm.Set("appid", p.config.AppID)
	// bm.Set("mchid", p.config.MchID)
	// bm.Set("description", req.Subject)
	// bm.Set("out_trade_no", req.OrderID)
	// bm.Set("notify_url", p.config.NotifyPath) // This should be full URL
	// ...

	// resp, err := p.cli.V3TransactionJsapi(ctx, bm)

	// Mock response
	return &provider.CreateOrderResp{
		ProviderOrderNo: "wx_mock_order_no_" + req.OrderID,
		PayParams: map[string]interface{}{
			"prepay_id": "mock_prepay_id",
			"nonceStr":  "mock_nonce",
		},
		Status: model.OrderStatusCreated,
	}, nil
}

func (p *WechatProvider) QueryOrder(ctx context.Context, req *provider.QueryOrderReq) (*provider.QueryOrderResp, error) {
	return &provider.QueryOrderResp{
		Status:          model.OrderStatusPaid,
		Amount:          100,
		ProviderOrderNo: req.ProviderOrderNo,
	}, nil
}

func (p *WechatProvider) CloseOrder(ctx context.Context, req *provider.CloseOrderReq) (*provider.CloseOrderResp, error) {
	return &provider.CloseOrderResp{Success: true}, nil
}

func (p *WechatProvider) Refund(ctx context.Context, req *provider.RefundReq) (*provider.RefundResp, error) {
	return &provider.RefundResp{
		ProviderRefundNo: "wx_refund_" + req.RefundID,
		Status:           model.RefundStatusSuccess,
	}, nil
}

func (p *WechatProvider) ParseNotify(ctx context.Context, r *http.Request) (*provider.NotifyData, error) {
	// Parse WeChat callback
	// notifyReq, err := wechat.V3ParseNotify(r)
	// Verify signature...

	body, _ := io.ReadAll(r.Body)
	logger.Log.Info("Wechat Notify", zap.String("body", string(body)))

	// Mock parsing
	return &provider.NotifyData{
		OrderID:         "mock_order_id_from_callback", // Should extract from body
		ProviderOrderNo: "mock_provider_no",
		Status:          model.OrderStatusPaid,
		Amount:          100,
		Currency:        "CNY",
	}, nil
}

func (p *WechatProvider) AckNotify(w http.ResponseWriter) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"code":"SUCCESS","message":"成功"}`))
}
