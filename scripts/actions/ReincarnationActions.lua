local ReincarnationSystem = require("ReincarnationSystem")
local Stats = require("combat.Stats")

local ReincarnationActions = {}

function ReincarnationActions.Upgrade(state, upgradeId)
    local result = ReincarnationSystem.Upgrade(state, upgradeId)
    if result.ok and result.definition.id == "maxHp" then
        Stats.RecalculateMaxHp(state, { addDeltaToHp = true })
    end
    return result
end

return ReincarnationActions
