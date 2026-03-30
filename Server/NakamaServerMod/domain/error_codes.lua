local M = {}

-- 统一错误码字典：键为业务语义，值为数值码与默认文案。
local ERROR_MAP = {
    COMMON_INTERNAL_ERROR = { code = 10000001, message = "内部服务异常" },
    COMMON_INVALID_PARAM = { code = 10000001, message = "参数非法" },
    COMMON_STORAGE_READ_FAILED = { code = 10000002, message = "存储读失败" },
    COMMON_STORAGE_WRITE_FAILED = { code = 10000003, message = "存储写失败" },
    WALLET_INSUFFICIENT_GEM = { code = 100001, message = "水晶不足" },
    BACKPACK_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    BACKPACK_ITEM_NOT_FOUND = { code = 600001, message = "物品不存在" },
    BACKPACK_INSUFFICIENT_ITEM = { code = 600002, message = "物品数量不足" },
    BACKPACK_CAPACITY_EXCEEDED = { code = 600003, message = "背包容量不足" },
    BACKPACK_INVALID_PARAM = { code = 600004, message = "背包参数非法" },
    BACKPACK_GRANT_FAILED = { code = 600005, message = "物品发放失败" },
    BACKPACK_CONSUME_FAILED = { code = 600006, message = "物品消耗失败" },
    GACHA_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    GACHA_BANNER_NOT_FOUND = { code = 110001, message = "卡池不存在" },
    GACHA_INSUFFICIENT_CURRENCY = { code = 110002, message = "抽卡货币不足" },
    GACHA_GRANT_FAILED = { code = 110003, message = "抽卡奖励发放失败" },
    SHOP_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    SHOP_GOODS_NOT_FOUND = { code = 300001, message = "商品不存在" },
    SHOP_LIMIT_REACHED = { code = 300003, message = "限购次数不足" },
    SHOP_INVALID_PARAM = { code = 300004, message = "购买参数非法" },
    SHOP_GRANT_FAILED = { code = 300005, message = "发货失败" },
    SHOP_CREATE_ORDER_FAILED = { code = 300006, message = "创建订单失败" },
    CHECKIN_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    CHECKIN_ALREADY_CLAIMED = { code = 400001, message = "今日已签到" },
    CHECKIN_INVALID_PARAM = { code = 400002, message = "签到参数非法" },
    CHECKIN_INVALID_ACTION = { code = 400002, message = "签到参数非法" },
    CHECKIN_CONFIG_ERROR = { code = 400003, message = "签到配置错误" },
    CHECKIN_INSUFFICIENT_COST = { code = 400004, message = "补签成本不足" },
    CHECKIN_GRANT_FAILED = { code = 400005, message = "签到奖励发放失败" },
    GIFT_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    GIFT_NOT_FOUND = { code = 500001, message = "礼包不存在" },
    GIFT_LIMIT_REACHED = { code = 500003, message = "礼包限购次数不足" },
    GIFT_NOT_ELIGIBLE = { code = 500004, message = "礼包领取条件不满足" },
    GIFT_GRANT_FAILED = { code = 500005, message = "礼包奖励发放失败" },
    GIFT_ALREADY_CLAIMED = { code = 500006, message = "礼包已领取" },
    GIFT_CREATE_ORDER_FAILED = { code = 800002, message = "验单失败" },
    IAP_CREATE_ORDER_FAILED = { code = 800002, message = "验单失败" },
    IAP_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    IAP_INVALID_PAYLOAD = { code = 800004, message = "支付回调参数非法" },
    IAP_MISSING_PRODUCT = { code = 800004, message = "支付回调参数非法" },
    IAP_USER_NOT_FOUND = { code = 10000001, message = "内部服务异常" },
    IAP_PAYGATEWAY_FAILED = { code = 800002, message = "验单失败" },
    IAP_PROCESS_REWARD_FAILED = { code = 800005, message = "IAP 发货失败" },
    VIP_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    VIP_PLAN_INVALID = { code = 900001, message = "会员方案非法" },
    VIP_NOT_ACTIVE = { code = 900002, message = "会员未激活或已过期" },
    VIP_STATE_NOT_FOUND = { code = 900003, message = "会员状态不存在" },
    VIP_NO_PENDING_REWARD = { code = 900004, message = "无可领取奖励" },
    VIP_EXCEEDS_MAX_CUMULATIVE_DAYS = { code = 900005, message = "超出最大累计天数" },
    VIP_UNSUPPORTED_PLAN_ID = { code = 900006, message = "不支持的会员方案ID" },
    VIP_INVALID_PLAN_ID = { code = 900007, message = "调试购买参数非法" },
    SKILL_ENHANCEMENT_SERVICE_NOT_WIRED = { code = 10000001, message = "内部服务异常" },
    SKILL_ENHANCEMENT_INVALID_PARAM = { code = 700001, message = "技能强化参数非法" },
    SKILL_ENHANCEMENT_NOT_FOUND = { code = 700002, message = "技能强化件不存在" },
    SKILL_ENHANCEMENT_CONFIG_MISSING = { code = 700003, message = "技能强化配置缺失" },
    SKILL_ENHANCEMENT_FRAGMENT_NOT_ENOUGH = { code = 700004, message = "强化碎片不足" },
    SKILL_ENHANCEMENT_MAX_LEVEL = { code = 700005, message = "技能强化件已满级" },
    SKILL_ENHANCEMENT_INVALID_LEVEL = { code = 700006, message = "技能强化等级非法" },
    SKILL_ENHANCEMENT_UPGRADE_FAILED = { code = 700007, message = "技能强化升级失败" }
}

-- 获取指定错误键的原始映射项。
function M.get(key)
    return ERROR_MAP[key]
end

-- 解析错误键为（数值码, 文案）；可用 fallback 覆盖默认文案。
function M.resolve(key, fallback_message)
    local item = ERROR_MAP[key] or ERROR_MAP.COMMON_INTERNAL_ERROR
    local message = fallback_message
    if message == nil or message == "" then
        message = item.message
    end
    return item.code, message
end

return M
