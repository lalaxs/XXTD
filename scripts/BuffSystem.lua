local Config = require("Config")

local BuffSystem = {}

local function FormatBuffLog(buffType, value)
    if buffType == "shield" or buffType == "heal" then
        return tostring(math.floor((value or 0) + 0.5))
    end
    return string.format("%.0f%%", (value or 0) * 100)
end

function BuffSystem.TickBuffs(state)
    local remaining = {}
    for _, buff in ipairs(state.buffs or {}) do
        buff.remainTurns = buff.remainTurns - 1
        if buff.remainTurns > 0 then
            table.insert(remaining, buff)
        else
            print(string.format("  [Buff] %s 效果消失", buff.type))
        end
    end
    state.buffs = remaining
end

function BuffSystem.GetBuffValue(state, buffType)
    local total = 0
    for _, buff in ipairs(state.buffs or {}) do
        if buff.type == buffType then
            total = total + buff.value
        end
    end
    return total
end

function BuffSystem.AddBuff(state, buffType, value, duration)
    local realm = Config.GetRealm(state.realmIndex)
    local finalValue = value
    if buffType == "heal" or buffType == "atkUp" or buffType == "allUp" then
        finalValue = value * realm.pillMul
    end
    state.buffs = state.buffs or {}
    table.insert(state.buffs, {
        type = buffType,
        value = finalValue,
        remainTurns = duration,
    })
    print(string.format("  [Buff] 获得 %s (%s, %d回合)", buffType, FormatBuffLog(buffType, finalValue), duration))
end

return BuffSystem
