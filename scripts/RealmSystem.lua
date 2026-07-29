local Config = require("Config")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local VisualEventQueue = require("events.VisualEventQueue")
local WaveSystem = require("WaveSystem")
local ReincarnationSystem = require("ReincarnationSystem")
local Stats = require("combat.Stats")

local RealmSystem = {}

function RealmSystem.GetMaxHp(state)
    return Stats.GetMaxHp(state)
end

function RealmSystem.GetExpMultiplier(state)
    return 1.0 + ReincarnationSystem.GetValue(state, "expGain")
end

local function RefreshReincarnationEligibility(state)
    local currentRealm = Config.GetRealm(state.realmIndex)
    local reachedRealmThreshold = state.realmIndex >= Config.REINCARNATION_REALM_INDEX
        and state.exp >= (currentRealm.expRequired or 0)
    state.canReincarnate = state.reincarnationClaimed ~= true
        and (state.ascensionAchieved == true or (not state.ascensionMode and reachedRealmThreshold))
end

function RealmSystem.AddExp(state, amount, options)
    options = options or {}
    local baseAmount = math.max(0, amount or 0)
    local finalAmount = math.max(0, math.floor(baseAmount * RealmSystem.GetExpMultiplier(state)))
    state.exp = math.max(0, (state.exp or 0) + finalAmount)

    if not options.deferCheck then
        RealmSystem.CheckRealmUp(state)
    end

    RefreshReincarnationEligibility(state)
    return finalAmount
end

local function ResetRealmBoard(state)
    WaveSystem.PrepareRealmBreakthroughWave(state)
    state.shouldSpawnBreakthroughWave = true
    state.lastAttackEvents = {}
    state.lastMonsterAttackEvents = {}
    VisualEventQueue.ClearTurnEvents(state)
end

function RealmSystem.EnterAscension(state)
    if state.ascensionMode == true then return end

    state.ascensionAchieved = true
    state.ascensionMode = true
    state.isVictory = true
    state.isGameOver = true
    state.victoryReason = "ascension"
    state.settlementType = "ascension_reached"
    state.canContinueRun = true
    state.canReincarnate = true
    state.exp = 0
    state.endlessWaveIndex = 0
    state.endlessBudget = 0
    state.endlessKills = 0
    state.endlessWaveActive = false
    state.pendingRogueEvent = nil
    state.pendingRogueChoices = nil
    state.shouldSpawnBreakthroughWave = false
    state.forceSpawnNextTurn = false
    state.maxUnlockedDifficulty = math.min(Config.MAX_DIFFICULTY or 5,
        math.max(state.maxUnlockedDifficulty or 1, (state.difficulty or 1) + 1))

    Stats.RecalculateMaxHp(state)
    VisualEventQueue.PushDropMessage(state, "渡劫后期突破，飞升成功")
    print(string.format("[Ascension] 飞升成功，保留当前战场，继续按钮可开启无尽模式；当前敌人=%d",
        #(state.monsters or {})))
end

function RealmSystem.FinishAscensionRun(state)
    state.ascensionAchieved = true
    state.ascensionMode = false
    state.isVictory = true
    state.isGameOver = true
    state.victoryReason = "ascension_death"
    state.settlementType = "ascension_death"
    state.canReincarnate = true
    state.canContinueRun = false
end

function RealmSystem.CheckRealmUp(state)
    if state.ascensionMode == true then return end
    if state.realmIndex >= Config.ASCENSION_TRIGGER_REALM_INDEX then
        if state.exp >= (Config.ASCENSION_EXP_REQUIRED or 0) then
            RealmSystem.EnterAscension(state)
        end
        return
    end

    while state.realmIndex < Config.ASCENSION_TRIGGER_REALM_INDEX and not state.pendingRogueChoices do
        local currentRealm = Config.GetRealm(state.realmIndex)
        if state.exp < (currentRealm.expRequired or 0) then break end

        state.realmIndex = state.realmIndex + 1
        state.exp = 0
        local realm = Config.GetRealm(state.realmIndex)
        local isMajorBreakthrough = Config.IsMajorRealmBreakthrough(state.realmIndex)
        if isMajorBreakthrough then
            ResetRealmBoard(state)
        end

        Stats.RecalculateMaxHp(state)

        local breakthroughEvent = {
            realmIndex = state.realmIndex,
            realmName = realm.name,
            isMajorBreakthrough = isMajorBreakthrough,
        }
        VisualEventQueue.PushBreakthrough(state, breakthroughEvent)

        if isMajorBreakthrough then
            state.pendingRogueEvent = breakthroughEvent
            RogueRewardSystem.CreateBreakthroughChoices(state)
        else
            state.pendingRogueEvent = nil
            state.pendingRogueChoices = nil
            state.shouldSpawnBreakthroughWave = false
        end

        print(string.format("[Realm Up] 境界突破: %s! 气血=%d/%d%s",
            realm.name, state.hp, state.maxHp, isMajorBreakthrough and " 大境界突破" or ""))
    end

    if state.realmIndex >= Config.ASCENSION_TRIGGER_REALM_INDEX
        and state.exp >= (Config.ASCENSION_EXP_REQUIRED or 0)
        and not state.pendingRogueChoices then
        RealmSystem.EnterAscension(state)
    end
end

function RealmSystem.HandleDeath(state)
    state.hp = 0
    if state.ascensionMode == true then
        RealmSystem.FinishAscensionRun(state)
        print("[Ascension] 飞升状态下气血归零，进入无尽挑战结算")
    else
        state.isVictory = false
        state.isGameOver = true
        state.victoryReason = "failed"
        state.settlementType = "failed"
        state.canContinueRun = false
        print("[GameOver] 气血归零，本轮直接重开")
    end
    return false
end

function RealmSystem.TriggerReincarnation(state)
    if not state or state.canReincarnate ~= true or state.reincarnationClaimed == true then
        return false
    end

    state.reincarnationClaimed = true
    state.canReincarnate = false
    ReincarnationSystem.GrantReincarnationPoint(state)
    VisualEventQueue.PushReincarnation(state)
    return true
end

return RealmSystem
