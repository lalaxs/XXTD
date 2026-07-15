local Config = require("Config")
local FieldRewardService = require("rewards.FieldRewardService")
local RogueRewardSystem = require("rogue.RogueRewardSystem")

local FieldRewardSystem = {}

local function EnsureRewardRuntime(state)
    state.fieldRewardTurnsSinceSpawn = state.fieldRewardTurnsSinceSpawn or 0
    state.fieldRewardRecentCols = state.fieldRewardRecentCols or {}
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

local function CountMonstersInColumn(state, col)
    local count = 0
    for _, monster in ipairs(state.monsters or {}) do
        if monster.hp > 0 and monster.col == col then
            count = count + 1
        end
    end
    return count
end

local function TopRowBlocked(state, col)
    for _, fieldReward in ipairs(state.fieldRewards or {}) do
        if fieldReward.hp > 0 and fieldReward.row == 1 and fieldReward.col == col then return true end
    end
    return false
end

local function FieldCellBlocked(state, col, row)
    for _, fieldReward in ipairs(state.fieldRewards or {}) do
        if fieldReward.hp > 0 and fieldReward.row == row and fieldReward.col == col then return true end
    end
    return false
end

local function WasRecentlyUsed(state, col)
    for _, recentCol in ipairs(state.fieldRewardRecentCols or {}) do
        if recentCol == col then return true end
    end
    return false
end

local function PushRecentRewardColumn(state, col)
    state.fieldRewardRecentCols = state.fieldRewardRecentCols or {}
    table.insert(state.fieldRewardRecentCols, 1, col)
    local limit = math.max(1, math.floor((Config.FIELD_REWARD and Config.FIELD_REWARD.RECENT_MEMORY) or 3))
    while #state.fieldRewardRecentCols > limit do
        table.remove(state.fieldRewardRecentCols)
    end
end

local function PickRewardColumn(state)
    local rules = Config.FIELD_REWARD or {}
    local bestCols = {}
    local bestScore = nil

    for col = 1, Config.GRID_COLS do
        if not TopRowBlocked(state, col) then
            local deployed = CountDeployedItemsInColumn(state, col)
            local monsters = CountMonstersInColumn(state, col)
            local score = math.random() * (rules.RANDOM_JITTER or 0.5)
            score = score + deployed * (rules.DEPLOYED_COLUMN_BONUS or 2.0)
            score = score - monsters * (rules.MONSTER_PRESSURE_PENALTY or 0.7)

            if deployed <= 0 then
                score = score - (rules.EMPTY_COLUMN_PENALTY or 1.2)
            end
            if WasRecentlyUsed(state, col) then
                score = score - (rules.RECENT_COLUMN_PENALTY or 2.0)
            end

            if not bestScore or score > bestScore then
                bestScore = score
                bestCols = { col }
            elseif score == bestScore then
                table.insert(bestCols, col)
            end
        end
    end

    if #bestCols == 0 then return nil end
    return bestCols[math.random(#bestCols)]
end

local function GetRewardSpawnChance(state)
    local rules = Config.FIELD_REWARD or {}
    local difficulty = Config.DIFFICULTY[state.difficulty or 1] or Config.DIFFICULTY[1]
    local turns = state.fieldRewardTurnsSinceSpawn or 0
    local spawnChance = (rules.SPAWN_CHANCE or 0.15) * (difficulty.fieldRewardSpawnMul or 1.0)
    spawnChance = spawnChance * (1 + RogueRewardSystem.GetModifierValue(state, "fieldRewardSpawnPct"))
    spawnChance = spawnChance + math.max(0, turns - (rules.MIN_INTERVAL or 2)) * (rules.CHANCE_GROWTH_PER_TURN or 0.08)
    if turns >= (rules.PITY_INTERVAL or 6) then
        return 1.0
    end
    return math.min(rules.MAX_SPAWN_CHANCE or 0.85, spawnChance)
end

local function MonsterMovementBlocked(monster)
    if monster.monsterType == Config.MONSTER_TYPE.MELEE and monster.row >= Config.FIELD_ROWS then
        return true
    end
    if (monster.rootTurns or 0) > 0 then
        return true
    end
    if monster.slowed and monster.slowed >= 1.0 then
        return true
    elseif monster.slowed and monster.slowed > 0 then
        if monster.plannedSkipMovement == nil then
            monster.plannedSkipMovement = math.random() < monster.slowed
        end
        return monster.plannedSkipMovement
    end
    return false
end

local function AddColumnEntity(columns, entity)
    if not entity.col or not entity.row then return end
    columns[entity.col] = columns[entity.col] or {}
    table.insert(columns[entity.col], entity)
end

local function BuildFieldMovementPlans(state)
    local columns = {}
    local plans = {}

    for i, monster in ipairs(state.monsters or {}) do
        if monster.hp > 0 then
            AddColumnEntity(columns, {
                kind = "monster",
                index = i,
                row = monster.row,
                col = monster.col,
                canMove = not MonsterMovementBlocked(monster),
            })
        end
    end

    for i, fieldReward in ipairs(state.fieldRewards or {}) do
        if fieldReward.hp > 0 then
            AddColumnEntity(columns, {
                kind = "fieldReward",
                index = i,
                row = fieldReward.row,
                col = fieldReward.col,
                canMove = true,
            })
        end
    end

    for _, entities in pairs(columns) do
        table.sort(entities, function(a, b)
            if a.row == b.row then
                if a.kind == b.kind then return a.index < b.index end
                return a.kind == "monster"
            end
            return a.row > b.row
        end)

        local finalOccupied = {}
        for _, entity in ipairs(entities) do
            local targetRow = entity.row + 1
            local blocked = false
            local removed = false
            local finalRow = entity.row

            if not entity.canMove then
                blocked = true
            elseif targetRow > Config.FIELD_ROWS then
                removed = true
            elseif finalOccupied[targetRow] then
                blocked = true
            else
                finalRow = targetRow
            end

            if not removed then
                finalOccupied[finalRow] = true
            end

            if entity.kind == "fieldReward" then
                plans[entity.index] = {
                    row = finalRow,
                    removed = removed,
                    blocked = blocked,
                }
            end
        end
    end

    return plans
end

function FieldRewardSystem.MoveFieldRewards(state)
    EnsureRewardRuntime(state)

    local toRemove = {}
    local plans = BuildFieldMovementPlans(state)

    for i, fieldReward in ipairs(state.fieldRewards) do
        if fieldReward.hp > 0 then
            local plan = plans[i]
            if plan and plan.removed then
                table.insert(toRemove, i)
                print("  [FieldReward] 随机奖励离场消失")
            elseif plan and plan.blocked then
                print(string.format("  [FieldReward] 随机奖励前方被阻挡，停留在第%d行", fieldReward.row))
            elseif plan then
                fieldReward.row = plan.row
            end
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(state.fieldRewards, toRemove[i])
    end
end

local function ApplyReincarnationQualityBonus(state, quality, maxQuality)
    local count = math.max(0, state.reincarnationCount or 0)
    if count <= 0 or quality >= maxQuality then return quality end

    local chance = math.min(Config.REINCARNATION_DROP_QUALITY_CHANCE_CAP or 0.30, count * (Config.REINCARNATION_DROP_QUALITY_CHANCE or 0.05))
    if math.random() < chance then
        return math.min(maxQuality, quality + 1)
    end
    return quality
end

function FieldRewardSystem.RollRewardQuality(state)
    local shift = math.floor(RogueRewardSystem.GetModifierValue(state, "fieldRewardQualityShift"))
    local minQuality, maxQuality = Config.GetDropQualityRange(state.realmIndex or 1)
    local total = 0
    for _, entry in ipairs(Config.DROP_RULES.QUALITY_WEIGHTS or {}) do
        local quality = entry.quality or 1
        if quality >= minQuality and quality <= maxQuality then
            total = total + math.max(0, entry.weight or 0)
        end
    end
    if total <= 0 then return minQuality end

    local roll = math.random() * total
    local acc = 0
    for _, entry in ipairs(Config.DROP_RULES.QUALITY_WEIGHTS or {}) do
        local quality = entry.quality or 1
        if quality >= minQuality and quality <= maxQuality then
            acc = acc + math.max(0, entry.weight or 0)
            if roll <= acc then
                local shiftedQuality = math.min(maxQuality, math.max(minQuality, quality + shift))
                return ApplyReincarnationQualityBonus(state, shiftedQuality, maxQuality)
            end
        end
    end
    return ApplyReincarnationQualityBonus(state, math.min(maxQuality, math.max(minQuality, minQuality + shift)), maxQuality)
end

local function PickFallbackCell(state)
    local cells = {}
    for row = 1, Config.FIELD_ROWS do
        for col = 1, Config.GRID_COLS do
            if not FieldCellBlocked(state, col, row) then
                table.insert(cells, { col = col, row = row })
            end
        end
    end
    if #cells == 0 then return nil end
    return cells[math.random(#cells)]
end

local function CreateRewardAtCell(state, col, row, sourceLabel)
    local rewardQuality = FieldRewardSystem.RollRewardQuality(state)
    local rewardItem = FieldRewardService.CreateRewardItem(state, rewardQuality)
    if not rewardItem then return false end

    table.insert(state.fieldRewards, {
        col = col,
        row = row,
        hp = Config.FIELD_REWARD.HP or 1,
        quality = rewardItem.quality or rewardQuality,
        rewardItem = rewardItem,
    })

    state.fieldRewardTurnsSinceSpawn = 0
    PushRecentRewardColumn(state, col)
    print(string.format("  [Spawn] %s刷新在第%d列第%d行：%s", sourceLabel or "随机奖励", col, row, rewardItem.name or "未知道具"))
    return true
end

local function SpawnRewardAtTop(state, sourceLabel)
    local col = PickRewardColumn(state)
    if not col then return false end
    return CreateRewardAtCell(state, col, 1, sourceLabel)
end

function FieldRewardSystem.SpawnFieldRewards(state)
    EnsureRewardRuntime(state)

    state.fieldRewardTurnsSinceSpawn = (state.fieldRewardTurnsSinceSpawn or 0) + 1
    if #state.fieldRewards >= Config.FIELD_REWARD.MAX_COUNT then return end
    if state.fieldRewardTurnsSinceSpawn < (Config.FIELD_REWARD.MIN_INTERVAL or 2) then return end

    local spawnChance = GetRewardSpawnChance(state)
    if math.random() > spawnChance then return end

    SpawnRewardAtTop(state, "随机奖励")
end

function FieldRewardSystem.ForceSpawnFieldReward(state, sourceLabel)
    EnsureRewardRuntime(state)
    if #state.fieldRewards >= Config.FIELD_REWARD.MAX_COUNT then
        table.remove(state.fieldRewards, 1)
    end
    if SpawnRewardAtTop(state, sourceLabel or "强制奖励") then
        return true
    end

    local fallback = PickFallbackCell(state)
    if not fallback then return false end
    return CreateRewardAtCell(state, fallback.col, fallback.row, sourceLabel or "强制奖励")
end

return FieldRewardSystem
