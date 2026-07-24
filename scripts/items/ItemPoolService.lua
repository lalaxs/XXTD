-- items/ItemPoolService.lua
-- 标准道具池服务：护甲、丹药、符咒全量开放；武器仅从本轮已解锁池抽取。

local Config = require("Config")
local WeaponDefs = require("config.WeaponDefs")
local ArmorDefs = require("config.ArmorDefs")
local PillDefs = require("config.PillDefs")
local TalismanDefs = require("config.TalismanDefs")

local ItemPoolService = {}

local CATEGORY_TO_ITEM_TYPE = {
    [Config.ITEM_CATEGORY.WEAPON] = Config.ITEM_TYPE.ATTACK,
    [Config.ITEM_CATEGORY.ARMOR] = Config.ITEM_TYPE.DEFENSE,
    [Config.ITEM_CATEGORY.PILL] = Config.ITEM_TYPE.PILL,
    [Config.ITEM_CATEGORY.TALISMAN] = Config.ITEM_TYPE.TALISMAN,
}

local ITEM_TYPE_TO_CATEGORY = {
    [Config.ITEM_TYPE.ATTACK] = Config.ITEM_CATEGORY.WEAPON,
    [Config.ITEM_TYPE.DEFENSE] = Config.ITEM_CATEGORY.ARMOR,
    [Config.ITEM_TYPE.PILL] = Config.ITEM_CATEGORY.PILL,
    [Config.ITEM_TYPE.TALISMAN] = Config.ITEM_CATEGORY.TALISMAN,
}

local CATEGORY_TO_DEFS = {
    [Config.ITEM_CATEGORY.WEAPON] = WeaponDefs,
    [Config.ITEM_CATEGORY.ARMOR] = ArmorDefs,
    [Config.ITEM_CATEGORY.PILL] = PillDefs,
    [Config.ITEM_CATEGORY.TALISMAN] = TalismanDefs,
}

local function ClampQuality(quality)
    return math.min(Config.MAX_QUALITY, math.max(1, quality or 1))
end

local function BuildDefinition(category, quality, data)
    local defCategory = data.category or category
    return {
        id = data.id or string.format("%s_%d", defCategory, quality),
        baseId = data.baseId,
        category = defCategory,
        itemType = data.itemType or CATEGORY_TO_ITEM_TYPE[defCategory],
        quality = data.quality or quality,
        data = data,
        weight = data.weight or data.spawnChance or 1,
    }
end

function ItemPoolService.GetCategoryByItemType(itemType)
    return ITEM_TYPE_TO_CATEGORY[itemType]
end

function ItemPoolService.GetItemTypeByCategory(category)
    return CATEGORY_TO_ITEM_TYPE[category]
end

local function GetDefsPool(category, quality)
    local defs = CATEGORY_TO_DEFS[category]
    if not defs then return {} end
    local pool = {}
    for _, data in ipairs(defs) do
        if (data.category or category) == category and data.quality == quality then
            table.insert(pool, BuildDefinition(category, quality, data))
        end
    end
    return pool
end

function ItemPoolService.GetPool(category, quality, state, options)
    local pool = GetDefsPool(category, ClampQuality(quality))
    if (category ~= Config.ITEM_CATEGORY.WEAPON and category ~= Config.ITEM_CATEGORY.ARMOR)
        or (options and (options.ignoreUnlock or options.ignoreWeaponUnlock)) then
        return pool
    end

    local unlocked
    if category == Config.ITEM_CATEGORY.WEAPON then
        unlocked = state and state.runWeapons or { qingfeng_sword = true }
    else
        unlocked = state and state.runArmors or { dark_iron_shield = true }
    end

    local filtered = {}
    for _, def in ipairs(pool) do
        if unlocked[def.baseId] then
            table.insert(filtered, def)
        end
    end
    return filtered
end

function ItemPoolService.GetDefinitionByBaseId(category, quality, baseId, state, options)
    for _, def in ipairs(ItemPoolService.GetPool(category, quality, state, options)) do
        if def.baseId == baseId then return def end
    end
    return nil
end

function ItemPoolService.RollDefinition(category, quality, state)
    local pool = ItemPoolService.GetPool(category, quality, state)
    if #pool == 0 then return nil end
    local totalWeight = 0
    for _, def in ipairs(pool) do totalWeight = totalWeight + math.max(0, def.weight or 1) end
    if totalWeight <= 0 then return pool[1] end
    local roll, acc = math.random() * totalWeight, 0
    for _, def in ipairs(pool) do
        acc = acc + math.max(0, def.weight or 1)
        if roll <= acc then return def end
    end
    return pool[#pool]
end

return ItemPoolService
