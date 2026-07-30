-- actions/ShopActions.lua
-- 云游商铺购买与商品入库。

local Config = require("Config")
local FieldRewardService = require("rewards.FieldRewardService")
local BoardSystem = require("BoardSystem")
local VisualEventQueue = require("events.VisualEventQueue")
local DailyChallenge = require("DailyChallenge")

local ShopActions = {}

local function StorePurchasedItem(state, item)
    if not state.dropQueue[1] then
        state.dropQueue[1] = item
        return "暂存台"
    end

    local emptySlot = BoardSystem.FindEmptySlot(state)
    if emptySlot then
        state.slots[emptySlot] = item
        return "布政区"
    end
    return nil
end

local function GetRefreshCost(state, shop)
    local rules = Config.SHOP or {}
    local baseMultiplier = DailyChallenge.GetEffect(state, "shopRefreshBaseMul", 1.0)
    local stepMultiplier = DailyChallenge.GetEffect(state, "shopRefreshStepMul", 1.0)
    local maxMultiplier = DailyChallenge.GetEffect(state, "shopRefreshMaxMul", 1.0)
    local basePrice = math.max(1, math.floor((rules.REFRESH_BASE_PRICE or 3) * baseMultiplier + 0.5))
    local priceStep = math.max(0, math.floor((rules.REFRESH_PRICE_STEP or 1) * stepMultiplier + 0.5))
    local maxPrice = math.max(basePrice, math.floor((rules.REFRESH_MAX_PRICE or 20) * maxMultiplier + 0.5))
    local refreshCount = math.max(0, math.floor(shop and shop.refreshCount or 0))
    return math.min(maxPrice, basePrice + refreshCount * priceStep)
end

local function GetShopMinQuality(state)
    local minQuality, maxQuality = Config.GetDropQualityRange(state.realmIndex or 1)
    local shift = math.floor(DailyChallenge.GetEffect(state, "rewardQualityShift", 0))
    return math.min(maxQuality, math.max(minQuality, minQuality + shift))
end

local function EnsureShopInventory(state)
    if state.shopInventory then
        state.shopInventory.refreshCount = math.max(0, math.floor(state.shopInventory.refreshCount or 0))
        state.shopInventory.refreshCost = GetRefreshCost(state, state.shopInventory)
        return state.shopInventory
    end
    local quality = GetShopMinQuality(state)
    state.shopInventory = {
        id = "fixed_shop",
        title = "云游商铺",
        refreshCount = 0,
        refreshCost = GetRefreshCost(state, { refreshCount = 0 }),
        items = FieldRewardService.CreateShopItems(state, quality),
    }
    return state.shopInventory
end

function ShopActions.Open(state)
    if not state then return nil end
    state.pendingShop = EnsureShopInventory(state)
    return state.pendingShop
end

function ShopActions.Buy(state, itemIndex)
    local shop = state and state.pendingShop
    local entry = shop and shop.items and shop.items[itemIndex]
    if not entry or not entry.item then
        return { ok = false, message = "商品已失效" }
    end
    if entry.purchased then
        return { ok = false, message = "该商品已经售罄" }
    end

    if entry.adReward then
        return { ok = true, requiresAd = true, item = entry.item }
    end

    local price = math.max(0, math.floor(entry.price or 0))
    if (state.coins or 0) < price then
        return { ok = false, message = "金币不足" }
    end

    local destination = StorePurchasedItem(state, entry.item)
    if not destination then
        return { ok = false, message = "暂存台与布政区均已满" }
    end

    state.coins = (state.coins or 0) - price
    entry.purchased = true
    local message = string.format("购得%s，已送往%s", entry.item.name or "商品", destination)
    VisualEventQueue.PushDropMessage(state, message)
    print(string.format("  [Shop] 购买%s，花费%d金币，剩余%d", entry.item.name or "商品", price, state.coins))
    return { ok = true, message = message, item = entry.item, destination = destination }
end

function ShopActions.ClaimAdItem(state, itemIndex)
    local shop = state and state.pendingShop
    local entry = shop and shop.items and shop.items[itemIndex]
    if not entry or not entry.item or entry.purchased or not entry.adReward then
        return { ok = false, message = "广告商品已失效" }
    end

    local destination = StorePurchasedItem(state, entry.item)
    if not destination then
        return { ok = false, message = "暂存台与布政区均已满" }
    end
    entry.purchased = true
    local message = string.format("看广告获得%s，已送往%s", entry.item.name or "商品", destination)
    VisualEventQueue.PushDropMessage(state, message)
    return { ok = true, message = message, item = entry.item, destination = destination }
end

function ShopActions.Refresh(state)
    local shop = state and state.pendingShop
    if not shop then
        return { ok = false, message = "商铺未打开" }
    end

    local price = GetRefreshCost(state, shop)
    if (state.coins or 0) < price then
        return { ok = false, message = "金币不足" }
    end

    local minQuality = GetShopMinQuality(state)
    state.coins = (state.coins or 0) - price
    shop.refreshCount = math.max(0, math.floor(shop.refreshCount or 0)) + 1
    shop.refreshCost = GetRefreshCost(state, shop)
    shop.items = FieldRewardService.CreateShopItems(state, minQuality)

    local message = string.format("商店已刷新，花费%d金币", price)
    VisualEventQueue.PushDropMessage(state, message)
    print(string.format("  [Shop] 刷新商店，花费%d金币，剩余%d，下次刷新%d", price, state.coins, shop.refreshCost))
    return { ok = true, message = message, refreshCost = shop.refreshCost }
end

function ShopActions.RefreshByAd(state)
    local shop = state and state.pendingShop
    if not shop then
        return { ok = false, message = "商铺未打开" }
    end

    local minQuality = GetShopMinQuality(state)
    shop.refreshCount = math.max(0, math.floor(shop.refreshCount or 0)) + 1
    shop.refreshCost = GetRefreshCost(state, shop)
    shop.items = FieldRewardService.CreateShopItems(state, minQuality)
    local message = "看广告刷新商店成功"
    VisualEventQueue.PushDropMessage(state, message)
    return { ok = true, message = message, refreshCost = shop.refreshCost }
end

function ShopActions.Close(state)
    if state then
        state.pendingShop = nil
    end
end

return ShopActions
