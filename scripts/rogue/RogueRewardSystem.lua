-- rogue/RogueRewardSystem.lua
-- 大境界突破后的本轮肉鸽构筑选择。

local Config = require("Config")
local BoardSystem = require("BoardSystem")
local RogueRewardDefs = require("config.RogueRewardDefs")

local RogueRewardSystem = {}

local function EnsureTables(state)
    state.modifiers = state.modifiers or {}
    state.selectedRogueRewards = state.selectedRogueRewards or {}
    state.rogueRewardHistory = state.rogueRewardHistory or {}
    state.runWeapons = state.runWeapons or { qingfeng_sword = true }
    state.weaponUpgradeLevels = state.weaponUpgradeLevels or {}
end

local function CountRunWeapons(state)
    local count = 0
    for _, enabled in pairs(state.runWeapons or {}) do
        if enabled then count = count + 1 end
    end
    return count
end

local function GetRewardLevel(state, rewardId)
    return state.selectedRogueRewards[rewardId] or 0
end

local function IsAvailable(state, def)
    local level = GetRewardLevel(state, def.id)
    if level >= (def.maxStacks or 1) then return false end
    if def.kind == "unlock" then
        return not state.runWeapons[def.weaponId] and CountRunWeapons(state) < Config.ROGUE.MAX_WEAPONS
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
        category = def.category,
        desc = def.desc,
        kind = def.kind,
        weaponId = def.weaponId,
        modifier = def.modifier and { stat = def.modifier.stat, value = def.modifier.value } or nil,
        level = level,
        nextLevel = level + 1,
        maxStacks = def.maxStacks or 1,
        immediate = def.immediate == true,
    }
end

local function WeightedPick(candidates, picked, predicate)
    local options, total = {}, 0
    for _, def in ipairs(candidates) do
        if not picked[def.id] and (not predicate or predicate(def)) then
            local weight = math.max(1, def.weight or 1)
            total = total + weight
            table.insert(options, { def = def, edge = total })
        end
    end
    if total <= 0 then return nil end
    local roll = math.random() * total
    for _, option in ipairs(options) do
        if roll <= option.edge then return option.def end
    end
    return options[#options].def
end

local function BuildCandidates(state)
    local candidates = {}
    local major = Config.GetRealmMajorIndex(state.realmIndex or 1)
    for _, def in ipairs(RogueRewardDefs) do
        if IsAvailable(state, def) then
            local copy = def
            if def.kind == "unlock" then
                copy = {}
                for k, v in pairs(def) do copy[k] = v end
                copy.weight = major <= 3 and 7 or (major <= 6 and 4 or 2)
            elseif def.kind == "weapon" then
                copy = {}
                for k, v in pairs(def) do copy[k] = v end
                copy.weight = major <= 2 and 2 or 5
            end
            table.insert(candidates, copy)
        end
    end
    return candidates
end

local function BuildOffer(state, candidates)
    local selected, ids, weaponCounts = {}, {}, {}
    local function canPick(def)
        if ids[def.id] then return false end
        return not def.weaponId or (weaponCounts[def.weaponId] or 0) < 1
    end
    local function add(def)
        if not def then return false end
        table.insert(selected, def)
        ids[def.id] = true
        if def.weaponId then weaponCounts[def.weaponId] = (weaponCounts[def.weaponId] or 0) + 1 end
        return true
    end

    local first = WeightedPick(candidates, ids, function(def) return def.immediate and canPick(def) end)
    add(first)
    while #selected < math.min(3, #candidates) do
        local nextDef = WeightedPick(candidates, ids, canPick)
        if not nextDef then break end
        add(nextDef)
    end

    local commonCount = 0
    for _, def in ipairs(selected) do if def.kind == "common" then commonCount = commonCount + 1 end end
    if commonCount >= 3 then
        local replacement = WeightedPick(candidates, ids, function(def) return def.kind ~= "common" and canPick(def) end)
        if replacement then selected[#selected] = replacement end
    end
    return selected
end

function RogueRewardSystem.GetModifierValue(state, stat)
    local total = 0
    for _, modifier in ipairs(state.modifiers or {}) do
        if modifier.stat == stat then total = total + (modifier.value or 0) end
    end
    return total
end

function RogueRewardSystem.CreateBreakthroughChoices(state)
    EnsureTables(state)
    local choices = {}
    for _, def in ipairs(BuildOffer(state, BuildCandidates(state))) do
        table.insert(choices, CopyReward(state, def))
    end
    state.pendingRogueChoices = choices
    return choices
end

local function GrantUnlockWeapon(state, reward)
    state.runWeapons[reward.weaponId] = true
    local minQuality = Config.GetDropQualityRange(state.realmIndex or 1)
    local ItemSystem = require("ItemSystem")
    local item = ItemSystem.CreateItemByBaseId(state, Config.ITEM_CATEGORY.WEAPON, reward.weaponId, minQuality)
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
    print(string.format("[Rogue Unlock] 解锁%s，已获得一把%s法宝", reward.name:gsub("解锁·", ""), qualityName))
end

local function AddHistory(state, reward)
    local realm = Config.GetRealm(state.realmIndex)
    table.insert(state.rogueRewardHistory, {
        id = reward.id,
        name = reward.name,
        category = reward.category,
        desc = reward.desc,
        realmIndex = state.realmIndex,
        realmName = realm.name,
        level = reward.nextLevel,
        maxStacks = reward.maxStacks,
    })
end

function RogueRewardSystem.SelectChoice(state, rewardId)
    EnsureTables(state)
    local picked = nil
    for _, reward in ipairs(state.pendingRogueChoices or {}) do
        if reward.id == rewardId then picked = reward break end
    end
    if not picked then return { ok = false, message = "奖励已失效" } end

    if picked.kind == "unlock" then
        GrantUnlockWeapon(state, picked)
    elseif picked.modifier then
        table.insert(state.modifiers, picked.modifier)
    end
    state.selectedRogueRewards[picked.id] = picked.nextLevel
    if picked.weaponId then state.weaponUpgradeLevels[picked.id] = picked.nextLevel end
    AddHistory(state, picked)
    state.pendingRogueChoices = nil
    state.pendingRogueEvent = nil
    print(string.format("[Rogue Reward] 选择%s %d/%d", picked.name, picked.nextLevel, picked.maxStacks))
    return { ok = true, reward = picked, message = "获得机缘：" .. picked.name }
end

return RogueRewardSystem
