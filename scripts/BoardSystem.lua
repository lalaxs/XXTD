local Config = require("Config")

local BoardSystem = {}

function BoardSystem.FindEmptySlot(state)
    for i = 1, Config.TOTAL_SLOTS do
        if state.slots[i] == nil then
            return i
        end
    end
    return nil
end

function BoardSystem.SwapSlots(state, from, to)
    if from < 1 or from > Config.TOTAL_SLOTS then return false end
    if to < 1 or to > Config.TOTAL_SLOTS then return false end
    if from == to then return false end

    state.slots[from], state.slots[to] = state.slots[to], state.slots[from]
    return true
end

return BoardSystem
