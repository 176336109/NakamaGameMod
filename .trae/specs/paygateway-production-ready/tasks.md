# Tasks
- [x] Task 1: Initialize Database Auto-Migration
  - [x] SubTask 1.1: Update `cmd/paygateway/main.go` to connect to PostgreSQL when `db.type` is "postgres", and call `db.AutoMigrate(&model.Order{}, &model.Refund{}, &model.CallbackLog{})`.
  - [x] SubTask 1.2: Update `README.md` to explain the automatic table creation process.
- [x] Task 2: Implement Structured Logging
  - [x] SubTask 2.1: Add `go.uber.org/zap` dependency.
  - [x] SubTask 2.2: Create `pkg/logger` package to initialize and provide a global logger instance.
  - [x] SubTask 2.3: Replace standard `log` usage in `main.go`, `api.go`, `service.go`, and custom providers with the new logger. Add contextual information (like OrderID, Request parameters) to log entries.
  - [x] SubTask 2.4: Add a logging middleware in Gin to log all incoming HTTP requests and their processing time.

# Task Dependencies
- Task 2 depends on Task 1