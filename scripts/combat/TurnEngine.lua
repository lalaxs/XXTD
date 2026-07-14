-- combat/TurnEngine.lua
-- 回合编排入口，按设计文档流程结算法宝、击杀、怪物行动、承伤、状态与补给。

local Config = require("Config")
local BuffSystem = require("BuffSystem")
local RealmSystem = require("RealmSystem")
local MonsterSystem = require("MonsterSystem")
local FieldRewardSystem = require("FieldRewardSystem")
local WaveSystem = require("WaveSystem")
local PlayerItemResolver = require("combat.PlayerItemResolver")
local KillResolver = require("combat.KillResolver")
local TalentSystem = require("TalentSystem")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local Stats = require("combat.Stats")

local TurnEngine = {}

local function ResetTurnEvents(state)
    state.turnLog = {}
    state.lastDamageDealt = {}
    state.lastAttackEvents = {}
    state.lastMonsterAttackEvents = {}
    state.lastPlayerDamage = 0
    state.lastPlayerDamageCrit = false
    state.consumableUsesThisTurn = 0
end

local function TakeHeldDeathSavePill(state)
    if state.deathSaveUsed then return nil end

    local function isDeathSavePill(item)
        return item
            and item.category == Config.ITEM_CATEGORY.PILL
            and item.baseId == "xuming"
            and item.pillEffect
            and item.pillEffect.type == "deathSave"
    end

    local picked = nil
    local pickedSlotIdx = nil
    local pickedQueueIndex = nil
    local pickedRatio = 0

    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots and state.slots[slotIdx]
        if isDeathSavePill(item) then
            local ratio = item.pillEffect.value or 0
            if ratio > pickedRatio then
                picked = item
                pickedSlotIdx = slotIdx
                pickedQueueIndex = nil
                pickedRatio = ratio
            end
        end
    end

    for index, item in ipairs(state.dropQueue or {}) do
        if isDeathSavePill(item) then
            local ratio = item.pillEffect.value or 0
            if ratio > pickedRatio then
                picked = item
                pickedSlotIdx = nil
                pickedQueueIndex = index
                pickedRatio = ratio
            end
        end
    end

    if pickedSlotIdx then
        state.slots[pickedSlotIdx] = nil
    elseif pickedQueueIndex then
        table.remove(state.dropQueue, pickedQueueIndex)
    end

    return picked
end

local function TriggerDeathSave(state, ratio, sourceName)
    if state.deathSaveUsed or (ratio or 0) <= 0 then return false end

    state.deathSaveRatio = 0
    state.deathSaveUsed = true
    state.hp = 0
    Stats.Heal(state, math.max(1, math.floor(state.maxHp * ratio)))
    print(string.format("[Death Save] %s触发，恢复%d气血", sourceName or "免死护佑", state.hp))
    return true
end

local function ResolveDeath(state)
    if state.hp > 0 then return false end

    if TriggerDeathSave(state, state.deathSaveRatio or 0, "免死护佑") then
        return false
    end

    local deathSavePill = TakeHeldDeathSavePill(state)
    if deathSavePill then
        local effect = deathSavePill.pillEffect or {}
        if TriggerDeathSave(state, effect.value or 0, deathSavePill.name or "续命丹") then
            return false
        end
    end

    state.hp = 0
    RealmSystem.HandleDeath(state)
    return true
end

local function AdvanceWaveProgress(state)
    local monstersHit = #state.lastDamageDealt > 0
    local fieldRewardOnly = (not monstersHit) and state._fieldRewardClaimedThisTurn
    if not fieldRewardOnly then
        state.waveTurnProgress = state.waveTurnProgress + 1
    end
    state._fieldRewardClaimedThisTurn = false
end

local function HasActiveMonster(state)
    for _, monster in ipairs(state.monsters or {}) do
        if monster.hp > 0 then
            return true
        end
    end
    return false
end

local function RefreshBoard(state, suppressWaveSpawn)
    if state.pendingRogueChoices then return end
    FieldRewardSystem.SpawnFieldRewards(state)

    if state.forceSpawnNextTurn then
        state.forceSpawnNextTurn = false
        WaveSystem.ForceSpawnWave(state)
    elseif not suppressWaveSpawn then
        WaveSystem.SpawnWave(state)
    end
end

local function ApplyTurnRegen(state)
    local regenPct = TalentSystem.GetModifierValue(state, "turnRegenPct")
    if regenPct <= 0 or state.hp <= 0 then return end

    local heal = math.max(1, math.floor(state.maxHp * regenPct))
    local actualHeal = Stats.Heal(state, heal)
    print(string.format("  [Talent] 回春再生恢复%d气血", actualHeal))
end

local function TriggerFieldRewardSupply(state)
    local interval = math.floor(RogueRewardSystem.GetModifierValue(state, "fieldRewardSupplyInterval"))
    if interval <= 0 or state.turn <= 0 or state.turn % interval ~= 0 then return end

    local spawned = FieldRewardSystem.ForceSpawnFieldReward(state, "百宝囊")
    if spawned then
        table.insert(state.dropMessages, "百宝囊感应：随机奖励已刷新")
        print("  [Rogue] 百宝囊触发，强制刷新一个随机奖励")
    else
        print("  [Rogue] 百宝囊触发，但场上没有可用刷新点")
    end
end

function TurnEngine.ExecuteTurn(state)
    if state.isGameOver then return end

    state.turn = state.turn + 1
    ResetTurnEvents(state)
    local hadMonsterAtTurnStart = HasActiveMonster(state)

    print(string.format("[Turn %d] === 回合开始 ===", state.turn))

    MonsterSystem.ApplyArmorTurnEffects(state)
    PlayerItemResolver.Resolve(state)
    KillResolver.Resolve(state)
    if state.isGameOver then return end
    MonsterSystem.RangedAttack(state)
    FieldRewardSystem.MoveFieldRewards(state)
    MonsterSystem.MoveMonsters(state)
    MonsterSystem.MeleeAttack(state)
    MonsterSystem.ApplyDamage(state)
    if ResolveDeath(state) then return end
    if state.isGameOver then return end

    ApplyTurnRegen(state)
    KillResolver.Resolve(state)
    if state.isGameOver then return end
    MonsterSystem.TickStatuses(state)
    KillResolver.Resolve(state)
    if ResolveDeath(state) then return end
    if state.isGameOver then return end

    RealmSystem.CheckRealmUp(state)
    TriggerFieldRewardSupply(state)

    if ResolveDeath(state) then return end
    if state.isGameOver then return end

    local clearedAllMonsters = hadMonsterAtTurnStart and not HasActiveMonster(state) and not state.pendingRogueChoices
    if clearedAllMonsters then
        state.forceSpawnNextTurn = true
    end

    AdvanceWaveProgress(state)
    RefreshBoard(state, clearedAllMonsters)
    BuffSystem.TickBuffs(state)

    print(string.format("[Turn %d] === 回合结束 === HP: %d/%d", state.turn, state.hp, state.maxHp))
end

return TurnEngine
