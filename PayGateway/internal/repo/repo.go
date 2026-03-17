package repo

import (
	"context"
	"fmt"
	"paygateway/internal/model"
	"sync"
	"time"

	"gorm.io/gorm"
)

type Repo interface {
	CreateOrder(ctx context.Context, order *model.Order) error
	GetOrder(ctx context.Context, id string) (*model.Order, error)
	UpdateOrderStatus(ctx context.Context, id string, status model.OrderStatus, providerOrderNo string) error
	CreateRefund(ctx context.Context, refund *model.Refund) error
	CreateCallbackLog(ctx context.Context, log *model.CallbackLog) error

	Transaction(ctx context.Context, fn func(repo Repo) error) error
	CreateNotifyTask(ctx context.Context, task *model.NotifyTask) error
	GetPendingNotifyTasks(ctx context.Context, limit int) ([]*model.NotifyTask, error)
	UpdateNotifyTask(ctx context.Context, task *model.NotifyTask) error
}

type PostgresRepo struct {
	db *gorm.DB
}

func NewRepo(db *gorm.DB) *PostgresRepo {
	return &PostgresRepo{db: db}
}

func (r *PostgresRepo) CreateOrder(ctx context.Context, order *model.Order) error {
	return r.db.WithContext(ctx).Create(order).Error
}

func (r *PostgresRepo) GetOrder(ctx context.Context, id string) (*model.Order, error) {
	var order model.Order
	if err := r.db.WithContext(ctx).First(&order, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &order, nil
}

func (r *PostgresRepo) UpdateOrderStatus(ctx context.Context, id string, status model.OrderStatus, providerOrderNo string) error {
	updates := map[string]interface{}{
		"status": status,
	}
	if providerOrderNo != "" {
		updates["provider_order_no"] = providerOrderNo
	}
	return r.db.WithContext(ctx).Model(&model.Order{}).Where("id = ?", id).Updates(updates).Error
}

func (r *PostgresRepo) CreateRefund(ctx context.Context, refund *model.Refund) error {
	return r.db.WithContext(ctx).Create(refund).Error
}

func (r *PostgresRepo) CreateCallbackLog(ctx context.Context, log *model.CallbackLog) error {
	return r.db.WithContext(ctx).Create(log).Error
}

func (r *PostgresRepo) Transaction(ctx context.Context, fn func(repo Repo) error) error {
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		txRepo := &PostgresRepo{db: tx}
		return fn(txRepo)
	})
}

func (r *PostgresRepo) CreateNotifyTask(ctx context.Context, task *model.NotifyTask) error {
	return r.db.WithContext(ctx).Create(task).Error
}

func (r *PostgresRepo) GetPendingNotifyTasks(ctx context.Context, limit int) ([]*model.NotifyTask, error) {
	var tasks []*model.NotifyTask
	err := r.db.WithContext(ctx).
		Where("status = ? AND next_retry_at <= ?", model.NotifyTaskStatusPending, time.Now()).
		Limit(limit).
		Find(&tasks).Error
	return tasks, err
}

func (r *PostgresRepo) UpdateNotifyTask(ctx context.Context, task *model.NotifyTask) error {
	return r.db.WithContext(ctx).Save(task).Error
}

// InMemoryRepo for testing/demo
type InMemoryRepo struct {
	orders      map[string]*model.Order
	notifyTasks map[string]*model.NotifyTask
	mu          *sync.RWMutex
}

func NewInMemoryRepo() *InMemoryRepo {
	return &InMemoryRepo{
		orders:      make(map[string]*model.Order),
		notifyTasks: make(map[string]*model.NotifyTask),
		mu:          &sync.RWMutex{},
	}
}

func (r *InMemoryRepo) CreateOrder(ctx context.Context, order *model.Order) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.orders[order.ID] = order
	return nil
}

func (r *InMemoryRepo) GetOrder(ctx context.Context, id string) (*model.Order, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	order, ok := r.orders[id]
	if !ok {
		return nil, fmt.Errorf("order not found")
	}
	return order, nil
}

func (r *InMemoryRepo) UpdateOrderStatus(ctx context.Context, id string, status model.OrderStatus, providerOrderNo string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	order, ok := r.orders[id]
	if !ok {
		return fmt.Errorf("order not found")
	}
	order.Status = status
	if providerOrderNo != "" {
		order.ProviderOrderNo = providerOrderNo
	}
	return nil
}

func (r *InMemoryRepo) CreateRefund(ctx context.Context, refund *model.Refund) error {
	return nil
}

func (r *InMemoryRepo) CreateCallbackLog(ctx context.Context, log *model.CallbackLog) error {
	return nil
}

func (r *InMemoryRepo) Transaction(ctx context.Context, fn func(repo Repo) error) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	// Copy maps for rollback support
	ordersCopy := make(map[string]*model.Order)
	for k, v := range r.orders {
		ordersCopy[k] = v
	}
	notifyTasksCopy := make(map[string]*model.NotifyTask)
	for k, v := range r.notifyTasks {
		notifyTasksCopy[k] = v
	}

	txRepo := &InMemoryRepo{
		orders:      ordersCopy,
		notifyTasks: notifyTasksCopy,
		mu:          &sync.RWMutex{}, // Dummy lock for tx methods to avoid deadlock
	}

	err := fn(txRepo)
	if err == nil {
		// Commit
		r.orders = txRepo.orders
		r.notifyTasks = txRepo.notifyTasks
	}
	return err
}

func (r *InMemoryRepo) CreateNotifyTask(ctx context.Context, task *model.NotifyTask) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.notifyTasks[task.ID] = task
	return nil
}

func (r *InMemoryRepo) GetPendingNotifyTasks(ctx context.Context, limit int) ([]*model.NotifyTask, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var tasks []*model.NotifyTask
	now := time.Now()
	for _, t := range r.notifyTasks {
		if t.Status == model.NotifyTaskStatusPending && !t.NextRetryAt.After(now) {
			tasks = append(tasks, t)
			if len(tasks) >= limit {
				break
			}
		}
	}
	return tasks, nil
}

func (r *InMemoryRepo) UpdateNotifyTask(ctx context.Context, task *model.NotifyTask) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.notifyTasks[task.ID] = task
	return nil
}
