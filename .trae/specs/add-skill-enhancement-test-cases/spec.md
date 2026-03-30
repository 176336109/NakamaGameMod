# 技能强化件核心与边界测试 Spec

## Why
当前仓库尚未形成一套与《技能强化件设计文档》一致的自动化测试，无法持续验证“数据实例 + 统一判定口径”在演进中的正确性。需要补齐核心场景与边界场景测试，确保读取、升级、回滚与并发行为稳定且可回归。

## What Changes
- 新增技能强化件测试能力，按文档 C01~C12 与 B01~B12 建立自动化测试覆盖。
- 测试严格遵循 DDD 规则：领域层负责规则判定，服务层负责编排，主入口仅注册与转发，不在主入口承载业务逻辑。
- 对“属性读取按 itemId+level、品质来源于升级配置、升级事务原子性、并发单次成功”建立显式断言。
- 新增数据实例构建与测试辅助方法，统一管理测试前置数据，避免散落硬编码。
- 补充失败场景断言：配置缺失、碎片不足、非法等级、满级限制与迁移失败回滚。

## Impact
- Affected specs: 技能强化件配置读取口径、升级事务口径、背包 level 堆叠口径、并发升级限制口径。
- Affected code:
  - `Assets/com.nakamaservermod.unity-sdk/NakamaServerMod/domain/*`（技能强化件相关领域规则）
  - `Assets/com.nakamaservermod.unity-sdk/NakamaServerMod/service/*`（技能强化件读取与升级服务）
  - `Assets/com.nakamaservermod.unity-sdk/NakamaServerMod/main.lua`（仅 RPC 注册映射校验）
  - `Assets/com.nakamaservermod.unity-sdk/Tests/Runtime/*`（新增/扩展技能强化件测试）

## ADDED Requirements
### Requirement: 核心场景自动化回归
The system SHALL provide 针对技能强化件核心场景（C01~C12）的自动化测试，并对每个场景建立可重复执行的前置数据与结果断言。

#### Scenario: 新获得与同级叠加
- **WHEN** 执行 C01 与 C02 的发放流程
- **THEN** 断言同一 `itemId+level(+expireAt批次)` 聚合规则与 `count` 变化符合预期

#### Scenario: 读取详情口径一致
- **WHEN** 执行 C03、C07、C08、C09、C10、C12 的读取流程
- **THEN** 断言详情结果包含背包堆叠对象、当前等级属性、当前等级升级信息、品质，且读取条件符合 `itemId+level`

#### Scenario: 升级库存迁移与连续升级
- **WHEN** 执行 C04、C05、C11 的升级流程
- **THEN** 断言碎片扣减、原等级减 1、目标等级加 1、目标记录合并/新建与连续升级结果正确

#### Scenario: 跨等级隔离
- **WHEN** 执行 C06 的背包读取
- **THEN** 不同等级记录独立返回，不发生跨等级聚合

### Requirement: 边界与失败场景自动化回归
The system SHALL provide 针对边界场景（B01~B12）的自动化测试，并在失败路径验证无副作用与回滚完整性。

#### Scenario: 配置与数据缺失
- **WHEN** 执行 B01、B02、B03
- **THEN** 返回对应错误，且不扣碎片、不变更库存记录

#### Scenario: 升级失败与满级限制
- **WHEN** 执行 B04、B05、B10
- **THEN** 返回碎片不足/已满级/非法等级，且库存与碎片保持不变

#### Scenario: 并发与事务回滚
- **WHEN** 执行 B06、B11
- **THEN** 并发仅一次成功，迁移失败整笔回滚，避免重复扣碎片与等级跳变

#### Scenario: 记录清理与批次隔离
- **WHEN** 执行 B07、B08、B12
- **THEN** 验证原等级清理、同 item 不同等级不误合并、同等级不同过期批次互不影响

#### Scenario: 品质读取来源
- **WHEN** 执行 B09
- **THEN** 在属性配置无 `quality` 字段时，仍从升级配置读取品质并返回

### Requirement: DDD 分层约束下的测试实现
The system SHALL provide 符合 ddd.md 的测试实现方式，不通过跨层直接调用破坏职责边界。

#### Scenario: 分层调用约束
- **WHEN** 组织测试用例与测试辅助代码
- **THEN** 仅通过服务层入口验证业务行为；领域规则通过服务编排间接覆盖；主入口仅验证 RPC 注册映射，不承载业务判断

## MODIFIED Requirements
### Requirement: 背包测试覆盖范围
现有背包测试范围从通用背包能力扩展为“技能强化件专项口径覆盖”，确保 `level` 维度、升级碎片消耗与技能属性读取在统一模型下可回归。

## REMOVED Requirements
### Requirement: 仅人工走查技能强化件规则
**Reason**: 人工走查无法稳定覆盖并发、回滚与配置缺失等高风险边界。  
**Migration**: 将文档用例映射为自动化测试，人工走查仅保留为补充验证手段。
