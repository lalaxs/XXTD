-- items/ConsumableService.lua
-- 丹药/符咒主动使用逻辑。使用不推进回合。

local Config = require("Config")
local ItemSystem = require("ItemSystem")
local BuffSystem = require("BuffSystem")
local KillResolver = require("combat.KillResolver")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local GameEvents = require("GameEvents")
local VisualEventQueue = require("events.VisualEventQueue")

local ConsumableService = {}

local function IsConsumable(item)
    local category = ItemSystem.GetCategory(item)
    return category == "pill" or category == "talisman"
end

local function HasUsableEffect(item)
    return IsConsumable(item)
end

local function GetItem(state, category, index)
    if category == "deploy" then
        return state.slots[index]
    elseif category == "storage" then
        return state.dropQueue[1]
    end
    return nil
end

local function RemoveItem(state, category, index)
    if category == "deploy" then
        state.slots[index] = nil
    elseif category == "storage" then
        table.remove(state.dropQueue, 1)
    end
end

local function GetPillMultiplier(state)
    return 1 + RogueRewardSystem.GetModifierValue(state, "pillEffectPct")
end

local function GetTalismanMultiplier(state)
    return 1 + RogueRewardSystem.GetModifierValue(state, "talismanEffectPct")
end

local function ClearPlayerDebuffs(state)
    state.debuffs = {}
    state.playerDebuffs = {}
    state.sealedSlots = {}
    state.poisonStacks = 0
    state.poisonDamageRatio = 0
    state.pendingPlayerDebuffs = nil
    state.pendingSealedSlots = nil
end

local function ClearOnePlayerDebuff(state)
    if state.playerDebuffs then
        for key, _ in pairs(state.playerDebuffs) do
            state.playerDebuffs[key] = nil
            return true
        end
    end
    if state.sealedSlots then
        for slotIdx, _ in pairs(state.sealedSlots) do
            state.sealedSlots[slotIdx] = nil
            return true
        end
    end
    if (state.poisonStacks or 0) > 0 then
        state.poisonStacks = 0
        state.poisonDamageRatio = 0
        if state.debuffs then
            state.debuffs.poisonStacks = nil
        end
        return true
    end
    if state.pendingPlayerDebuffs then
        for key, _ in pairs(state.pendingPlayerDebuffs) do
            state.pendingPlayerDebuffs[key] = nil
            return true
        end
    end
    if state.pendingSealedSlots then
        for slotIdx, _ in pairs(state.pendingSealedSlots) do
            state.pendingSealedSlots[slotIdx] = nil
            return true
        end
    end
    return false
end

local function ClearPlayerDebuffsByCount(state, count)
    if count >= 99 then
        ClearPlayerDebuffs(state)
        return
    end
    for _ = 1, math.max(0, count or 0) do
        if not ClearOnePlayerDebuff(state) then break end
    end
end

local function ApplyPlayerHeal(state, amount)
    local beforeHp = state.hp or 0
    local maxHp = state.maxHp or beforeHp
    state.hp = math.min(maxHp, beforeHp + math.max(0, amount or 0))
    return math.max(0, state.hp - beforeHp)
end

local function UsePill(state, item)
    local effect = item.pillEffect
    if effect and effect.type == "heal" then
        local realm = Config.GetRealm(state.realmIndex)
        local finalHeal = math.floor((effect.value or 0) * realm.pillMul * GetPillMultiplier(state))
        local actualHeal = ApplyPlayerHeal(state, finalHeal)
        if effect.reduction and effect.reduction > 0 then
            BuffSystem.AddBuff(state, "allUp", effect.reduction, effect.duration or 3)
            GameEvents.AddPlayerStatus(state, "攻防强化", "buff")
        end
        if (effect.cleanseCount or 0) > 0 then
            ClearPlayerDebuffsByCount(state, effect.cleanseCount or 0)
        end
        return string.format("使用%s，恢复%d气血", item.name, actualHeal), actualHeal
    elseif effect and effect.type == "shield" then
        BuffSystem.AddBuff(state, "shield", effect.value or 0, effect.duration or 3)
        GameEvents.AddPlayerStatus(state, "护盾", "buff")
        return string.format("使用%s，获得%d护盾", item.name, effect.value or 0), 0
    elseif effect and effect.type == "cleanse" then
        ClearPlayerDebuffsByCount(state, effect.cleanseCount or 99)
        GameEvents.AddPlayerStatus(state, "净化", "buff")
        if (effect.immunityTurns or 0) > 0 then
            state.debuffImmunityTurns = math.max(state.debuffImmunityTurns or 0, effect.immunityTurns)
            GameEvents.AddPlayerStatus(state, "负面免疫", "buff")
        end
        return string.format("使用%s，清除负面状态", item.name)
    elseif effect and effect.type == "attackBuff" then
        BuffSystem.AddBuff(state, "atkUp", effect.value or 0, effect.duration or 3)
        GameEvents.AddPlayerStatus(state, "法宝增伤", "buff")
        if (effect.speedValue or item.teamAtkSpeedBonus or 0) > 0 then
            BuffSystem.AddBuff(state, "atkSpeedUp", effect.speedValue or item.teamAtkSpeedBonus or 0, effect.duration or 3)
            GameEvents.AddPlayerStatus(state, "追加出手", "buff")
            return string.format("使用%s，法宝伤害提升%d%%，追加出手提升%d%%", item.name, math.floor((effect.value or 0) * 100), math.floor((effect.speedValue or item.teamAtkSpeedBonus or 0) * 100))
        end
        return string.format("使用%s，法宝伤害提升%d%%", item.name, math.floor((effect.value or 0) * 100))
    elseif effect and effect.type == "deathSave" then
        if state.deathSaveUsed then
            return string.format("%s本局免死次数已用尽", item.name), 0, false
        end
        local currentRatio = state.deathSaveRatio or 0
        local nextRatio = effect.value or 0
        if currentRatio >= nextRatio then
            return string.format("%s未提升当前免死护佑", item.name), 0, false
        end
        state.deathSaveRatio = nextRatio
        GameEvents.AddPlayerStatus(state, "免死护佑", "buff")
        return string.format("使用%s，获得免死护佑", item.name)
    end

    local realm = Config.GetRealm(state.realmIndex)
    local totalHeal = (item.healPerSec or item.value or 0) * (item.duration or 5)
    local finalHeal = math.floor(totalHeal * realm.pillMul * GetPillMultiplier(state))
    local actualHeal = ApplyPlayerHeal(state, finalHeal)

    if item.teamAtkBonus and item.teamAtkBonus > 0 then
        BuffSystem.AddBuff(state, "atkUp", item.teamAtkBonus, item.duration or 5)
        GameEvents.AddPlayerStatus(state, "法宝增伤", "buff")
    end
    if item.teamAtkSpeedBonus and item.teamAtkSpeedBonus > 0 then
        BuffSystem.AddBuff(state, "atkSpeedUp", item.teamAtkSpeedBonus, item.duration or 5)
        GameEvents.AddPlayerStatus(state, "追加出手", "buff")
    end

    return string.format("使用%s，恢复%d气血", item.name, actualHeal), actualHeal
end

local function CollectRandomAliveMonsters(state, targetCount)
    local candidates = {}
    for _, monster in ipairs(state.monsters) do
        if monster.hp > 0 then
            table.insert(candidates, monster)
        end
    end

    if targetCount >= 99 then
        return candidates
    end

    local count = math.min(targetCount, #candidates)
    local targets = {}
    for _ = 1, count do
        local index = math.random(1, #candidates)
        table.insert(targets, candidates[index])
        table.remove(candidates, index)
    end
    return targets
end

local function UseTalisman(state, item)
    local effect = item.talismanEffect
    local talismanMul = GetTalismanMultiplier(state)
    local damage = math.floor((item.aoeDmg or item.atk or 0) * talismanMul)
    if effect and effect.type == "damage" then
        damage = math.floor((effect.value or damage) * talismanMul)
    end
    local targetCount = effect and effect.targetCount or item.targetCount or 1
    local hitCount = 0

    local function applyEffect(monster)
        if damage > 0 then
            monster.hp = monster.hp - damage
            local event = {
                col = monster.col,
                row = monster.row,
                dmg = damage,
                target = monster,
            }
            table.insert(state.lastDamageDealt, event)
            VisualEventQueue.PushDamageDealt(state, event)
        end
        if effect and effect.type == "root" then
            monster.slowed = 1.0
            monster.rootTurns = math.max(monster.rootTurns or 0, effect.turns or 1)
            GameEvents.AddMonsterStatus(state, monster, "定身", "control")
        elseif effect and effect.type == "armorBreak" then
            monster.defenseDown = math.max(monster.defenseDown or 0, (effect.value or 0) * talismanMul)
            monster.defenseDownTurns = math.max(monster.defenseDownTurns or 0, effect.duration or 2)
            GameEvents.AddMonsterStatus(state, monster, "破甲", "debuff")
        elseif effect and effect.type == "attackDown" then
            monster.attackDown = math.max(monster.attackDown or 0, (effect.value or 0) * talismanMul)
            monster.attackDownTurns = math.max(monster.attackDownTurns or 0, effect.duration or 2)
            GameEvents.AddMonsterStatus(state, monster, "削攻", "debuff")
        elseif effect and effect.type == "vulnerable" then
            monster.vulnerable = math.max(monster.vulnerable or 0, (effect.value or 0) * talismanMul)
            monster.vulnerableTurns = math.max(monster.vulnerableTurns or 0, effect.duration or 2)
            GameEvents.AddMonsterStatus(state, monster, "易伤", "debuff")
        elseif item.controlType == "slow" or item.controlType == "stun_slow" or item.controlType == "stun" or item.controlType == "root" then
            monster.slowed = 1.0
            GameEvents.AddMonsterStatus(state, monster, "定身", "control")
        end
    end

    local targets = CollectRandomAliveMonsters(state, targetCount)
    for _, monster in ipairs(targets) do
        applyEffect(monster)
        hitCount = hitCount + 1
    end

    return string.format("使用%s，随机影响%d个目标", item.name, hitCount)
end

function ConsumableService.CanUse(state, category, index)
    local item = GetItem(state, category, index)
    if not IsConsumable(item) or not HasUsableEffect(item) then return false end

    local limit = state.consumableUseLimit or Config.CONSUMABLE_USE_LIMIT or 2
    if limit > 0 and (state.consumableUsesThisTurn or 0) >= limit then
        return false
    end

    return true
end

function ConsumableService.Use(state, category, index)
    local item = GetItem(state, category, index)
    if not IsConsumable(item) then
        return { ok = false, message = "该道具不能主动使用" }
    end
    if not HasUsableEffect(item) then
        return { ok = false, message = "该道具当前没有主动效果" }
    end

    local limit = state.consumableUseLimit or Config.CONSUMABLE_USE_LIMIT or 2
    if limit > 0 and (state.consumableUsesThisTurn or 0) >= limit then
        return { ok = false, message = "本回合可使用次数已达上限" }
    end

    local message
    local heal = 0
    local ok = true
    local itemCategory = ItemSystem.GetCategory(item)
    if itemCategory == "pill" then
        message, heal, ok = UsePill(state, item)
    elseif itemCategory == "talisman" then
        message = UseTalisman(state, item)
        KillResolver.Resolve(state)
    end

    if ok == false then
        return { ok = false, message = message or "该道具当前无法使用" }
    end

    RemoveItem(state, category, index)
    state.consumableUsesThisTurn = (state.consumableUsesThisTurn or 0) + 1
    return { ok = true, message = message or "已使用", heal = heal or 0 }
end

return ConsumableService
