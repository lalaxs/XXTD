-- rewards/FieldRewardService.lua
-- 场上随机奖励命中后的结算。使用四类道具池：法宝、护甲、丹药、符咒。

local Config = require("Config")
local ItemSystem = require("ItemSystem")
local RogueRewardSystem = require("rogue.RogueRewardSystem")

local FieldRewardService = {}

local CATEGORY_LABELS = {
    [Config.ITEM_CATEGORY.WEAPON] = "法宝",
    [Config.ITEM_CATEGORY.ARMOR] = "护甲",
    [Config.ITEM_CATEGORY.PILL] = "丹药",
    [Config.ITEM_CATEGORY.TALISMAN] = "符咒",
}

local function GetCategoryWeightMultiplier(state, category)
    local bonus = RogueRewardSystem.GetModifierValue(state, "itemCategoryWeightPct:" .. tostring(category))
    return math.max(0, 1 + bonus)
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

function FieldRewardService.CreateRewardItem(state, quality)
    local itemCategory = RollItemCategory(state)
    return ItemSystem.CreateItemByCategory(state, itemCategory, math.min(quality or 1, Config.MAX_QUALITY))
end

function FieldRewardService.CreateConsumableReward(state, quality)
    local category = math.random() < 0.5 and Config.ITEM_CATEGORY.PILL or Config.ITEM_CATEGORY.TALISMAN
    return ItemSystem.CreateItemByCategory(state, category, math.min(quality or 1, Config.MAX_QUALITY))
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

    table.insert(state.dropMessages, FormatDropMessage(newItem, stored))
end

return FieldRewardService
