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

function RealmSystem.AddExp(state, amount, options)
    options = options or {}
    local finalAmount = math.floor((amount or 0) * RealmSystem.GetExpMultiplier(state))
    state.exp = state.exp + finalAmount

    if not options.deferCheck then
        RealmSystem.CheckRealmUp(state)
    end

    local currentRealm = Config.GetRealm(state.realmIndex)
    if state.realmIndex >= Config.REINCARNATION_REALM_INDEX and state.exp >= (currentRealm.expRequired or 0) then
        state.canReincarnate = true
    end
    return finalAmount
end

local function ResetRealmBoard(state)
    WaveSystem.PrepareRealmBreakthroughWave(state)
    state.shouldSpawnBreakthroughWave = true
    state.lastAttackEvents = {}
    state.lastMonsterAttackEvents = {}
    VisualEventQueue.ClearTurnEvents(state)
end

function RealmSystem.MarkAscensionVictory(state, reason, options)
    options = options or {}
    state.ascensionAchieved = true
    state.isVictory = true
    state.isGameOver = true
    state.victoryReason = reason or "ascension"
    state.canReincarnate = true
    state.canContinueRun = options.canContinue == true
    state.maxUnlockedDifficulty = math.min(Config.MAX_DIFFICULTY or 5,
        math.max(state.maxUnlockedDifficulty or 1, (state.difficulty or 1) + 1))
end

function RealmSystem.CheckRealmUp(state)
    while state.realmIndex < #Config.REALMS and not state.pendingRogueChoices do
        local currentRealm = Config.GetRealm(state.realmIndex)
        if state.exp < (currentRealm.expRequired or 0) then break end

        state.realmIndex = state.realmIndex + 1
        state.exp = 0
        local realm = Config.GetRealm(state.realmIndex)
        local isMajorBreakthrough = Config.IsMajorRealmBreakthrough(state.realmIndex)
        if isMajorBreakthrough then
            ResetRealmBoard(state)
        end

        Stats.RecalculateMaxHp(state, { fullHeal = true })
        local bonusHeal = math.floor(state.maxHp * RogueRewardSystem.GetModifierValue(state, "breakthroughHealPct"))
        if bonusHeal > 0 then
            Stats.Heal(state, bonusHeal, { allowOverheal = true })
        end

        local breakthroughEvent = {
            realmIndex = state.realmIndex,
            realmName = realm.name,
            isMajorBreakthrough = isMajorBreakthrough,
        }
        VisualEventQueue.PushBreakthrough(state, breakthroughEvent)

        if state.realmIndex >= #Config.REALMS then
            RealmSystem.MarkAscensionVictory(state, "ascension", { canContinue = true })
            state.pendingRogueEvent = nil
            state.pendingRogueChoices = nil
            state.shouldSpawnBreakthroughWave = false
        elseif isMajorBreakthrough then
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
end

function RealmSystem.HandleDeath(state)
    state.hp = 0
    if state.realmIndex >= #Config.REALMS or state.ascensionAchieved then
        RealmSystem.MarkAscensionVictory(state, "ascension_failed", { canContinue = false })
        print("[Victory] 飞升后气血归零，天命已成，进入轮回结算")
    else
        state.isVictory = false
        state.isGameOver = true
        state.victoryReason = "failed"
        state.canContinueRun = false
        print("[GameOver] 气血归零，本轮直接重开")
    end
    return false
end

function RealmSystem.TriggerReincarnation(state)
    ReincarnationSystem.GrantReincarnationPoint(state)
    VisualEventQueue.PushReincarnation(state)
end

return RealmSystem
