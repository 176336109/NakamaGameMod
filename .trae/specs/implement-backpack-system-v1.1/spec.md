# 背包系统统一口径实现 Spec

## Why
当前 `backpack.lua` 尚未按《背包系统设计》实现统一存储与判定口径，导致各系统在加物、扣物、时效校验、幂等与并发行为上缺乏一致性。需要补齐服务端 Lua、Unity SDK 接口与测试，确保背包能力可被商店、月卡、礼包、任务等统一复用。

## What Changes
- 在服务端实现背包核心能力：统一加物、扣物、使用、查询、过期清理、容量判定、批量原子发奖、幂等与并发控制。
- 按“是否堆叠”与“是否有时限”两组独立属性实现建模与判定，不混用业务流程规则。
- 保留资源口径：水晶按原有钻石逻辑处理，金币按原方式处理，时光沙漏按 `010300001` 处理。
- 复用 VIP 获得物品思路处理时效权益实例（如 `item_vip_active` / `item_svip_active`），避免重复实现。
- 扩展 Unity SDK 的背包相关请求/响应 DTO 与服务方法，确保接口可直接调用。
- 新增并完善 Lua 与 Unity SDK 自动化测试，覆盖核心场景与边界场景（非 UI 范围）。

## Impact
- Affected specs: 背包统一存储模型、物品有效性判定、发奖/扣减幂等、容量判定与过期清理。
- Affected code:
  - `Assets/com.nakamaservermod.unity-sdk/NakamaServerMod/domain/backpack.lua`
  - `Assets/com.nakamaservermod.unity-sdk/NakamaServerMod/service/backpack_service.lua`
  - `Assets/com.nakamaservermod.unity-sdk/NakamaServerMod/main.lua`
  - `Assets/com.nakamaservermod.unity-sdk/Runtime/InventoryService.cs`（及相关 DTO）
  - `Assets/com.nakamaservermod.unity-sdk/Tests/Runtime/*`

## ADDED Requirements
### Requirement: 统一背包入包与存储口径
系统 SHALL 仅接收已定义 `itemId` 的物品进入背包，并根据 `stackable` 与 `hasExpireAt` 独立判定存储形态与有效性。

#### Scenario: 可堆叠永久物品首次入包
- **WHEN** 发放一个不存在记录的可堆叠永久物品
- **THEN** 新增一条 `stackItemRecord`，`count` 增加且 `usedSlotCount+1`

#### Scenario: 可堆叠物品追加数量
- **WHEN** 发放一个已有记录的可堆叠物品
- **THEN** 仅累加 `count`，不新增占格

#### Scenario: 不可堆叠时效权益入包
- **WHEN** 发放 `item_vip_active` 或 `item_svip_active`
- **THEN** 按实例存储并记录时效字段，遵循 VIP 既有实例口径

### Requirement: 有效期与清理口径
系统 SHALL 以 `expireAt > 当前时间` 判定时效物品有效，并在查询或清理流程中剔除已过期库存。

#### Scenario: 读取刚到期物品
- **WHEN** 物品 `expireAt == 当前时间`
- **THEN** 返回无效，不计入有效库存

#### Scenario: 过期清理
- **WHEN** 触发登录或定时清理
- **THEN** 已过期记录不再占格，`usedSlotCount` 按实际减少

### Requirement: 原子发奖、幂等与并发安全
系统 SHALL 对单次批量发奖执行原子事务；同一 `requestId` 只生效一次；并发扣减不得出现负数或重复扣减。

#### Scenario: 批量发奖容量不足
- **WHEN** 批次内任一物品需要新增占格但容量不足
- **THEN** 整批失败，所有物品均不落库

#### Scenario: 重复发奖请求
- **WHEN** 同一 `requestId` 再次到达
- **THEN** 返回幂等成功，不重复加物

#### Scenario: 并发扣减同一数量
- **WHEN** 两个请求同时扣减最后 1 个可堆叠物品
- **THEN** 最终仅一次成功，库存不为负

### Requirement: 服务端与 Unity SDK 接口可用
系统 SHALL 暴露并对齐背包相关 RPC 与 Unity SDK 调用接口，支持加物、扣物、使用、查询、清理等非 UI 能力。

#### Scenario: Unity SDK 调用背包接口
- **WHEN** 客户端通过 SDK 调用背包 RPC
- **THEN** 返回结构化结果并与服务端判定口径一致

### Requirement: 资源别名兼容
系统 SHALL 兼容“水晶=原钻石”业务口径，不新增重复资源类型映射分支。

#### Scenario: 发放水晶
- **WHEN** 外部请求发放水晶资源
- **THEN** 按原钻石物品 ID 与原处理路径入包

## MODIFIED Requirements
### Requirement: 背包模块职责边界
背包模块在领域层负责库存状态与规则判定，服务层负责 RPC 编排与入参校验，主入口仅做 RPC 注册，不在主入口实现业务逻辑。

## REMOVED Requirements
### Requirement: 背包仅作为临时重命名兼容层
**Reason**: 该阶段目标已从“inventory→backpack 引用修复”升级为“完整背包能力实现”。
**Migration**: 保留已有接口兼容，逐步以统一背包接口替代旧散落逻辑调用。

## 测试用例对齐检查（BackpackServiceTests ↔ 背包系统设计 v1.1）

结论：`BackpackServiceTests.cs` 的已实现用例整体遵循《背包系统设计.md》v1.1 的核心口径（堆叠/时限独立、`expireAt > 当前时间` 有效、幂等、并发扣减不重复）。但仍存在若干“设计已定义、测试环境暂无法稳定构造”的跳过用例，以及少量断言粒度未完全覆盖设计关注点（例如容量/原子回滚、流水、占格回收）。

### 覆盖矩阵（设计用例 → 自动化测试）
| 设计用例 | 设计点摘要 | 对应测试方法 | 状态 | 备注 |
|---|---|---|---|---|
| C01 | 新增堆叠记录，数量累计，占格+1 | `C01_Grant_NewStackable_AddsCountAndSlot` | 覆盖 | 断言 `count=3` 与 `usedSlotCount>=1`，未对比发放前后 `+1` |
| C02 | 已有堆叠仅累加数量，不新增占格 | `C02_Grant_ExistingStackable_AccumulatesWithoutNewSlot` | 覆盖 | 显式对比发放前后 `usedSlotCount` 不变 |
| C03 | 可堆叠有时限物品（跨批次/有效期） | `C03_Grant_StackableTimedItem` | 跳过 | 备注为当前配置无法稳定构造 |
| C04 | 不可堆叠有时限（VIP 实例）写入时效记录 | `C04_Grant_VipInstance_WritesTimedRecord` | 覆盖 | 校验 `stackable=false`、`hasExpireAt=true`、`expireAt` |
| C05 | 使用堆叠道具扣减数量 | `C05_Use_Hourglass_DecrementsCount` | 覆盖 | 未验证对应流水落库 |
| C06 | 扣减至 0 后不再视为有效库存 | `C06_Consume_ToZero_RemovesEffectiveStock` | 覆盖（部分） | 仅校验 `count=0`，未验证占格减少或记录删除 |
| C07 | 不可堆叠永久物品入包 | `C07_Grant_NonStackPermanentItem` | 跳过 | 备注为当前配置普通非货币物品均按堆叠处理 |
| C08 | 过期清理后有效库存更新 | `C08_Cleanup_ExpiredItems_UpdatesUsableInventory` | 覆盖 | 校验 `cleaned=true` 与有效数量为 0 |
| C09 | 时效权益续费复用实例并延长 | `C09_Renew_Vip_ReusesInstance` | 覆盖 | 校验仅 1 条有效记录且 `expireAt` 延长 |
| C10 | 查询有效库存剔除过期记录 | `C10_Query_EffectiveInventory_ExcludesExpired` | 覆盖 | 过期 VIP 返回 `count=0` |
| C11 | 混合批量发奖成功（钱包+背包） | `C11_BatchGrant_MixedItems_Succeeds` | 覆盖 | 未覆盖“任一失败整批回滚”的设计要求 |
| C12 | 发奖幂等（同 requestId 仅生效一次） | `C12_Idempotent_GrantByRequestId_OnlyAppliesOnce` | 覆盖 | 校验 `idempotent=true` 且数量不重复累加 |
| B01 | 满包：追加已有堆叠允许成功 | `B01_FullBag_AddExistingStackable` | 跳过 | 测试环境无法稳定构造满包 |
| B02 | 满包：新增堆叠记录失败 | `B02_FullBag_AddNewStackable` | 跳过 | 同上 |
| B03 | 满包：新增实例失败 | `B03_FullBag_AddNewInstance` | 跳过 | 同上 |
| B04 | 并发扣减最后 1 个，仅一次成功 | `B04_ConcurrentConsume_LastOneOnlyOnce` | 覆盖 | 明确断言成功次数=1 且最终为 0 |
| B05 | 可堆叠限时物品跨批次共存 | `B05_StackableTimed_BatchCoexistence` | 跳过 | 同 C03：配置无法稳定构造 |
| B06 | 设计未定义 | `B06_NotDefinedInDesignDoc` | 跳过 | 明确标记跳过 |
| B07 | 变更原子性：任一失败不产生“部分成功” | `B07_AtomicFailure_MixedCurrencyAndItem_RollsBackOnConflict` | 覆盖 | 通过并发冲突场景验证“钱包变更回滚 + 背包库存一致性”（替代原 slot pressure 构造） |
| B08 | `expireAt==now` 视为无效 | `B08_ExpireAtEqualsNow_IsInvalid` | 覆盖 | 校验 `count=0` |
| B09 | 续费幂等（重复 requestId 仅一次延长） | `B09_RenewDuplicateRequest_OnlyOnce` | 覆盖 | 校验 `idempotent=true` 与数量不重复 |
| B10 | `count=0` 的记录不在有效列表 | `B10_ZeroCountRecord_NotInEffectiveList` | 覆盖 | 通过 `ListAsync` 校验不返回 |
| B11 | 非物品引用拒绝入包 | `B11_Reject_NonItemReference` | 覆盖 | 断言失败且 `error.code=GRANT_FAILED` |
| B12 | 错误命名/别名拒绝入包 | `B12_Reject_WrongAliasName` | 覆盖 | 与设计“只接受 itemId”一致 |
| B13 | 变更后版本号前进 | `B13_ReadAfterMutation_StateVersionAdvances` | 覆盖 | 断言 `version` 至少 +1 |
| B14 | 已过期限时物品不作为有效返回 | `B14_ExpiredTimedItem_NotReturnedAsValid` | 覆盖 | 通过 `ListAsync` 校验不返回 |

### 发现的缺口与风险（设计口径已定义，但测试未完全覆盖）
- 容量相关用例（B01-B03）当前均为跳过，无法自动化验证“满包判定仅在需要新增占格时触发”的关键边界。
- 已补充可稳定自动化的“混合钱包+背包并发冲突回滚”用例，并在实现中加入 Wallet↔Storage 的补偿回滚逻辑；仍建议在后续环境允许时补齐原设计的 slot pressure 场景覆盖。
- 流水（`bagChangeRecord`）落库与查询口径未在测试中断言；设计强调用于审计/补单，建议补充最小验证（至少校验每次成功变更产生一条对应 `changeType`）。
- C06 场景仅校验 `count=0`，未校验“占格回收/usedSlotCount 更新”或“记录删除/不继续占格”的设计要求。
