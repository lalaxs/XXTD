local RealmSystem = require("RealmSystem")
local ConsumableService = require("items.ConsumableService")
local VisualEventQueue = require("events.VisualEventQueue")

local ConsumableActions = {}

function ConsumableActions.Use(state, context)
    local result = ConsumableService.Use(state, context.category, context.index)
    if result.ok then
        if (result.heal or 0) > 0 then
            VisualEventQueue.PushPillConsume(state, { heal = result.heal })
        end
        RealmSystem.CheckRealmUp(state)
    end
    return result
end

return ConsumableActions
