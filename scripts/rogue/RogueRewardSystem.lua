-- rogue/RogueRewardSystem.lua
-- 突破后肉鸽 3 选 1 奖励。奖励写入 state.modifiers，局内生效。

local Config = require("Config")
local RogueRewardDefs = require("config.RogueRewardDefs")
local TalentUnlockSystem = require("TalentUnlockSystem")

local RogueRewardSystem = {}

local OFFENSE_OR_DEFENSE = {
    ["攻势"] = true,
    ["守势"] = true,
}

local function EnsureTables(state)
    state.modifiers = state.modifiers or {}
    state.selectedRogueRewards = state.selectedRogueRewards or {}
    state.rogueRewardHistory = state.rogueRewardHistory or {}
    TalentUnlockSystem.EnsureDefaults(state)
end

local function GetRealmScale(state, def)
    if not def.scalable then return 1.0 end
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)
    if majorIndex < 5 then return 1.0 end
    return 1.0 + 0.15 * (majorIndex - 4)
end

local function CopyModifier(modifier, scale)
    if not modifier then return nil end
    return {
        stat = modifier.stat,
        value = (modifier.value or 0) * (scale or 1.0),
    }
end

local function CopyReward(def, state)
    local scale = GetRealmScale(state, def)
    local copied = {
        id = def.id,
        name = def.name,
        category = def.category,
        desc = def.desc,
        modifier = CopyModifier(def.modifier, scale),
        extraModifiers = {},
    }
    for _, modifier in ipairs(def.extraModifiers or {}) do
        table.insert(copied.extraModifiers, CopyModifier(modifier, scale))
    end
    return copied
end

local function Shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

local function IsItemUnlocked(state, category, baseId)
    local unlocked = state.unlockedPools and state.unlockedPools[category]
    return unlocked and unlocked[baseId] == true
end

local function HasAnyUnlocked(state, category)
    local unlocked = state.unlockedPools and state.unlockedPools[category]
    if not unlocked then return false end
    for _, enabled in pairs(unlocked) do
        if enabled then return true end
    end
    return false
end

local function HasWeaponSchool(state, school)
    return state.unlockedWeaponSchools and state.unlockedWeaponSchools[school] == true
end

local function HasAnyUnlockedBaseId(state, category, baseIds)
    for _, baseId in ipairs(baseIds or {}) do
        if IsItemUnlocked(state, category, baseId) then
            return true
        end
    end
    return false
end

local function HasHighQualityWeapon(state)
    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots and state.slots[slotIdx]
        if item and item.itemType == Config.ITEM_TYPE.ATTACK and (item.quality or 0) >= 5 then
            return true
        end
    end

    for _, item in ipairs(state.dropQueue or {}) do
        if item and item.itemType == Config.ITEM_TYPE.ATTACK and (item.quality or 0) >= 5 then
            return true
        end
    end

    return false
end

local function IsPrereqMet(state, prereq)
    if not prereq then return true end

    if prereq.type == "anyWeapon" then
        return HasAnyUnlocked(state, Config.ITEM_CATEGORY.WEAPON)
    elseif prereq.type == "anyArmor" then
        return HasAnyUnlocked(state, Config.ITEM_CATEGORY.ARMOR)
    elseif prereq.type == "anyPill" then
        return HasAnyUnlocked(state, Config.ITEM_CATEGORY.PILL)
    elseif prereq.type == "anyTalisman" then
        return HasAnyUnlocked(state, Config.ITEM_CATEGORY.TALISMAN)
    elseif prereq.type == "weaponSchool" then
        return HasWeaponSchool(state, prereq.school)
    elseif prereq.type == "weaponBaseAny" then
        return HasAnyUnlockedBaseId(state, Config.ITEM_CATEGORY.WEAPON, prereq.baseIds)
    elseif prereq.type == "item" then
        return IsItemUnlocked(state, prereq.category, prereq.baseId)
    elseif prereq.type == "highQualityWeapon" then
        return HasHighQualityWeapon(state)
    end

    return true
end

local function ExpandDynamicRewardDefs(state, def)
    if def.dynamic ~= "weaponSchoolSpecialization" then
        return { def }
    end

    local defs = {}
    for _, variant in ipairs(def.variants or {}) do
        if HasWeaponSchool(state, variant.school) then
            table.insert(defs, {
                id = def.id .. "_" .. variant.school,
                name = def.name .. "·" .. variant.label,
                category = def.category,
                desc = variant.desc or def.desc,
                power = def.power,
                scalable = def.scalable,
                modifier = {
                    stat = "schoolDamagePct:" .. variant.school,
                    value = 0.18,
                },
            })
        end
    end
    return defs
end

local function ForEachAvailableRewardDef(state, callback)
    for _, def in ipairs(RogueRewardDefs) do
        if def.dynamic then
            for _, dynamicDef in ipairs(ExpandDynamicRewardDefs(state, def)) do
                callback(dynamicDef)
            end
        elseif IsPrereqMet(state, def.prereq) then
            callback(def)
        end
    end
end

local function GetWeightForRealm(def, realmIndex)
    local power = def.power or "small"
    if realmIndex >= 5 then
        if power == "large" then return 4 end
        if power == "medium" then return 3 end
        return 2
    end

    if power == "large" then return 1 end
    if power == "medium" then return 2 end
    return 3
end

local function BuildCandidates(state)
    local candidates = {}
    local weighted = {}
    local majorIndex = Config.GetRealmMajorIndex(state.realmIndex or 1)

    ForEachAvailableRewardDef(state, function(def)
        if not state.selectedRogueRewards[def.id] then
            table.insert(candidates, def)
            local weight = GetWeightForRealm(def, majorIndex)
            for _ = 1, weight do
                table.insert(weighted, def)
            end
        end
    end)

    if #candidates == 0 then
        ForEachAvailableRewardDef(state, function(def)
            table.insert(candidates, def)
            table.insert(weighted, def)
        end)
    end

    return candidates, weighted
end

local function ContainsReward(list, rewardId)
    for _, def in ipairs(list) do
        if def.id == rewardId then return true end
    end
    return false
end

local function PickFromPool(pool, picked, predicate)
    local options = {}
    for _, def in ipairs(pool) do
        if not ContainsReward(picked, def.id) and (not predicate or predicate(def)) then
            table.insert(options, def)
        end
    end
    if #options == 0 then return nil end
    return options[math.random(#options)]
end

local function BuildOffer(candidates, weighted)
    Shuffle(weighted)
    local picked = {}

    local first = PickFromPool(weighted, picked)
    if first then table.insert(picked, first) end

    local firstCategory = first and first.category or nil
    local second = PickFromPool(weighted, picked, function(def)
        return def.category ~= firstCategory
    end) or PickFromPool(weighted, picked)
    if second then table.insert(picked, second) end

    while #picked < math.min(3, #candidates) do
        local nextReward = PickFromPool(weighted, picked) or PickFromPool(candidates, picked)
        if not nextReward then break end
        table.insert(picked, nextReward)
    end

    local hasOffenseOrDefense = false
    for _, def in ipairs(picked) do
        if OFFENSE_OR_DEFENSE[def.category] then
            hasOffenseOrDefense = true
            break
        end
    end

    if #picked > 0 and not hasOffenseOrDefense then
        local fallback = PickFromPool(candidates, picked, function(def)
            return OFFENSE_OR_DEFENSE[def.category]
        end)
        if fallback then
            picked[#picked] = fallback
        end
    end

    return picked
end

function RogueRewardSystem.GetModifierValue(state, stat)
    local total = 0
    for _, modifier in ipairs(state.modifiers or {}) do
        if modifier.stat == stat then
            total = total + (modifier.value or 0)
        end
    end
    return total
end

function RogueRewardSystem.CreateBreakthroughChoices(state)
    EnsureTables(state)

    local candidates, weighted = BuildCandidates(state)
    local picked = BuildOffer(candidates, weighted)

    local choices = {}
    for _, def in ipairs(picked) do
        table.insert(choices, CopyReward(def, state))
    end

    state.pendingRogueChoices = choices
    return choices
end

local function AddModifier(state, modifier)
    if not modifier then return end
    table.insert(state.modifiers, modifier)
end

local function AddRewardHistory(state, reward)
    if not reward then return end
    local realm = Config.GetRealm(state.realmIndex)
    table.insert(state.rogueRewardHistory, {
        id = reward.id,
        name = reward.name,
        category = reward.category,
        desc = reward.desc,
        realmIndex = state.realmIndex,
        realmName = realm and realm.name or nil,
        modifier = reward.modifier,
        extraModifiers = reward.extraModifiers,
    })
end

function RogueRewardSystem.SelectChoice(state, rewardId)
    EnsureTables(state)

    local choices = state.pendingRogueChoices or {}
    local picked = nil
    for _, reward in ipairs(choices) do
        if reward.id == rewardId then
            picked = reward
            break
        end
    end

    if not picked then
        return { ok = false, message = "奖励已失效" }
    end

    AddModifier(state, picked.modifier)
    for _, modifier in ipairs(picked.extraModifiers or {}) do
        AddModifier(state, modifier)
    end
    state.selectedRogueRewards[picked.id] = true
    AddRewardHistory(state, picked)
    state.pendingRogueChoices = nil
    state.pendingRogueEvent = nil

    return { ok = true, reward = picked, message = "获得机缘：" .. picked.name }
end

return RogueRewardSystem
