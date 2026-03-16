# 每日签到系统 V1.1 实现规范

## 1. 概述
根据《每日签到系统设计 V1.1》文档，实现基于账号创建时间的7天循环签到系统。该系统包含服务端 Lua 逻辑、Unity SDK 封装以及配套的测试用例。

## 2. 核心逻辑变更

### 2.1 签到周期计算 (Unified Criteria)
- **基准时间**：账号创建时间 (`account.create_time`)。
- **当前周期推导**：
  - `accountCreateDateKey` = 账号创建日的 00:00:00 (北京时间)。
  - `currentDateKey` = 当前服务器时间的 00:00:00 (北京时间)。
  - `diffDays` = `(currentDateKey - accountCreateDateKey)` 的天数差。
  - `cycleNo` (周期序号) = `floor(diffDays / 7) + 1`。
  - `currentDayIndex` (当前周期第几天) = `(diffDays % 7) + 1`。
- **重置规则**：基于上述数学公式自然推进，无需额外的“重置”操作，每次请求时动态计算。

### 2.2 数据存储结构
- **Collection**: `checkin`
- **Key**: `daily_status`
- **Value**:
  ```json
  {
    "cycleId": "C{cycleNo}", // e.g., "C1", "C2"
    "days": {
      "1": { "status": "signed", "claimAt": 1234567890, "claimType": "normal" },
      "2": { "status": "makeup_signed", "claimAt": 1234567999, "claimType": "makeup" }
    }
  }
  ```
- **注意**：如果不匹配当前的 `cycleNo`，则视为旧周期数据失效，逻辑上视为新周期初始状态。

### 2.3 奖励与消耗
- **奖励配置**：
  - Day 1: Gold x100
  - Day 2: Crystal x50
  - Day 3: Hourglass (010300001) x1
  - Day 4: Skill Shard Green (020100001) x5
  - Day 5: Mod Shard Green (030100001) x3
  - Day 6: Gold x200, Crystal x30
  - Day 7: Hourglass (010300001) x2
- **补签消耗**：固定 20 水晶 (ID: 2 / "gem")。

## 3. 接口定义 (RPC)

### 3.1 `checkin_get_state`
- **Request**: `{}`
- **Response**:
  ```json
  {
    "cycle_no": 1,
    "current_cycle_day": 3,
    "days": [
      { "day_index": 1, "status": "signed", "rewards": [...] },
      { "day_index": 2, "status": "missed", "rewards": [...] },
      { "day_index": 3, "status": "claimable", "rewards": [...] },
      { "day_index": 4, "status": "locked", "rewards": [...] }
    ],
    "makeup_cost": { "id": "gem", "count": 20 }
  }
  ```

### 3.2 `daily_checkin`
- **Request**: `{}` (默认签到“今天”)
- **Response**:
  ```json
  {
    "success": true,
    "day_index": 3,
    "status": "signed",
    "rewards": [...]
  }
  ```

### 3.3 `checkin_makeup`
- **Request**: `{ "day_index": 2 }`
- **Response**:
  ```json
  {
    "success": true,
    "day_index": 2,
    "status": "makeup_signed",
    "rewards": [...]
  }
  ```

## 4. 测试用例要求
- **命名规范**：`TestC01_场景描述`, `TestB01_边界描述`。
- **用户命名**：`C01_场景描述_时间戳`。
- **注释要求**：中文注释，包含步骤说明。
- **最终验证**：每个用例末尾必须包含“最终结果验证”注释块。
- **覆盖范围**：文档中 C01-C12 和 B01-B16。

## 5. 其他要求
- 水晶物品 ID 统一为 `gem` (对应文档中的 ID 2)。
- 确保 `main.lua` 注册了所有 RPC。
