-- views/ShopView.lua
-- 云游商铺弹窗：出售丹药与符咒。

local UI = require("urhox-libs/UI")
local Config = require("Config")
local SlotAdapter = require("SlotAdapter")
local VectorIcons = require("views.VectorIcons")
local RogueRewardSystem = require("rogue.RogueRewardSystem")

local ShopView = {}
ShopView.__index = ShopView

local COLORS = {
    overlay = {0, 0, 0, 160},
    panel = {232, 228, 210, 255},
    card = {243, 240, 230, 255},
    border = {111, 78, 39, 230},
    ink = {28, 27, 36, 255},
    muted = {122, 118, 130, 255},
    red = {166, 60, 51, 255},
    redPressed = {130, 42, 36, 255},
    gold = {181, 150, 91, 255},
    green = {82, 132, 111, 255},
    greenPressed = {61, 104, 86, 255},
    disabled = {122, 118, 130, 150},
}

local CoinIcon = VectorIcons.CoinIcon
local PlayIcon = VectorIcons.PlayIcon

local CATEGORY_LABELS = {
    [Config.ITEM_CATEGORY.WEAPON] = "攻击法宝",
    [Config.ITEM_CATEGORY.ARMOR] = "防御法宝",
    [Config.ITEM_CATEGORY.PILL] = "丹药",
    [Config.ITEM_CATEGORY.TALISMAN] = "符咒",
}

local function DescribeItem(item, state)
    if not item then return "未知商品" end
    local effect = item.pillEffect or item.talismanEffect
    if not effect then return "可主动使用的消耗品" end
    local realm = state and Config.GetRealm(state.realmIndex or 1) or { pillMul = 1.0 }
    local pillMul = (realm.pillMul or 1.0) * (1 + (state and RogueRewardSystem.GetModifierValue(state, "pillEffectPct") or 0))
    local talismanMul = 1 + (state and RogueRewardSystem.GetModifierValue(state, "talismanEffectPct") or 0)
    if effect.type == "heal" then
        local actualHeal = math.floor((effect.value or 0) * pillMul)
        local parts = { string.format("恢复%d气血", actualHeal) }
        if (effect.reduction or 0) > 0 then
            local actualReduction = (effect.reduction or 0) * (realm.pillMul or 1.0)
            table.insert(parts, string.format("攻防强化%d%%", math.floor(actualReduction * 100 + 0.5)))
        end
        if (effect.cleanseCount or 0) > 0 then
            local countText = effect.cleanseCount >= 99 and "全部" or tostring(effect.cleanseCount)
            table.insert(parts, "净化" .. countText .. "负面")
        end
        return table.concat(parts, "，")
    elseif effect.type == "shield" then
        return string.format("获得%d护盾，持续%d回合", effect.value or 0, effect.duration or 0)
    elseif effect.type == "cleanse" then
        local countText = effect.cleanseCount >= 99 and "全部" or tostring(effect.cleanseCount)
        local text = string.format("清除%s负面状态", countText)
        if (effect.immunityTurns or 0) > 0 then
            text = text .. string.format("，免疫%d回合", effect.immunityTurns)
        end
        return text
    elseif effect.type == "attackBuff" then
        local actualAtkBuff = (effect.value or 0) * (realm.pillMul or 1.0)
        return string.format("法宝伤害提升%d%%，持续%d回合", math.floor(actualAtkBuff * 100 + 0.5), effect.duration or 0)
    elseif effect.type == "deathSave" then
        return string.format("免死护佑：气血归零恢复%d%%气血", math.floor((effect.value or 0) * 100 + 0.5))
    elseif effect.type == "damage" then
        local actualDmg = math.floor((effect.value or item.aoeDmg or 0) * talismanMul)
        local targetText = effect.targetCount >= 99 and "全体" or tostring(effect.targetCount or 1)
        return string.format("对%s目标造成%d伤害", targetText, actualDmg)
    elseif effect.type == "root" then
        local targetText = effect.targetCount >= 99 and "全体" or tostring(effect.targetCount or 1)
        return string.format("定身%s目标%d回合", targetText, effect.turns or 1)
    elseif effect.type == "armorBreak" then
        local actualVal = (effect.value or 0) * talismanMul
        local targetText = effect.targetCount >= 99 and "全体" or tostring(effect.targetCount or 1)
        return string.format("破甲%s目标%d%%", targetText, math.floor(actualVal * 100 + 0.5))
    elseif effect.type == "attackDown" then
        local actualVal = (effect.value or 0) * talismanMul
        local targetText = effect.targetCount >= 99 and "全体" or tostring(effect.targetCount or 1)
        return string.format("削攻%s目标%d%%", targetText, math.floor(actualVal * 100 + 0.5))
    elseif effect.type == "vulnerable" then
        local actualVal = (effect.value or 0) * talismanMul
        local targetText = effect.targetCount >= 99 and "全体" or tostring(effect.targetCount or 1)
        return string.format("易伤%s目标%d%%", targetText, math.floor(actualVal * 100 + 0.5))
    end
    -- 兜底：根据 family 判断
    if item.family == "death_save" then
        return "免死护佑：气血归零恢复一定气血"
    elseif item.family == "heal" then
        return string.format("恢复%d气血", math.floor((item.power or 0) * pillMul))
    elseif item.family == "shield" then
        return string.format("获得%d护盾", item.power or 0)
    elseif item.family == "cleanse" then
        return "清除负面状态"
    elseif item.family == "attack_buff" then
        return string.format("法宝伤害提升%d%%", math.floor((item.power or 0) * (realm.pillMul or 1.0) * 100 + 0.5))
    elseif item.family == "damage" then
        return string.format("造成%d伤害", math.floor((item.power or 0) * talismanMul))
    elseif item.family == "root" then
        return "定身目标"
    elseif item.family == "armor_break" then
        return "降低目标防御"
    elseif item.family == "attack_down" then
        return "降低目标攻击"
    elseif item.family == "vulnerable" then
        return "使目标易伤"
    end
    return "可主动使用的消耗品"
end

local function CreatePriceButton(entry, index, coins, onBuy, onClaimAd)
    local affordable = entry.adReward or (not entry.purchased and coins >= (entry.price or 0))
    local children
    if entry.purchased then
        children = {
            UI.Label {
                text = "已售罄",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
            },
        }
    else
        children = entry.adReward and {
            PlayIcon {
                width = 15,
                height = 15,
                pointerEvents = "none",
            },
            UI.Label {
                text = "领取",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
                pointerEvents = "none",
            },
        } or {
            UI.Label {
                text = "购买",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
            },
        }
        if not entry.adReward then
            table.insert(children, CoinIcon {
                width = 25,
                height = 25,
                pointerEvents = "none",
            })
            table.insert(children, UI.Label {
                text = tostring(entry.price or 0),
                fontSize = 15,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
                pointerEvents = "none",
            })
        end
    end

    return UI.Panel {
        width = "100%",
        height = 38,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 4,
        backgroundColor = affordable and COLORS.green or COLORS.disabled,
        borderRadius = 8,
        transition = "scale 0.1s easeOut, opacity 0.1s easeOut, backgroundColor 0.1s easeOut",
        onTapStart = function(event, widget)
            if affordable then
                widget:SetStyle({ scale = 0.96, opacity = 0.86, backgroundColor = COLORS.greenPressed })
            end
        end,
        onTapEnd = function(event, widget)
            widget:SetStyle({
                scale = 1.0,
                opacity = 1.0,
                backgroundColor = affordable and COLORS.green or COLORS.disabled,
            })
        end,
        onTap = function()
            if not affordable then return end
            if entry.adReward then
                if onClaimAd then onClaimAd(index) end
            elseif onBuy then
                onBuy(index)
            end
        end,
        children = children,
    }
end

local function CreateItemCard(entry, index, coins, onBuy, onClaimAd, state)
    local item = entry.item
    local quality = Config.QUALITY[item.quality] or Config.QUALITY[1]
    return UI.Panel {
        width = "48%",
        flexGrow = 0,
        flexShrink = 1,
        minHeight = 204,
        padding = 10,
        gap = 6,
        backgroundColor = COLORS.card,
        borderWidth = 3,
        borderColor = quality.color,
        borderRadius = 14,
        boxShadow = {
            { x = 3, y = 3, blur = 0, spread = 0, color = {28, 27, 36, 45} },
        },
        children = {
            UI.Panel {
                alignSelf = "flex-start",
                paddingHorizontal = 7,
                paddingVertical = 3,
                backgroundColor = quality.color,
                borderRadius = 6,
                children = {
                    UI.Label {
                        text = string.format("%s · %s", CATEGORY_LABELS[item.category] or "商品", quality.name),
                        fontSize = 11,
                        fontWeight = "bold",
                        fontColor = COLORS.ink,
                    },
                },
            },
            UI.Panel {
                alignSelf = "center",
                width = 64,
                height = 64,
                backgroundImage = SlotAdapter.GetItemImage(item),
                backgroundFit = "contain",
                backgroundColor = {0, 0, 0, 0},
                pointerEvents = "none",
            },
            UI.Label {
                text = item.name or "未知商品",
                width = "100%",
                fontSize = 17,
                fontWeight = "bold",
                fontColor = COLORS.ink,
                textAlign = "center",
            },
            UI.Label {
                text = DescribeItem(item, state),
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                fontSize = 12,
                lineHeight = 1.2,
                fontColor = COLORS.muted,
                textAlign = "center",
                whiteSpace = "normal",
            },
            CreatePriceButton(entry, index, coins, onBuy, onClaimAd),
        },
    }
end

function ShopView.Create(callbacks)
    callbacks = callbacks or {}
    local self = setmetatable({
        root = nil,
        panel = nil,
        coinLabel = nil,
        refreshCostLabel = nil,
        refreshButton = nil,
        itemsPanel = nil,
        refreshEnabled = false,
        adRefreshEnabled = false,
        callbacks = callbacks,
    }, ShopView)

    self.coinLabel = UI.Label {
        text = "0",
        fontSize = 17,
        fontWeight = "bold",
        fontColor = COLORS.ink,
    }
    self.refreshCostLabel = UI.Label {
        text = "0",
        fontSize = 14,
        fontWeight = "bold",
        fontColor = {255, 255, 255, 255},
        pointerEvents = "none",
    }
    self.itemsPanel = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        alignItems = "stretch",
        justifyContent = "space-between",
        columnGap = 10,
        rowGap = 10,
        flexGrow = 1,
    }
    self.refreshButton = UI.Panel {
        width = 142,
        height = 40,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 5,
        backgroundColor = COLORS.disabled,
        borderRadius = 8,
        transition = "scale 0.1s easeOut, opacity 0.1s easeOut",
        onTapStart = function(event, widget)
            if self.refreshEnabled then widget:SetStyle({ scale = 0.96, opacity = 0.86 }) end
        end,
        onTapEnd = function(event, widget)
            widget:SetStyle({ scale = 1.0, opacity = 1.0 })
        end,
        onTap = function()
            if self.refreshEnabled and self.callbacks.onRefresh then
                self.callbacks.onRefresh()
            end
        end,
        children = {
            UI.Label {
                text = "刷新",
                fontSize = 14,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
                pointerEvents = "none",
            },
            CoinIcon {
                width = 23,
                height = 23,
                pointerEvents = "none",
            },
            self.refreshCostLabel,
        },
    }
    self.adRefreshButton = UI.Panel {
        width = 142,
        height = 40,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        gap = 7,
        backgroundColor = COLORS.green,
        borderRadius = 8,
        borderWidth = 2,
        borderColor = COLORS.border,
        transition = "scale 0.1s easeOut, opacity 0.1s easeOut",
        onTapStart = function(event, widget)
            if self.adRefreshEnabled then
                widget:SetStyle({ scale = 0.96, opacity = 0.86, backgroundColor = COLORS.greenPressed })
            end
        end,
        onTapEnd = function(event, widget)
            widget:SetStyle({ scale = 1.0, opacity = 1.0, backgroundColor = COLORS.green })
        end,
        onTap = function()
            if self.adRefreshEnabled and self.callbacks.onAdRefresh then
                self.callbacks.onAdRefresh()
            end
        end,
        children = {
            PlayIcon {
                width = 18,
                height = 18,
                pointerEvents = "none",
            },
            UI.Label {
                text = "刷新",
                fontSize = 14,
                fontWeight = "bold",
                fontColor = {255, 255, 255, 255},
                pointerEvents = "none",
            },
        },
    }

    self.panel = UI.Panel {
        width = "90%",
        maxWidth = 680,
        minHeight = 650,
        padding = 16,
        gap = 10,
        backgroundColor = COLORS.panel,
        borderWidth = 3,
        borderColor = COLORS.border,
        borderRadius = 18,
        boxShadow = {
            { x = 0, y = 4, blur = 16, spread = 0, color = {0, 0, 0, 55} },
        },
        transition = "opacity 0.2s easeOutCubic, scale 0.2s easeOutCubic",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                paddingBottom = 8,
                borderBottomWidth = 2,
                borderBottomColor = COLORS.gold,
                children = {
                    UI.Panel {
                        children = {
                            UI.Label {
                                text = "云游商铺",
                                fontSize = 22,
                                fontWeight = "bold",
                                fontColor = COLORS.ink,
                            },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 5,
                        children = {
                            CoinIcon {
                                width = 30,
                                height = 30,
                                pointerEvents = "none",
                            },
                            self.coinLabel,
                        },
                    },
                },
            },
            self.itemsPanel,
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "center",
                gap = 10,
                paddingTop = 2,
                children = {
                    self.refreshButton,
                    self.adRefreshButton,
                },
            },
        },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        zIndex = 1250,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        padding = 12,
        children = {
            UI.Panel {
                position = "absolute",
                top = 0,
                left = 0,
                right = 0,
                bottom = 0,
                backgroundColor = {0, 0, 0, 0},
                pointerEvents = "auto",
                onTap = function()
                    if self.callbacks.onClose then self.callbacks.onClose() end
                end,
            },
            self.panel,
        },
    }
    return self
end

function ShopView:GetRoot()
    return self.root
end

function ShopView:Refresh(state)
    if not state then return end
    self.coinLabel:SetText(tostring(state.coins or 0))
    self.itemsPanel:RemoveAllChildren()
    local pendingShop = state.pendingShop
    for index, entry in ipairs(pendingShop and pendingShop.items or {}) do
        self.itemsPanel:AddChild(CreateItemCard(entry, index, state.coins or 0, function(itemIndex)
            if self.callbacks.onBuy then self.callbacks.onBuy(itemIndex) end
        end, function(itemIndex)
            if self.callbacks.onClaimAdItem then self.callbacks.onClaimAdItem(itemIndex) end
        end, state))
    end

    local rules = Config.SHOP or {}
    local refreshCost = math.max(1, math.floor((pendingShop and pendingShop.refreshCost) or rules.REFRESH_BASE_PRICE or 3))
    self.refreshCostLabel:SetText(tostring(refreshCost))
    self.refreshEnabled = (state.coins or 0) >= refreshCost
    self.refreshButton:SetStyle({
        backgroundColor = self.refreshEnabled and COLORS.gold or COLORS.disabled,
        opacity = self.refreshEnabled and 1 or 0.72,
    })
    self.adRefreshEnabled = true
    self.adRefreshButton:SetStyle({ opacity = 1.0 })
end

function ShopView:Show(state)
    self:Refresh(state)
    if self.root:IsVisible() then return end
    self.root:SetVisible(true)
    self.panel:Animate({
        keyframes = {
            [0] = { opacity = 0, scale = 0.88 },
            [1] = { opacity = 1, scale = 1.0 },
        },
        duration = 0.22,
        easing = "easeOutCubic",
        fillMode = "forwards",
    })
end

function ShopView:Hide()
    self.root:SetVisible(false)
end

return ShopView
