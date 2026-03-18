package service

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"paygateway/internal/model"
	"paygateway/internal/provider"
	"paygateway/internal/repo"
	"paygateway/pkg/config"
	"paygateway/pkg/logger"
	"strings"
	"time"

	"sync"

	"github.com/google/uuid"
	"go.uber.org/zap"
)

type PayService struct {
	repo repo.Repo
	cfg  config.Config

	// Token management
	tokenMutex  sync.RWMutex
	token       string
	tokenExpiry time.Time
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

	// Nakama RPC expects the payload to be a JSON string
	body, _ = json.Marshal(string(body))

	req, err := http.NewRequest("POST", s.cfg.Business.NakamaNotifyURL, bytes.NewBuffer(body))
	if err != nil {
		logger.Log.Error("Failed to create request", zap.String("orderID", order.ID), zap.Error(err))
		return
	}

	req.Header.Set("Content-Type", "application/json")

	// Set Authorization/Signature headers if configured
	token, err := s.getNakamaToken(ctx)
	if err != nil {
		logger.Log.Error("Failed to get nakama token", zap.Error(err))
		// If we can't get a token, we treat it as a failure to notify
		task.RetryCount++
		task.UpdatedAt = time.Now()
		s.handleNotifyFailure(ctx, task)
		return
	}
	req.Header.Set("Authorization", "Bearer "+token)

	if s.cfg.Business.SignSecret != "" {
		h := hmac.New(sha256.New, []byte(s.cfg.Business.SignSecret))
		h.Write(body)
		signature := base64.StdEncoding.EncodeToString(h.Sum(nil))
		req.Header.Set("X-Signature", signature)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)

	// Handle 401 Retry
	if err == nil && resp.StatusCode == 401 {
		resp.Body.Close()
		logger.Log.Warn("Nakama returned 401, clearing token and retrying", zap.String("orderID", order.ID))

		// Clear token
		s.tokenMutex.Lock()
		s.token = ""
		s.tokenMutex.Unlock()

		// Get new token
		token, err = s.getNakamaToken(ctx)
		if err != nil {
			logger.Log.Error("Failed to refresh nakama token", zap.Error(err))
			task.RetryCount++
			task.UpdatedAt = time.Now()
			s.handleNotifyFailure(ctx, task)
			return
		}

		// Re-create request (body buffer is consumed, need to recreate it)
		req, err = http.NewRequest("POST", s.cfg.Business.NakamaNotifyURL, bytes.NewBuffer(body))
		if err != nil {
			logger.Log.Error("Failed to recreate request", zap.String("orderID", order.ID), zap.Error(err))
			return
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		if s.cfg.Business.SignSecret != "" {
			h := hmac.New(sha256.New, []byte(s.cfg.Business.SignSecret))
			h.Write(body)
			signature := base64.StdEncoding.EncodeToString(h.Sum(nil))
			req.Header.Set("X-Signature", signature)
		}

		resp, err = client.Do(req)
	}

	task.RetryCount++
	task.UpdatedAt = time.Now()

	if err != nil {
		logger.Log.Error("Failed to notify business", zap.String("orderID", order.ID), zap.Error(err))
		s.handleNotifyFailure(ctx, task)
		return
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		logger.Log.Info("Successfully notified business", zap.String("orderID", order.ID), zap.String("response", string(respBody)))
		// Update task status to success
		s.tokenMutex.Lock()
		task.Status = model.NotifyTaskStatusSuccess
		task.RetryCount = task.RetryCount + 1 // Count successful attempt
		s.tokenMutex.Unlock()
		s.repo.UpdateNotifyTask(ctx, task)
	} else if resp.StatusCode == 401 {
		logger.Log.Warn("Business returned 401, refreshing token and retrying", zap.String("orderID", order.ID))
		s.tokenMutex.Lock()
		s.token = "" // Clear token
		s.tokenMutex.Unlock()
		// Retry once (simple recursion, careful with depth)
		// For robustness, we should probably just let the retryer handle it, but for 401 we want immediate retry
		s.notifyBusiness(ctx, task)
	} else {
		logger.Log.Error("Business returned error status",
			zap.Int("statusCode", resp.StatusCode),
			zap.String("orderID", order.ID),
			zap.String("responseBody", string(respBody)),
		)
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

func (s *PayService) getNakamaToken(ctx context.Context) (string, error) {
	s.tokenMutex.RLock()
	if s.token != "" && time.Now().Add(60*time.Second).Before(s.tokenExpiry) {
		defer s.tokenMutex.RUnlock()
		return s.token, nil
	}
	s.tokenMutex.RUnlock()

	s.tokenMutex.Lock()
	defer s.tokenMutex.Unlock()

	// Double check
	if s.token != "" && time.Now().Add(60*time.Second).Before(s.tokenExpiry) {
		return s.token, nil
	}

	// Authenticate
	token, err := s.authenticate(ctx)
	if err != nil {
		return "", err
	}

	// Parse expiry
	exp, err := s.parseTokenExpiry(token)
	if err != nil {
		logger.Log.Warn("Failed to parse token expiry, using default 60s", zap.Error(err))
		exp = time.Now().Add(60 * time.Second)
	}

	s.token = token
	s.tokenExpiry = exp
	return token, nil
}

func (s *PayService) authenticate(ctx context.Context) (string, error) {
	url := s.cfg.Business.NakamaApiURL + "/v2/account/authenticate/custom?username=paygateway"

	body := map[string]string{"id": "paygateway_server_user"}
	jsonBody, _ := json.Marshal(body)

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", err
	}

	req.Header.Set("Content-Type", "application/json")
	// Use NakamaServerKey as Basic Auth username
	req.SetBasicAuth(s.cfg.Business.NakamaServerKey, "")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("nakama auth failed: status %d", resp.StatusCode)
	}

	var result struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	return result.Token, nil
}

func (s *PayService) parseTokenExpiry(token string) (time.Time, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return time.Time{}, fmt.Errorf("invalid token format")
	}

	payload := parts[1]
	// Add padding if needed
	if l := len(payload) % 4; l > 0 {
		payload += strings.Repeat("=", 4-l)
	}

	decoded, err := base64.URLEncoding.DecodeString(payload)
	if err != nil {
		// Try StdEncoding if URLEncoding fails, though JWT is usually URL encoded
		decoded, err = base64.StdEncoding.DecodeString(payload)
		if err != nil {
			return time.Time{}, err
		}
	}

	var claims struct {
		Exp int64 `json:"exp"`
	}
	if err := json.Unmarshal(decoded, &claims); err != nil {
		return time.Time{}, err
	}

	return time.Unix(claims.Exp, 0), nil
}
