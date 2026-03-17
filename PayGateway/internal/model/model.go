package model

import (
	"time"

	"gorm.io/gorm"
)

type OrderStatus string

const (
	OrderStatusCreated  OrderStatus = "CREATED"
	OrderStatusPaid     OrderStatus = "PAID"
	OrderStatusFailed   OrderStatus = "FAILED"
	OrderStatusClosed   OrderStatus = "CLOSED"
	OrderStatusRefunded OrderStatus = "REFUNDED"
)

type Order struct {
	ID              string         `gorm:"primaryKey" json:"id"`
	AppID           string         `json:"app_id"`
	UserID          string         `json:"user_id"`
	ProductID       string         `json:"product_id"`
	Amount          int64          `json:"amount"` // In cents
	Currency        string         `json:"currency"`
	Provider        string         `json:"provider"`
	ProviderOrderNo string      `json:"provider_order_no"`
	Status          OrderStatus `json:"status"`
	ReturnURL       string      `json:"return_url"`
	Extra           string      `json:"extra"` // JSON string
	ExpireAt        time.Time      `json:"expire_at"`
	CreatedAt       time.Time      `json:"created_at"`
	UpdatedAt       time.Time      `json:"updated_at"`
	DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}

type RefundStatus string

const (
	RefundStatusPending RefundStatus = "PENDING"
	RefundStatusSuccess RefundStatus = "SUCCESS"
	RefundStatusFailed  RefundStatus = "FAILED"
)

type Refund struct {
	ID               string       `gorm:"primaryKey" json:"id"`
	OrderID          string       `json:"order_id"`
	Amount           int64        `json:"amount"`
	Reason           string       `json:"reason"`
	ProviderRefundNo string       `json:"provider_refund_no"`
	Status           RefundStatus `json:"status"`
	CreatedAt        time.Time    `json:"created_at"`
	UpdatedAt        time.Time    `json:"updated_at"`
}

type CallbackLog struct {
	ID             uint      `gorm:"primaryKey" json:"id"`
	Provider       string    `json:"provider"`
	RawBody        string    `json:"raw_body"`
	Headers        string    `json:"headers"` // JSON string
	HandleResult   string    `json:"handle_result"`
	SignatureValid bool      `json:"signature_valid"`
	ReceivedAt     time.Time `json:"received_at"`
}

type NotifyTaskStatus string

const (
	NotifyTaskStatusPending NotifyTaskStatus = "PENDING"
	NotifyTaskStatusSuccess NotifyTaskStatus = "SUCCESS"
	NotifyTaskStatusFailed  NotifyTaskStatus = "FAILED"
)

type NotifyTask struct {
	ID          string           `gorm:"primaryKey" json:"id"`
	OrderID     string           `gorm:"index" json:"order_id"`
	Status      NotifyTaskStatus `gorm:"index" json:"status"`
	RetryCount  int              `json:"retry_count"`
	MaxRetry    int              `json:"max_retry"`
	NextRetryAt time.Time        `gorm:"index" json:"next_retry_at"`
	CreatedAt   time.Time        `json:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at"`
}
