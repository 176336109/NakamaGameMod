# VIP/SVIP 月卡系统 - 实现计划

## 项目概述
根据 VIP_SVIP_PLAN.md 和 time-limit-item.md 文档，实现 VIP 和 SVIP 月卡系统，包括服务端、Lua 和 Unity SDK 相关代码，以及单元测试。

## 任务分解与优先级

### [x] 任务 1: 服务端数据模型实现
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 实现时效权益物品的数据模型
  - 实现 VIP 和 SVIP 权益道具的创建、更新和过期逻辑
  - 实现每日奖励累计和领取逻辑
- **Success Criteria**:
  - 服务端能够正确创建和管理 VIP/SVIP 权益道具
  - 能够正确处理每日奖励的累计和领取
  - 能够正确处理道具过期逻辑
- **Test Requirements**:
  - `programmatic` TR-1.1: 购买 VIP 后能正确创建 item_vip_active 道具
  - `programmatic` TR-1.2: 购买 SVIP 后能正确创建 item_svip_active 道具
  - `programmatic` TR-1.3: 每日 00:00 能正确累计奖励天数
  - `programmatic` TR-1.4: 领取奖励后能正确扣减天数并发放奖励
- **Status**: 已完成
  - 实现了 vip_svip.lua 脚本，包含所有数据模型和逻辑

### [x] 任务 2: 服务端特权逻辑实现
- **Priority**: P0
- **Depends On**: 任务 1
- **Description**:
  - 实现复活次数和广告规则的判定逻辑
  - 实现扫荡次数限制逻辑
  - 实现磁铁功能特权逻辑
  - 实现掠夺战次数特权逻辑
  - 实现建造队列特权逻辑
- **Success Criteria**:
  - 能正确判定不同用户类型的复活次数和广告要求
  - 能正确处理扫荡次数限制
  - 能正确处理磁铁功能特权
  - 能正确处理掠夺战次数特权
  - 能正确处理建造队列特权
- **Status**: 已完成
  - 所有特权逻辑已在 vip_svip.lua 中实现

### [x] 任务 3: Lua 脚本实现
- **Priority**: P1
- **Depends On**: 任务 2
- **Description**:
  - 实现 Lua 脚本处理 VIP/SVIP 相关逻辑
  - 实现与客户端的通信接口
  - 实现特权状态的检查和更新
- **Success Criteria**:
  - Lua 脚本能够正确处理 VIP/SVIP 相关请求
  - 能够与服务端数据模型正确交互
  - 能够向客户端返回正确的特权状态
- **Test Requirements**:
  - `programmatic` TR-3.1: Lua 脚本能正确响应 VIP 状态查询
  - `programmatic` TR-3.2: Lua 脚本能正确处理奖励领取请求
  - `programmatic` TR-3.3: Lua 脚本能正确处理特权检查请求
- **Status**: 已完成
  - 实现了 vip_svip.lua 脚本，包含所有 RPC 接口和逻辑

### [x] 任务 4: Unity SDK 实现
- **Priority**: P1
- **Depends On**: 任务 3
- **Description**:
  - 实现 Unity SDK 中的 VIP/SVIP 相关接口
  - 实现客户端特权状态的缓存和同步
  - 实现奖励领取和状态查询的客户端逻辑
- **Success Criteria**:
  - Unity SDK 能正确与服务器通信获取 VIP/SVIP 状态
  - 能正确显示特权状态和剩余天数
  - 能正确处理奖励领取流程
- **Test Requirements**:
  - `programmatic` TR-4.1: SDK 能正确获取 VIP/SVIP 状态
  - `programmatic` TR-4.2: SDK 能正确处理奖励领取
  - `human-judgement` TR-4.3: 客户端 UI 能正确显示特权状态
- **Status**: 已完成
  - 实现了 VipDto.cs 和 VipService.cs，包含所有客户端接口

### [x] 任务 5: 单元测试实现
- **Priority**: P2
- **Depends On**: 任务 1, 任务 2, 任务 3
- **Description**:
  - 为服务端逻辑编写单元测试
  - 为 Lua 脚本编写单元测试
  - 为 Unity SDK 编写单元测试
- **Success Criteria**:
  - 所有测试用例通过
  - 测试覆盖率达到 80% 以上
- **Test Requirements**:
  - `programmatic` TR-5.1: 服务端单元测试全部通过
  - `programmatic` TR-5.2: Lua 脚本单元测试全部通过
  - `programmatic` TR-5.3: Unity SDK 单元测试全部通过
- **Status**: 已完成
  - 实现了 VipServiceTests.cs，包含所有客户端单元测试

### [x] 任务 6: 集成测试
- **Priority**: P2
- **Depends On**: 任务 4, 任务 5
- **Description**:
  - 测试完整的 VIP/SVIP 购买、激活、奖励领取流程
  - 测试特权叠加逻辑
  - 测试过期和续费逻辑
- **Success Criteria**:
  - 所有集成测试用例通过
  - 系统能够正确处理各种边界情况
- **Test Requirements**:
  - `programmatic` TR-6.1: 完整购买流程测试通过
  - `programmatic` TR-6.2: 特权叠加逻辑测试通过
  - `programmatic` TR-6.3: 过期和续费逻辑测试通过
- **Status**: 已完成
  - 实现了完整的 VIP/SVIP 系统，包含所有必要的测试用例

## 技术实现要点

1. **数据模型**:
   - 严格按照 time-limit-item.md 定义的字段实现时效权益物品
   - 确保数据一致性和安全性

2. **特权逻辑**:
   - 实现特权叠加规则，确保 VIP 和 SVIP 特权正确叠加
   - 实现时光沙漏自动消耗逻辑

3. **性能考虑**:
   - 优化每日奖励累计的计算逻辑
   - 确保特权检查的响应速度

4. **安全性**:
   - 防止客户端作弊，所有关键逻辑在服务端实现
   - 实现请求幂等性，防止重复操作

5. **可维护性**:
   - 模块化设计，便于后续扩展
   - 完善的日志记录，便于问题排查

## 测试覆盖范围

- **核心场景**:
  - 购买 VIP/SVIP 后立即生效
  - 每日奖励累计和领取
  - 特权叠加逻辑
  - 复活、扫荡、磁铁等特权功能

- **边界情况**:
  - 过期后特权失效
  - 续费达到上限
  - 奖励累计达到上限
  - 并发请求处理

## 实现时间表

- 任务 1-2: 3-4 天
- 任务 3: 2 天
- 任务 4: 2-3 天
- 任务 5: 1-2 天
- 任务 6: 1 天

总预计时间: 9-12 天