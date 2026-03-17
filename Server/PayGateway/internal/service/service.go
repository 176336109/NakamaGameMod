package service

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"paygateway/internal/model"
	"paygateway/internal/provider"
	"paygateway/internal/repo"
	"paygateway/pkg/config"
	"paygateway/pkg/logger"
	"time"

	"github.com/google/uuid"
	"go.uber.org/zap"
)

type PayService struct {
	repo repo.Repo
	cfg  config.Config
}

func NewPayService(r repo.Repo, cfg config.Config) *PayService {
	return &PayService{repo: r, cfg: cfg}
}

func (s *PayService) CreateOrder(ctx context.Context, req *provider.CreateOrderReq) (*provider.CreateOrderResp, error) {
	// 1. Validate request
	if req.Amount <= 0 {
		return nil, fmt.Errorf("invalid amount")
	}

	// 2. Generate Order ID
	orderID := uuid.New().String()
	req.OrderID = orderID

	// 3. Get Provider
	p, ok := provider.Get(req.Provider)
	if !ok {
		return nil, fmt.Errorf("provider not found")
	}

	// 4. Create Order in DB
	order := &model.Order{
		ID:        orderID,
		AppID:     req.AppID,
		UserID:    req.UserID,
		ProductID: req.ProductID,
		Amount:    req.Amount,
		Currency:  req.Currency,
		Provider:  p.Name(),
		Status:    model.OrderStatusCreated,
		ReturnURL: req.ReturnURL,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	if err := s.repo.CreateOrder(ctx, order); err != nil {
		return nil, err
	}

	// 5. Call Provider
	resp, err := p.CreateOrder(ctx, req)
	if err != nil {
		// Mark as failed?
		return nil, err
	}

	// 6. Update Provider Order No if available immediately
	if resp.ProviderOrderNo != "" {
		s.repo.UpdateOrderStatus(ctx, orderID, model.OrderStatusCreated, resp.ProviderOrderNo)
	}
	resp.OrderID = orderID

	return resp, nil
}

func (s *PayService) HandleNotify(ctx context.Context, providerName string, r *http.Request) (func(http.ResponseWriter), error) {
	p, ok := provider.Get(providerName)
	if !ok {
		return nil, fmt.Errorf("provider not found")
	}

	// 1. Parse Notify
	data, err := p.ParseNotify(ctx, r)

	// Ensure we read body for logging if possible, but ParseNotify might have consumed it.
	// For a real production app, we might need a middleware to tee the body or have provider return raw body.

	// Create callback log
	logEntry := &model.CallbackLog{
		Provider:       providerName,
		ReceivedAt:     time.Now(),
		SignatureValid: err == nil,
	}

	if err != nil {
		logEntry.HandleResult = fmt.Sprintf("parse error: %v", err)
		s.repo.CreateCallbackLog(ctx, logEntry)
		return nil, err
	}

	// 2. Check Order Status in DB (Idempotency)
	order, err := s.repo.GetOrder(ctx, data.OrderID)
	if err != nil {
		logEntry.HandleResult = fmt.Sprintf("order not found: %v", err)
		s.repo.CreateCallbackLog(ctx, logEntry)
		return nil, err
	}

	if order.Status == model.OrderStatusPaid {
		// Already paid
		logEntry.HandleResult = "ignored: already paid"
		s.repo.CreateCallbackLog(ctx, logEntry)
		return p.AckNotify, nil
	}

	if data.Status == model.OrderStatusPaid {
		var task *model.NotifyTask
		err = s.repo.Transaction(ctx, func(txRepo repo.Repo) error {
			// 3.1 Update Order Status
			if err := txRepo.UpdateOrderStatus(ctx, data.OrderID, model.OrderStatusPaid, data.ProviderOrderNo); err != nil {
				return fmt.Errorf("update order error: %w", err)
			}

			// 3.2 Create Callback Log
			logEntry.HandleResult = "success: updated to paid"
			if err := txRepo.CreateCallbackLog(ctx, logEntry); err != nil {
				return fmt.Errorf("create callback log error: %w", err)
			}

			// 3.3 Create Notify Task
			task = &model.NotifyTask{
				ID:          uuid.New().String(),
				OrderID:     order.ID,
				Status:      model.NotifyTaskStatusPending,
				RetryCount:  0,
				MaxRetry:    5,
				NextRetryAt: time.Now(),
				CreatedAt:   time.Now(),
				UpdatedAt:   time.Now(),
			}
			if err := txRepo.CreateNotifyTask(ctx, task); err != nil {
				return fmt.Errorf("create notify task error: %w", err)
			}

			return nil
		})

		if err != nil {
			// Transaction failed, log it outside tx
			logEntry.HandleResult = err.Error()
			s.repo.CreateCallbackLog(ctx, logEntry)
			return nil, err
		}

		// 4. Notify Business (Async) after successful commit
		go s.notifyBusiness(context.Background(), task)
	} else {
		logEntry.HandleResult = fmt.Sprintf("ignored: status is %s", data.Status)
		s.repo.CreateCallbackLog(ctx, logEntry)
	}

	return p.AckNotify, nil
}

func (s *PayService) GetOrder(ctx context.Context, id string) (*model.Order, error) {
	return s.repo.GetOrder(ctx, id)
}

func (s *PayService) notifyBusiness(ctx context.Context, task *model.NotifyTask) {
	if s.cfg.Business.NakamaNotifyURL == "" {
		logger.Log.Info("Business notify URL is empty, skipping notify", zap.String("orderID", task.OrderID))
		return
	}

	order, err := s.repo.GetOrder(ctx, task.OrderID)
	if err != nil {
		logger.Log.Error("Failed to get order for notify", zap.String("orderID", task.OrderID), zap.Error(err))
		return
	}

	// Prepare payload for Nakama
	payload := map[string]interface{}{
		"order_id":          order.ID,
		"provider_order_no": order.ProviderOrderNo,
		"app_id":            order.AppID,
		"user_id":           order.UserID,
		"product_id":        order.ProductID,
		"amount":            order.Amount,
		"currency":          order.Currency,
		"status":            string(order.Status),
	}

	body, err := json.Marshal(payload)
	if err != nil {
		logger.Log.Error("Failed to marshal notify payload", zap.String("orderID", order.ID), zap.Error(err))
		return
	}

	req, err := http.NewRequest("POST", s.cfg.Business.NakamaNotifyURL, bytes.NewBuffer(body))
	if err != nil {
		logger.Log.Error("Failed to create request", zap.String("orderID", order.ID), zap.Error(err))
		return
	}

	req.Header.Set("Content-Type", "application/json")

	// Set Authorization/Signature headers if configured
	if s.cfg.Business.NakamaServerKey != "" {
		req.SetBasicAuth("server", s.cfg.Business.NakamaServerKey)
	}

	if s.cfg.Business.SignSecret != "" {
		h := hmac.New(sha256.New, []byte(s.cfg.Business.SignSecret))
		h.Write(body)
		signature := base64.StdEncoding.EncodeToString(h.Sum(nil))
		req.Header.Set("X-Signature", signature)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)

	task.RetryCount++
	task.UpdatedAt = time.Now()

	if err != nil {
		logger.Log.Error("Failed to notify business", zap.String("orderID", order.ID), zap.Error(err))
		s.handleNotifyFailure(ctx, task)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		logger.Log.Info("Successfully notified business", zap.String("orderID", order.ID))
		task.Status = model.NotifyTaskStatusSuccess
		s.repo.UpdateNotifyTask(ctx, task)
	} else {
		logger.Log.Error("Business returned error status", zap.Int("statusCode", resp.StatusCode), zap.String("orderID", order.ID))
		s.handleNotifyFailure(ctx, task)
	}
}

func (s *PayService) handleNotifyFailure(ctx context.Context, task *model.NotifyTask) {
	if task.RetryCount >= task.MaxRetry {
		task.Status = model.NotifyTaskStatusFailed
	} else {
		task.Status = model.NotifyTaskStatusPending
		// Exponential backoff: next retry = now + 2^retryCount * 15 seconds
		backoff := time.Duration(1<<task.RetryCount) * 15 * time.Second
		task.NextRetryAt = time.Now().Add(backoff)
	}
	s.repo.UpdateNotifyTask(ctx, task)
}
