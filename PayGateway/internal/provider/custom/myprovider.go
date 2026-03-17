package custom_provider

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"paygateway/internal/model"
	"paygateway/internal/provider"
	"paygateway/pkg/config"
	"paygateway/pkg/logger"

	"go.uber.org/zap"
)

type MyProvider struct {
	config config.ProviderConfig
}

func NewMyProvider(cfg config.ProviderConfig) *MyProvider {
	return &MyProvider{config: cfg}
}

func (p *MyProvider) Name() string {
	return "myprovider"
}

func (p *MyProvider) CreateOrder(ctx context.Context, req *provider.CreateOrderReq) (*provider.CreateOrderResp, error) {
	// Custom API call logic
	logger.Log.Info("MyProvider CreateOrder", zap.Any("req", req))

	// Example: post JSON to p.config.BaseURL
	// resp, err := http.Post(p.config.BaseURL + "/orders", ...)

	return &provider.CreateOrderResp{
		ProviderOrderNo: "custom_order_" + req.OrderID,
		PayURL:          p.config.BaseURL + "/pay/" + req.OrderID,
		Status:          model.OrderStatusCreated,
	}, nil
}

func (p *MyProvider) QueryOrder(ctx context.Context, req *provider.QueryOrderReq) (*provider.QueryOrderResp, error) {
	return &provider.QueryOrderResp{
		Status:          model.OrderStatusPaid,
		Amount:          100,
		ProviderOrderNo: req.ProviderOrderNo,
	}, nil
}

func (p *MyProvider) CloseOrder(ctx context.Context, req *provider.CloseOrderReq) (*provider.CloseOrderResp, error) {
	return &provider.CloseOrderResp{Success: true}, nil
}

func (p *MyProvider) Refund(ctx context.Context, req *provider.RefundReq) (*provider.RefundResp, error) {
	return &provider.RefundResp{
		ProviderRefundNo: "custom_refund_" + req.RefundID,
		Status:           model.RefundStatusSuccess,
	}, nil
}

func (p *MyProvider) ParseNotify(ctx context.Context, r *http.Request) (*provider.NotifyData, error) {
	// Parse custom callback
	body, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, err
	}

	logger.Log.Info("MyProvider Notify", zap.String("body", string(body)))

	var data map[string]interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		return nil, err
	}

	orderID, ok := data["order_id"].(string)
	if !ok {
		return nil, fmt.Errorf("missing order_id")
	}

	return &provider.NotifyData{
		OrderID:         orderID,
		ProviderOrderNo: "custom_txn_" + orderID,
		Status:          model.OrderStatusPaid,
		Amount:          100, // Should parse from body
		Currency:        "USD",
	}, nil
}

func (p *MyProvider) AckNotify(w http.ResponseWriter) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(p.config.NotifyExpectBody))
}
