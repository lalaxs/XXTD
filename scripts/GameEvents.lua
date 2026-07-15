-- GameEvents.lua
-- UI 展示事件的集中消费入口，避免视图层散落修改战斗状态字段。

local VisualEventQueue = require("events.VisualEventQueue")

local GameEvents = {}

function GameEvents.AddStatusEvent(state, event)
    if not state or not event or not event.text then return end
    VisualEventQueue.PushStatus(state, event)
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
    return VisualEventQueue.DrainCompat(state)
end

return GameEvents
