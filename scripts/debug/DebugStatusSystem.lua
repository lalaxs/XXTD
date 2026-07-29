local Config = require("Config")

local DebugStatusSystem = {}

local DEFINITIONS = {
    { id = "shield", name = "护盾", desc = "获得208点护盾", kind = "buff" },
    { id = "atkUp", name = "法宝增伤", desc = "法宝伤害提高25%", kind = "buff" },
    { id = "allUp", name = "攻防强化", desc = "伤害提高20%，承伤降低20%", kind = "buff" },
    { id = "debuffImmunity", name = "负面免疫", desc = "免疫怪物施加的负面状态", kind = "buff" },
    { id = "deathSave", name = "免死护佑", desc = "气血归零时恢复50%最大气血", kind = "buff" },
    { id = "attackDown", name = "减攻", desc = "法宝伤害降低25%", kind = "debuff" },
    { id = "vulnerable", name = "易伤", desc = "受到的怪物伤害提高20%", kind = "debuff" },
    { id = "seal", name = "法宝封印", desc = "封印前两个法宝位", kind = "debuff" },
    { id = "poison", name = "腐毒", desc = "获得3层腐毒", kind = "debuff" },
    { id = "silence", name = "灾厄压制", desc = "所有攻击法宝无法行动", kind = "debuff" },
}

local function GetDuration()
    local debugConfig = Config.DEBUG or {}
    return math.max(1, math.floor(debugConfig.PLAYER_STATUS_DURATION or 99))
end

local function UpsertBuff(state, buffType, value, duration)
    state.buffs = state.buffs or {}
    for _, buff in ipairs(state.buffs) do
        if buff.type == buffType and buff.debugStatus == true then
            buff.value = value
            buff.remainTurns = duration
            return
        end
    end
    table.insert(state.buffs, {
        type = buffType,
        value = value,
        remainTurns = duration,
        debugStatus = true,
    })
end

function DebugStatusSystem.GetDefinitions()
    return DEFINITIONS
end

function DebugStatusSystem.Apply(state, statusId)
    if not state then return false end

    local duration = GetDuration()
    state.debugStatuses = state.debugStatuses or {}
    if statusId == "shield" then
        UpsertBuff(state, "shield", 208, duration)
    elseif statusId == "atkUp" then
        UpsertBuff(state, "atkUp", 0.25, duration)
    elseif statusId == "allUp" then
        UpsertBuff(state, "allUp", 0.20, duration)
    elseif statusId == "debuffImmunity" then
        state.debuffImmunityTurns = duration
    elseif statusId == "deathSave" then
        state.deathSaveRatio = 0.50
        state.deathSaveUsed = false
    elseif statusId == "attackDown" or statusId == "vulnerable" then
        state.playerDebuffs = state.playerDebuffs or {}
        state.playerDebuffs[statusId] = {
            value = statusId == "attackDown" and 0.25 or 0.20,
            turns = duration,
            debugStatus = true,
        }
    elseif statusId == "seal" then
        state.sealedSlots = state.sealedSlots or {}
        state.sealedSlots[1] = duration
        state.sealedSlots[2] = duration
    elseif statusId == "poison" then
        state.poisonStacks = 3
        state.poisonDamageRatio = 0.04
        state.debuffs = state.debuffs or {}
        state.debuffs.poisonStacks = state.poisonStacks
    elseif statusId == "silence" then
        state.itemSilenceTurns = duration
    else
        return false
    end

    state.debugStatuses[statusId] = true
    state.__useRealStatuses = true
    print(string.format("[Debug Status] 已施加状态: %s", statusId))
    return true
end

function DebugStatusSystem.ClearAll(state)
    if not state then return end

    local debugStatuses = state.debugStatuses or {}
    local remainingBuffs = {}
    for _, buff in ipairs(state.buffs or {}) do
        if buff.debugStatus ~= true then
            table.insert(remainingBuffs, buff)
        end
    end
    state.buffs = remainingBuffs

    if debugStatuses.debuffImmunity then
        state.debuffImmunityTurns = 0
    end
    if debugStatuses.deathSave then
        state.deathSaveRatio = 0
        state.deathSaveUsed = false
    end
    if state.playerDebuffs then
        if debugStatuses.attackDown and state.playerDebuffs.attackDown and state.playerDebuffs.attackDown.debugStatus == true then
            state.playerDebuffs.attackDown = nil
        end
        if debugStatuses.vulnerable and state.playerDebuffs.vulnerable and state.playerDebuffs.vulnerable.debugStatus == true then
            state.playerDebuffs.vulnerable = nil
        end
    end
    if debugStatuses.seal then
        state.sealedSlots = state.sealedSlots or {}
        state.sealedSlots[1] = nil
        state.sealedSlots[2] = nil
    end
    if debugStatuses.poison then
        state.poisonStacks = 0
        state.poisonDamageRatio = 0
        if state.debuffs then
            state.debuffs.poisonStacks = nil
        end
    end
    if debugStatuses.silence then
        state.itemSilenceTurns = 0
    end

    state.debugStatuses = {}
    state.__useRealStatuses = true
    print("[Debug Status] 已清空调试面板施加的玩家状态")
end

return DebugStatusSystem
