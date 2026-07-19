local Config = require("Config")
local GameState = require("GameState")
local WaveSystem = require("WaveSystem")
local RealmSystem = require("RealmSystem")
local Stats = require("combat.Stats")
local ReincarnationSystem = require("ReincarnationSystem")

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
        reincarnationPoints = state.reincarnationPoints or 0,
        reincarnationUpgrades = CopyTable(state.reincarnationUpgrades or {}),
        reincarnationCount = state.reincarnationCount or 0,
        difficulty = state.difficulty or 1,
        maxUnlockedDifficulty = state.maxUnlockedDifficulty or 1,
    }
end

function RunLifecycle.RestorePermanentProgress(state, progress)
    if not state or not progress then return end
    state.reincarnationPoints = progress.reincarnationPoints or 0
    state.reincarnationUpgrades = CopyTable(progress.reincarnationUpgrades or {})
    state.reincarnationCount = progress.reincarnationCount or 0
    state.difficulty = progress.difficulty or 1
    state.maxUnlockedDifficulty = progress.maxUnlockedDifficulty or 1
    ReincarnationSystem.EnsureState(state)
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
        Stats.RecalculateMaxHp(state, { fullHeal = true })
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
