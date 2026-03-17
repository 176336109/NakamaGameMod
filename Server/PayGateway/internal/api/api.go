package api

import (
	"net/http"
	"paygateway/internal/provider"
	"paygateway/internal/service"

	"github.com/gin-gonic/gin"
)

type API struct {
	svc *service.PayService
}

func NewAPI(svc *service.PayService) *API {
	return &API{svc: svc}
}

func (a *API) RegisterRoutes(r *gin.Engine) {
	v1 := r.Group("/v1")
	{
		v1.POST("/orders", a.CreateOrder)
		v1.GET("/orders/:id", a.GetOrder)
		v1.POST("/providers/:provider/notify", a.Notify)
	}
}

type CreateOrderRequest struct {
	AppID       string                 `json:"app_id" binding:"required"`
	UserID      string                 `json:"user_id" binding:"required"`
	ProductID   string                 `json:"product_id" binding:"required"`
	Amount      int64                  `json:"amount" binding:"required,gt=0"`
	Currency    string                 `json:"currency" binding:"required"`
	Provider    string                 `json:"provider" binding:"required"`
	Subject     string                 `json:"subject"`
	Description string                 `json:"description"`
	ReturnURL   string                 `json:"return_url"`
	Extra       map[string]interface{} `json:"extra"`
}

func (a *API) CreateOrder(c *gin.Context) {
	var req CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	pReq := &provider.CreateOrderReq{
		AppID:       req.AppID,
		UserID:      req.UserID,
		ProductID:   req.ProductID,
		Amount:      req.Amount,
		Currency:    req.Currency,
		Provider:    req.Provider,
		Subject:     req.Subject,
		Description: req.Description,
		ClientIP:    c.ClientIP(),
		ReturnURL:   req.ReturnURL,
		Extra:       req.Extra,
	}

	resp, err := a.svc.CreateOrder(c.Request.Context(), pReq)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (a *API) GetOrder(c *gin.Context) {
	id := c.Param("id")
	order, err := a.svc.GetOrder(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}
	c.JSON(http.StatusOK, order)
}

func (a *API) Notify(c *gin.Context) {
	providerName := c.Param("provider")

	// Delegate to service to parse and handle logic
	// But service needs request object to parse body/headers

	// For simplicity, we pass request to service
	// Wait, service returns Ack function

	// Create a new context for service
	// In Gin, we can't pass c.Request directly if we want to read body multiple times without care,
	// but provider parsing usually reads body.

	// We need to implement HandleNotify in service that takes *http.Request
	// And returns a function that writes to ResponseWriter?
	// Or we just handle logic and return data, and handler writes response?
	// The provider interface has AckNotify(w http.ResponseWriter).
	// So we should pass ResponseWriter to service? No, service shouldn't know about HTTP response writer ideally.
	// But Provider interface has it.

	// Let's adapt.
	// We'll call service, which calls provider.ParseNotify.
	// Then service does logic.
	// Then service returns the Ack function or data.

	// Wait, the AckNotify takes http.ResponseWriter. Gin has c.Writer.

	// Let's modify service.HandleNotify to return the Ack closure.
	ackFunc, err := a.svc.HandleNotify(c.Request.Context(), providerName, c.Request)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Execute Ack
	ackFunc(c.Writer)
}
