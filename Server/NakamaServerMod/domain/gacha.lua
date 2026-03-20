local nk = require("nakama")
local config = require("config")

local M = {}

local backpack_gateway = nil

function M.set_item_gateway(gateway)
    backpack_gateway = gateway
end

--[[
职责：
- 提供抽卡（Gacha）RPC 入口：扣除成本 → 抽取 → 发奖 → 读写保底状态 → 返回结果。
- 依赖：
  - nakama：JSON 编解码与 Storage 读写。
  - config：读取卡池/横幅配置（config.gacha[banner_id]）。
  - backpack：扣道具与发放奖励（通过注入的 gateway）。
- 随机性来源：
  - 通过 Lua 标准库 math.random 产生随机数并按权重抽取；随机种子通常由运行时或其他模块在进程启动时初始化。
]]--

-- 按权重从指定池中随机出 1 个条目
-- pool 期望结构：{ { item_id = "...", rarity = "SSR"/"SR"/..., weight = number }, ... }
local function get_random_item(pool)
    local total_weight = 0
    for _, item in ipairs(pool) do
        total_weight = total_weight + item.weight
    end

    local random_val = math.random(total_weight)
    local current_weight = 0

    for _, item in ipairs(pool) do
        current_weight = current_weight + item.weight
        if random_val <= current_weight then
            return item
        end
    end
    return pool[#pool] -- Fallback
end

-- 抽卡入口（RPC）：payload(JSON) 至少包含 banner_id/count（count 默认为 1）
-- 返回结构：
-- - 成功：{ results = [ { id, count, rarity }, ... ], pity_state = { ssr_counter, sr_counter } }
-- - 失败：{ error = "..." }（错误码/错误文案保持原样，不在此处变更）
function M.rpc_gacha_pull(context, payload)
    local user_id = context.user_id
    local req = nk.json_decode(payload)
    local banner_id = req.banner_id or "standard_banner"
    local count = req.count or 1 -- 1 or 10 pulls

    -- 池/权重读取：从配置表中按 banner_id 取出横幅；banner.pool 为按稀有度与权重定义的条目列表
    local banner = config.gacha[banner_id]
    if not banner then
        return nk.json_encode({ error = "Invalid banner ID" })
    end

    -- 1) 扣除抽卡成本：按次数线性放大扣除数量（cost_amount * count）
    local cost_items = { { id = banner.cost_item, count = banner.cost_amount * count } }
    local success, err = backpack_gateway.consume_items(context, user_id, cost_items, "consume", {
        origin = "gacha",
        banner_id = banner_id,
        count = count,
        cost_item = banner.cost_item,
        cost_amount = banner.cost_amount
    })
    if not success then
        return nk.json_encode({ error = err or "Insufficient funds" })
    end

    -- 2) 读取保底状态：
    -- - 存储位置：collection = "gacha_pity"
    -- - 键名：pity_{banner_id}（不同 banner 独立保底）
    -- - 值结构：{ ssr_counter = number, sr_counter = number }
    -- - version：用于乐观并发控制；读到什么版本就原样写回（不改变逻辑）
    local pity_key = "pity_" .. banner_id
    local storage_objs = nk.storage_read({ { collection = "gacha_pity", key = pity_key, user_id = user_id } })
    local pity_state = { ssr_counter = 0, sr_counter = 0 }
    local version = nil

    if #storage_objs > 0 then
        pity_state = storage_objs[1].value
        version = storage_objs[1].version
    end

    -- 3) 执行抽取：逐抽递增计数器 → 判断是否触发保底 → 否则按权重常规抽取
    local results = {}
    for i = 1, count do
        pity_state.ssr_counter = pity_state.ssr_counter + 1
        pity_state.sr_counter = pity_state.sr_counter + 1

        local item_result = nil

        -- SSR 保底：达到阈值则强制从 SSR 子池中抽 1 个，并重置 SSR 计数
        if pity_state.ssr_counter >= banner.pity_ssr then
            -- Force SSR
            local ssr_pool = {}
            for _, item in ipairs(banner.pool) do
                if item.rarity == "SSR" then table.insert(ssr_pool, item) end
            end
            item_result = get_random_item(ssr_pool)
            pity_state.ssr_counter = 0 -- Reset SSR pity
        elseif pity_state.sr_counter >= banner.pity_sr then
            -- SR 保底：达到阈值则强制从 SR 子池中抽 1 个，并重置 SR 计数
             local sr_pool = {}
            for _, item in ipairs(banner.pool) do
                if item.rarity == "SR" then table.insert(sr_pool, item) end
            end
            -- 说明：SR 保底是否影响 SSR 保底在不同游戏中规则不同；此处不重置 SSR 计数
            item_result = get_random_item(sr_pool)
            pity_state.sr_counter = 0 -- Reset SR pity
        else
            -- 常规抽取：直接从总池按权重抽 1 个；若抽到 SR/SSR 则对应计数清零
            item_result = get_random_item(banner.pool)
            if item_result.rarity == "SSR" then
                pity_state.ssr_counter = 0
            elseif item_result.rarity == "SR" then
                pity_state.sr_counter = 0
            end
        end

        -- 结果条目结构：id 为物品 ID；count 固定为 1；rarity 透传用于客户端展示
        table.insert(results, { id = item_result.item_id, count = 1, rarity = item_result.rarity })
    end

    -- 4) 发放奖励：将 results 作为奖励清单写入背包；同时附带本次保底状态用于审计/日志（由 backpack 模块处理）
    local ok, err = backpack_gateway.add_items(context, user_id, results, "gacha", {
        banner_id = banner_id,
        count = count,
        phase = "reward",
        pity_state = pity_state
    })
    if not ok then
        return nk.json_encode({ error = err or "Grant rewards failed" })
    end

    -- 5) 保存保底状态：permission_write=0 表示仅服务器可写；permission_read=1 允许客户端读取（如需）
    nk.storage_write({
        {
            collection = "gacha_pity",
            key = pity_key,
            user_id = user_id,
            value = pity_state,
            version = version,
            permission_read = 1,
            permission_write = 0 -- Server only write
        }
    })

    -- 返回：抽卡结果 + 最新保底计数
    return nk.json_encode({ results = results, pity_state = pity_state })
end

return M
