# VIP/SVIP月卡策划文档

**版本**：1.4  
**日期**：2026年3月9日  
**负责人**：马尔斯（主策划）  
**修订时间**：18:09  
**修订记录**：
- v1.1（14:29）：增加立即钻石奖励、时光沙漏奖励、磁铁与掠夺战特权
- v1.2（15:38）：统一奖励描述、明确扫荡限制、定义时光沙漏价值、修复文档错误
- v1.3（16:58）：根据CEO澄清更新关键规则（特权叠加确认）
- v1.4（18:09）：修正状态转换规则与续费规则，完全适配特权叠加设计

## 📋 重要澄清（CEO确认）
1. **VIP与SVIP特权叠加**：玩家可同时购买VIP和SVIP，享有两者全部特权
2. **时光沙漏使用规则**：当需要观看广告时，自动消耗时光沙漏1个跳过广告
3. **扫荡特权**：SVIP具有无限扫荡特权，实际实现有次数上限（50次/日）防止资源过度产出
4. **磁铁功能验证**：VIP需服务器验证状态，免费/SVIP每次使用检查广告状态
5. **时光沙漏定价**：5钻石/个（已确认）
6. **取消扫荡券**：SVIP每日奖励统一为时光沙漏×3
7. **通用物品口径**：钻石、时光沙漏与VIP/SVIP权益道具统一纳入物品体系管理

## 🎯 设计目标
1. **提升用户LTV**：通过订阅制付费提高用户长期价值
2. **改善游戏体验**：提供便利性功能，减少挫败感
3. **分级变现**：满足不同付费能力用户的需求
4. **激励留存**：每日登录奖励促进用户活跃

## 📦 月卡概览

### VIP月卡（基础版）
| 项目 | 规格 |
|------|------|
| **价格** | 18元/月 |
| **有效期** | 30天（从激活开始计算） |
| **购买方式** | 购买后立即生效，并在背包中生成1个VIP时效权益道具 |
| **目标用户** | 轻度付费玩家，愿意小额付费改善体验 |

### SVIP月卡（高级版）
| 项目 | 规格 |
|------|------|
| **价格** | 30元/月 |
| **有效期** | 30天（从激活开始计算） |
| **购买方式** | 购买后立即生效，并在背包中生成1个SVIP时效权益道具 |
| **目标用户** | 中度付费玩家，追求最佳游戏体验 |

## 🎁 特权对比表

| 特权项目 | 免费玩家 | VIP玩家 | SVIP玩家 |
|----------|----------|---------|----------|
| **立即获得钻石奖励** | 无 | 180钻石 | 300钻石 |
| **每日钻石奖励** | 无 | 30钻石/日 | 60钻石/日 |
| **每日时光沙漏奖励** | 无 | 无 | 3张/日 |
| **战斗中复活规则** | 3次/日（需观看广告） | 4次/日（需观看广告） | 3次/日（无需观看广告） |
| **扫荡次数限制** | 3次/日（需消耗体力） | 5次/日（需消耗体力） | 无限次（实际每日次数上限50次，防止资源过度产出） |
| **研究建造队列** | 默认1队列 | 默认1队列 | 2队列（+1额外队列） |
| **专属标识** | 无 | 无 | SVIP专属标识 |
| **去广告体验** | 需观看所有激励视频 | 需观看所有激励视频 | 战斗中复活无需观看广告 |
| **磁铁**（战斗中功能） | 需观看广告解锁磁铁 | 无需看广告解锁磁铁 | 需观看广告解锁磁铁 |
| **掠夺战次数** | 1次/日，看广告可增加到2次 | 1次/日，看广告可增加到2次 | 2次/日，看广告可增加到3次 |

## 💎 详细特权说明

**重要说明**：VIP和SVIP特权可以叠加。当玩家同时拥有VIP和SVIP时，享有两者全部特权，具体规则如下：
- **奖励叠加**：每日可领取VIP的30钻石 + SVIP的60钻石+3时光沙漏
- **特权叠加**：复活次数取更高值，广告要求取更优值；即同时拥有VIP和SVIP时，可复活4次且无需观看广告
- **功能叠加**：建造队列为SVIP的2队列，扫荡次数为SVIP的无限次（实际50次/日上限）
- **状态独立**：VIP和SVIP有效期独立计算，可独立续费

### 1. 每日奖励系统
#### VIP月卡
- **立即奖励**：购买VIP立即获得180钻石
- **每日奖励**：每日登录可领取30钻石（价值约3元）
- **领取规则**：激活当日立即获得1次可领取次数，需玩家手动领取；此后每日00:00增加1次可领取次数，可累积3日（防流失）
- **累计价值**：立即180钻石 + 30天共900钻石 = 1080钻石，价值108元，性价比6倍

#### SVIP月卡
- **立即奖励**：购买SVIP立即获得300钻石
- **每日奖励**：每日登录可领取60钻石（价值约6元）+ 时光沙漏×3
- **领取规则**：激活当日立即获得1次可领取次数，需玩家手动领取；此后每日00:00增加1次可领取次数，可累积3日（防流失）
- **时光沙漏价值**：每个时光沙漏价值5钻石
- **累计价值**：立即300钻石 + 30天共1800钻石 + 时光沙漏×90（价值450钻石）= 2550钻石总价值，价值255元，性价比8.5倍

### 2. 战斗中复活特权
#### 免费玩家
- 每日可复活3次
- 每次复活需观看30秒广告
- 复活后恢复50%血量

#### VIP玩家
- 每日可复活4次（+1次机会）
- 每次复活仍需观看广告，但次数更多

#### SVIP玩家
- 每日可复活3次
- 每次复活无需观看广告
- SVIP不增加复活次数，只移除复活广告要求
- **技术实现**：服务器验证SVIP状态，直接发放复活奖励

#### VIP+SVIP玩家（特权叠加）
- **每日复活总次数**：4次（取VIP的更高次数）
- **广告规则**：4次复活均无需观看广告（取SVIP的更优广告规则）
- **技术实现**：服务器需同时验证VIP和SVIP状态，复活次数按更高值结算，广告要求按更优规则结算

### 3. 扫荡特权
#### 基础规则
- 扫荡消耗体力（与手动战斗相同）
- 扫荡获得100%基础资源（金币、经验）
- 无法获得首次通关奖励、成就进度

#### 次数限制
- 免费玩家：3次/日
- VIP玩家：5次/日（+2次）
- SVIP玩家：无限次

#### 扫荡限制机制
- **免费玩家**：3次/日（需消耗体力）
- **VIP玩家**：5次/日（需消耗体力）
- **SVIP玩家**：无限次扫荡特权，实际实现中设置每日50次上限防止资源过度产出

### 4. 建造队列特权
#### SVIP专属
- 默认建造队列：1个（所有玩家相同）
- SVIP额外队列：+1个（可同时进行2项黑科技/改装）
- **效果**：节省50%等待时间，加速成长

### 5. 视觉标识
#### SVIP专属标识
- 玩家头像框带SVIP标识
- 聊天频道特殊前缀
- 排行榜特殊标记
- **目的**：满足玩家荣誉感，促进社交传播

### 6. 磁铁功能特权
#### 免费玩家
- **磁铁功能**：战斗中可使用磁铁吸附掉落物
- **解锁方式**：每次使用需观看激励视频广告
- **使用限制**：每日无使用次数限制，但每次使用都需看广告

#### VIP玩家
- **磁铁功能**：战斗中可使用磁铁吸附掉落物
- **解锁方式**：永久解锁，无需观看广告
- **优势**：提升战斗流畅度，节省时间

#### SVIP玩家
- **磁铁功能**：战斗中可使用磁铁吸附掉落物
- **解锁方式**：每次使用需观看激励视频广告（同免费玩家）
- **设计考虑**：SVIP特权已集中在其他核心体验上，磁铁作为轻度便利功能保持广告变现点

#### VIP+SVIP玩家（特权叠加）
- **磁铁功能**：战斗中可使用磁铁吸附掉落物
- **解锁方式**：永久解锁，无需观看广告（以VIP特权为准）
- **逻辑说明**：当VIP和SVIP叠加时，取最优特权。VIP的永久解锁磁铁优于SVIP的需看广告解锁

### 7. 掠夺战次数特权
#### 免费玩家
- **基础次数**：1次/日
- **增加方式**：观看激励视频广告可额外增加1次（每日最多2次）
- **策略目的**：通过广告激励增加核心玩法参与度

#### VIP玩家
- **基础次数**：1次/日
- **增加方式**：观看激励视频广告可额外增加1次（每日最多2次）
- **与免费玩家相同**：掠夺战作为核心产出玩法，保持一致的参与门槛

#### SVIP玩家
- **基础次数**：2次/日（+1次）
- **增加方式**：观看激励视频广告可额外增加1次（每日最多3次）
- **特权价值**：相比VIP/免费玩家，每日多1次基础次数，获得更多资源产出机会

#### VIP+SVIP玩家（特权叠加）
- **基础次数**：2次/日（以SVIP特权为准）
- **增加方式**：观看激励视频广告可额外增加1次（每日最多3次）
- **特权说明**：当VIP和SVIP叠加时，取最优特权。SVIP的2次基础次数优于VIP的1次

## 🔄 状态管理系统

### 月卡权益道具定义
```javascript
// 道具化设计：月卡权益本身就是背包中的时效道具
月卡权益道具 {
  instanceId: "ent_vip_xxx", // 或 "ent_svip_xxx"
  itemId: "item_vip_active", // 或 "item_svip_active"
  type: "时效权益",
  subType: "月卡",
  description: "拥有期间可领取月卡奖励并享受对应特权",
  stackable: false,
  usable: false,
  startAt: "服务器记录的购买生效时间",
  expireAt: "startAt + 30天",
  benefitPlanId: "vip_monthly" // 或 "svip_monthly"
}
```

月卡奖励配置不直接写进权益实例，而是通过 `benefitPlanId` 关联到独立的 `rewardConfig` 对象：

```javascript
rewardConfig {
  id: "vip_monthly", // 或 "svip_monthly"
  immediateItems: [{ itemId: "item_diamond", count: 180 }],
  dailyItems: [{ itemId: "item_diamond", count: 30 }],
  privileges: {
    reviveLimit: 4,
    reviveNeedsAd: true,
    sweepLimit: 5,
    queueExtraEnabled: false,
    magnetNeedsAd: false,
    plunderBaseLimit: 1,
    plunderAdLimit: 1,
    svipBadgeEnabled: false
  }
}
```

SVIP对应的 `benefitPlanId=svip_monthly`，其 `rewardConfig` 内容为：立即奖励 `item_diamond x300`，每日奖励 `item_diamond x60 + item_hourglass x3`，且 `privileges.queueExtraEnabled=true`。

### 状态管理规则
#### VIP状态管理
| VIP当前状态 | 动作 | VIP新状态 | 效果 |
|-------------|------|-----------|------|
| 未激活 | 购买VIP月卡 | VIP激活 | 立即创建 `item_vip_active` 权益实例，开始30天倒计时，发放180钻石，并创建对应权益状态对象且增加当天1次可领取日奖励次数 |
| VIP激活 | 再次购买VIP月卡 | VIP激活 | 更新同一个 `item_vip_active` 权益实例的有效期，延长30天（累积最多180天） |
| VIP激活 | 有效期结束 | 未激活 | 移除VIP特权 |

#### SVIP状态管理
| SVIP当前状态 | 动作 | SVIP新状态 | 效果 |
|--------------|------|------------|------|
| 未激活 | 购买SVIP月卡 | SVIP激活 | 立即创建 `item_svip_active` 权益实例，开始30天倒计时，发放300钻石，并创建对应权益状态对象且增加当天1次可领取日奖励次数 |
| SVIP激活 | 再次购买SVIP月卡 | SVIP激活 | 更新同一个 `item_svip_active` 权益实例的有效期，延长30天（累积最多180天） |
| SVIP激活 | 有效期结束 | 未激活 | 移除SVIP特权 |

#### 特权叠加规则
- VIP和SVIP状态独立管理，可同时激活
- 同时激活时，玩家享有全部VIP和SVIP特权
- 每日奖励独立累计并手动领取：VIP和SVIP分别维护各自的权益状态对象，VIP每日30钻石，SVIP每日60钻石+3时光沙漏

### 有效期管理
1. **服务器计时**：激活时间由服务器记录，防止客户端作弊
2. **每日检查**：服务器定时任务每日检查月卡有效期
3. **客户端同步**：登录时同步剩余天数与特权状态
4. **过期提醒**：到期前3天、1天、当天推送提醒

### 续费规则
1. **提前续费**：有效期内再次购买，延长有效期（VIP+30天，SVIP+30天）
2. **过期续费**：过期后购买，重新开始30天
3. **叠加购买**：VIP和SVIP可独立购买与续费，有效期独立计算
4. **最大累积**：每张月卡有效期可累积，上限180天（防囤积）
5. **超上限处理**：若本次续费后将超过180天，则本次续费不生效，不更新权益道具有效期

## 🎮 游戏内集成点

### 1. 商店展示
- 月卡商品位于商店首页显著位置
- 显示原价、折扣价、剩余购买次数
- 已激活月卡显示剩余天数

### 2. 每日奖励领取
- 主界面增加"月卡奖励"入口
- 红点提示未领取奖励
- 一键领取所有每日奖励

### 3. 特权状态显示
- 个人资料页面显示月卡类型与剩余天数
- 战斗界面显示剩余复活次数与当前是否免广告
- 扫荡界面显示剩余扫荡次数

### 4. 过期提示
- 主界面月卡图标倒计时
- 即将过期时增加特效提醒
- 过期后灰化显示，点击跳转商店

## 🧱 测试建模口径（统一按物品处理）

为满足“任何东西都当成物品”的实现目标，测试用例统一采用“购买即生成时效权益物品 + 通用物品发奖 + 分离权益状态与玩法日切状态”的口径。VIP、SVIP购买后立即生效，并在背包中存在一个时效权益道具作为权益证明；钻石、时光沙漏也统一视为普通物品；每日奖励累计状态与第二队列开关不再揉进权益实例对象，而是拆分到独立状态对象。

### 1. 物品模型定义

| 物品ID | 物品名称 | 类型 | 是否进背包 | 是否可使用 | 是否有时效 | 逻辑含义 |
|--------|----------|------|------------|------------|------------|----------|
| `item_vip_active` | VIP权益道具 | 时效物品 | 是 | 否 | 是 | 购买VIP后立即进入背包；存在且未过期即代表VIP生效；到期后自动失效 |
| `item_svip_active` | SVIP权益道具 | 时效物品 | 是 | 否 | 是 | 购买SVIP后立即进入背包；存在且未过期即代表SVIP生效；到期后自动失效 |
| `item_diamond` | 钻石 | 普通物品 | 是 | 否 | 否 | 月卡立即奖励与每日奖励都以该物品形式发放 |
| `item_hourglass` | 时光沙漏 | 普通物品 | 是 | 否 | 否 | SVIP每日奖励发放该物品；有广告需求时自动消耗1个跳过广告 |

### 2. 数据对象拆分

#### 2.1 可堆叠物品对象（stackItemRecord）

| 字段 | 含义 |
|------|------|
| `itemType` | 物品类型，如 `currency` |
| `itemId` | 物品类型ID，如 `item_diamond` / `item_hourglass` |
| `count` | 当前持有数量 |
| `hasExpireAt` | 是否有时效；钻石、时光沙漏为 `false` |
| `expireAt` | 过期时间；无时效时为空 |

说明：
- 可堆叠物品按“同一背包下同一 `itemId`、同一过期批次对应一条记录”处理
- 钻石、时光沙漏都属于普通堆叠物品，不为每一份奖励单独生成实例ID
- `itemType` 取自物品配置，用于筛选和展示
- `hasExpireAt=true` 时必须同时存在 `expireAt`
- 发奖、扣减、消耗统一直接变更 `count`
- 文档统一使用 `count` 表示数量，不使用 `delta`

#### 2.2 不可堆叠有时限物品实例（VIP/SVIP权益样例）

| 字段 | 含义 |
|------|------|
| `instanceId` | 权益实例唯一ID |
| `itemId` | 物品类型ID |
| `startAt` | 激活时间 |
| `expireAt` | 过期时间 |
| `benefitPlanId` | 权益配置ID，如 `vip_monthly` / `svip_monthly` |

说明：
- 权益实例对象只表达“资格”和“时效”
- 对象本身已存放在玩家自己的 Storage 下，不重复保存 `ownerId`
- 该对象是“不可堆叠 + 有时限”组合在月卡系统中的具体样例
- 是否生效只看 `expireAt > 当前时间`，不再单独维护 `status`
- 不再保存奖励累计字段
- 不再保存玩法日切计数字段
- 不再直接保存 `rewardConfig`

#### 2.3 权益状态对象

| 字段 | 含义 |
|------|------|
| `instanceId` | 关联的权益实例ID |
| `pendingClaimDays` | 当前累计未领取的每日奖励天数，最多3 |
| `lastRefreshAt` | 最近一次累计可领奖励天数的刷新时间 |
| `lastClaimAt` | 最近一次成功领取每日奖励的时间 |
| `queueExtraEnabled` | 是否允许开启第二队列；VIP为 `false`，SVIP为 `true` |

说明：
- 激活成功时，`pendingClaimDays` 立即加1
- 每日00:00刷新时，若权益仍有效，则 `pendingClaimDays` 加1，最大累计到3
- 领取成功后，`pendingClaimDays` 减1
- `queueExtraEnabled` 由对应 `rewardConfig.privileges` 投影到玩家状态中，便于业务模块直接读取
- `queueExtraEnabled` 是否真正生效仍以关联权益实例未过期为前提

#### 2.4 权益配置对象（rewardConfig）

| 字段 | 含义 |
|------|------|
| `id` | 配置ID，与 `benefitPlanId` 对应 |
| `immediateItems` | 激活立即发放的物品列表 |
| `dailyItems` | 每次领取每日奖励时发放的物品列表 |
| `privileges` | 特权配置，如复活次数、扫荡上限、`queueExtraEnabled` 等 |

说明：
- `rewardConfig` 是配置实例，不随玩家购买复制进背包
- 权益实例只保存 `benefitPlanId`，运行时按该ID读取配置
- `immediateItems`、`dailyItems` 中每一项都用 `count` 表示本次应发数量
- 需要热更的奖励和特权都放在这里维护

#### 2.5 玩法日切状态对象

| 字段 | 含义 |
|------|------|
| `dateKey` | 自然日标识，如 `2026-03-11` |
| `reviveUsed` | 当日已消耗复活次数 |
| `reviveAdUsed` | 当日已走广告校验的复活次数 |
| `sweepUsed` | 当日已消耗扫荡次数 |
| `plunderBaseUsed` | 当日已消耗基础掠夺战次数 |
| `plunderAdUsed` | 当日已消耗广告补充次数 |

说明：
- 按“账号+日期”维护玩法日切状态
- VIP、SVIP、VIP+SVIP的次数上限与广告规则，在运行时根据当前有效权益组合判定

### 3. 统一判定口径

| 规则项 | 统一口径 |
|--------|----------|
| VIP生效 | 存在 `expireAt > 当前时间` 的 `item_vip_active` 权益实例 |
| SVIP生效 | 存在 `expireAt > 当前时间` 的 `item_svip_active` 权益实例 |
| 配置来源 | 奖励与特权配置通过权益实例上的 `benefitPlanId` 读取对应 `rewardConfig` |
| 特权叠加 | 两个权益实例同时有效时，奖励累加；复活次数取更高值，广告要求取更优值；其他功能取最优或并集 |
| 激活当日奖励 | 激活成功时，对应权益状态对象的 `pendingClaimDays` 立即加1，玩家需手动领取当天日奖励 |
| 每日奖励 | 每日00:00为有效权益实例对应的权益状态对象执行累计；`pendingClaimDays` 最大累计到3；不生成任何奖励包物品 |
| 奖励领取 | 领取时先校验权益实例仍有效，再校验权益状态对象 `pendingClaimDays>0`；成功后扣减1天，并按 `benefitPlanId` 对应 `rewardConfig` 发放物品 |
| 到期后领取 | 权益实例过期后，即使权益状态对象 `pendingClaimDays>0` 也不可继续领取 |
| 复活次数 | 从玩法日切状态对象读取 `reviveUsed`；上限由当前权益组合判定：免费3次，VIP4次，SVIP3次，VIP+SVIP4次 |
| 复活广告 | 从玩法日切状态对象读取 `reviveAdUsed`；是否需要广告由当前权益组合判定：免费和VIP需广告，SVIP与VIP+SVIP免广告 |
| 自动跳广告 | 当玩法需要广告时，若背包存在 `item_hourglass`，优先自动消耗1个；否则走广告流程 |
| 扫荡次数 | 从玩法日切状态对象读取 `sweepUsed`；上限由当前权益组合判定：免费3次，VIP5次，SVIP50次 |
| 掠夺战次数 | 从玩法日切状态对象读取 `plunderBaseUsed` 与 `plunderAdUsed`；上限由当前权益组合判定 |
| 第二队列 | 从权益状态对象读取 `queueExtraEnabled`；仅当关联权益实例未过期时允许开启第二队列 |
| 独立续费 | 续费本质为更新对应权益实例的 `expireAt` |
| 续费上限 | 若续费后将超过180天，则续费失败，不延长有效期 |
| 物品上限 | 物品上限校验不在月卡模块处理；月卡模块只负责按配置发放 `item_diamond`、`item_hourglass` 等物品 |
| 配置热更 | 奖励内容跟随当前配置；配置说给什么，领取时就给什么 |
| 支付回滚/退款 | 不在月卡模块处理；由专门管理后台执行退款处理 |

## ✅ 核心场景用例（仅逻辑与预期数据）

| 用例ID | 场景 | 前置数据 | 触发 | 预期数据 |
|--------|------|----------|------|----------|
| C01 | 购买VIP后立即生效 | 不存在未过期 `item_vip_active`；`item_diamond=D0` | 购买VIP月卡 | 新增 `item_vip_active` 权益实例 x1；`instanceId=I1`；`startAt=当前时间`；`expireAt=startAt+30天`；`benefitPlanId=vip_monthly`；新增对应权益状态对象：`instanceId=I1`，`pendingClaimDays=1`，`queueExtraEnabled=false`；`item_diamond=D0+180`；VIP权益立即生效 |
| C02 | 购买SVIP后立即生效 | 不存在未过期 `item_svip_active`；`item_diamond=D0` | 购买SVIP月卡 | 新增 `item_svip_active` 权益实例 x1；`instanceId=I2`；`startAt=当前时间`；`expireAt=startAt+30天`；`benefitPlanId=svip_monthly`；新增对应权益状态对象：`instanceId=I2`，`pendingClaimDays=1`，`queueExtraEnabled=true`；`item_diamond=D0+300`；SVIP权益立即生效 |
| C03 | 已有VIP时购买SVIP | 已存在未过期 `item_vip_active`；不存在未过期 `item_svip_active` | 购买SVIP月卡 | `item_vip_active` 保持不变；新增 `item_svip_active` 权益实例与其对应权益状态对象；账号同时拥有两类权益；奖励与特权按叠加规则生效 |
| C04 | VIP续费延长有效期 | 已存在未过期 `item_vip_active` 权益实例；原 `expireAt=T1` | 再次购买VIP月卡 | 同一个VIP权益实例继续有效；`expireAt=T1+30天`；若累积未超过180天则续费成功 |
| C05 | SVIP续费延长有效期 | 已存在未过期 `item_svip_active` 权益实例；原 `expireAt=T1` | 再次购买SVIP月卡 | 同一个SVIP权益实例继续有效；`expireAt=T1+30天`；若累积未超过180天则续费成功 |
| C06 | VIP每日可领奖励天数累计 | 存在未过期 `item_vip_active`；对应权益状态对象 `pendingClaimDays=0` | 跨过00:00 | 对应权益状态对象 `pendingClaimDays=1`；不生成新物品 |
| C07 | SVIP每日可领奖励天数累计 | 存在未过期 `item_svip_active`；对应权益状态对象 `pendingClaimDays=0` | 跨过00:00 | 对应权益状态对象 `pendingClaimDays=1`；不生成新物品 |
| C08 | 双月卡每日奖励独立累计 | 同时存在未过期 `item_vip_active` 和 `item_svip_active`；两个权益状态对象 `pendingClaimDays=0` | 跨过00:00 | 两个权益状态对象的 `pendingClaimDays` 各自+1 |
| C08A | 激活当日手动领取VIP日奖励 | 存在刚激活的 `item_vip_active`；对应权益状态对象 `pendingClaimDays=1`；`item_diamond=D0` | 手动领取当天VIP日奖励 | `pendingClaimDays=0`；`item_diamond=D0+30` |
| C08B | 激活当日手动领取SVIP日奖励 | 存在刚激活的 `item_svip_active`；对应权益状态对象 `pendingClaimDays=1`；`item_diamond=D0`；`item_hourglass=H0` | 手动领取当天SVIP日奖励 | `pendingClaimDays=0`；`item_diamond=D0+60`；`item_hourglass=H0+3` |
| C09 | 领取VIP每日奖励 | 存在未过期 `item_vip_active`；对应权益状态对象 `pendingClaimDays=1`；`item_diamond=D0` | 领取VIP每日奖励 | `pendingClaimDays=0`；`item_diamond=D0+30` |
| C10 | 领取SVIP每日奖励 | 存在未过期 `item_svip_active`；对应权益状态对象 `pendingClaimDays=1`；`item_diamond=D0`；`item_hourglass=H0` | 领取SVIP每日奖励 | `pendingClaimDays=0`；`item_diamond=D0+60`；`item_hourglass=H0+3` |
| C11 | 双月卡一键领取 | 同时存在未过期 `item_vip_active` 和 `item_svip_active`；两个权益状态对象 `pendingClaimDays=1`；`item_diamond=D0`；`item_hourglass=H0` | 一键领取月卡奖励 | 两个权益状态对象的 `pendingClaimDays` 各减1；`item_diamond=D0+90`；`item_hourglass=H0+3` |
| C12 | SVIP免广告复活 | 存在未过期 `item_svip_active`；`dailyState.reviveUsed=0`；`dailyState.reviveAdUsed=0` | 连续触发4次复活 | 前3次直接成功且无需广告；`dailyState.reviveUsed=3`；`dailyState.reviveAdUsed=0`；第4次失败 |
| C13 | VIP广告复活 | 存在未过期 `item_vip_active`；`dailyState.reviveUsed=0`；`dailyState.reviveAdUsed=0`；背包无时光沙漏 | 连续触发5次复活 | 前4次均需广告校验后成功；`dailyState.reviveUsed=4`；`dailyState.reviveAdUsed=4`；第5次失败 |
| C14 | VIP+SVIP复活规则 | 同时存在未过期 `item_vip_active` 和 `item_svip_active`；`dailyState.reviveUsed=0`；`dailyState.reviveAdUsed=0` | 连续触发5次复活 | 前4次均成功且无需广告；`dailyState.reviveUsed=4`；`dailyState.reviveAdUsed=0`；第5次失败 |
| C15 | 时光沙漏自动跳过广告 | 玩家需要触发广告玩法；背包有 `item_hourglass` x2 | 触发一次需要广告的复活/磁铁/掠夺战补次 | 自动消耗 `item_hourglass` x1；本次不进入广告流程；对应玩法成功结算 |
| C16 | 免费玩家磁铁使用 | 无VIP；背包无时光沙漏 | 战斗中触发磁铁 | 必须走广告校验；广告完成后磁铁生效 |
| C17 | VIP玩家磁铁使用 | 存在未过期 `item_vip_active` | 战斗中触发磁铁 | 不需要广告；不消耗时光沙漏；磁铁直接生效 |
| C18 | SVIP玩家磁铁使用 | 存在未过期 `item_svip_active`；背包有 `item_hourglass` x1 | 战斗中触发磁铁 | 按“需广告”口径判定；自动消耗 `item_hourglass` x1；磁铁生效 |
| C19 | 免费/VIP/SVIP扫荡上限 | 分别准备三种账号；体力充足；`dailyState.sweepUsed=0` | 连续扫荡直到失败 | 免费第4次失败；VIP第6次失败；SVIP第51次失败；每次仅发基础资源 |
| C20 | SVIP额外建造队列 | 存在未过期 `item_svip_active`；对应权益状态对象 `queueExtraEnabled=true`；主队列空闲；额外队列空闲 | 同时开启2个研究/改装 | 两个任务均成功开始；第二队列资格以 `queueExtraEnabled=true` 且关联权益未过期为准 |
| C21 | 掠夺战次数叠加后取最优 | 同时存在未过期 `item_vip_active` 和 `item_svip_active`；`dailyState.plunderBaseUsed=0`；`dailyState.plunderAdUsed=0` | 连续发起掠夺战直到失败 | 基础2次成功；再通过广告或时光沙漏补1次成功；总上限3次；第4次失败 |
| C22 | SVIP标识展示 | 存在未过期 `item_svip_active` | 读取角色展示数据 | 头像框、聊天前缀、排行榜均带SVIP标识 |

## ⚠️ 边界情况用例（仅逻辑与预期数据）

| 用例ID | 场景 | 前置数据 | 触发 | 预期数据 |
|--------|------|----------|------|----------|
| B01 | VIP过期后SVIP仍有效 | 同时存在 `item_vip_active` 和 `item_svip_active`；VIP先到期，SVIP未到期 | 时间推进到VIP过期 | `item_vip_active` 失效；复活规则从“4次免广告”切回“3次免广告”；VIP每日奖励、VIP磁铁免广告失效；SVIP队列、SVIP标识、SVIP每日奖励仍保留 |
| B02 | SVIP过期后VIP仍有效 | 同时存在 `item_vip_active` 和 `item_svip_active`；SVIP先到期，VIP未到期 | 时间推进到SVIP过期 | `item_svip_active` 失效；复活规则从“4次免广告”切回“4次需广告”；SVIP第二队列、SVIP标识、SVIP每日奖励失效；VIP磁铁免广告仍保留 |
| B03 | 双卡同时过期 | `item_vip_active` 与 `item_svip_active` 同时到期 | 时间超过二者 `expireAt` | 两个权益物品均失效；所有月卡派生权益全部失效 |
| B04 | 每日奖励累计上限 | 存在未过期权益实例；对应权益状态对象连续4天未领取 | 第4次每日刷新 | 对应权益状态对象 `pendingClaimDays` 最大仍为3；不得增长到4 |
| B05 | 购买当日奖励与00:00累计并存 | 购买月卡前对应权益状态对象 `pendingClaimDays=0` | 购买后跨到次日00:00 | 购买成功时 `pendingClaimDays=1`；若当日未领，00:00后再+1；最终最多为2 |
| B06 | 23:59购买月卡 | 当前时间23:59；购买前无对应权益道具 | 购买月卡并跨到00:00 | 购买时创建对应权益状态对象且 `pendingClaimDays=1`；00:00后 `pendingClaimDays=2`；玩家需手动领取，不自动发放 |
| B07 | 续费达到上限180天 | 已存在未过期VIP或SVIP权益，剩余天数接近180天 | 再次购买同类月卡 | 本次续费失败；背包中的权益道具保持不变；`expireAt` 保持不变 |
| B08 | 同一购买请求重复提交 | 不存在对应权益道具；客户端因超时重发同一购买请求 | 服务端收到同一购买请求两次 | 只创建1个权益道具；立即钻石只增加1次；有效期只记录1次 |
| B09 | 同一奖励领取请求重复提交 | 存在未过期权益物品；对应权益状态对象 `pendingClaimDays=1` | 服务端收到两次领取请求 | 仅第一次成功；`pendingClaimDays` 只减1次；`item_diamond`、`item_hourglass` 等奖励物品只增加1次 |
| B10 | 同账号双端同时领取奖励 | 同一账号双端在线；对应权益状态对象 `pendingClaimDays=1` | 双端同时领取 | 最终只成功1次；`pendingClaimDays` 不得减成负数；奖励物品无重复增加 |
| B11 | 同账号双端同时开启第二队列 | 同一SVIP账号双端在线；对应权益状态对象 `queueExtraEnabled=true`；额外队列空闲 | 双端同时提交第二队列任务 | 最终只有1个任务成功占用额外队列；不得出现第二队列超开 |
| B12 | 体力不足时扫荡 | 账号拥有扫荡权限；体力不足；`dailyState.sweepUsed=S0` | 发起扫荡 | 扫荡失败；`dailyState.sweepUsed` 保持 `S0`；不扣体力；不发奖励 |
| B13 | SVIP第4次复活无时光沙漏 | 仅存在未过期 `item_svip_active`；`dailyState.reviveUsed=3`；`dailyState.reviveAdUsed=0`；背包无时光沙漏 | 再次触发复活 | 第4次直接失败；SVIP不增加复活次数，只移除前3次复活的广告要求 |
| B14 | 时光沙漏不足时广告回退 | 玩法需要广告；背包 `item_hourglass` x0 | 触发广告玩法 | 不可跳过广告，必须进入广告校验流程 |
| B15 | 免费玩家持有时光沙漏 | 免费玩家无任何月卡；背包 `item_hourglass` x1 | 触发一次需要广告的磁铁/复活/掠夺战补次 | 自动消耗 `item_hourglass` x1；本次跳过广告；对应玩法成功 |
| B16 | SVIP 50次扫荡封顶 | 存在未过期 `item_svip_active`；体力充足；`dailyState.sweepUsed=49` | 再连续扫荡2次 | 第50次成功；第51次失败；`dailyState.sweepUsed=50` |
| B17 | 掠夺战广告补次重复申请 | 账号已有基础次数用完；`dailyState.plunderAdUsed=0` | 重复申请广告补次两次以上 | 每日最多只补1次；第2次补次失败 |
| B18 | SVIP过期时额外队列有进行中任务 | `item_svip_active` 即将过期；对应权益状态对象 `queueExtraEnabled=true`；第二队列已有进行中项目 | 超过 `expireAt` | SVIP模块仅移除第二队列开启权限；进行中的队列任务不由SVIP模块处理 |
| B19 | 到期后仍有未领取每日奖励天数 | 对应权益物品已过期；对应权益状态对象 `pendingClaimDays>0` | 尝试领取每日奖励 | 领取失败；`pendingClaimDays` 不再可用；不发放任何奖励 |
| B20 | 标识失效一致性 | `item_svip_active` 刚过期 | 立即查询头像框、聊天、排行榜 | 三处标识应同一时刻失效，不能局部残留 |
| B21 | 物品接近上限时发立即奖励 | 购买月卡前 `item_diamond` 接近上限 | 购买月卡 | 月卡模块仍按配置发放立即奖励物品；`item_diamond` 是否溢出、截断或转邮件由物品模块处理 |
| B22 | 物品接近上限时领SVIP每日奖励 | 存在未过期 `item_svip_active`；对应权益状态对象 `pendingClaimDays=1`；`item_diamond` 或 `item_hourglass` 接近上限 | 领取SVIP每日奖励 | 月卡模块仍按配置发放 `item_diamond x60` 和 `item_hourglass x3`；物品上限处理由物品模块负责 |
| B23 | 每日刷新幂等 | 权益物品已存在，且当天刷新已执行一次 | 再次登录、重连或重复跑刷新任务 | 对应权益状态对象 `pendingClaimDays` 不得重复增加；日切玩法状态不得重复重置 |
| B24 | 配置热更影响存量实例 | 已存在未过期权益物品 | 后台修改月卡奖励配置后再领取奖励 | 奖励按当前配置发放；配置说给什么，领取时就给什么 |
| B25 | 支付回滚或退款 | 月卡已激活，立即奖励已发，部分权益已用 | 支付回滚/退款 | 月卡模块不处理退款回滚；由专门管理后台执行退款处理 |
