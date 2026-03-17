package provider

import (
	"context"
	"net/http"
	"paygateway/internal/model"
)

type CreateOrderReq struct {
	OrderID     string
	Provider    string // "wechat", "alipay", "custom_x"
	AppID       string
	UserID      string
	ProductID   string
	Amount      int64 // In cents
	Currency    string
	Subject     string
	Description string
	ClientIP    string
	ReturnURL   string
	Extra       map[string]interface{}
}

type CreateOrderResp struct {
	OrderID         string
	ProviderOrderNo string
	PayParams       map[string]interface{} // e.g., prepay_id, sign, etc.
	PayURL          string                 // e.g., QR code URL, H5 URL
	Status          model.OrderStatus
}

type QueryOrderReq struct {
	OrderID         string
	ProviderOrderNo string
}

type QueryOrderResp struct {
	Status          model.OrderStatus
	Amount          int64
	ProviderOrderNo string
}

type CloseOrderReq struct {
	OrderID         string
	ProviderOrderNo string
}

type CloseOrderResp struct {
	Success bool
}

type RefundReq struct {
	RefundID        string
	OrderID         string
	Amount          int64
	TotalAmount     int64
	Reason          string
	ProviderOrderNo string
}

type RefundResp struct {
	ProviderRefundNo string
	Status           model.RefundStatus
}

type NotifyData struct {
	OrderID         string
	ProviderOrderNo string
	Status          model.OrderStatus
	Amount          int64
	Currency        string
	Extra           string // JSON string if needed
	RawResponse     interface{}
}

type Provider interface {
	Name() string
	CreateOrder(ctx context.Context, req *CreateOrderReq) (*CreateOrderResp, error)
	QueryOrder(ctx context.Context, req *QueryOrderReq) (*QueryOrderResp, error)
	CloseOrder(ctx context.Context, req *CloseOrderReq) (*CloseOrderResp, error)
	Refund(ctx context.Context, req *RefundReq) (*RefundResp, error)
	ParseNotify(ctx context.Context, r *http.Request) (*NotifyData, error)
	AckNotify(w http.ResponseWriter) // Write success response to provider
}

var registry = make(map[string]Provider)

func Register(p Provider) {
	registry[p.Name()] = p
}

func Get(name string) (Provider, bool) {
	p, ok := registry[name]
	return p, ok
}
