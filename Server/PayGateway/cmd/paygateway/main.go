package main

import (
	"context"
	"paygateway/internal/api"
	"paygateway/internal/model"
	"paygateway/internal/provider"
	custom_provider "paygateway/internal/provider/custom"
	gopay_provider "paygateway/internal/provider/gopay"
	"paygateway/internal/repo"
	"paygateway/internal/service"
	"paygateway/pkg/config"
	"paygateway/pkg/logger"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	// 0. Init Logger
	logger.InitLogger()
	defer logger.Sync()

	// 1. Load Config
	err := config.LoadConfig("config.yaml")
	if err != nil {
		logger.Log.Fatal("Failed to load config", zap.Error(err))
	}
	cfg := config.C

	// 2. Init DB & Repo
	var r repo.Repo
	if cfg.DB.Type == "postgres" {
		db, err := gorm.Open(postgres.Open(cfg.DB.DSN), &gorm.Config{})
		if err != nil {
			logger.Log.Fatal("Failed to connect to postgres", zap.Error(err))
		}

		// AutoMigrate models
		err = db.AutoMigrate(&model.Order{}, &model.Refund{}, &model.CallbackLog{}, &model.NotifyTask{})
		if err != nil {
			logger.Log.Fatal("Failed to auto migrate database", zap.Error(err))
		}

		r = repo.NewRepo(db)
		logger.Log.Info("Connected to PostgreSQL and migrated tables successfully.")
	} else {
		// Fallback to In-Memory Repo for demonstration if DB type is not postgres
		r = repo.NewInMemoryRepo()
		logger.Log.Info("Using In-Memory Repository.")
	}

	// 4. Init Providers
	for _, pCfg := range cfg.Providers {
		switch pCfg.Name {
		case "wechat":
			p, _ := gopay_provider.NewWechatProvider(pCfg)
			provider.Register(p)
		case "myprovider":
			p := custom_provider.NewMyProvider(pCfg)
			provider.Register(p)
		}
	}

	// 5. Init Service
	svc := service.NewPayService(r, cfg)

	// Start Retryer
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	svc.StartRetryer(ctx, 10*time.Second)

	// 6. Init API
	apiHandler := api.NewAPI(svc)

	// 7. Run Server
	router := gin.New()
	router.Use(logger.GinLogger(), gin.Recovery())
	apiHandler.RegisterRoutes(router)

	logger.Log.Info("Starting server", zap.String("addr", cfg.Server.Addr))
	if err := router.Run(cfg.Server.Addr); err != nil {
		logger.Log.Fatal("Server failed", zap.Error(err))
	}
}
