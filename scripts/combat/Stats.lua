-- combat/Stats.lua
-- 玩家派生属性与生命值工具。集中处理最大气血、回血封顶等跨系统规则。

local Config = require("Config")
local TalentSystem = require("TalentSystem")
local RogueRewardSystem = require("rogue.RogueRewardSystem")

local Stats = {}

function Stats.GetMaxHp(state)
    local realm = Config.GetRealm(state.realmIndex or 1)
    local baseHp = realm.maxHp or Config.PLAYER.BASE_HP
    local hpBonus = 1.0 + TalentSystem.GetModifierValue(state, "maxHpPct")
    local rogueHpBonus = 1.0 + RogueRewardSystem.GetModifierValue(state, "maxHpPct")
    return math.max(1, math.floor(baseHp * hpBonus * rogueHpBonus))
end

function Stats.RecalculateMaxHp(state, options)
    options = options or {}
    local oldMaxHp = state.maxHp or Stats.GetMaxHp(state)
    local oldHp = state.hp or oldMaxHp
    local newMaxHp = Stats.GetMaxHp(state)
    state.maxHp = newMaxHp

    if options.fullHeal then
        state.hp = newMaxHp
    elseif options.addDeltaToHp then
        state.hp = math.min(newMaxHp, oldHp + math.max(0, newMaxHp - oldMaxHp))
    elseif options.keepRatio then
        local ratio = oldMaxHp > 0 and oldHp / oldMaxHp or 1
        state.hp = math.min(newMaxHp, math.max(1, math.floor(newMaxHp * ratio + 0.5)))
    else
        state.hp = math.min(newMaxHp, oldHp)
    end

    state.lastPillHp = state.hp
    return newMaxHp, oldMaxHp
end

function Stats.Heal(state, amount, options)
    options = options or {}
    local beforeHp = state.hp or 0
    local heal = math.max(0, amount or 0)
    if options.allowOverheal then
        state.hp = beforeHp + heal
    else
        state.hp = math.min(state.maxHp or beforeHp, beforeHp + heal)
    end
    return math.max(0, (state.hp or 0) - beforeHp)
end

return Stats
