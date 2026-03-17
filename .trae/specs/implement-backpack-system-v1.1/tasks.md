# Tasks
- [x] Task 1: 对齐背包数据模型与基础规则
  - [x] 在 `domain/backpack.lua` 建立 `itemConfig`、堆叠记录、实例记录、背包状态与变更流水结构
  - [x] 实现 `stackable` 与 `hasExpireAt` 独立判定逻辑
  - [x] 落实 `usedSlotCount` 与占格规则（新增占格才校验容量）

- [x] Task 2: 实现背包核心领域能力
  - [x] 实现统一加物（含批量原子事务）
  - [x] 实现统一扣物/用物（含数量、有效期、实例状态校验）
  - [x] 实现过期清理与有效库存查询
  - [x] 实现幂等键与并发版本控制

- [x] Task 3: 对齐 VIP 口径与资源兼容规则
  - [x] 复用 VIP 时效权益实例处理方式（新增/续费更新 `expireAt`）
  - [x] 保持金币与钻石原有处理路径
  - [x] 增加“水晶映射到原钻石口径”的兼容处理

- [x] Task 4: 完成服务层与 RPC 暴露
  - [x] 在 `service/backpack_service.lua` 编排背包接口
  - [x] 在 `main.lua` 注册背包相关 RPC（不下沉业务逻辑到 main）
  - [x] 对外返回统一错误码与结构化响应

- [x] Task 5: 完成 Unity SDK 接口对齐
  - [x] 新增或扩展 Runtime DTO（请求/响应）
  - [x] 扩展 `InventoryService.cs` 或同域服务方法
  - [x] 保证 SDK 字段命名与服务端返回一致

- [x] Task 6: 补齐自动化测试并验证
  - [x] 覆盖核心场景（C01-C12）对应的关键断言
  - [x] 覆盖边界场景（B01-B14）中的关键一致性断言
  - [x] 运行 Lua/Unity 测试并修复失败项
  - [x] 复核《背包系统设计》用例与 `BackpackServiceTests.cs` 覆盖矩阵并记录缺口

- [x] Task 7: 修复批量发奖原子回滚缺口
  - [x] 将背包批量发奖与钱包更新改为单事务提交或补偿回滚
  - [x] 在发奖失败路径回滚已写入状态，避免“部分成功”
  - [x] 增加原子回滚自动化用例并验证通过

# Task Dependencies
- Task 2 depends on Task 1.
- Task 3 depends on Task 2.
- Task 4 depends on Task 2.
- Task 5 depends on Task 4.
- Task 6 depends on Task 3, Task 4, Task 5.
