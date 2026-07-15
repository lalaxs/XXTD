local VisualState = {}

function VisualState.Create()
    return {
        monsterSpawnAnimations = {},
    }
end

function VisualState.Ensure(state)
    if not state then return nil end
    state.visual = state.visual or VisualState.Create()
    state.visual.monsterSpawnAnimations = state.visual.monsterSpawnAnimations or {}
    return state.visual
end

function VisualState.MarkMonsterSpawnPending(state, monster)
    local visual = VisualState.Ensure(state)
    local instanceId = monster and monster.instanceId
    if not visual or not instanceId then return end
    visual.monsterSpawnAnimations[instanceId] = false
end

function VisualState.MarkMonsterSpawnPlayed(state, monster)
    local visual = VisualState.Ensure(state)
    local instanceId = monster and monster.instanceId
    if not visual or not instanceId then return end
    visual.monsterSpawnAnimations[instanceId] = true
end

function VisualState.ShouldPlayMonsterSpawn(state, monster)
    local visual = state and state.visual
    local instanceId = monster and monster.instanceId
    return visual ~= nil and instanceId ~= nil and visual.monsterSpawnAnimations and visual.monsterSpawnAnimations[instanceId] == false
end

return VisualState
