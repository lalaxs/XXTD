local Config = require("Config")
local GameState = require("GameState")
local WaveSystem = require("WaveSystem")
local RealmSystem = require("RealmSystem")
local Stats = require("combat.Stats")

local RunLifecycle = {}

local function CopyTable(value)
    if type(value) ~= "table" then return value end
    local copied = {}
    for k, v in pairs(value) do
        copied[k] = CopyTable(v)
    end
    return copied
end

local function HasPendingRogueChoice(state)
    return state and state.pendingRogueChoices and #state.pendingRogueChoices > 0
end

local function HasActiveMonster(state)
    if not state then return false end
    for _, monster in ipairs(state.monsters or {}) do
        if monster.hp and monster.hp > 0 then
            return true
        end
    end
    return false
end

function RunLifecycle.CapturePermanentProgress(state)
    if not state then return nil end
    return {
        talentPoints = state.talentPoints or 0,
        spentTalentPoints = state.spentTalentPoints or 0,
        purchasedTalents = CopyTable(state.purchasedTalents or {}),
        talentModifiers = CopyTable(state.talentModifiers or {}),
        talentVariants = CopyTable(state.talentVariants or {}),
        unlockedPools = CopyTable(state.unlockedPools or {}),
        unlockedWeaponSchools = CopyTable(state.unlockedWeaponSchools or {}),
        reincarnationCount = state.reincarnationCount or 0,
        difficulty = state.difficulty or 1,
        difficultyTalentBonus = state.difficultyTalentBonus or 0,
        maxUnlockedDifficulty = state.maxUnlockedDifficulty or 1,
    }
end

function RunLifecycle.RestorePermanentProgress(state, progress)
    if not state or not progress then return end
    state.talentPoints = progress.talentPoints
    state.spentTalentPoints = progress.spentTalentPoints
    state.purchasedTalents = progress.purchasedTalents
    state.talentModifiers = progress.talentModifiers
    state.talentVariants = progress.talentVariants
    state.unlockedPools = progress.unlockedPools
    state.unlockedWeaponSchools = progress.unlockedWeaponSchools
    state.reincarnationCount = progress.reincarnationCount
    state.difficulty = progress.difficulty
    state.difficultyTalentBonus = progress.difficultyTalentBonus
    state.maxUnlockedDifficulty = progress.maxUnlockedDifficulty
    Stats.RecalculateMaxHp(state, { fullHeal = true })
end

function RunLifecycle.ResetOpeningWave(state)
    if not state then return end
    state.monsters = {}
    state.waveCount = 0
    state.realmWaveIndex = 0
    WaveSystem.ForceSpawnWave(state)
end

function RunLifecycle.StartNewGame(progress)
    local state = GameState.New()
    state.slots[1] = GameState.CreateItemByBaseId(state, Config.ITEM_CATEGORY.WEAPON, "qingfeng_sword", 1)
    state.waveCount = 0
    state.realmWaveIndex = 0
    WaveSystem.ForceSpawnWave(state)

    if progress then
        RunLifecycle.RestorePermanentProgress(state, progress)
        RunLifecycle.ResetOpeningWave(state)
    end

    return state
end

function RunLifecycle.RestartKeepingProgress(state)
    return RunLifecycle.StartNewGame(RunLifecycle.CapturePermanentProgress(state))
end

function RunLifecycle.AbandonRunKeepingProgress(state)
    return RunLifecycle.StartNewGame(RunLifecycle.CapturePermanentProgress(state))
end

function RunLifecycle.EnterReincarnation(state)
    if not state then return nil end
    RealmSystem.TriggerReincarnation(state)
    return RunLifecycle.StartNewGame(RunLifecycle.CapturePermanentProgress(state))
end

function RunLifecycle.ContinueRun(state)
    if not state or not state.canContinueRun then return state end

    state.isGameOver = false
    state.isVictory = false
    state.victoryReason = nil
    state.canContinueRun = false
    state.hp = state.maxHp
    state.lastPillHp = state.maxHp
    state.forceSpawnNextTurn = false

    if state.shouldSpawnBreakthroughWave then
        state.shouldSpawnBreakthroughWave = false
        WaveSystem.ForceSpawnWave(state)
    elseif not HasPendingRogueChoice(state) and not HasActiveMonster(state) then
        WaveSystem.ForceSpawnWave(state)
    end

    return state
end

return RunLifecycle
