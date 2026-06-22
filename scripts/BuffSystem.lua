local Config = require("Config")

local BuffSystem = {}

function BuffSystem.TickBuffs(state)
    local remaining = {}
    for _, buff in ipairs(state.buffs) do
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
    for _, buff in ipairs(state.buffs) do
        if buff.type == buffType then
            total = total + buff.value
        end
    end
    return total
end

function BuffSystem.AddBuff(state, buffType, value, duration)
    local realm = Config.REALMS[state.realmIndex]
    local finalValue = value * realm.pillMul
    table.insert(state.buffs, {
        type = buffType,
        value = finalValue,
        remainTurns = duration,
    })
    print(string.format("  [Buff] 获得 %s (%.0f%%, %d回合)", buffType, finalValue * 100, duration))
end

return BuffSystem
