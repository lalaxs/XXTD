local RealmSystem = require("RealmSystem")
local WaveSystem = require("WaveSystem")
local Stats = require("combat.Stats")
local RogueRewardSystem = require("rogue.RogueRewardSystem")

local RogueRewardActions = {}

local function HasPendingRogueChoice(state)
    return state and state.pendingRogueChoices and #state.pendingRogueChoices > 0
end

local function HasActiveMonster(state)
    if not state then return false end
    for _, monster in ipairs(state.monsters or {}) do
        if monster.hp and monster.hp > 0 then
            return true
        end
    end
    return false
end

function RogueRewardActions.Select(state, rewardId)
    local result = RogueRewardSystem.SelectChoice(state, rewardId)
    if result.ok then
        Stats.RecalculateMaxHp(state, { addDeltaToHp = true })
        RealmSystem.CheckRealmUp(state)
        if state.shouldSpawnBreakthroughWave then
            state.shouldSpawnBreakthroughWave = false
            WaveSystem.ForceSpawnWave(state)
        elseif not HasPendingRogueChoice(state) and not HasActiveMonster(state) then
            state.forceSpawnNextTurn = false
            WaveSystem.ForceSpawnWave(state)
        end
    end
    return result
end

return RogueRewardActions
