package mock

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"

	"paygateway/internal/model"
	"paygateway/internal/provider"
	"paygateway/pkg/config"
)

type MockProvider struct {
	cfg config.ProviderConfig
}

func NewMockProvider(cfg config.ProviderConfig) *MockProvider {
	return &MockProvider{
		cfg: cfg,
	}
}

func (p *MockProvider) Name() string {
	return p.cfg.Name
}

func (p *MockProvider) CreateOrder(ctx context.Context, req *provider.CreateOrderReq) (*provider.CreateOrderResp, error) {
	// Simulate success
	return &provider.CreateOrderResp{
		OrderID:         req.OrderID,
		ProviderOrderNo: "mock_provider_order_" + req.OrderID,
		PayParams: map[string]interface{}{
			"mock_pay_url": "http://mock-payment-url.com/" + req.OrderID,
		},
		PayURL: "http://mock-payment-url.com/" + req.OrderID,
		Status: model.OrderStatusCreated,
	}, nil
}

func (p *MockProvider) QueryOrder(ctx context.Context, req *provider.QueryOrderReq) (*provider.QueryOrderResp, error) {
	return &provider.QueryOrderResp{
		Status:          model.OrderStatusPaid,
		Amount:          100, // Dummy amount
		ProviderOrderNo: req.ProviderOrderNo,
	}, nil
}

func (p *MockProvider) CloseOrder(ctx context.Context, req *provider.CloseOrderReq) (*provider.CloseOrderResp, error) {
	return &provider.CloseOrderResp{
		Success: true,
	}, nil
}

func (p *MockProvider) Refund(ctx context.Context, req *provider.RefundReq) (*provider.RefundResp, error) {
	return &provider.RefundResp{
		ProviderRefundNo: "mock_refund_" + req.RefundID,
		Status:           model.RefundStatusSuccess,
	}, nil
}

func (p *MockProvider) ParseNotify(ctx context.Context, r *http.Request) (*provider.NotifyData, error) {
	// Try to parse JSON body first
	var body struct {
		OrderID string `json:"order_id"`
		Status  string `json:"status"`
	}

	// We need to read the body, but r.Body is a ReadCloser.
	// In a real provider, we might need to verify signature which requires raw body.
	// Here we just decode JSON.
	if r.Header.Get("Content-Type") == "application/json" {
		if err := json.NewDecoder(r.Body).Decode(&body); err == nil && body.OrderID != "" {
			return &provider.NotifyData{
				OrderID:         body.OrderID,
				ProviderOrderNo: "mock_provider_order_" + body.OrderID,
				Status:          model.OrderStatusPaid,
				Amount:          100,
				Currency:        "CNY",
				Extra:           "",
				RawResponse:     body,
			}, nil
		}
	}

	// Fallback to query params
	orderID := r.URL.Query().Get("order_id")
	if orderID == "" {
		return nil, fmt.Errorf("missing order_id in mock notify")
	}

	return &provider.NotifyData{
		OrderID:         orderID,
		ProviderOrderNo: "mock_provider_order_" + orderID,
		Status:          model.OrderStatusPaid,
		Amount:          100,
		Currency:        "CNY",
		Extra:           "",
		RawResponse:     nil,
	}, nil
}

func (p *MockProvider) AckNotify(w http.ResponseWriter) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("success"))
}
