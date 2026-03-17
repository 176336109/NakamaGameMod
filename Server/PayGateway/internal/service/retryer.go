package service

import (
	"context"
	"paygateway/internal/model"
	"paygateway/pkg/logger"
	"time"

	"go.uber.org/zap"
)

// StartRetryer starts a background worker that polls for pending notify tasks and retries them.
func (s *PayService) StartRetryer(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				logger.Log.Info("Retryer stopped")
				return
			case <-ticker.C:
				s.processPendingTasks(ctx)
			}
		}
	}()
}

func (s *PayService) processPendingTasks(ctx context.Context) {
	// Fetch up to 100 pending tasks at a time
	tasks, err := s.repo.GetPendingNotifyTasks(ctx, 100)
	if err != nil {
		logger.Log.Error("Failed to fetch pending notify tasks", zap.Error(err))
		return
	}

	for _, task := range tasks {
		// Start a goroutine for each task to notify business concurrently
		go func(t *model.NotifyTask) {
			s.notifyBusiness(ctx, t)
		}(task)
	}
}
