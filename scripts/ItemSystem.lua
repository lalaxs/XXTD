local Config = require("Config")
local BuffSystem = require("BuffSystem")
local RealmSystem = require("RealmSystem")
local BoardSystem = require("BoardSystem")

local ItemSystem = {}

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
    local item = {
        itemType = itemType,
        quality = quality,
    }

    if itemType == Config.ITEM_TYPE.ATTACK then
        local data = Config.ATTACK_ITEMS[quality]
        item.name = data.name
        item.atk = data.atk
        item.crit = data.crit
    elseif itemType == Config.ITEM_TYPE.DEFENSE then
        local data = Config.DEFENSE_ITEMS[quality]
        item.name = data.name
        item.shield = data.shield
        item.slow = data.slow
    elseif itemType == Config.ITEM_TYPE.PILL then
        local data = Config.PILL_ITEMS[quality]
        item.name = data.name
        item.buff = data.buff
        item.value = data.value
        item.duration = data.duration
        item.buffActive = true
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
