local Config = require("Config")

local WaveSystem = {}

local BUDGET_MAX_ATTEMPTS = 80
local COLUMN_SOFT_CAP = 7
local EARLY_REALM_ACTIVE_LIMIT = 1
local MID_REALM_ACTIVE_LIMIT = 3
local DEFAULT_SPAWN_MAX = 3

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

function WaveSystem.PrepareRealmBreakthroughWave(state)
    state.waveTurnProgress = 0
    state.realmWaveIndex = 0
    state.pendingWaveQueue = {}
    state.pendingWaveIndex = nil
    state.pendingWaveExp = 0
    state.forceSpawnNextTurn = false
    state.breakthroughSpawnAllowance = 1
end

function WaveSystem.CreateMonsterFromDef(def, col, row, state)
    local difficulty = GetDifficultyConfig(state)
    local enemyMul = difficulty.enemyMul or 1.0
    local isEndlessAscension = state and (state.realmIndex or 1) >= #Config.REALMS and state.ascensionAchieved == true
    local waveRank = isEndlessAscension and math.max(0, (state.realmWaveIndex or 1) - 1) or 0
    local hpGrowth = 1.0 + waveRank * (Config.WAVE_ENEMY_HP_GROWTH or 0)
    local atkGrowth = 1.0 + waveRank * (Config.WAVE_ENEMY_ATK_GROWTH or 0)
    local realmAtkScale = (Config.REALM_ENEMY_ATK_SCALE and Config.REALM_ENEMY_ATK_SCALE[def.realm or 1]) or 1.0
    local atkMul = enemyMul * (1 + (difficulty.enemyAtkBonus or 0)) * realmAtkScale
    local hp = math.max(1, math.floor((def.hp or 1) * enemyMul * hpGrowth + 0.5))
    local atk = math.max(1, math.floor((def.atk or 1) * atkMul * atkGrowth + 0.5))

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
        defense = def.defense or 0,
        critChance = def.critChance or 0,
        critMultiplier = def.critMultiplier or 1.0,
        exp = def.exp or 0,
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

local function DefExp(def)
    return def and (def.exp or 0) or 0
end

local function SumExp(defs)
    local total = 0
    for _, def in ipairs(defs or {}) do
        total = total + DefExp(def)
    end
    return total
end

local function CopyDefs(defs)
    local copied = {}
    for _, def in ipairs(defs or {}) do
        table.insert(copied, def)
    end
    return copied
end

local function IsWithinBudget(exp, target)
    if target <= 0 then return true end
    local tolerance = Config.WAVE_BUDGET_TOLERANCE or 0.08
    return exp >= target * (1 - tolerance) and exp <= target * (1 + tolerance)
end

local function FindBestCandidate(candidates, currentExp, targetExp)
    local best = nil
    local bestScore = nil
    for _, def in ipairs(candidates or {}) do
        local score = math.abs(targetExp - (currentExp + DefExp(def)))
        if not best or score < bestScore then
            best = def
            bestScore = score
        end
    end
    return best
end

local function PickRandomDef(ids)
    if not ids or #ids == 0 then return nil end
    return GetDef(ids[math.random(#ids)])
end

local function BuildCandidateDefs(plan)
    local candidates = {}
    for _, id in ipairs(plan.candidates or {}) do
        local def = GetDef(id)
        if def then table.insert(candidates, def) end
    end
    return candidates
end

local function BuildLockedDefs(plan, waveIndex)
    local defs = {}
    local locks = plan.locks and plan.locks[waveIndex]
    if not locks then return defs end
    for _, id in ipairs(locks) do
        local def = GetDef(id)
        if def then table.insert(defs, def) end
    end
    return defs
end

local function AddBossDef(state, plan, waveIndex, defs)
    if not plan.boss then return end
    local firstWave = plan.boss.firstWave or 4
    local repeatEvery = plan.boss.repeatEvery or 0
    local shouldSpawn = waveIndex == firstWave
        or (repeatEvery > 0 and waveIndex > firstWave and (waveIndex - firstWave) % repeatEvery == 0)
    if shouldSpawn then
        local def = GetDef(plan.boss.id)
        if def then table.insert(defs, def) end
    end
end

local function AddDifficultyExtra(state, candidates, defs)
    local difficulty = GetDifficultyConfig(state)
    local extraCount = difficulty.extraMonsterPerWave or 0
    for _ = 1, extraCount do
        if #candidates == 0 then return end
        table.insert(defs, candidates[math.random(#candidates)])
    end
end

local function GenerateBudgetCandidate(state, plan, waveIndex, targetExp)
    local candidates = BuildCandidateDefs(plan)
    local defs = BuildLockedDefs(plan, waveIndex)
    AddBossDef(state, plan, waveIndex, defs)

    local maxMonsters = Config.WAVE_MAX_MONSTERS or 10
    local currentExp = SumExp(defs)
    if #candidates == 0 then
        AddDifficultyExtra(state, candidates, defs)
        return defs
    end

    while #defs < maxMonsters and currentExp < targetExp * (1 - (Config.WAVE_BUDGET_TOLERANCE or 0.08)) do
        local candidate = FindBestCandidate(candidates, currentExp, targetExp)
        if not candidate then break end
        table.insert(defs, candidate)
        currentExp = currentExp + DefExp(candidate)
    end

    if not IsWithinBudget(currentExp, targetExp) and #defs < maxMonsters then
        local randomCandidate = candidates[math.random(#candidates)]
        local withRandom = currentExp + DefExp(randomCandidate)
        if math.abs(targetExp - withRandom) < math.abs(targetExp - currentExp) then
            table.insert(defs, randomCandidate)
            currentExp = withRandom
        end
    end

    while #defs > 1 and currentExp > targetExp * (1 + (Config.WAVE_BUDGET_TOLERANCE or 0.08)) do
        local removableIndex = #defs
        local bossId = plan.boss and plan.boss.id or nil
        for i = #defs, 1, -1 do
            local def = defs[i]
            if not (bossId and def.id == bossId) then
                removableIndex = i
                break
            end
        end
        local removed = table.remove(defs, removableIndex)
        currentExp = currentExp - DefExp(removed)
    end

    AddDifficultyExtra(state, candidates, defs)
    return defs
end

local function GenerateRandomBudgetCandidate(state, plan, waveIndex, targetExp)
    local candidates = BuildCandidateDefs(plan)
    local defs = BuildLockedDefs(plan, waveIndex)
    AddBossDef(state, plan, waveIndex, defs)

    local maxMonsters = Config.WAVE_MAX_MONSTERS or 10
    if #candidates == 0 then
        AddDifficultyExtra(state, candidates, defs)
        return defs
    end

    while #defs < maxMonsters and SumExp(defs) < targetExp * (1 - (Config.WAVE_BUDGET_TOLERANCE or 0.08)) do
        table.insert(defs, candidates[math.random(#candidates)])
    end

    while #defs > 1 and SumExp(defs) > targetExp * (1 + (Config.WAVE_BUDGET_TOLERANCE or 0.08)) do
        table.remove(defs, #defs)
    end

    AddDifficultyExtra(state, candidates, defs)
    return defs
end

local function GetWaveTargetExp(plan, waveIndex, state)
    local baseBudget = plan.baseBudget or 10
    local growth = plan.budgetGrowth or 0.10
    if state and (state.realmIndex or 1) >= #Config.REALMS and state.ascensionAchieved then
        growth = Config.ENDLESS_WAVE_BUDGET_GROWTH or growth
    end
    local rank = math.max(0, waveIndex - 1)
    return math.max(1, math.floor(baseBudget * (1.0 + rank * growth) + 0.5))
end

local function BuildWaveDefs(state, plan, waveIndex)
    local targetExp = GetWaveTargetExp(plan, waveIndex, state)
    local bestDefs = nil
    local bestDiff = nil

    for attempt = 1, BUDGET_MAX_ATTEMPTS do
        local defs = attempt == 1
            and GenerateBudgetCandidate(state, plan, waveIndex, targetExp)
            or GenerateRandomBudgetCandidate(state, plan, waveIndex, targetExp)
        local exp = SumExp(defs)
        local diff = math.abs(targetExp - exp)
        if not bestDefs or diff < bestDiff then
            bestDefs = defs
            bestDiff = diff
        end
        if IsWithinBudget(exp, targetExp) then
            return defs, exp, true
        end
    end

    local exp = SumExp(bestDefs)
    return bestDefs or {}, exp, IsWithinBudget(exp, targetExp)
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
    local score = math.random() * (rules.RANDOM_JITTER or 0.8)

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

    score = score + (Config.GRID_COLS - math.abs(col - center)) * (rules.CENTER_COLUMN_BONUS or 0.35)
    return score
end

local function PickSpawnColumn(state, reserved)
    local counts = ColumnMonsterCounts(state)
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

    local col = bestCols[math.random(#bestCols)]
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

local function GetActiveMonsterLimit(state)
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    if majorIndex <= 2 then
        return EARLY_REALM_ACTIVE_LIMIT
    elseif majorIndex <= 4 then
        return MID_REALM_ACTIVE_LIMIT
    end
    return 5
end

local function GetSpawnBatchLimit(state)
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    if majorIndex <= 2 then
        return 1
    end

    local baseMax = DEFAULT_SPAWN_MAX
    if majorIndex >= 6 then
        baseMax = 4
    end
    return math.random(1, baseMax)
end

local function SpawnQueuedMonsters(state)
    state.pendingWaveQueue = state.pendingWaveQueue or {}
    if #state.pendingWaveQueue == 0 then return 0, state.pendingWaveIndex end

    local waveIndex = state.pendingWaveIndex
    local activeLimit = GetActiveMonsterLimit(state)
    local activeCount = CountActiveMonsters(state)
    local bonusAllowance = state.breakthroughSpawnAllowance or 0
    local availableSlots = math.max(0, activeLimit - activeCount)
    if bonusAllowance > 0 then
        availableSlots = math.max(availableSlots, bonusAllowance)
    end
    if availableSlots <= 0 then
        return 0, waveIndex
    end

    local reserved = {}
    local spawned = 0
    local remaining = {}
    local batchLimit = math.min(#state.pendingWaveQueue, GetSpawnBatchLimit(state), availableSlots)

    for _, def in ipairs(state.pendingWaveQueue) do
        if spawned < batchLimit then
            local col = PickSpawnColumn(state, reserved)
            if col then
                table.insert(state.monsters, WaveSystem.CreateMonsterFromDef(def, col, 1, state))
                spawned = spawned + 1
            else
                table.insert(remaining, def)
            end
        else
            table.insert(remaining, def)
        end
    end

    state.pendingWaveQueue = remaining
    if spawned > 0 and bonusAllowance > 0 then
        state.breakthroughSpawnAllowance = math.max(0, bonusAllowance - spawned)
    end
    if #remaining == 0 then
        state.pendingWaveIndex = nil
        state.pendingWaveExp = 0
        state.breakthroughSpawnAllowance = 0
    end

    return spawned, waveIndex
end

local function QueueNextWave(state)
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    local plan = Config.WAVE_PLANS[majorIndex]
    if not plan then return false end

    if state.pendingWaveQueue and #state.pendingWaveQueue > 0 then
        return false
    end

    state.realmWaveIndex = (state.realmWaveIndex or 0) + 1
    state.waveCount = (state.waveCount or 0) + 1
    local waveIndex = state.realmWaveIndex
    local defs, exp, inBudget = BuildWaveDefs(state, plan, waveIndex)
    state.pendingWaveQueue = CopyDefs(defs)
    state.pendingWaveIndex = waveIndex
    state.pendingWaveExp = exp

    local targetExp = GetWaveTargetExp(plan, waveIndex, state)
    if not inBudget then
        print(string.format("  [Wave Budget] R%d-W%d 修为%d/目标%d 超出±%d%%，使用最接近组合",
            majorIndex, waveIndex, exp, targetExp, math.floor((Config.WAVE_BUDGET_TOLERANCE or 0.08) * 100)))
    end

    return true
end

local function TrySpawnWaveOrQueue(state)
    local queued = state.pendingWaveQueue and #state.pendingWaveQueue > 0
    if not queued then
        QueueNextWave(state)
    end

    local spawned, waveIndex = SpawnQueuedMonsters(state)
    if spawned > 0 then
        print(string.format("  [Wave R%d-W%d] 刷新%d只，剩余排队%d只",
            state.realmIndex or 1,
            waveIndex or state.realmWaveIndex or 0,
            spawned,
            #(state.pendingWaveQueue or {})))
    elseif state.pendingWaveQueue and #state.pendingWaveQueue > 0 then
        print(string.format("  [Wave Queue] 列防溢触发，%d只怪物顺延", #state.pendingWaveQueue))
    end

    return spawned > 0
end

function WaveSystem.SpawnWave(state)
    if state.pendingWaveQueue and #state.pendingWaveQueue > 0 then
        TrySpawnWaveOrQueue(state)
        return
    end

    local interval = Config.GetRealmMajorIndex(state.realmIndex or 1) == 1 and Config.TUTORIAL_WAVE_INTERVAL or Config.WAVE_INTERVAL
    if state.waveTurnProgress > 0 and state.waveTurnProgress % interval == 0 then
        TrySpawnWaveOrQueue(state)
    end
end

function WaveSystem.ForceSpawnWave(state)
    return TrySpawnWaveOrQueue(state)
end

return WaveSystem
