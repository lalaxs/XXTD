local VisualEventQueue = {}

function VisualEventQueue.Ensure(state)
    if not state then return nil end
    state.visualEventQueue = state.visualEventQueue or {
        statusEvents = {},
        dropMessages = {},
        pillConsumeMessages = {},
        damageDealt = {},
        playerDamage = 0,
        playerDamageCrit = false,
        reincarnationTriggered = false,
        breakthroughEvent = nil,
    }
    state.visualEventQueue.statusEvents = state.visualEventQueue.statusEvents or {}
    state.visualEventQueue.dropMessages = state.visualEventQueue.dropMessages or {}
    state.visualEventQueue.pillConsumeMessages = state.visualEventQueue.pillConsumeMessages or {}
    state.visualEventQueue.damageDealt = state.visualEventQueue.damageDealt or {}
    state.visualEventQueue.playerDamage = state.visualEventQueue.playerDamage or 0
    state.visualEventQueue.playerDamageCrit = state.visualEventQueue.playerDamageCrit == true
    state.visualEventQueue.reincarnationTriggered = state.visualEventQueue.reincarnationTriggered == true
    return state.visualEventQueue
end

function VisualEventQueue.PushStatus(state, event)
    if not event or not event.text then return end
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    table.insert(queue.statusEvents, event)
end

function VisualEventQueue.PushDropMessage(state, message)
    if not message or message == "" then return end
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    table.insert(queue.dropMessages, message)
end

function VisualEventQueue.PushPillConsume(state, info)
    if not info or (info.heal or 0) <= 0 then return end
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    table.insert(queue.pillConsumeMessages, info)
end

function VisualEventQueue.PushDamageDealt(state, event)
    if not event or (event.dmg or 0) <= 0 then return end
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    table.insert(queue.damageDealt, event)
end

function VisualEventQueue.DrainDamageDealtWhere(state, predicate)
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return {} end

    local matched = {}
    local remaining = {}
    for _, event in ipairs(queue.damageDealt or {}) do
        if predicate and predicate(event) then
            table.insert(matched, event)
        else
            table.insert(remaining, event)
        end
    end
    queue.damageDealt = remaining
    return matched
end

function VisualEventQueue.PushPlayerDamage(state, amount, crit)
    if (amount or 0) <= 0 then return end
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    queue.playerDamage = (queue.playerDamage or 0) + amount
    if crit == true then
        queue.playerDamageCrit = true
    end
end

function VisualEventQueue.PushReincarnation(state)
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    queue.reincarnationTriggered = true
end

function VisualEventQueue.PushBreakthrough(state, event)
    if not event then return end
    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    queue.breakthroughEvent = event
end

function VisualEventQueue.ClearTurnEvents(state)
    if not state then return end
    state.lastDamageDealt = {}
    state.lastPlayerDamage = 0
    state.lastPlayerDamageCrit = false
    state.pillConsumeMessages = {}
    state.visualStatusEvents = {}
    state.lastBreakthroughEvent = nil
    state.dropMessages = {}
    state.reincarnationTriggered = false

    local queue = VisualEventQueue.Ensure(state)
    if not queue then return end
    queue.damageDealt = {}
    queue.playerDamage = 0
    queue.playerDamageCrit = false
    queue.pillConsumeMessages = {}
    queue.statusEvents = {}
    queue.dropMessages = {}
    queue.breakthroughEvent = nil
    queue.reincarnationTriggered = false
end

function VisualEventQueue.DrainCompat(state)
    if not state then
        return {
            damageDealt = {},
            playerDamage = 0,
            playerDamageCrit = false,
            pillConsumeMessages = {},
            statusEvents = {},
            breakthroughEvent = nil,
            dropMessages = {},
            reincarnationTriggered = false,
        }
    end

    local queue = VisualEventQueue.Ensure(state)
    local events = {
        damageDealt = queue and queue.damageDealt or state.lastDamageDealt or {},
        playerDamage = queue and queue.playerDamage or state.lastPlayerDamage or 0,
        playerDamageCrit = (queue and queue.playerDamageCrit == true) or state.lastPlayerDamageCrit == true,
        pillConsumeMessages = queue and queue.pillConsumeMessages or state.pillConsumeMessages or {},
        statusEvents = queue and queue.statusEvents or {},
        breakthroughEvent = queue and queue.breakthroughEvent or state.lastBreakthroughEvent,
        dropMessages = queue and queue.dropMessages or state.dropMessages or {},
        reincarnationTriggered = (queue and queue.reincarnationTriggered == true) or state.reincarnationTriggered == true,
    }

    VisualEventQueue.ClearTurnEvents(state)

    return events
end

return VisualEventQueue
