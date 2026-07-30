local Config = require("Config")
local GameState = require("GameState")
local WaveSystem = require("WaveSystem")
local RealmSystem = require("RealmSystem")
local Stats = require("combat.Stats")
local ReincarnationSystem = require("ReincarnationSystem")
local DailyChallenge = require("DailyChallenge")
local VisualState = require("VisualState")
local TutorialSystem = require("TutorialSystem")

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
    state.endlessWaveIndex = 0
    state.endlessBudget = 0
    state.endlessKills = 0
    state.endlessWaveActive = false
    if DailyChallenge.IsActive(state) then
        state.coins = state.coins + DailyChallenge.GetEffect(state, "initialCoinsAdd", 0)
        Stats.RecalculateMaxHp(state, { fullHeal = true })
    end
    WaveSystem.ForceSpawnWave(state)
end

function RunLifecycle.RestoreSavedState(savedState)
    if type(savedState) ~= "table" then return nil end

    local state = GameState.New()
    for key, value in pairs(savedState) do
        state[key] = CopyTable(value)
    end

    state.slots = state.slots or {}
    state.monsters = state.monsters or {}
    state.fieldRewards = state.fieldRewards or {}
    state.dropQueue = state.dropQueue or {}
    state.buffs = state.buffs or {}
    state.weaponCombatState = state.weaponCombatState or {}
    state.runWeapons = state.runWeapons or { qingfeng_sword = true }
    state.runArmors = state.runArmors or { dark_iron_shield = true }
    state.weaponUpgradeLevels = state.weaponUpgradeLevels or {}
    state.modifiers = state.modifiers or {}
    state.selectedRogueRewards = state.selectedRogueRewards or {}
    state.rogueRewardHistory = state.rogueRewardHistory or {}
    state.visual = VisualState.Create()
    state.visualEventQueue = nil
    state.lastDamageDealt = {}
    state.lastAttackEvents = {}
    state.lastMonsterAttackEvents = {}
    state.lastCoinDropEvents = {}
    state.lastPlayerDamage = 0
    state.lastPlayerDamageCrit = false
    state.pillConsumeMessages = {}
    state.visualStatusEvents = {}
    state.lastBreakthroughEvent = nil
    state.dropMessages = {}
    state.reincarnationTriggered = false
    state.turnLog = {}
    state.leaderboardSubmitted = false
    ReincarnationSystem.EnsureState(state)
    return state
end

function RunLifecycle.StartNewGame(progress, runOptions)
    local state = GameState.New()
    if runOptions and runOptions.dailyChallenge then
        DailyChallenge.ApplyToState(state, runOptions.dailyChallenge)
    end
    state.slots[1] = GameState.CreateItemByBaseId(state, Config.ITEM_CATEGORY.WEAPON, "qingfeng_sword", 1)
    state.waveCount = 0
    state.realmWaveIndex = 0
    state.endlessWaveIndex = 0
    state.endlessBudget = 0
    state.endlessKills = 0
    state.endlessWaveActive = false

    if runOptions and runOptions.firstRunTutorial == true then
        TutorialSystem.Begin(state)
        local monster = WaveSystem.SpawnTutorialOpeningMonster(state, 3)
        TutorialSystem.RegisterOpeningMonster(state, monster)
    else
        WaveSystem.ForceSpawnWave(state)
    end

    if progress then
        RunLifecycle.RestorePermanentProgress(state, progress)
        Stats.RecalculateMaxHp(state, { fullHeal = true })
        RunLifecycle.ResetOpeningWave(state)
    end

    return state
end

function RunLifecycle.RestartKeepingProgress(state)
    if DailyChallenge.IsActive(state) then
        local challenge = DailyChallenge.ResolveToday()
        if challenge.available ~= true then
            print("[Daily] 服务器时间不可用，无法重开每日挑战")
            return state
        end
        return RunLifecycle.StartNewGame(nil, { dailyChallenge = challenge })
    end
    return RunLifecycle.StartNewGame(RunLifecycle.CapturePermanentProgress(state))
end

function RunLifecycle.AbandonRun(state)
    if not state or state.isGameOver then return state end

    state.hp = 0
    state.isGameOver = true
    state.isVictory = false
    state.victoryReason = "abandoned"
    state.settlementType = "abandoned"
    state.canReincarnate = false
    state.reincarnationClaimed = true
    state.canContinueRun = false
    state.pendingRogueEvent = nil
    state.pendingRogueChoices = nil
    state.pendingRogueStage = nil
    state.pendingRogueStages = nil
    state.pendingRogueStageIndex = nil
    state.shouldSpawnBreakthroughWave = false
    state.forceSpawnNextTurn = false
    print("[GameOver] 玩家放弃当前轮回，不获得轮回点")
    return state
end

function RunLifecycle.AbandonRunKeepingProgress(state)
    if DailyChallenge.IsActive(state) then
        return RunLifecycle.StartNewGame(nil)
    end
    return RunLifecycle.StartNewGame(RunLifecycle.CapturePermanentProgress(state))
end

function RunLifecycle.EnterReincarnation(state)
    if not state then return nil end
    if not RealmSystem.TriggerReincarnation(state) then return state end
    return RunLifecycle.StartNewGame(RunLifecycle.CapturePermanentProgress(state))
end

function RunLifecycle.ContinueRun(state)
    if not state or not state.canContinueRun then return state end

    state.isGameOver = false
    state.isVictory = false
    state.victoryReason = nil
    state.settlementType = nil
    state.canContinueRun = false
    state.forceSpawnNextTurn = false

    if state.ascensionMode == true then
        state.isGameOver = false
        state.isVictory = false
        state.victoryReason = nil
        state.settlementType = nil
        state.endlessWaveIndex = 0
        state.endlessBudget = 0
        state.endlessKills = 0
        state.endlessWaveActive = HasActiveMonster(state)
        if not HasActiveMonster(state) then
            WaveSystem.ForceSpawnWave(state)
        end
        return state
    end

    if state.shouldSpawnBreakthroughWave then
        state.shouldSpawnBreakthroughWave = false
        WaveSystem.ForceSpawnWave(state)
    elseif not HasPendingRogueChoice(state) and not HasActiveMonster(state) then
        WaveSystem.ForceSpawnWave(state)
    end

    return state
end

return RunLifecycle
