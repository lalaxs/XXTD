-- rogue/RogueRewardSystem.lua
-- 大境界突破后的三选三肉鸽构筑选择。

local Config = require("Config")
local BoardSystem = require("BoardSystem")
local RogueRewardDefs = require("config.RogueRewardDefs")
local DailyChallenge = require("DailyChallenge")

local RogueRewardSystem = {}

local ROGUE_STAGES = {
    attack = { label = "攻击法宝", index = 1 },
    armor = { label = "防御法宝", index = 2 },
    enemy = { label = "敌方强化", index = 3 },
}

local function EnsureTables(state)
    state.modifiers = state.modifiers or {}
    state.selectedRogueRewards = state.selectedRogueRewards or {}
    state.rogueRewardHistory = state.rogueRewardHistory or {}
    state.runWeapons = state.runWeapons or { qingfeng_sword = true }
    state.runArmors = state.runArmors or { dark_iron_shield = true }
    state.weaponUpgradeLevels = state.weaponUpgradeLevels or {}
    state.armorUpgradeLevels = state.armorUpgradeLevels or {}
end

local function CountEnabledItems(items)
    local count = 0
    for _, enabled in pairs(items or {}) do
        if enabled then count = count + 1 end
    end
    return count
end

local function CanUnlockWeapon(state, weaponId)
    return weaponId
        and not state.runWeapons[weaponId]
        and CountEnabledItems(state.runWeapons) < Config.ROGUE.MAX_WEAPONS
end

local function CanUnlockArmor(state, armorId)
    return armorId
        and not state.runArmors[armorId]
        and CountEnabledItems(state.runArmors) < Config.ROGUE.MAX_ARMORS
end

local function GetRewardLevel(state, rewardId)
    return state.selectedRogueRewards[rewardId] or 0
end

local function GetRewardStage(def)
    if def.kind == "unlock" or def.kind == "weapon" or def.rewardGroup == "attack" then
        return "attack"
    end
    if def.kind == "unlockArmor" or def.kind == "armor" or def.rewardGroup == "defense" then
        return "armor"
    end
    if def.rewardGroup == "enemy" then
        return "enemy"
    end
    return nil
end

local function IsAvailable(state, def)
    local level = GetRewardLevel(state, def.id)
    if level >= (def.maxStacks or 1) then return false end

    if def.kind == "unlock" then
        return CanUnlockWeapon(state, def.weaponId)
    end
    if def.kind == "unlockArmor" then
        return CanUnlockArmor(state, def.armorId)
    end
    if def.kind == "armor" then
        return state.runArmors[def.armorId] == true
    end
    if def.kind == "weapon" then
        return state.runWeapons[def.weaponId] == true
    end
    return true
end

local function CopyReward(state, def)
    local level = GetRewardLevel(state, def.id)
    return {
        id = def.id,
        name = def.name,
        shortName = def.shortName,
        category = def.category,
        desc = def.desc,
        kind = def.kind,
        weaponId = def.weaponId,
        armorId = def.armorId,
        rewardGroup = def.rewardGroup,
        modifier = def.modifier and { stat = def.modifier.stat, value = def.modifier.value } or nil,
        icon = def.icon,
        abilityName = def.abilityName,
        abilityDesc = def.abilityDesc,
        level = level,
        nextLevel = level + 1,
        maxStacks = def.maxStacks or 1,
        immediate = def.immediate == true,
    }
end

local function WeightedPick(state, candidates, picked, predicate)
    local options, total = {}, 0
    for _, def in ipairs(candidates) do
        if not picked[def.id] and (not predicate or predicate(def)) then
            local weight = math.max(1, def.weight or 1)
            total = total + weight
            table.insert(options, { def = def, edge = total })
        end
    end
    if total <= 0 then return nil end

    local roll = DailyChallenge.RandomFloat(state) * total
    for _, option in ipairs(options) do
        if roll <= option.edge then return option.def end
    end
    return options[#options].def
end

local function BuildCandidates(state, stage)
    local candidates = {}
    local major = Config.GetRealmMajorIndex(state.realmIndex or 1)
    for _, def in ipairs(RogueRewardDefs) do
        if GetRewardStage(def) == stage and IsAvailable(state, def) then
            local copy = {}
            for k, v in pairs(def) do copy[k] = v end
            if def.kind == "unlock" or def.kind == "unlockArmor" then
                copy.weight = major <= 3 and 7 or (major <= 6 and 4 or 2)
            elseif def.kind == "weapon" then
                copy.weight = major <= 2 and 2 or 5
            end
            table.insert(candidates, copy)
        end
    end
    return candidates
end

local function BuildOffer(state, candidates)
    local selected, ids, itemCounts = {}, {}, {}

    local function canPick(def)
        if ids[def.id] then return false end
        local itemId = def.weaponId or def.armorId
        return not itemId or (itemCounts[itemId] or 0) < 1
    end

    local function add(def)
        if not def then return false end
        table.insert(selected, def)
        ids[def.id] = true
        local itemId = def.weaponId or def.armorId
        if itemId then itemCounts[itemId] = (itemCounts[itemId] or 0) + 1 end
        return true
    end

    local first = WeightedPick(state, candidates, ids, function(def)
        return def.immediate and canPick(def)
    end)
    add(first)
    while #selected < math.min(3, #candidates) do
        local nextDef = WeightedPick(state, candidates, ids, canPick)
        if not nextDef then break end
        add(nextDef)
    end
    return selected
end

function RogueRewardSystem.GetStageInfo(stage)
    return ROGUE_STAGES[stage]
end

function RogueRewardSystem.GetModifierValue(state, stat)
    local total = 0
    for _, modifier in ipairs(state.modifiers or {}) do
        if modifier.stat == stat then total = total + (modifier.value or 0) end
    end
    return total
end

function RogueRewardSystem.GetArmorModifierValue(state, stat, armorId)
    local total = 0
    local scopedStat = stat .. ":" .. tostring(armorId)
    for _, modifier in ipairs(state.modifiers or {}) do
        if modifier.stat == scopedStat then
            total = total + (modifier.value or 0)
        end
    end
    return total
end

function RogueRewardSystem.CreateChoicesForStage(state, stage)
    EnsureTables(state)
    local choices = {}
    for _, def in ipairs(BuildOffer(state, BuildCandidates(state, stage))) do
        table.insert(choices, CopyReward(state, def))
    end
    state.pendingRogueStage = stage
    state.pendingRogueChoices = choices
    return choices
end

function RogueRewardSystem.CreateBreakthroughChoices(state)
    return RogueRewardSystem.CreateChoicesForStage(state, "attack")
end

local function GrantUnlockItem(state, reward, category, unlocked, limit, itemId)
    if not itemId or unlocked[itemId] or CountEnabledItems(unlocked) >= limit then
        return false
    end

    local minQuality = Config.GetDropQualityRange(state.realmIndex or 1)
    local ItemSystem = require("ItemSystem")
    local item = ItemSystem.CreateItemByBaseId(state, category, itemId, minQuality)
    unlocked[itemId] = true

    if not state.dropQueue[1] then
        state.dropQueue[1] = item
    else
        local emptySlot = BoardSystem.FindEmptySlot(state)
        if emptySlot then
            state.slots[emptySlot] = item
        else
            state.dropQueue[1] = item
        end
    end

    local qualityName = Config.QUALITY[minQuality] and Config.QUALITY[minQuality].name or "基础品质"
    print(string.format("[Rogue Unlock] 解锁%s，已获得一件%s", reward.name, qualityName))
    return true
end

local function GrantUnlockWeapon(state, reward)
    return GrantUnlockItem(
        state,
        reward,
        Config.ITEM_CATEGORY.WEAPON,
        state.runWeapons,
        Config.ROGUE.MAX_WEAPONS,
        reward.weaponId
    )
end

local function GrantUnlockArmor(state, reward)
    return GrantUnlockItem(
        state,
        reward,
        Config.ITEM_CATEGORY.ARMOR,
        state.runArmors,
        Config.ROGUE.MAX_ARMORS,
        reward.armorId
    )
end

local function AddHistory(state, reward, stage)
    local realm = Config.GetRealm(state.realmIndex)
    table.insert(state.rogueRewardHistory, {
        id = reward.id,
        name = reward.name,
        category = reward.category,
        desc = reward.desc,
        abilityName = reward.abilityName,
        abilityDesc = reward.abilityDesc,
        stage = stage,
        realmIndex = state.realmIndex,
        realmName = realm.name,
        level = reward.nextLevel,
        maxStacks = reward.maxStacks,
    })
end

function RogueRewardSystem.SelectChoice(state, rewardId)
    EnsureTables(state)
    local stage = state.pendingRogueStage or "attack"
    local picked = nil
    for _, reward in ipairs(state.pendingRogueChoices or {}) do
        if reward.id == rewardId then picked = reward break end
    end
    if not picked then return { ok = false, message = "奖励已失效" } end
    if GetRewardStage(picked) ~= stage then
        return { ok = false, message = "请先完成当前阶段选择" }
    end

    if picked.kind == "unlock" then
        if not GrantUnlockWeapon(state, picked) then
            return { ok = false, message = "攻击法宝已达到上限" }
        end
    elseif picked.kind == "unlockArmor" then
        if not GrantUnlockArmor(state, picked) then
            return { ok = false, message = "防御法宝已达到上限" }
        end
    elseif picked.modifier then
        table.insert(state.modifiers, picked.modifier)
    end

    state.selectedRogueRewards[picked.id] = picked.nextLevel
    if picked.weaponId then state.weaponUpgradeLevels[picked.id] = picked.nextLevel end
    if picked.armorId then state.armorUpgradeLevels[picked.id] = picked.nextLevel end
    AddHistory(state, picked, stage)

    local nextStage = stage == "attack" and "armor" or (stage == "armor" and "enemy" or nil)
    if nextStage then
        local nextChoices = RogueRewardSystem.CreateChoicesForStage(state, nextStage)
        if #nextChoices == 0 then
            return { ok = false, message = "当前阶段暂无可用机缘" }
        end
    else
        state.pendingRogueChoices = nil
        state.pendingRogueStage = nil
        state.pendingRogueEvent = nil
    end

    print(string.format("[Rogue Reward] %s阶段选择%s %d/%d", ROGUE_STAGES[stage].label, picked.name, picked.nextLevel, picked.maxStacks))
    return {
        ok = true,
        reward = picked,
        stage = stage,
        nextStage = nextStage,
        completed = nextStage == nil,
        message = "获得机缘：" .. picked.name,
    }
end

return RogueRewardSystem
