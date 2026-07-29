local Config = require("Config")
local RealmSystem = require("RealmSystem")
local BoardSystem = require("BoardSystem")
local ItemPoolService = require("items.ItemPoolService")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local DailyChallenge = require("DailyChallenge")

local ItemSystem = {}

local CATEGORY_BY_ITEM_TYPE = {
    [Config.ITEM_TYPE.ATTACK] = Config.ITEM_CATEGORY.WEAPON,
    [Config.ITEM_TYPE.DEFENSE] = Config.ITEM_CATEGORY.ARMOR,
    [Config.ITEM_TYPE.PILL] = Config.ITEM_CATEGORY.PILL,
    [Config.ITEM_TYPE.TALISMAN] = Config.ITEM_CATEGORY.TALISMAN,
}

local ITEM_TYPE_BY_CATEGORY = {
    [Config.ITEM_CATEGORY.WEAPON] = Config.ITEM_TYPE.ATTACK,
    [Config.ITEM_CATEGORY.ARMOR] = Config.ITEM_TYPE.DEFENSE,
    [Config.ITEM_CATEGORY.PILL] = Config.ITEM_TYPE.PILL,
    [Config.ITEM_CATEGORY.TALISMAN] = Config.ITEM_TYPE.TALISMAN,
}

local function ClampQuality(quality)
    return math.min(Config.MAX_QUALITY, math.max(1, quality or 1))
end

local EXTRA_DEF_FIELDS = {
    "baseId",
    "power",
    "school",
    "family",
    "attackMode",
    "coefficient",
    "tendency",
    "signature",
    "splashRatio",
    "areaPattern",
    "specialEffect",
    "armorEffect",
    "pillEffect",
    "talismanEffect",
    "targetCount",
    "defense",
    "critMultiplier",
    "weaponDamagePct",
    "highHpThreshold",
    "highHpBonusPct",
    "lowHpThreshold",
    "lowHpBonusPct",
    "maxHpDamagePct",
    "splashCount",
    "chainCritStep",
    "lowPlayerDamagePct",
    "lowPlayerLayerPct",
    "attackDownPct",
    "blindChance",
    "defenseDownBonus",
    "defenseDownDamagePct",
    "rootChance",
    "rootCooldown",
    "globalDamagePct",
    "doubleCastChance",
    "healChance",
    "healDamagePct",
    "doubleDamageChance",
    "baseDefenseDamagePct",
    "knockbackChance",
    "collisionDamagePct",
    "burnDamagePct",
    "extraBurnChance",
    "segmentDamagePct",
    "tripleChance",
}

local function CopyDefinitionFields(item, data)
    for _, field in ipairs(EXTRA_DEF_FIELDS) do
        if data[field] ~= nil then
            item[field] = data[field]
        end
    end
end

local function AssignCombatInstanceId(state, item)
    if item and item.itemType == Config.ITEM_TYPE.ATTACK then
        state.nextWeaponCombatInstanceId = (state.nextWeaponCombatInstanceId or 0) + 1
        item.combatInstanceId = state.nextWeaponCombatInstanceId
        state.weaponCombatState = state.weaponCombatState or {}
        state.weaponCombatState[item.combatInstanceId] = {}
    end
    return item
end

local function BuildItemFromDefinition(state, def)
    local data = def.data
    local item = {
        id = def.id,
        baseId = def.baseId or data.baseId,
        itemType = def.itemType,
        category = def.category,
        quality = def.quality,
    }

    if item.itemType == Config.ITEM_TYPE.ATTACK then
        item.name = data.name
        item.atk = data.atk
        item.crit = data.crit or 0
        item.defIgnore = data.defIgnore or 0
    elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
        item.name = data.name
        item.defense = data.defense or data.power or 0
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        item.name = data.name
        item.healPerSec = data.healPerSec or 0
        item.duration = data.duration or 5
        item.teamAtkBonus = data.teamAtkBonus or 0
        item.globalHealAura = data.globalHealAura or false
        item.buff = "heal"
        item.value = data.healPerSec or 0
        item.buffActive = true
    elseif item.itemType == Config.ITEM_TYPE.TALISMAN then
        item.name = data.name
        item.aoeDmg = data.aoeDmg or 0
        item.aoeRange = data.aoeRange or 3
        item.controlType = data.controlType or "none"
        item.controlDuration = data.controlDuration or 0
        item.atk = data.aoeDmg
        item.crit = 0
    else
        error("Unknown item type: " .. tostring(item.itemType))
    end

    CopyDefinitionFields(item, data)
    return AssignCombatInstanceId(state, item)
end

local function ReleaseCombatInstance(state, item)
    if not item or not item.combatInstanceId or not state.weaponCombatState then return end
    state.weaponCombatState[item.combatInstanceId] = nil
end

function ItemSystem.GetCategory(item)
    if not item then return nil end
    return item.category or CATEGORY_BY_ITEM_TYPE[item.itemType]
end

function ItemSystem.GetItemTypeByCategory(category)
    return ITEM_TYPE_BY_CATEGORY[category]
end

function ItemSystem.CanMerge(itemA, itemB)
    if not itemA or not itemB then return false end
    local categoryA = ItemSystem.GetCategory(itemA)
    local categoryB = ItemSystem.GetCategory(itemB)
    return categoryA ~= nil
        and categoryA == categoryB
        and itemA.quality == itemB.quality
        and itemA.quality < Config.MAX_QUALITY
end

function ItemSystem.MergeItems(state, itemA, itemB)
    if not ItemSystem.CanMerge(itemA, itemB) then return nil end

    local category = ItemSystem.GetCategory(itemA)
    local newQuality = itemA.quality + 1
    local newItem = ItemSystem.CreateItemByCategory(state, category, newQuality)

    if newItem.itemType == Config.ITEM_TYPE.DEFENSE then
        newItem.defense = newItem.defense or newItem.power or 0
    end

    return newItem
end

function ItemSystem.IsWeaponCategory(item)
    local category = ItemSystem.GetCategory(item)
    return category == "weapon" or category == "talisman"
end

function ItemSystem.SpawnRandomItem(state)
    if state.onItemDrop then
        state.onItemDrop(state)
        return true
    end

    local emptySlot = BoardSystem.FindEmptySlot(state)
    if not emptySlot then
        print("  [Full] 已满，道具作废!")
        return false
    end

    local item = ItemSystem.GenerateRandomItem(state)
    state.slots[emptySlot] = item
    print(string.format("  [Item] 获得 %s (%s)", item.name, Config.QUALITY[item.quality].name))
    return true
end

function ItemSystem.GenerateRandomItem(state)

    local categoryWeights = Config.DROP_RULES.CATEGORY_WEIGHTS or {}
    local totalCategoryWeight = 0
    for _, entry in ipairs(categoryWeights) do
        local bonus = RogueRewardSystem.GetModifierValue(state, "itemCategoryWeightPct:" .. tostring(entry.category))
        local multiplier = math.max(0, 1 + bonus)
            * DailyChallenge.GetEffect(state, "itemCategoryWeightMul_" .. tostring(entry.category), 1.0)
        totalCategoryWeight = totalCategoryWeight + math.max(0, (entry.weight or 0) * multiplier)
    end

    local category = Config.ITEM_CATEGORY.WEAPON
    if totalCategoryWeight > 0 then
        local categoryRoll = DailyChallenge.RandomFloat(state) * totalCategoryWeight
        local categoryAcc = 0
        for _, entry in ipairs(categoryWeights) do
            local bonus = RogueRewardSystem.GetModifierValue(state, "itemCategoryWeightPct:" .. tostring(entry.category))
            local multiplier = math.max(0, 1 + bonus)
                * DailyChallenge.GetEffect(state, "itemCategoryWeightMul_" .. tostring(entry.category), 1.0)
            categoryAcc = categoryAcc + math.max(0, (entry.weight or 0) * multiplier)
            if categoryRoll <= categoryAcc then
                category = entry.category
                break
            end
        end
    end

    local minQuality, maxQuality = Config.GetDropQualityRange(state.realmIndex or 1)
    local qualityWeights = Config.DROP_RULES.QUALITY_WEIGHTS or {}
    local totalQualityWeight = 0
    for _, entry in ipairs(qualityWeights) do
        local quality = entry.quality or 1
        if quality >= minQuality and quality <= maxQuality then
            totalQualityWeight = totalQualityWeight + math.max(0, entry.weight or 0)
        end
    end

    local quality = minQuality
    if totalQualityWeight > 0 then
        local qualityRoll = DailyChallenge.RandomFloat(state) * totalQualityWeight
        local qualityAcc = 0
        for _, entry in ipairs(qualityWeights) do
            local entryQuality = entry.quality or 1
            if entryQuality >= minQuality and entryQuality <= maxQuality then
                qualityAcc = qualityAcc + math.max(0, entry.weight or 0)
                if qualityRoll <= qualityAcc then
                    quality = entryQuality
                    break
                end
            end
        end
    end

    return ItemSystem.CreateItemByCategory(state, category, quality)
end

function ItemSystem.CreateItem(state, itemType, quality)
    quality = ClampQuality(quality)
    local category = ItemPoolService.GetCategoryByItemType(itemType)
    local def = ItemPoolService.RollDefinition(category, quality, state)
    assert(def, "Missing item pool config")
    return BuildItemFromDefinition(state, def)
end

function ItemSystem.CreateItemByCategory(state, category, quality)
    local itemType = ItemPoolService.GetItemTypeByCategory(category)
    assert(itemType, "Unknown item category: " .. tostring(category))
    return ItemSystem.CreateItem(state, itemType, quality)
end

function ItemSystem.CreateItemByBaseId(state, category, baseId, quality)
    quality = ClampQuality(quality)
    local def = ItemPoolService.GetDefinitionByBaseId(category, quality, baseId, state, { ignoreWeaponUnlock = true })
    assert(def, "Missing item definition: " .. tostring(category) .. ":" .. tostring(baseId))
    return BuildItemFromDefinition(state, def)
end

function ItemSystem.TryMerge(state, fromSlot, toSlot)
    local itemA = state.slots[fromSlot]
    local itemB = state.slots[toSlot]

    if not ItemSystem.CanMerge(itemA, itemB) then return false end

    local newQuality = itemA.quality + 1
    local newItem = ItemSystem.MergeItems(state, itemA, itemB)
    if not newItem then return false end

    state.slots[toSlot] = newItem
    state.slots[fromSlot] = nil
    ReleaseCombatInstance(state, itemA)
    ReleaseCombatInstance(state, itemB)


    print(string.format("[Merge] %s + %s → %s (%s)",
        itemA.name, itemB.name, newItem.name, Config.QUALITY[newQuality].name))
    return true
end

function ItemSystem.DecomposeItem(state, slotIdx)
    local item = state.slots[slotIdx]
    if not item then return false end

    local expGain = Config.DECOMPOSE_EXP[item.quality] or 2
    RealmSystem.AddExp(state, expGain, { deferCheck = true })
    state.slots[slotIdx] = nil
    ReleaseCombatInstance(state, item)

    print(string.format("[Decompose] 分解 %s → +%d修为", item.name, expGain))
    return true
end

return ItemSystem
