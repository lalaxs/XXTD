local Config = require("Config")
local BuffSystem = require("BuffSystem")
local RealmSystem = require("RealmSystem")
local BoardSystem = require("BoardSystem")

local ItemSystem = {}

local function ClampQuality(quality)
    return math.min(Config.MAX_QUALITY, math.max(1, quality or 1))
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
    local roll = math.random()
    local itemType
    if roll < 0.40 then
        itemType = Config.ITEM_TYPE.ATTACK
    elseif roll < 0.70 then
        itemType = Config.ITEM_TYPE.DEFENSE
    else
        itemType = Config.ITEM_TYPE.PILL
    end

    local realm = Config.REALMS[state.realmIndex]
    local qualityRoll = math.random()
    local quality = 1
    if qualityRoll > 0.95 - realm.dropBonus then quality = 3
    elseif qualityRoll > 0.80 - realm.dropBonus then quality = 2
    end
    quality = math.min(quality, Config.MAX_QUALITY)
    return ItemSystem.CreateItem(itemType, quality)
end

function ItemSystem.CreateItem(itemType, quality)
    quality = ClampQuality(quality)
    local item = {
        itemType = itemType,
        quality = quality,
    }

    if itemType == Config.ITEM_TYPE.ATTACK then
        local data = assert(Config.ATTACK_ITEMS[quality], "Missing attack item config")
        item.name = data.name
        item.atk = data.atk
        item.crit = data.crit or 0
        item.atkSpeed = data.atkSpeed or 1.0
        item.defIgnore = data.defIgnore or 0
    elseif itemType == Config.ITEM_TYPE.DEFENSE then
        local data = assert(Config.DEFENSE_ITEMS[quality], "Missing defense item config")
        item.name = data.name
        item.shield = data.shield
        item.damageReduction = data.damageReduction or 0
        item.shareReduction = data.shareReduction or 0
        item.globalReduction = data.globalReduction or 0
        item.slowRate = data.slowRate or 0
        item.maxDurability = 5
        item.durability = 5
    elseif itemType == Config.ITEM_TYPE.PILL then
        local data = assert(Config.PILL_ITEMS[quality], "Missing pill item config")
        item.name = data.name
        item.healPerSec = data.healPerSec or 0
        item.duration = data.duration or 5
        item.teamAtkBonus = data.teamAtkBonus or 0
        item.teamAtkSpeedBonus = data.teamAtkSpeedBonus or 0
        item.globalHealAura = data.globalHealAura or false
        item.buff = "heal"
        item.value = data.healPerSec or 0
        item.buffActive = true
    elseif itemType == Config.ITEM_TYPE.TALISMAN then
        local data = assert(Config.TALISMAN_ITEMS[quality], "Missing talisman item config")
        item.name = data.name
        item.aoeDmg = data.aoeDmg or 0
        item.aoeRange = data.aoeRange or 3
        item.controlType = data.controlType or "none"
        item.controlDuration = data.controlDuration or 0
        item.atk = data.aoeDmg
        item.crit = 0
    else
        error("Unknown item type: " .. tostring(itemType))
    end

    return item
end

function ItemSystem.TryMerge(state, fromSlot, toSlot)
    local itemA = state.slots[fromSlot]
    local itemB = state.slots[toSlot]

    if not itemA or not itemB then return false end
    if itemA.itemType ~= itemB.itemType then return false end
    if itemA.quality ~= itemB.quality then return false end
    if itemA.quality >= Config.MAX_QUALITY then return false end

    local newQuality = itemA.quality + 1
    local newItem = ItemSystem.CreateItem(itemA.itemType, newQuality)
    if newItem.itemType == Config.ITEM_TYPE.DEFENSE then
        local durA = itemA.durability or itemA.maxDurability or 5
        local durB = itemB.durability or itemB.maxDurability or 5
        newItem.durability = math.max(durA, durB)
        newItem.maxDurability = math.max(newItem.maxDurability or 5, newItem.durability)
    end

    state.slots[toSlot] = newItem
    state.slots[fromSlot] = nil

    if newItem.itemType == Config.ITEM_TYPE.PILL then
        BuffSystem.AddBuff(state, newItem.buff, newItem.value, newItem.duration)
    end

    print(string.format("[Merge] %s + %s → %s (%s)",
        itemA.name, itemB.name, newItem.name, Config.QUALITY[newQuality].name))
    return true
end

function ItemSystem.DecomposeItem(state, slotIdx)
    local item = state.slots[slotIdx]
    if not item then return false end

    local expGain = Config.DECOMPOSE_EXP[item.quality] or 2
    RealmSystem.AddExp(state, expGain)
    state.slots[slotIdx] = nil

    print(string.format("[Decompose] 分解 %s → +%d修为", item.name, expGain))
    return true
end

return ItemSystem
