local Config = require("Config")
local ItemSystem = require("ItemSystem")

local TutorialSystem = {}

TutorialSystem.VERSION = 1
TutorialSystem.STEP = {
    ALIGN_WEAPON = "align_weapon",
    WAIT_FIRST_KILL = "wait_first_kill",
    ATTACK_REWARD = "attack_reward",
    DEPLOY_REWARD = "deploy_reward",
    MERGE_WEAPONS = "merge_weapons",
    OPEN_SHOP = "open_shop",
    COMPLETED = "completed",
}

local function SlotColumn(slotIdx)
    return ((slotIdx - 1) % Config.GRID_COLS) + 1
end

local function FindLiveMonsterByInstance(state, instanceId)
    for _, monster in ipairs(state and state.monsters or {}) do
        if monster.instanceId == instanceId and (monster.hp or 0) > 0 then
            return monster
        end
    end
    return nil
end

local function FindRewardById(state, rewardId)
    for _, reward in ipairs(state and state.fieldRewards or {}) do
        if reward.id == rewardId and (reward.hp or 0) > 0 then
            return reward
        end
    end
    return nil
end

local function FindWeaponSlot(state, combatInstanceId)
    if not state or not combatInstanceId then return nil end
    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots and state.slots[slotIdx]
        if item and item.combatInstanceId == combatInstanceId then
            return slotIdx
        end
    end
    return nil
end

local function FirstEmptySlot(state, excludedColumn)
    for slotIdx = 1, Config.TOTAL_SLOTS do
        if not state.slots[slotIdx] and SlotColumn(slotIdx) ~= excludedColumn then
            return slotIdx
        end
    end
    for slotIdx = 1, Config.TOTAL_SLOTS do
        if not state.slots[slotIdx] then return slotIdx end
    end
    return nil
end

local function IsTutorialWeapon(item)
    return item
        and ItemSystem.GetCategory(item) == Config.ITEM_CATEGORY.WEAPON
        and (item.quality or 0) == 1
end

function TutorialSystem.IsActive(state)
    return state
        and state.tutorial
        and state.tutorial.active == true
        and state.tutorial.completed ~= true
end

function TutorialSystem.GetStep(state)
    return TutorialSystem.IsActive(state) and state.tutorial.step or nil
end

function TutorialSystem.Begin(state)
    if not state or not state.slots or not state.slots[1] then return false end

    local starter = state.slots[1]
    state.tutorial = {
        version = TutorialSystem.VERSION,
        active = true,
        completed = false,
        step = TutorialSystem.STEP.ALIGN_WEAPON,
        starterWeaponInstanceId = starter.combatInstanceId,
        starterSlot = 1,
        enemyColumn = nil,
        firstMonsterInstanceId = nil,
        rewardId = nil,
        rewardWeaponInstanceId = nil,
        deployTargetSlot = nil,
    }
    print("[Tutorial] 首次普通对局引导已启动")
    return true
end

function TutorialSystem.RegisterOpeningMonster(state, monster)
    if not TutorialSystem.IsActive(state) or not monster then return end
    local tutorial = state.tutorial
    tutorial.firstMonsterInstanceId = monster.instanceId
    tutorial.enemyColumn = monster.col
    print(string.format("[Tutorial] 首只妖魔登记完成：实例=%s，第%d列", tostring(monster.instanceId), monster.col or 0))
end

function TutorialSystem.GetOpeningEnemyColumn(state)
    local tutorial = state and state.tutorial
    if not tutorial or tutorial.step ~= TutorialSystem.STEP.ALIGN_WEAPON then return nil end
    return tutorial.enemyColumn
end

function TutorialSystem.MarkWeaponAligned(state)
    if not TutorialSystem.IsActive(state) then return false end
    local tutorial = state.tutorial
    if tutorial.step ~= TutorialSystem.STEP.ALIGN_WEAPON then return false end
    tutorial.step = TutorialSystem.STEP.WAIT_FIRST_KILL
    print("[Tutorial] 已完成同列部署，等待首只妖魔死亡")
    return true
end

function TutorialSystem.OnMonsterKilled(state, monster)
    if not TutorialSystem.IsActive(state) or not monster then return false end
    local tutorial = state.tutorial
    if tutorial.step ~= TutorialSystem.STEP.WAIT_FIRST_KILL
        or monster.instanceId ~= tutorial.firstMonsterInstanceId then
        return false
    end
    tutorial.firstMonsterKilled = true
    tutorial.rewardPending = true
    print("[Tutorial] 首只妖魔已死亡，已安排攻击法宝奖励")
    return true
end

function TutorialSystem.NeedsRewardSpawn(state)
    local tutorial = state and state.tutorial
    return TutorialSystem.IsActive(state)
        and tutorial.rewardPending == true
        and tutorial.rewardId == nil
end

function TutorialSystem.GetRewardColumn(state)
    local tutorial = state and state.tutorial
    if not tutorial then return 1 end
    local weaponSlot = FindWeaponSlot(state, tutorial.starterWeaponInstanceId)
    local weaponColumn = weaponSlot and SlotColumn(weaponSlot) or tutorial.enemyColumn or 1
    return weaponColumn % Config.GRID_COLS + 1
end

function TutorialSystem.RegisterReward(state, reward)
    if not TutorialSystem.IsActive(state) or not reward or not reward.rewardItem then return false end
    local tutorial = state.tutorial
    tutorial.rewardPending = false
    tutorial.rewardId = reward.id
    tutorial.rewardWeaponInstanceId = reward.rewardItem.combatInstanceId
    tutorial.step = TutorialSystem.STEP.ATTACK_REWARD
    print(string.format("[Tutorial] 攻击法宝奖励已刷新：%s，第%d列", reward.rewardItem.name or "法宝", reward.col or 0))
    return true
end

function TutorialSystem.RefreshProgress(state)
    if not TutorialSystem.IsActive(state) then return false end
    local tutorial = state.tutorial

    if tutorial.step == TutorialSystem.STEP.WAIT_FIRST_KILL
        and not FindLiveMonsterByInstance(state, tutorial.firstMonsterInstanceId) then
        tutorial.firstMonsterKilled = true
        tutorial.rewardPending = tutorial.rewardId == nil
    end

    if tutorial.step == TutorialSystem.STEP.ATTACK_REWARD
        and tutorial.rewardId
        and not FindRewardById(state, tutorial.rewardId) then
        local stored = state.dropQueue and state.dropQueue[1]
        if stored and stored.combatInstanceId == tutorial.rewardWeaponInstanceId then
            local starterSlot = FindWeaponSlot(state, tutorial.starterWeaponInstanceId)
            tutorial.deployTargetSlot = FirstEmptySlot(state, starterSlot and SlotColumn(starterSlot) or nil)
            tutorial.step = TutorialSystem.STEP.DEPLOY_REWARD
            print("[Tutorial] 攻击法宝已进入暂存区")
            return true
        end
    end

    return false
end

function TutorialSystem.CanDrop(state, sourceSlot, targetSlot)
    if not TutorialSystem.IsActive(state) then return true end
    if not sourceSlot or not targetSlot then return false end

    local sourceCategory, sourceIndex = require("DragActions").ParseSlot(sourceSlot)
    local targetCategory, targetIndex = require("DragActions").ParseSlot(targetSlot)
    if not sourceCategory or not targetCategory then return false end

    local tutorial = state.tutorial
    local step = tutorial.step
    if step == TutorialSystem.STEP.ALIGN_WEAPON then
        if sourceCategory ~= "deploy" or targetCategory ~= "deploy" then return false end
        local sourceItem = state.slots[sourceIndex]
        return sourceItem
            and sourceItem.combatInstanceId == tutorial.starterWeaponInstanceId
            and SlotColumn(targetIndex) == tutorial.enemyColumn
            and state.slots[targetIndex] == nil
    elseif step == TutorialSystem.STEP.WAIT_FIRST_KILL then
        return false
    elseif step == TutorialSystem.STEP.ATTACK_REWARD then
        if sourceCategory ~= "deploy" or targetCategory ~= "deploy" then return false end
        local sourceItem = state.slots[sourceIndex]
        local reward = FindRewardById(state, tutorial.rewardId)
        return sourceItem
            and sourceItem.combatInstanceId == tutorial.starterWeaponInstanceId
            and reward ~= nil
            and SlotColumn(targetIndex) == reward.col
            and state.slots[targetIndex] == nil
    elseif step == TutorialSystem.STEP.DEPLOY_REWARD then
        return sourceCategory == "storage"
            and sourceIndex == 1
            and targetCategory == "deploy"
            and targetIndex == tutorial.deployTargetSlot
            and state.slots[targetIndex] == nil
    elseif step == TutorialSystem.STEP.MERGE_WEAPONS then
        if sourceCategory ~= "deploy" or targetCategory ~= "deploy" then return false end
        return IsTutorialWeapon(state.slots[sourceIndex])
            and IsTutorialWeapon(state.slots[targetIndex])
            and ItemSystem.CanMerge(state.slots[sourceIndex], state.slots[targetIndex])
    end
    return false
end

function TutorialSystem.OnDropApplied(state, sourceSlot, targetSlot, result)
    if not TutorialSystem.IsActive(state) or not result or result.changed ~= true then return false end
    local tutorial = state.tutorial
    local sourceCategory = sourceSlot and sourceSlot:GetSlotCategory() or nil
    local targetCategory = targetSlot and targetSlot:GetSlotCategory() or nil

    if tutorial.step == TutorialSystem.STEP.ALIGN_WEAPON and result.moved then
        return TutorialSystem.MarkWeaponAligned(state)
    elseif tutorial.step == TutorialSystem.STEP.ATTACK_REWARD and result.moved then
        print("[Tutorial] 已将攻击法宝移至奖励所在列")
        return true
    elseif tutorial.step == TutorialSystem.STEP.DEPLOY_REWARD
        and sourceCategory == "storage" and targetCategory == "deploy" and result.moved then
        tutorial.step = TutorialSystem.STEP.MERGE_WEAPONS
        print("[Tutorial] 暂存区法宝已部署")
        return true
    elseif tutorial.step == TutorialSystem.STEP.MERGE_WEAPONS and result.merged then
        tutorial.step = TutorialSystem.STEP.OPEN_SHOP
        print("[Tutorial] 攻击法宝合成完成")
        return true
    end
    return false
end

function TutorialSystem.CanOpenShop(state)
    return not TutorialSystem.IsActive(state)
        or state.tutorial.step == TutorialSystem.STEP.OPEN_SHOP
end

function TutorialSystem.OnShopOpened(state)
    if not TutorialSystem.IsActive(state) or state.tutorial.step ~= TutorialSystem.STEP.OPEN_SHOP then
        return false
    end
    state.tutorial.step = TutorialSystem.STEP.COMPLETED
    state.tutorial.active = false
    state.tutorial.completed = true
    print("[Tutorial] 新手引导已完成，当前普通对局继续")
    return true
end

function TutorialSystem.GetPresentation(state)
    if not TutorialSystem.IsActive(state) then return nil end
    local tutorial = state.tutorial
    local step = tutorial.step

    if step == TutorialSystem.STEP.ALIGN_WEAPON then
        return {
            text = "攻击法宝会攻击同列目标\n将青锋剑拖到妖魔所在列",
            source = { kind = "deploy", slot = FindWeaponSlot(state, tutorial.starterWeaponInstanceId) or tutorial.starterSlot or 1 },
            target = { kind = "deployColumn", col = tutorial.enemyColumn or 2 },
        }
    elseif step == TutorialSystem.STEP.WAIT_FIRST_KILL then
        return {
            text = "青锋剑正在攻击同列妖魔",
            target = { kind = "fieldCell", col = tutorial.enemyColumn or 2, row = 1 },
        }
    elseif step == TutorialSystem.STEP.ATTACK_REWARD then
        local reward = FindRewardById(state, tutorial.rewardId)
        return {
            text = "攻击场上的法宝即可获得它\n将青锋剑拖到法宝所在列",
            source = { kind = "deploy", slot = FindWeaponSlot(state, tutorial.starterWeaponInstanceId) or 1 },
            target = reward and { kind = "deployColumn", col = reward.col } or nil,
        }
    elseif step == TutorialSystem.STEP.DEPLOY_REWARD then
        return {
            text = "新法宝会先进入暂存区\n将它拖到高亮的部署格",
            source = { kind = "storage" },
            target = { kind = "deploy", slot = tutorial.deployTargetSlot or FirstEmptySlot(state) or 1 },
        }
    elseif step == TutorialSystem.STEP.MERGE_WEAPONS then
        local weaponSlots = {}
        for slotIdx = 1, Config.TOTAL_SLOTS do
            if IsTutorialWeapon(state.slots[slotIdx]) then table.insert(weaponSlots, slotIdx) end
        end
        return {
            text = "相同品质的攻击法宝可以合成\n将一把青锋剑拖到另一把上",
            source = weaponSlots[1] and { kind = "deploy", slot = weaponSlots[1] } or nil,
            target = weaponSlots[2] and { kind = "deploy", slot = weaponSlots[2] } or nil,
        }
    elseif step == TutorialSystem.STEP.OPEN_SHOP then
        return {
            text = "点击左上角商店\n获取更多修行资源",
            target = { kind = "shop" },
        }
    end
    return nil
end

return TutorialSystem
