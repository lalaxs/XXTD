local Config = require("Config")

local WaveSystem = {}

-- 根据当前波次获取允许的最高怪物阶级
local function GetMaxTierForWave(waveCount)
    for _, rule in ipairs(Config.WAVE_RULES) do
        if waveCount <= rule.maxWave then
            return rule.maxMonsterTier
        end
    end
    return Config.MAX_QUALITY
end

-- 按概率权重从模板列表中选择一个怪物模板（受波次限制）
local function PickMonsterTemplate(templates, maxTier)
    -- 筛选符合阶级限制的模板
    local eligible = {}
    local totalWeight = 0
    for _, t in ipairs(templates) do
        if (t.quality or 1) <= maxTier then
            table.insert(eligible, t)
            totalWeight = totalWeight + t.spawnChance
        end
    end
    if #eligible == 0 then return templates[1] end

    -- 加权随机选择
    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, t in ipairs(eligible) do
        cumulative = cumulative + t.spawnChance
        if roll <= cumulative then
            return t
        end
    end
    return eligible[#eligible]
end

local function SpawnWaveNow(state)
    state.waveCount = state.waveCount + 1

    local maxTier = GetMaxTierForWave(state.waveCount)

    -- 统计row=1已有实体数量
    local row1Count = 0
    for _, m in ipairs(state.monsters) do
        if m.row == 1 then row1Count = row1Count + 1 end
    end
    for _, c in ipairs(state.chests) do
        if c.row == 1 then row1Count = row1Count + 1 end
    end
    local maxSpawn = math.max(0, 2 - row1Count)
    if maxSpawn == 0 then
        print("  [Wave] row=1已满，跳过刷新")
        return
    end

    -- 早期波次只刷1只，后期1-2只
    local baseCount = state.waveCount <= 5 and 1 or math.random(1, 2)
    local count = math.min(maxSpawn, baseCount)
    local usedCols = {}
    for _, m in ipairs(state.monsters) do
        if m.row == 1 then usedCols[m.col] = true end
    end
    for _, c in ipairs(state.chests) do
        if c.row == 1 then usedCols[c.col] = true end
    end

    for _ = 1, count do
        local col
        local attempts = 0
        repeat
            col = math.random(1, Config.GRID_COLS)
            attempts = attempts + 1
        until not usedCols[col] or attempts > 10
        if attempts > 10 then break end
        usedCols[col] = true

        -- 决定近战还是远程（60%近战 40%远程）
        local isMelee = math.random() < 0.6
        local template
        if isMelee then
            template = PickMonsterTemplate(Config.MELEE_TEMPLATES, maxTier)
            table.insert(state.monsters, {
                monsterType = Config.MONSTER_TYPE.MELEE,
                name = template.name,
                quality = template.quality or 1,
                hp = template.hp, maxHp = template.hp,
                atk = template.atk, exp = template.exp,
                dropChance = template.dropChance,
                skill = template.skill,
                col = col, row = 1,
                charging = false, chargeTimer = 0, slowed = nil,
                rowsWalked = 0,  -- 已行走格数（技能触发用）
                skillTriggered = false,  -- 一次性技能是否已触发
                shieldAmount = 0,  -- 当前护盾值
            })
        else
            template = PickMonsterTemplate(Config.RANGED_TEMPLATES, maxTier)
            table.insert(state.monsters, {
                monsterType = Config.MONSTER_TYPE.RANGED,
                name = template.name,
                quality = template.quality or 1,
                hp = template.hp, maxHp = template.hp,
                atk = template.atk, exp = template.exp,
                dropChance = template.dropChance,
                skill = template.skill,
                col = col, row = 1,
                charging = false, chargeTimer = 0, slowed = nil,
                attackRange = template.attackRange or 3,
                rowsWalked = 0,
                skillTriggered = false,
                stealthActive = false,
            })
        end
    end

    print(string.format("  [Wave %d] 刷新完成 (maxTier=%d)", state.waveCount, maxTier))
end

function WaveSystem.SpawnWave(state)
    if state.waveTurnProgress > 0 and state.waveTurnProgress % Config.WAVE_INTERVAL == 0 then
        SpawnWaveNow(state)
    end
end

function WaveSystem.ForceSpawnWave(state)
    SpawnWaveNow(state)
end

return WaveSystem
