local Config = require("Config")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local WaveSystem = require("WaveSystem")

local Stats = require("combat.Stats")

local RealmSystem = {}

-- 获取天赋加成后的最大血量
function RealmSystem.GetMaxHp(state)
    return Stats.GetMaxHp(state)
end

-- 获取天赋加成后的经验倍率
function RealmSystem.GetExpMultiplier(state)
    local talentPoints = state.talentPoints or 0
    return 1.0 + talentPoints * Config.TALENT.PER_POINT_EXP
end

function RealmSystem.CalculateBreakthroughTalentGain(state)
    return 1
end

function RealmSystem.GrantBreakthroughTalentPoints(state)
    local gain = RealmSystem.CalculateBreakthroughTalentGain(state)
    local before = state.talentPoints or 0
    local after = math.min(Config.TALENT.MAX_POINTS, before + gain)
    state.talentPoints = after
    return after - before
end

-- 添加经验（含天赋加成和轮回检测）
function RealmSystem.AddExp(state, amount, options)
    options = options or {}

    local expMul = RealmSystem.GetExpMultiplier(state)
    local finalAmount = math.floor(amount * expMul)
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
    state.lastDamageDealt = {}
    state.lastAttackEvents = {}
    state.lastMonsterAttackEvents = {}
    state.lastPlayerDamage = 0
    state.lastPlayerDamageCrit = false
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
        if state.exp >= (currentRealm.expRequired or 0) then
            state.realmIndex = state.realmIndex + 1
            state.exp = 0
            local realm = Config.GetRealm(state.realmIndex)
            local isMajorBreakthrough = Config.IsMajorRealmBreakthrough(state.realmIndex)
            if isMajorBreakthrough then
                ResetRealmBoard(state)
            end

            local talentGain = RealmSystem.GrantBreakthroughTalentPoints(state)
            Stats.RecalculateMaxHp(state, { fullHeal = true })
            local bonusHeal = math.floor(state.maxHp * RogueRewardSystem.GetModifierValue(state, "breakthroughHealPct"))
            if bonusHeal > 0 then
                Stats.Heal(state, bonusHeal, { allowOverheal = true })
            end

            state.lastBreakthroughEvent = {
                realmIndex = state.realmIndex,
                realmName = realm.name,
                talentGain = talentGain,
                totalTalentPoints = state.talentPoints or 0,
                isMajorBreakthrough = isMajorBreakthrough,
            }

            if state.realmIndex >= #Config.REALMS then
                RealmSystem.MarkAscensionVictory(state, "ascension", { canContinue = true })
                state.pendingRogueEvent = nil
                state.pendingRogueChoices = nil
                state.shouldSpawnBreakthroughWave = false
            elseif isMajorBreakthrough then
                state.pendingRogueEvent = state.lastBreakthroughEvent
                RogueRewardSystem.CreateBreakthroughChoices(state)
            else
                state.pendingRogueEvent = nil
                state.pendingRogueChoices = nil
                state.shouldSpawnBreakthroughWave = false
            end

            print(string.format("[Realm Up] 境界突破: %s! 气血=%d/%d 天赋点+%d 当前%d%s",
                realm.name, state.hp, state.maxHp, talentGain, state.talentPoints or 0,
                isMajorBreakthrough and " 大境界突破" or ""))
        else
            break
        end
    end
end

-- 死亡处理：飞升前失败直接结束本轮；飞升境界失败按胜利结算并要求进入轮回
-- 返回 false = 本轮已结束
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

-- 轮回系统
function RealmSystem.TriggerReincarnation(state)
    -- 获得1天赋点（受当前天赋点上限限制）
    state.talentPoints = state.talentPoints or 0
    if state.talentPoints < Config.TALENT.MAX_POINTS then
        state.talentPoints = state.talentPoints + 1
        print(string.format("[Reincarnation] 获得天赋点! 当前: %d/%d",
            state.talentPoints, Config.TALENT.MAX_POINTS))
    else
        print("[Reincarnation] 天赋点已满，不再增加")
    end

    -- 重置修为到1阶练气期，清空累计经验
    state.realmIndex = 1
    state.exp = 0

    -- 重置波次、场上怪物、已放置道具
    state.waveCount = 0
    state.waveTurnProgress = 0
    state.realmWaveIndex = 0
    state.pendingWaveQueue = {}
    state.pendingWaveIndex = nil
    state.pendingWaveExp = 0
    state.forceSpawnNextTurn = false
    state.monsters = {}
    state.fieldRewards = {}
    state.fieldRewardTurnsSinceSpawn = 0
    state.fieldRewardRecentCols = {}
    state.recentSpawnColumns = {}

    -- 清空布政区已放置道具
    for i = 1, Config.TOTAL_SLOTS do
        state.slots[i] = nil
    end

    -- 保留仓库内未放置道具（dropQueue）和已绑定词条
    -- dropQueue 不清空

    -- 重置血量为新境界满血（含天赋加成）
    Stats.RecalculateMaxHp(state, { fullHeal = true })

    -- 重置辅助计数器
    state.lastPillHp = state.maxHp
    state.buffs = {}
    state.deathSaveRatio = 0
    state.deathSaveUsed = false
    state.modifiers = {}
    state.selectedRogueRewards = {}
    state.rogueRewardHistory = {}
    state.pendingRogueChoices = nil
    state.pendingRogueEvent = nil
    state.lastBreakthroughEvent = nil
    state.turn = 0

    -- 标记轮回事件（UI可读取显示）
    state.reincarnationTriggered = true
    state.reincarnationCount = (state.reincarnationCount or 0) + 1

    print(string.format("[Reincarnation] 返璞归真！第%d次轮回，天赋点=%d",
        state.reincarnationCount, state.talentPoints))
end

return RealmSystem
