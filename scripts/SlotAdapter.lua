local Config = require("Config")

local SlotAdapter = {}

local RARITY_MAP = {"common", "uncommon", "rare", "epic", "legendary", "mythic", "mythic", "mythic", "mythic"}

-- 法宝图片映射（与 UIController 中一致）
local ITEM_IMAGES = {
    [Config.ITEM_TYPE.ATTACK] = {
        "image/weapon/weapon  (1).png",
        "image/weapon/weapon  (2).png",
        "image/weapon/weapon  (13).png",
        "image/weapon/weapon  (14).png",
        "image/weapon/weapon  (1).png",
        "image/weapon/weapon  (2).png",
        "image/weapon/weapon  (13).png",
        "image/weapon/weapon  (14).png",
        "image/weapon/weapon  (1).png",
    },
    [Config.ITEM_TYPE.DEFENSE] = {
        "image/weapon/weapon  (5).png",
        "image/weapon/weapon  (6).png",
        "image/weapon/weapon  (7).png",
        "image/weapon/weapon  (8).png",
        "image/weapon/weapon  (5).png",
        "image/weapon/weapon  (6).png",
        "image/weapon/weapon  (7).png",
        "image/weapon/weapon  (8).png",
        "image/weapon/weapon  (5).png",
    },
    [Config.ITEM_TYPE.PILL] = {
        "image/weapon/weapon  (9).png",
        "image/weapon/weapon  (10).png",
        "image/weapon/weapon  (11).png",
        "image/weapon/weapon  (12).png",
        "image/weapon/weapon  (9).png",
        "image/weapon/weapon  (10).png",
        "image/weapon/weapon  (11).png",
        "image/weapon/weapon  (12).png",
        "image/weapon/weapon  (9).png",
    },
    [Config.ITEM_TYPE.TALISMAN] = {
        "image/weapon/weapon  (3).png",
        "image/weapon/weapon  (4).png",
        "image/weapon/weapon  (15).png",
        "image/weapon/weapon  (3).png",
        "image/weapon/weapon  (4).png",
        "image/weapon/weapon  (15).png",
        "image/weapon/weapon  (3).png",
        "image/weapon/weapon  (4).png",
        "image/weapon/weapon  (15).png",
    },
}

function SlotAdapter.GetItemImage(item)
    if not item then return nil end
    local images = ITEM_IMAGES[item.itemType]
    if not images then return nil end
    return images[item.quality] or images[1]
end

function SlotAdapter.ItemToSlotData(item)
    if not item then return nil end

    local img = SlotAdapter.GetItemImage(item)

    return {
        name = item.name,
        icon = "",
        image = img,
        type = "any",
        rarity = RARITY_MAP[item.quality] or "common",
        _raw = item,
    }
end

return SlotAdapter
