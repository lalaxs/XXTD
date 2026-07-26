local Config = require("Config")
local VisualState = require("VisualState")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local DailyChallenge = require("DailyChallenge")

local WaveSystem = {}

local BUDGET_MAX_ATTEMPTS = 80
local COLUMN_SOFT_CAP = 7
local DEFAULT_ACTIVE_LIMIT = 8
local DEFAULT_SPAWN_MAX = 4
local RollSpawnCount
local IsEndlessAscension
local GetWaveRank

local function ClampDifficulty(value)
    return math.min(Config.MAX_DIFFICULTY or 5, math.max(1, value or 1))
end

local function GetDifficultyConfig(state)
    return Config.DIFFICULTY[ClampDifficulty(state and state.difficulty or 1)] or Config.DIFFICULTY[1]
end

local function CopyDebuffList(def)
    if def.playerDebuffs then
        local list = {}
        for _, debuff in ipairs(def.playerDebuffs) do
            table.insert(list, {
                type = debuff.type,
                value = debuff.value,
                duration = debuff.duration,
            })
        end
        return list
    elseif def.playerDebuff then
        return {
            {
                type = def.playerDebuff.type,
                value = def.playerDebuff.value,
                duration = def.playerDebuff.duration,
            }
        }
    end
    return nil
end

local function GetRealmMinorProgress(state)
    local realm = Config.GetRealm(state and state.realmIndex or 1)
    if not realm or not realm.minorCount or realm.minorCount <= 1 then
        return 0
    end
    return (realm.minorIndex - 1) / (realm.minorCount - 1)
end

local function GetRealmStatPressureMul(state, configKey, fallbackGrowth)
    local growth = ((Config.WAVE_SPAWN or {})[configKey]) or fallbackGrowth
    local progress = GetRealmMinorProgress(state)
    local easedProgress = progress * progress * (3 - 2 * progress)
    return 1.0 + easedProgress * growth
end

local function GetRealmHpPressureMul(state)
    return GetRealmStatPressureMul(state, "MINOR_HP_GROWTH", 1.00)
end

local function GetRealmAtkPressureMul(state)
    return GetRealmStatPressureMul(state, "MINOR_ATK_GROWTH", 0.45)
end

local function GetRealmDefPressureMul(state)
    return GetRealmStatPressureMul(state, "MINOR_DEF_GROWTH", 0.55)
end

local function GetRealmExpPressureMul(state)
    return GetRealmStatPressureMul(state, "MINOR_EXP_GROWTH", 0.75)
end

local function GetRealmExpRewardMul(state)
    local majorIndex = Config.GetRealmMajorIndex(state and state.realmIndex or 1)
    local earlyBonus = Config.MONSTER_EXP_EARLY_MAJOR_BONUS or 0
    local bonus = earlyBonus * math.max(0, 3 - majorIndex) / 2
    return 1.0 + bonus
end

function WaveSystem.PrepareRealmBreakthroughWave(state)
    state.waveTurnProgress = 0
    state.waveTurnsSinceSpawn = 0
    state.realmWaveIndex = 0
    state.forceSpawnNextTurn = false
    state.breakthroughSpawnAllowance = 1
end

function WaveSystem.CreateMonsterFromDef(def, col, row, state)
    local difficulty = GetDifficultyConfig(state)
    local enemyMul = difficulty.enemyMul or 1.0
    local hpPressureMul = GetRealmHpPressureMul(state)
    local atkPressureMul = GetRealmAtkPressureMul(state)
    local defPressureMul = GetRealmDefPressureMul(state)
    local expPressureMul = GetRealmExpPressureMul(state)
    local expRewardMul = GetRealmExpRewardMul(state)
    local expGlobalMul = Config.MONSTER_EXP_MUL or 1.0
    local isEndlessAscension = state and state.ascensionMode == true and state.ascensionAchieved == true
    local waveRank = isEndlessAscension and math.max(0, (state.endlessWaveIndex or 1) - 1) or 0
    local hpGrowth = 1.0 + waveRank * (isEndlessAscension and (Config.ENDLESS_WAVE_HP_GROWTH or 0) or (Config.WAVE_ENEMY_HP_GROWTH or 0))
    local atkGrowth = 1.0 + waveRank * (isEndlessAscension and (Config.ENDLESS_WAVE_ATK_GROWTH or 0) or (Config.WAVE_ENEMY_ATK_GROWTH or 0))
    local realmAtkScale = (Config.REALM_ENEMY_ATK_SCALE and Config.REALM_ENEMY_ATK_SCALE[def.realm or 1]) or 1.0
    local atkMul = enemyMul * atkPressureMul * (1 + (difficulty.enemyAtkBonus or 0)) * realmAtkScale
    local enemyHpMul = (1 + RogueRewardSystem.GetModifierValue(state, "enemyHpPct"))
        * DailyChallenge.GetEffect(state, "monsterHpMul", 1.0)
    local enemyAtkMul = (1 + RogueRewardSystem.GetModifierValue(state, "enemyAtkPct"))
        * DailyChallenge.GetEffect(state, "monsterAtkMul", 1.0)
    local enemyDefenseMul = (1 + RogueRewardSystem.GetModifierValue(state, "enemyDefensePct"))
        * DailyChallenge.GetEffect(state, "monsterDefenseMul", 1.0)
    local hp = math.max(1, math.floor((def.hp or 1) * enemyMul * hpPressureMul * hpGrowth * enemyHpMul + 0.5))
    local atk = math.max(1, math.floor((def.atk or 1) * atkMul * atkGrowth * enemyAtkMul + 0.5))
    local defense = math.max(0, math.floor((def.defense or 0) * defPressureMul * enemyDefenseMul + 0.5))
    local exp = math.max(1, math.floor((def.exp or 0) * expGlobalMul * expPressureMul * expRewardMul + 0.5))

    return {
        id = def.id,
        monsterType = def.monsterType,
        name = def.name,
        quality = def.quality or def.realm or 1,
        realm = def.realm or 1,
        tier = def.tier,
        tags = def.tags,
        hp = hp,
        maxHp = hp,
        baseHp = def.hp,
        atk = atk,
        baseAtk = def.atk,
        defense = defense,
        critChance = def.critChance or 0,
        critMultiplier = def.critMultiplier or 1.0,
        exp = exp,
        dropChance = def.dropChance or 0,
        skill = def.skill,
        playerDebuffs = CopyDebuffList(def),
        asset = def.asset,
        col = col or 1,
        row = row or 1,
        charging = false,
        chargeTimer = 0,
        slowed = nil,
        attackRange = def.attackRange or 3,
        rowsWalked = 0,
        skillTriggered = false,
        shieldAmount = 0,
        stealthActive = false,
    }
end

local function GetDef(id)
    return Config.MONSTER_BY_ID[id]
end

local function BuildCandidateDefs(plan)
    local candidates = {}
    for _, id in ipairs(plan.candidates or {}) do
        local def = GetDef(id)
        if def then table.insert(candidates, def) end
    end
    return candidates
end

local function ColumnMonsterCounts(state)
    local counts = {}
    for col = 1, Config.GRID_COLS do counts[col] = 0 end
    for _, monster in ipairs(state.monsters or {}) do
        if monster.hp > 0 and monster.col then
            counts[monster.col] = (counts[monster.col] or 0) + 1
        end
    end
    return counts
end

local function TopRowBlocked(state, col)
    for _, monster in ipairs(state.monsters or {}) do
        if monster.hp > 0 and monster.col == col and monster.row == 1 then
            return true
        end
    end
    for _, fieldReward in ipairs(state.fieldRewards or {}) do
        if fieldReward.hp > 0 and fieldReward.col == col and fieldReward.row == 1 then
            return true
        end
    end
    return false
end

local function HasReservedNeighbor(reserved, col)
    return reserved[col - 1] == true or reserved[col + 1] == true
end

local function CountDeployedItemsInColumn(state, col)
    local count = 0
    for row = 1, Config.DEPLOY_ROWS do
        local slotIdx = (row - 1) * Config.GRID_COLS + col
        if state.slots and state.slots[slotIdx] then
            count = count + 1
        end
    end
    return count
end

local function WasRecentSpawnColumn(state, col)
    for _, recentCol in ipairs(state.recentSpawnColumns or {}) do
        if recentCol == col then return true end
    end
    return false
end

local function PushRecentSpawnColumn(state, col)
    state.recentSpawnColumns = state.recentSpawnColumns or {}
    table.insert(state.recentSpawnColumns, 1, col)
    local limit = math.max(1, math.floor((Config.SPAWN_POINT_RULES and Config.SPAWN_POINT_RULES.RECENT_MEMORY) or 4))
    while #state.recentSpawnColumns > limit do
        table.remove(state.recentSpawnColumns)
    end
end

local function GetSpawnColumnScore(state, reserved, counts, col)
    local rules = Config.SPAWN_POINT_RULES or {}
    local realmIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    local load = counts[col] or 0
    local deployed = CountDeployedItemsInColumn(state, col)
    local center = (Config.GRID_COLS + 1) * 0.5
    local score = DailyChallenge.RandomFloat(state) * (rules.RANDOM_JITTER or 0.8)

    score = score - load * (rules.COLUMN_LOAD_PENALTY or 2.0)

    if HasReservedNeighbor(reserved, col) then
        score = score - (rules.RESERVED_NEIGHBOR_PENALTY or 1.0)
    end
    if WasRecentSpawnColumn(state, col) then
        score = score - (rules.RECENT_COLUMN_PENALTY or 1.5)
    end
    if state.recentSpawnColumns and state.recentSpawnColumns[1] == col then
        score = score - (rules.SAME_COLUMN_PENALTY or 4.0)
    end

    if deployed <= 0 then
        if realmIndex <= 3 then
            score = score - (rules.EARLY_EMPTY_DEPLOY_PENALTY or 2.5)
        elseif realmIndex >= 6 then
            score = score + (rules.LATE_EMPTY_DEPLOY_PRESSURE or 0.8)
        end
    end

    local centerWeight = DailyChallenge.GetEffect(state, "centerColumnBonusMul", 1.0)
    score = score + (Config.GRID_COLS - math.abs(col - center)) * (rules.CENTER_COLUMN_BONUS or 0.35) * centerWeight
    return score
end

local function PickRecentSpawnColumn(state, reserved, counts)
    local rules = Config.SPAWN_POINT_RULES or {}
    local repeatChance = (rules.SAME_COLUMN_REPEAT_CHANCE or 0)
        + DailyChallenge.GetEffect(state, "sameColumnRepeatChanceAdd", 0)
    if DailyChallenge.RandomFloat(state) >= math.min(1.0, repeatChance) then return nil end

    for _, col in ipairs(state.recentSpawnColumns or {}) do
        if col and not reserved[col] and not TopRowBlocked(state, col) and (counts[col] or 0) < COLUMN_SOFT_CAP then
            reserved[col] = true
            PushRecentSpawnColumn(state, col)
            return col
        end
    end
    return nil
end

local function PickSpawnColumn(state, reserved)
    local counts = ColumnMonsterCounts(state)
    local repeatedCol = PickRecentSpawnColumn(state, reserved, counts)
    if repeatedCol then return repeatedCol end

    local bestCols = {}
    local bestScore = nil

    for col = 1, Config.GRID_COLS do
        if not reserved[col] and not TopRowBlocked(state, col) and (counts[col] or 0) < COLUMN_SOFT_CAP then
            local score = GetSpawnColumnScore(state, reserved, counts, col)
            if not bestScore or score > bestScore then
                bestScore = score
                bestCols = { col }
            elseif score == bestScore then
                table.insert(bestCols, col)
            end
        end
    end

    if #bestCols == 0 then return nil end

    local col = bestCols[DailyChallenge.RandomInt(state, #bestCols)]
    reserved[col] = true
    PushRecentSpawnColumn(state, col)
    return col
end

local function CountActiveMonsters(state)
    local count = 0
    for _, monster in ipairs(state.monsters or {}) do
        if monster.hp > 0 then
            count = count + 1
        end
    end
    return count
end

IsEndlessAscension = function(state)
    return state and state.ascensionMode == true and state.ascensionAchieved == true
end

local function GetEndlessWaveRank(state)
    return math.max(0, (state and state.endlessWaveIndex or 1) - 1)
end

local function GetEndlessBudget(state)
    local rank = GetEndlessWaveRank(state)
    local startBudget = Config.ENDLESS_START_BUDGET or 260
    local growth = Config.ENDLESS_WAVE_BUDGET_GROWTH or 0.08
    local cap = Config.ENDLESS_WAVE_BUDGET_CAP or 1200
    local budget = startBudget * ((1 + growth) ^ rank)
    return math.min(cap, math.max(startBudget, budget))
end

local function GetEndlessActiveLimit(state)
    local base = (Config.WAVE_SPAWN.ACTIVE_LIMIT_BY_MAJOR or {})[9] or DEFAULT_ACTIVE_LIMIT
    local rank = GetEndlessWaveRank(state)
    local limit = base + math.floor(rank / 8)
    return math.min(Config.ENDLESS_ACTIVE_LIMIT_CAP or 18, limit)
end

local function GetEndlessPlan()
    return Config.WAVE_PLANS[9]
end

local function GetEndlessSpawnCount(state, budget)
    local maxMonsters = Config.WAVE_MAX_MONSTERS or DEFAULT_SPAWN_MAX
    local count = math.floor((budget or 0) / 100)
    return math.min(maxMonsters, math.max(1, count))
end

local function GetEndlessMonsterDef(state, spawnIndex)
    local plan = GetEndlessPlan()
    local bossInterval = Config.ENDLESS_BOSS_INTERVAL or 5
    local rank = state.endlessWaveIndex or 1
    if rank > 0 and rank % bossInterval == 0 then
        local bossDef = GetDef(plan.boss and plan.boss.id or "purple_fire_elder")
        if bossDef then return bossDef end
    end
    local candidates = BuildCandidateDefs(plan)
    if #candidates == 0 then return nil end
    return candidates[DailyChallenge.RandomInt(state, #candidates)]
end

GetWaveRank = function(state)
    if IsEndlessAscension(state) then
        return GetEndlessWaveRank(state)
    end
    return 0
end

local function GetSpawnWaveIndex(state)
    if IsEndlessAscension(state) then
        return state.endlessWaveIndex or 1
    end
    return state.realmWaveIndex or 0
end

local function GetWaveTargetCount(state)
    if IsEndlessAscension(state) then
        return GetEndlessSpawnCount(state, state.endlessBudget or GetEndlessBudget(state))
    end
    return RollSpawnCount(state)
end

local function AdvanceEndlessWave(state)
    state.endlessWaveIndex = (state.endlessWaveIndex or 0) + 1
    state.endlessBudget = GetEndlessBudget(state)
    state.waveCount = state.endlessWaveIndex
end

local function StartEndlessWave(state)
    if not IsEndlessAscension(state) then return end
    if state.endlessWaveActive ~= true or CountActiveMonsters(state) == 0 then
        AdvanceEndlessWave(state)
        state.endlessWaveActive = false
    end
end

local function GetActiveMonsterLimit(state)
    if IsEndlessAscension(state) then
        return GetEndlessActiveLimit(state)
    end
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    local rules = Config.WAVE_SPAWN or {}
    local limits = rules.ACTIVE_LIMIT_BY_MAJOR or {}
    return limits[majorIndex] or DEFAULT_ACTIVE_LIMIT
end

local function PickLockedStreamDef(state, plan, spawnIndex)
    local locks = plan.locks and plan.locks[spawnIndex]
    if not locks or #locks == 0 then return nil end
    return GetDef(locks[DailyChallenge.RandomInt(state, #locks)])
end

local function PickBossStreamDef(plan, spawnIndex)
    if not plan.boss then return nil end
    local firstSpawn = plan.boss.firstWave or 4
    local repeatEvery = plan.boss.repeatEvery or 0
    local shouldSpawn = spawnIndex == firstSpawn
        or (repeatEvery > 0 and spawnIndex > firstSpawn and (spawnIndex - firstSpawn) % repeatEvery == 0)
    if not shouldSpawn then return nil end
    return GetDef(plan.boss.id)
end

local function PickStreamMonsterDef(state, plan, spawnIndex)
    local bossDef = PickBossStreamDef(plan, spawnIndex)
    if bossDef then return bossDef end

    local lockedDef = PickLockedStreamDef(state, plan, spawnIndex)
    if lockedDef then return lockedDef end

    local candidates = BuildCandidateDefs(plan)
    if #candidates == 0 then return nil end
    return candidates[DailyChallenge.RandomInt(state, #candidates)]
end

local function SpawnOneMonster(state)
    local activeLimit = GetActiveMonsterLimit(state)
    if CountActiveMonsters(state) >= activeLimit then
        return false, nil, nil, "active_limit"
    end

    local spawnIndex = GetSpawnWaveIndex(state)
    local def
    if IsEndlessAscension(state) then
        def = GetEndlessMonsterDef(state, spawnIndex)
    else
        local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
        local plan = Config.WAVE_PLANS[majorIndex]
        if not plan then return false, nil, nil, "no_plan" end
        def = PickStreamMonsterDef(state, plan, (state.realmWaveIndex or 0) + 1)
    end
    if not def then return false, nil, nil, "no_def" end

    local reserved = {}
    local col = PickSpawnColumn(state, reserved)
    if not col then return false, nil, nil, "blocked" end

    if IsEndlessAscension(state) then
        state.endlessWaveActive = true
    else
        state.realmWaveIndex = (state.realmWaveIndex or 0) + 1
    end
    state.waveCount = IsEndlessAscension(state) and (state.endlessWaveIndex or 1) or ((state.waveCount or 0) + 1)
    local monster = WaveSystem.CreateMonsterFromDef(def, col, 1, state)
    state.nextMonsterInstanceId = (state.nextMonsterInstanceId or 0) + 1
    monster.instanceId = state.nextMonsterInstanceId
    monster.spawnAnimTurn = state.turn or 0
    VisualState.MarkMonsterSpawnPending(state, monster)
    table.insert(state.monsters, monster)
    return true, def, col, nil
end

RollSpawnCount = function(state)
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    local rules = Config.WAVE_SPAWN or {}
    local rollTable = rules.COUNT_ROLL_BY_MAJOR and rules.COUNT_ROLL_BY_MAJOR[majorIndex]
    if not rollTable or #rollTable == 0 then return 1 end

    local totalWeight = 0
    for _, entry in ipairs(rollTable) do
        totalWeight = totalWeight + math.max(0, entry.weight or 0)
    end
    if totalWeight <= 0 then return 1 end

    local roll = DailyChallenge.RandomFloat(state) * totalWeight
    local acc = 0
    for _, entry in ipairs(rollTable) do
        acc = acc + math.max(0, entry.weight or 0)
        if roll <= acc then
            local countMultiplier = DailyChallenge.GetEffect(state, "monsterSpawnCountMul", 1.0)
            return math.max(1, math.floor((entry.count or 1) * countMultiplier + 0.5))
        end
    end
    return 1
end

local function TrySpawnWaveOrQueue(state)
    if IsEndlessAscension(state) then
        StartEndlessWave(state)
    end
    local targetCount = GetWaveTargetCount(state)
    local spawnedCount = 0
    local blockedReason = nil

    for _ = 1, targetCount do
        local spawned, def, col, reason = SpawnOneMonster(state)
        if not spawned then
            blockedReason = reason
            break
        end
        spawnedCount = spawnedCount + 1
        print(string.format("  [Spawn] %s 刷新在第%d列", def.name or "妖魔", col or 1))
    end

    if spawnedCount == 0 then
        if blockedReason == "active_limit" then
            print("  [Spawn] 场上妖魔已达上限，本回合不刷新")
        elseif blockedReason == "blocked" then
            print("  [Spawn] 顶行无可用刷新点，本回合不刷新")
        end
    elseif spawnedCount < targetCount then
        print(string.format("  [Spawn] 本次计划刷新%d只，实际刷新%d只", targetCount, spawnedCount))
    end

    return spawnedCount > 0
end

local function GetWaveSpawnChance(state)
    local rules = Config.WAVE_SPAWN or {}
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    local turns = state.waveTurnsSinceSpawn or 0
    local baseChance = majorIndex == 1 and (rules.EARLY_CHANCE or 0.28) or (rules.DEFAULT_CHANCE or 0.50)
    local minInterval = majorIndex == 1 and (rules.EARLY_MIN_INTERVAL or 2) or (rules.DEFAULT_MIN_INTERVAL or 1)
    local pityInterval = majorIndex == 1 and (rules.EARLY_PITY_INTERVAL or 5) or (rules.DEFAULT_PITY_INTERVAL or 3)

    if turns < minInterval then
        return 0
    end
    if turns >= pityInterval then
        return 1.0
    end

    local chance = baseChance + math.max(0, turns - minInterval) * (rules.CHANCE_GROWTH_PER_TURN or 0.10)
    local chanceMultiplier = DailyChallenge.GetEffect(state, "monsterSpawnChanceMul", 1.0)
    return math.min(1.0, math.min(rules.MAX_SPAWN_CHANCE or 0.90, chance) * chanceMultiplier)
end

function WaveSystem.SpawnWave(state)
    state.waveTurnsSinceSpawn = (state.waveTurnsSinceSpawn or 0) + 1
    if DailyChallenge.RandomFloat(state) <= GetWaveSpawnChance(state) then
        if TrySpawnWaveOrQueue(state) then
            state.waveTurnsSinceSpawn = 0
        end
    end
end

function WaveSystem.ForceSpawnWave(state)
    local spawned = TrySpawnWaveOrQueue(state)
    if spawned then
        state.waveTurnsSinceSpawn = 0
    end
    return spawned
end

return WaveSystem
