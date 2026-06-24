local Config = require("Config")
local ItemSystem = require("ItemSystem")
local BuffSystem = require("BuffSystem")

local DragActions = {}

function DragActions.ParseSlotIndex(slotId)
    local num = string.match(tostring(slotId), "%d+")
    return num and tonumber(num) or nil
end

function DragActions.GetItemFromSlot(state, category, idx)
    if category == "deploy" then
        return state.slots[idx]
    elseif category == "storage" then
        return state.dropQueue[1]
    end
    return nil
end

function DragActions.SetItemToSlot(state, category, idx, item)
    if category == "deploy" then
        state.slots[idx] = item
    elseif category == "storage" then
        if item == nil then
            table.remove(state.dropQueue, 1)
        else
            state.dropQueue[1] = item
        end
    end
end

function DragActions.CanDrop(state, sourceSlot, targetSlot)
    if not sourceSlot or not targetSlot then return false end

    local srcCat = sourceSlot:GetSlotCategory()
    local dstCat = targetSlot:GetSlotCategory()

    if dstCat == "decompose" then
        return srcCat == "deploy" or srcCat == "storage"
    end

    if srcCat == "decompose" then
        return false
    end

    if srcCat == "deploy" and dstCat == "storage" then
        return false
    end

    if srcCat == "storage" and dstCat == "deploy" then
        local toIdx = DragActions.ParseSlotIndex(targetSlot:GetSlotId())
        if not toIdx then return false end
        local srcItem = state.dropQueue[1]
        local dstItem = state.slots[toIdx]
        if not srcItem then return false end
        if not dstItem then return true end
        return srcItem.itemType == dstItem.itemType
            and srcItem.quality == dstItem.quality
            and srcItem.quality < Config.MAX_QUALITY
    end

    return true
end

function DragActions.ApplyDrop(state, sourceSlot, targetSlot)
    local fromCat = sourceSlot:GetSlotCategory()
    local fromId = sourceSlot:GetSlotId()
    local toCat = targetSlot:GetSlotCategory()
    local toId = targetSlot:GetSlotId()

    if fromCat == toCat and fromId == toId then
        return { changed = false }
    end

    local fromIdx = DragActions.ParseSlotIndex(fromId)
    local toIdx = DragActions.ParseSlotIndex(toId)
    if not fromIdx or not toIdx then return { changed = false } end

    local srcItem = DragActions.GetItemFromSlot(state, fromCat, fromIdx)
    local dstItem = DragActions.GetItemFromSlot(state, toCat, toIdx)
    if not srcItem then return { changed = false } end

    if toCat == "decompose" then
        if fromCat == "deploy" then
            local ok = ItemSystem.DecomposeItem(state, fromIdx)
            return { changed = ok, decomposed = ok }
        elseif fromCat == "storage" then
            local expGain = Config.DECOMPOSE_EXP[srcItem.quality] or 2
            local RealmSystem = require("RealmSystem")
            RealmSystem.AddExp(state, expGain)
            DragActions.SetItemToSlot(state, fromCat, fromIdx, nil)
            print(string.format("[Decompose] 分解 %s → +%d修为", srcItem.name, expGain))
            return { changed = true, decomposed = true }
        end
        return { changed = false }
    end

    if fromCat == "decompose" then
        return { changed = false }
    end

    if fromCat == "deploy" and toCat == "storage" then
        return { changed = false }
    end

    if fromCat == "storage" and toCat == "deploy" and dstItem then
        local canMerge = srcItem.itemType == dstItem.itemType
            and srcItem.quality == dstItem.quality
            and srcItem.quality < Config.MAX_QUALITY
        if not canMerge then
            return { changed = false }
        end
    end

    if dstItem and srcItem.itemType == dstItem.itemType
       and srcItem.quality == dstItem.quality
       and srcItem.quality < Config.MAX_QUALITY then
        local newItem = ItemSystem.CreateItem(srcItem.itemType, srcItem.quality + 1)
        if newItem.itemType == Config.ITEM_TYPE.ATTACK then
            newItem.atk = srcItem.atk + dstItem.atk
        end
        DragActions.SetItemToSlot(state, toCat, toIdx, newItem)
        DragActions.SetItemToSlot(state, fromCat, fromIdx, nil)
        return {
            changed = true,
            merged = true,
            mergeCategory = toCat,
            mergeIndex = toIdx,
            mergeQuality = newItem.quality,
        }
    end

    if not dstItem then
        DragActions.SetItemToSlot(state, toCat, toIdx, srcItem)
        DragActions.SetItemToSlot(state, fromCat, fromIdx, nil)
        return { changed = true, moved = true }
    end

    DragActions.SetItemToSlot(state, fromCat, fromIdx, dstItem)
    DragActions.SetItemToSlot(state, toCat, toIdx, srcItem)
    return { changed = true, swapped = true }
end

return DragActions
