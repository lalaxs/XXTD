-- rewards/FieldRewardService.lua
-- 场上随机奖励命中后的结算。使用四类道具池：法宝、护甲、丹药、符咒。

local Config = require("Config")
local ItemSystem = require("ItemSystem")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local VisualEventQueue = require("events.VisualEventQueue")

local FieldRewardService = {}

local CATEGORY_LABELS = {
    [Config.ITEM_CATEGORY.WEAPON] = "法宝",
    [Config.ITEM_CATEGORY.ARMOR] = "护甲",
    [Config.ITEM_CATEGORY.PILL] = "丹药",
    [Config.ITEM_CATEGORY.TALISMAN] = "符咒",
}

local function CountOwnedWeapons(state)
    local count = 0
    for _, item in ipairs(state.slots or {}) do
        if ItemSystem.GetCategory(item) == Config.ITEM_CATEGORY.WEAPON then
            count = count + 1
        end
    end
    for _, item in ipairs(state.dropQueue or {}) do
        if ItemSystem.GetCategory(item) == Config.ITEM_CATEGORY.WEAPON then
            count = count + 1
        end
    end
    return count
end

local function ShouldGuaranteeEarlyWeapon(state)
    local rules = Config.FIELD_REWARD or {}
    if Config.GetRealmMajorIndex(state.realmIndex or 1) ~= 1 then return false end
    if (state.turn or 0) > (rules.EARLY_WEAPON_GUARANTEE_TURNS or 0) then return false end
    return CountOwnedWeapons(state) < (rules.EARLY_WEAPON_GUARANTEE_MIN_COUNT or 2)
end

local function GetCategoryWeightMultiplier(state, category)
    local bonus = RogueRewardSystem.GetModifierValue(state, "itemCategoryWeightPct:" .. tostring(category))
    local multiplier = math.max(0, 1 + bonus)
    if category == Config.ITEM_CATEGORY.WEAPON and Config.GetRealmMajorIndex(state.realmIndex or 1) == 1 then
        multiplier = multiplier * ((Config.FIELD_REWARD and Config.FIELD_REWARD.EARLY_WEAPON_WEIGHT_MUL) or 1.0)
    end
    return multiplier
end

local function BuildCategoryWeights(state)
    local weights = {}
    for _, entry in ipairs(Config.DROP_RULES.CATEGORY_WEIGHTS or {}) do
        local category = entry.category
        local multiplier = GetCategoryWeightMultiplier(state, category)
        table.insert(weights, {
            category = category,
            weight = (entry.weight or 0) * multiplier,
        })
    end
    return weights
end

local function RollWeightedCategory(weights)
    local total = 0
    for _, entry in ipairs(weights) do
        total = total + math.max(0, entry.weight or 0)
    end

    if total <= 0 then
        return Config.ITEM_CATEGORY.WEAPON
    end

    local roll = math.random() * total
    local acc = 0
    for _, entry in ipairs(weights) do
        acc = acc + math.max(0, entry.weight or 0)
        if roll <= acc then
            return entry.category
        end
    end

    return weights[#weights].category
end

local function RollItemCategory(state)
    return RollWeightedCategory(BuildCategoryWeights(state))
end

local function PutIntoStorage(state, item)
    local existing = state.dropQueue[1]
    if not existing then
        state.dropQueue[1] = item
        return true
    elseif item.quality > existing.quality then
        state.dropQueue[1] = item
        return true
    end
    return false
end

local function FormatDropMessage(item, stored)
    local category = ItemSystem.GetCategory(item)
    local categoryLabel = CATEGORY_LABELS[category] or "道具"
    local quality = Config.QUALITY[item.quality]
    local qualityName = quality and quality.name or "凡品"
    if stored then
        return string.format("获得%s：%s[%s]", categoryLabel, item.name, qualityName)
    end
    return string.format("发现%s：%s[%s]，品质未超过暂存", categoryLabel, item.name, qualityName)
end

local function ClampRewardQuality(state, quality)
    local minQuality, maxQuality = Config.GetDropQualityRange(state.realmIndex or 1)
    return math.min(maxQuality, math.max(minQuality, quality or minQuality))
end

function FieldRewardService.CreateRewardItem(state, quality)
    local itemCategory = RollItemCategory(state)
    if ShouldGuaranteeEarlyWeapon(state) then
        itemCategory = Config.ITEM_CATEGORY.WEAPON
    end
    return ItemSystem.CreateItemByCategory(state, itemCategory, ClampRewardQuality(state, quality))
end

function FieldRewardService.CreateConsumableReward(state, quality)
    local category = math.random() < 0.5 and Config.ITEM_CATEGORY.PILL or Config.ITEM_CATEGORY.TALISMAN
    return ItemSystem.CreateItemByCategory(state, category, ClampRewardQuality(state, quality))
end

function FieldRewardService.StoreRewardItem(state, item)
    if not item then return false end
    return PutIntoStorage(state, item)
end

function FieldRewardService.ResolveFieldRewardHit(state, fieldReward)
    fieldReward.hp = 0
    state._fieldRewardClaimedThisTurn = true

    local rewardQuality = fieldReward.quality or 1
    local newItem = fieldReward.rewardItem or FieldRewardService.CreateRewardItem(state, rewardQuality)
    local stored = PutIntoStorage(state, newItem)

    VisualEventQueue.PushDropMessage(state, FormatDropMessage(newItem, stored))
end

return FieldRewardService
