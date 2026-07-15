local TalentSystem = require("TalentSystem")
local Stats = require("combat.Stats")

local TalentActions = {}

function TalentActions.Purchase(state, nodeId)
    local result = TalentSystem.Purchase(state, nodeId)
    if result.ok then
        Stats.RecalculateMaxHp(state, { addDeltaToHp = true })
    end
    return result
end

return TalentActions
