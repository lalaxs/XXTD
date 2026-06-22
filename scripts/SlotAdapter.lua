local Config = require("Config")

local SlotAdapter = {}

local PILL_EMOJI = {"丹", "丹", "丹", "丹", "丹", "丹", "丹", "丹", "丹"}
local FULU_EMOJI = {"符", "符", "符", "符", "符", "符", "符", "符", "符"}
local RARITY_MAP = {"common", "uncommon", "rare", "epic", "legendary", "mythic", "mythic", "mythic", "mythic"}

function SlotAdapter.ItemToSlotData(item)
    if not item then return nil end

    local icon = "剑"
    if item.itemType == Config.ITEM_TYPE.DEFENSE then
        icon = FULU_EMOJI[item.quality] or "符"
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        icon = PILL_EMOJI[item.quality] or "丹"
    end

    return {
        name = item.name,
        icon = icon,
        type = "any",
        rarity = RARITY_MAP[item.quality] or "common",
        _raw = item,
    }
end

return SlotAdapter
