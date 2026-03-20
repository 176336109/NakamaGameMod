# Tasks
- [x] Task 1: Create NotifyTask Model and Repo Methods
  - [x] SubTask 1.1: Add `NotifyTask` struct to `model.go` with fields (ID, OrderID, Status, RetryCount, MaxRetry, NextRetryAt, etc.).
  - [x] SubTask 1.2: Add methods to `Repo` interface for creating tasks, fetching pending tasks, and updating task status.
  - [x] SubTask 1.3: Implement these methods in `PostgresRepo` and `InMemoryRepo`. Add `NotifyTask` to `AutoMigrate`.
  - [x] SubTask 1.4: Add transaction support to the `Repo` interface (e.g., `Transaction(fn func(Repo) error) error`).

- [x] Task 2: Refactor HandleNotify to use Transactions
  - [x] SubTask 2.1: Wrap the order status update, callback log creation, and notify task creation inside a database transaction in `service.go`.
  - [x] SubTask 2.2: Ensure `notifyBusiness` is called only after the transaction successfully commits.

- [x] Task 3: Implement Retry Logic and Background Worker
  - [x] SubTask 3.1: Refactor `notifyBusiness` to take a `NotifyTask` instead of just an `Order`, and update the task status in the DB based on the HTTP response.
  - [x] SubTask 3.2: Create `retryer.go` with a worker that runs on a ticker, fetching pending tasks and calling `notifyBusiness`.
  - [x] SubTask 3.3: Implement exponential backoff for calculating `NextRetryAt` when a notification fails.
  - [x] SubTask 3.4: Start the background retryer in `main.go`.

# Task Dependencies
- Task 2 depends on Task 1
- Task 3 depends on Task 1 and Task 2