-- GameEvents.lua
-- UI 展示事件的集中消费入口，避免视图层散落修改战斗状态字段。

local GameEvents = {}

function GameEvents.AddStatusEvent(state, event)
    if not state or not event or not event.text then return end
    state.visualStatusEvents = state.visualStatusEvents or {}
    table.insert(state.visualStatusEvents, event)
end

function GameEvents.AddMonsterStatus(state, monster, text, kind)
    if not monster or not text then return end
    GameEvents.AddStatusEvent(state, {
        targetType = "monster",
        target = monster,
        row = monster.row,
        col = monster.col,
        text = text,
        kind = kind or "debuff",
    })
end

function GameEvents.AddPlayerStatus(state, text, kind)
    GameEvents.AddStatusEvent(state, {
        targetType = "player",
        text = text,
        kind = kind or "buff",
    })
end

function GameEvents.ConsumeVisualEvents(state)
    local events = {
        damageDealt = state.lastDamageDealt or {},
        playerDamage = state.lastPlayerDamage or 0,
        playerDamageCrit = state.lastPlayerDamageCrit == true,
        pillConsumeMessages = state.pillConsumeMessages or {},
        statusEvents = state.visualStatusEvents or {},
        breakthroughEvent = state.lastBreakthroughEvent,
        dropMessages = state.dropMessages or {},
        reincarnationTriggered = state.reincarnationTriggered == true,
    }

    state.lastDamageDealt = {}
    state.lastPlayerDamage = 0
    state.lastPlayerDamageCrit = false
    state.pillConsumeMessages = {}
    state.visualStatusEvents = {}
    state.lastBreakthroughEvent = nil
    state.dropMessages = {}
    state.reincarnationTriggered = false

    return events
end

return GameEvents
