-- BoardView.lua
-- 新版战斗页面：使用拆分 UI 素材拼装完整战斗场景

local UI = require("urhox-libs/UI")
local Widget = require("urhox-libs/UI/Core/Widget")
local Config = require("Config")
local SlotAdapter = require("SlotAdapter")
local BoardLayout = require("BoardLayout")
local StatusPresenter = require("views.StatusPresenter")
local VisualState = require("VisualState")
local VectorIcons = require("views.VectorIcons")

local BoardView = {}

local ShieldBadge = setmetatable({}, { __index = Widget })
ShieldBadge.__index = ShieldBadge

function ShieldBadge:new(props)
    local instance = Widget.new(self, props or {})
    return instance
end

setmetatable(ShieldBadge, {
    __index = Widget,
    __call = function(cls, props)
        return cls:new(props)
    end,
})

function ShieldBadge:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local cx = l.x + l.w * 0.5
    local cy = l.y + l.h * 0.43
    local s = math.min(l.w, l.h) * 0.48

    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - s * 0.78, cy - s * 0.48)
    nvgLineTo(nvg, cx - s * 0.52, cy - s * 0.78)
    nvgLineTo(nvg, cx, cy - s * 0.62)
    nvgLineTo(nvg, cx + s * 0.52, cy - s * 0.78)
    nvgLineTo(nvg, cx + s * 0.78, cy - s * 0.48)
    nvgBezierTo(nvg,
        cx + s * 0.72, cy + s * 0.30,
        cx + s * 0.28, cy + s * 0.72,
        cx, cy + s * 0.98)
    nvgBezierTo(nvg,
        cx - s * 0.28, cy + s * 0.72,
        cx - s * 0.72, cy + s * 0.30,
        cx - s * 0.78, cy - s * 0.48)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(63, 156, 224, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(22, 73, 122, 255))
    nvgStrokeWidth(nvg, math.max(2, l.w * 0.055))
    nvgStroke(nvg)
end

local CoinIcon = VectorIcons.CoinIcon

local ShopIcon = setmetatable({}, { __index = Widget })
ShopIcon.__index = ShopIcon

function ShopIcon:new(props)
    return Widget.new(self, props or {})
end

setmetatable(ShopIcon, {
    __index = Widget,
    __call = function(cls, props)
        return cls:new(props)
    end,
})

function ShopIcon:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local cx = l.x + l.w * 0.5
    local base = l.y + l.h * 0.84
    local s = math.min(l.w, l.h)
    local bodyW = s * 0.56
    local bodyH = s * 0.36
    local bodyX = cx - bodyW * 0.5
    local bodyY = base - bodyH
    local stroke = math.max(1.5, s * 0.045)

    nvgBeginPath(nvg)
    nvgRect(nvg, bodyX, bodyY, bodyW, bodyH)
    nvgFillColor(nvg, nvgRGBA(232, 228, 210, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(58, 54, 69, 255))
    nvgStrokeWidth(nvg, stroke)
    nvgStroke(nvg)

    local roofY = l.y + s * 0.22
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - s * 0.38, bodyY + s * 0.04)
    nvgLineTo(nvg, cx - s * 0.27, roofY)
    nvgLineTo(nvg, cx + s * 0.27, roofY)
    nvgLineTo(nvg, cx + s * 0.38, bodyY + s * 0.04)
    nvgLineTo(nvg, cx + s * 0.32, bodyY + s * 0.10)
    nvgLineTo(nvg, cx - s * 0.32, bodyY + s * 0.10)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(82, 76, 89, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(28, 27, 36, 255))
    nvgStrokeWidth(nvg, stroke)
    nvgStroke(nvg)

    nvgBeginPath(nvg)
    nvgRect(nvg, cx - s * 0.11, base - s * 0.24, s * 0.22, s * 0.24)
    nvgFillColor(nvg, nvgRGBA(141, 117, 103, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(58, 54, 69, 255))
    nvgStrokeWidth(nvg, math.max(1, stroke * 0.8))
    nvgStroke(nvg)
end

local DESIGN_W = BoardLayout.DESIGN_W
local DESIGN_H = BoardLayout.DESIGN_H

local UI_ASSETS = {
    bg = "image/bg.png",
    hpBarBg = "image/bar_0_long.png",
    hpBarFill = "image/bar_1_long.png",
    decomposeArea = "image/fenjie_area.png",
    decomposeIcon = "image/fenjie.png",
    storage = "image/taizi.png",
    menu = "image/caidan.png",
}

local MELEE_IMAGES = {
    "image/enemy/enemy_ (1).png",
    "image/enemy/enemy_ (2).png",
    "image/enemy/enemy_ (3).png",
    "image/enemy/enemy_ (5).png",
    "image/enemy/enemy_ (7).png",
    "image/enemy/enemy_ (8).png",
    "image/enemy/enemy_ (9).png",
    "image/enemy/enemy_ (15).png",
    "image/enemy/enemy_ (16).png",
}
local RANGED_IMAGES = {
    "image/enemy/enemy_ (4).png",
    "image/enemy/enemy_ (6).png",
    "image/enemy/enemy_ (10).png",
    "image/enemy/enemy_ (11).png",
    "image/enemy/enemy_ (12).png",
    "image/enemy/enemy_ (13).png",
    "image/enemy/enemy_ (14).png",
    "image/enemy/enemy_ (17).png",
    "image/enemy/enemy_ (18).png",
}

local function Clamp01(value)
    return math.min(1.0, math.max(0.0, value or 0))
end

local function GetMonsterImage(monster)
    if monster.asset and monster.asset ~= "" then
        return monster.asset
    end

    local q = monster.quality or 1
    if monster.monsterType == Config.MONSTER_TYPE.MELEE then
        return MELEE_IMAGES[q] or MELEE_IMAGES[1]
    end
    return RANGED_IMAGES[q] or RANGED_IMAGES[1]
end

local function D(layout, scale)
    return BoardLayout.ScaleRect(layout, scale)
end

function BoardView.CalcMetrics(panelW, panelH)
    return BoardLayout.CalcMetrics(panelW, panelH)
end

local function AddImage(parent, m, designRect, image, fit, extra)
    local rect = D(designRect, m.scale)
    local props = {
        position = "absolute",
        left = m.originX + rect.x,
        top = m.originY + rect.y,
        width = rect.w,
        height = rect.h,
        backgroundImage = image,
        backgroundFit = fit or "stretch",
        backgroundColor = {0, 0, 0, 0},
        pointerEvents = "none",
    }
    if extra then
        for k, v in pairs(extra) do props[k] = v end
    end
    parent:AddChild(UI.Panel(props))
end

local function CellRect(m, row, col, isDeploy)
    return BoardLayout.CellRect(m, row, col, isDeploy)
end

BoardView.CellRect = CellRect

local function GetQualityColor(item)
    local quality = item and item.quality or 1
    return Config.QUALITY[quality] and Config.QUALITY[quality].color or {200, 200, 200, 255}
end

local function FormatIntegerStat(value)
    local n = tonumber(value)
    if not n or n <= 0 then return nil end
    return tostring(math.floor(n + 0.5))
end

local function FormatPercentStat(value)
    local n = tonumber(value)
    if not n or n <= 0 then return nil end
    return tostring(math.floor(n * 100 + 0.5)) .. "%"
end

local function GetPillStatText(item)
    local effect = item.pillEffect
    if effect then
        if effect.type == "heal" or effect.type == "shield" then
            return FormatIntegerStat(effect.value or item.power)
        elseif effect.type == "attackBuff" or effect.type == "deathSave" then
            return FormatPercentStat(effect.value or item.power)
        elseif effect.type == "cleanse" then
            return FormatIntegerStat(effect.cleanseCount or effect.immunityTurns)
        end
    end

    local totalHeal = (item.healPerSec or item.value or item.power or 0) * (item.duration or 1)
    return FormatIntegerStat(totalHeal)
end

local function GetTalismanStatText(item)
    local effect = item.talismanEffect
    if effect then
        if effect.type == "damage" then
            return FormatIntegerStat(effect.value or item.aoeDmg or item.power)
        elseif effect.type == "root" then
            return FormatIntegerStat(effect.turns or item.controlDuration)
        elseif effect.type == "armorBreak" or effect.type == "attackDown" or effect.type == "vulnerable" then
            return FormatPercentStat(effect.value or item.power)
        end
    end

    return FormatIntegerStat(item.aoeDmg or item.atk or item.damage or item.power)
end

local function GetAttackDebuffValue(state)
    local debuff = state and state.playerDebuffs and state.playerDebuffs.attackDown
    if not debuff or (debuff.turns or 0) <= 0 then return 0 end
    return math.min(0.20, debuff.value or 0)
end

local function GetAttackSlotDisplayStat(state, item, slotIdx)
    if (state.itemSilenceTurns or 0) > 0 then
        return "封"
    end
    local sealed = state.sealedSlots and state.sealedSlots[slotIdx]
    if sealed and sealed > 0 then
        return "封"
    end

    local value = item.atk or item.power or 0
    local attackDown = GetAttackDebuffValue(state)
    if attackDown > 0 then
        value = value * (1 - attackDown)
    end
    local shockedTurns = state.shockedSlots and state.shockedSlots[slotIdx]
    if shockedTurns and shockedTurns > 0 then
        local reduction = state.shockedSlotReduction and state.shockedSlotReduction[slotIdx] or 0
        value = value * math.max(0, 1 - reduction)
    end
    return FormatIntegerStat(value)
end

local function GetDeployStatText(item, state, slotIdx)
    if not item then return nil end
    if item.itemType == Config.ITEM_TYPE.ATTACK then
        return GetAttackSlotDisplayStat(state or {}, item, slotIdx)
    elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
        return FormatIntegerStat(item.defense or item.shield or item.power)
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        return GetPillStatText(item)
    elseif item.itemType == Config.ITEM_TYPE.TALISMAN then
        return GetTalismanStatText(item)
    end
    return FormatIntegerStat(item.damage or item.value or item.power)
end

local function AddDeployItemVisual(boardPanel, item, r, scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = r.x,
        top = r.y,
        width = r.w,
        height = r.h,
        pointerEvents = "none",
        children = {
            UI.Panel {
                position = "absolute",
                left = 0,
                top = 0,
                width = r.w,
                height = r.h,
                backgroundImage = SlotAdapter.GetItemImage(item),
                backgroundFit = "contain",
                pointerEvents = "none",
            },
        },
    })
end

local function AddDeployStatLabel(boardPanel, item, r, scale, state, slotIdx)
    local statText = GetDeployStatText(item, state, slotIdx)
    if not statText then return end

    local qColor = GetQualityColor(item)
    local labelH = 28 * scale
    local labelW = r.w * 0.58
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = math.floor(r.x + (r.w - labelW) * 0.5 + 0.5),
        top = math.floor(r.y + r.h - labelH + 0.5),
        width = math.floor(labelW + 0.5),
        height = math.floor(labelH + 0.5),
        borderRadius = math.floor(9 * scale + 0.5),
        borderWidth = 0,
        backgroundColor = {qColor[1], qColor[2], qColor[3], 255},
        alignItems = "center",
        justifyContent = "center",
        pointerEvents = "none",
        children = {
            UI.Label {
                text = statText,
                width = "100%",
                height = "100%",
                fontSize = math.floor(26 * scale),
                fontColor = {58, 32, 18, 255},
                fontWeight = "bold",
                textAlign = "center",
                pointerEvents = "none",
            },
        },
    })
end

local function AddStatusBars(boardPanel, state, m)
    local maxHp = math.max(1, state.maxHp)
    local hpRatio = Clamp01(state.hp / maxHp)
    local shieldValue = StatusPresenter.GetShieldValue(state)
    local hpText = tostring(state.hp)
    local hp = D(m.hpBar, m.scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + hp.x,
        top = m.originY + hp.y,
        width = hp.w,
        height = hp.h,
        backgroundImage = UI_ASSETS.hpBarBg,
        backgroundFit = "stretch",
        pointerEvents = "none",
        children = {
            UI.Panel {
                position = "absolute",
                left = 0,
                top = 0,
                width = tostring(math.floor(hpRatio * 100)) .. "%",
                height = "100%",
                overflow = "hidden",
                pointerEvents = "none",
                children = {
                    UI.Panel {
                        position = "absolute",
                        left = 0,
                        top = 0,
                        width = hp.w,
                        height = hp.h,
                        backgroundImage = UI_ASSETS.hpBarFill,
                        backgroundFit = "stretch",
                        pointerEvents = "none",
                    },
                },
            },
            UI.Panel {
                position = "absolute",
                left = 0,
                top = 0,
                width = hp.w,
                height = hp.h,
                alignItems = "center",
                justifyContent = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = hpText,
                        fontSize = math.floor(26 * m.scale),
                        fontColor = {245, 210, 185, 255},
                        fontWeight = "bold",
                        textAlign = "center",
                        pointerEvents = "none",
                    },
                },
            },
        },
    })

    if shieldValue > 0 then
        local badge = D(m.shieldBadge, m.scale)
        local shieldText = tostring(shieldValue)
        local shieldFontSize = 29
        if #shieldText >= 5 then
            shieldFontSize = 17
        elseif #shieldText == 4 then
            shieldFontSize = 21
        elseif #shieldText == 3 then
            shieldFontSize = 25
        end

        boardPanel:AddChild(ShieldBadge {
            value = shieldValue,
            position = "absolute",
            left = m.originX + badge.x,
            top = m.originY + badge.y,
            width = badge.w,
            height = badge.h,
            alignItems = "center",
            justifyContent = "center",
            pointerEvents = "none",
            children = {
                UI.Label {
                    text = shieldText,
                    width = "76%",
                    height = "44%",
                    fontSize = math.max(9, math.floor(shieldFontSize * m.scale + 0.5)),
                    fontColor = {255, 246, 218, 255},
                    fontWeight = "bold",
                    textAlign = "center",
                    verticalAlign = "middle",
                    pointerEvents = "none",
                },
            },
        })
    end

    local realm = Config.GetRealm(state.realmIndex)
    local requiredExp = realm.expRequired or 1
    local progress = Clamp01(state.exp / math.max(1, requiredExp))
    local circle = D(m.expCircle, m.scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + circle.x,
        top = m.originY + circle.y,
        width = circle.w,
        height = circle.h,
        borderRadius = circle.w / 2,
        borderWidth = 4 * m.scale,
        borderColor = {75, 52, 30, 220},
        backgroundColor = {246, 197, 130, 245},
        alignItems = "center",
        justifyContent = "center",
        pointerEvents = "none",
        children = {
            UI.Label {
                text = tostring(math.floor(progress * 100)) .. "%",
                fontSize = math.floor(28 * m.scale),
                fontColor = {80, 50, 35, 255},
                fontWeight = "bold",
                pointerEvents = "none",
            },
        },
    })

    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + circle.x - 14 * m.scale,
        top = m.originY + circle.y + circle.h + 8 * m.scale,
        width = circle.w + 28 * m.scale,
        height = 32 * m.scale,
        backgroundColor = {0, 0, 0, 0},
        alignItems = "center",
        justifyContent = "center",
        pointerEvents = "none",
        children = {
            UI.Label {
                text = tostring(realm.name),
                fontSize = math.floor(24 * m.scale),
                fontColor = {248, 224, 182, 255},
                fontWeight = "bold",
                textAlign = "center",
                pointerEvents = "none",
            },
        },
    })
end

function BoardView.Update(boardPanel, state, slots, storageSlot, decomposeSlot, callbacks)
    boardPanel:ClearChildren()

    local layout = boardPanel:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    local m = BoardView.CalcMetrics(layout.w, layout.h)

    AddImage(boardPanel, m, { x = 0, y = 0, w = DESIGN_W, h = DESIGN_H }, UI_ASSETS.bg, "stretch")
    AddStatusBars(boardPanel, state, m)

    local coinRect = D(m.coin, m.scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + coinRect.x,
        top = m.originY + coinRect.y,
        width = coinRect.w,
        height = coinRect.h,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 8 * m.scale,
        backgroundColor = {247, 226, 181, 250},
        borderWidth = math.max(1, 2 * m.scale),
        borderColor = {154, 112, 61, 235},
        borderRadius = math.max(12, 20 * m.scale),
        boxShadow = {
            { x = 3 * m.scale, y = 3 * m.scale, blur = 0, spread = 0, color = {28, 27, 36, 55} },
        },
        pointerEvents = "none",
        children = {
            CoinIcon {
                width = math.max(38, 93 * m.scale),
                height = math.max(38, 93 * m.scale),
                pointerEvents = "none",
            },
            UI.Label {
                text = tostring(state.coins or 0),
                flexShrink = 1,
                fontSize = math.max(20, math.floor(36 * m.scale)),
                fontWeight = "bold",
                fontColor = {28, 27, 36, 255},
                pointerEvents = "none",
            },
        },
    })

    local shopRect = D(m.shopEntry, m.scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + shopRect.x,
        top = m.originY + shopRect.y,
        width = shopRect.w,
        height = shopRect.h,
        alignItems = "center",
        justifyContent = "center",
        pointerEvents = "none",
        children = {
            ShopIcon {
                width = 150 * m.scale,
                height = 150 * m.scale,
                pointerEvents = "none",
            },
        },
    })

    AddImage(boardPanel, m, m.decomposeArea, UI_ASSETS.decomposeArea, "stretch")
    AddImage(boardPanel, m, m.decomposeIcon, UI_ASSETS.decomposeIcon, "contain")
    AddImage(boardPanel, m, m.storage, UI_ASSETS.storage, "stretch")
    AddImage(boardPanel, m, m.menu, UI_ASSETS.menu, "contain")
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = layout.w,
        height = layout.h,
        backgroundColor = {0, 0, 0, 0},
        pointerEvents = "auto",
        onClick = function()
            if callbacks and callbacks.onBlankClick then
                callbacks.onBlankClick()
            end
        end,
    })
    local shopRect = D(m.shopEntry, m.scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + shopRect.x,
        top = m.originY + shopRect.y,
        width = shopRect.w,
        height = shopRect.h,
        backgroundColor = {0, 0, 0, 0},
        pointerEvents = "auto",
        onTap = function()
            if callbacks and callbacks.onShopClick then
                callbacks.onShopClick()
            end
        end,
    })

    local expRect = D(m.expCircle, m.scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + expRect.x,
        top = m.originY + expRect.y,
        width = expRect.w,
        height = expRect.h,
        borderRadius = expRect.w / 2,
        backgroundColor = {0, 0, 0, 0},
        pointerEvents = "auto",
        onTap = function()
            if callbacks and callbacks.onExpCircleClick then
                callbacks.onExpCircleClick()
            end
        end,
    })
    local menuRect = D(m.menu, m.scale)
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = m.originX + menuRect.x,
        top = m.originY + menuRect.y,
        width = menuRect.w,
        height = menuRect.h,
        backgroundColor = {0, 0, 0, 0},
        pointerEvents = "auto",
        onTap = function()
            if callbacks and callbacks.onMainMenuClick then
                callbacks.onMainMenuClick()
            end
        end,
    })

    for _, monster in ipairs(state.monsters) do
        if monster.row >= 1 and monster.row <= Config.FIELD_ROWS and (monster.hp > 0 or monster.showDeadHit == true) then
            local r = CellRect(m, monster.row, monster.col, false)
            local img = GetMonsterImage(monster)
            local hpRatio = 0
            if monster.showDeadHit ~= true then
                hpRatio = math.max(0.02, Clamp01(monster.hp / math.max(1, monster.maxHp or 1)))
            end
            local hpBarW = r.w * 0.78
            local hpBarH = 28 * m.scale
            local hpBarInset = math.max(1, 2 * m.scale)
            local hpBarBorder = math.max(1, math.floor(3 * m.scale + 0.5))
            local hpBarInnerW = math.max(1, hpBarW - hpBarInset * 2)
            local hpBarInnerH = math.max(1, hpBarH - hpBarInset * 2)
            local hpBarRadius = math.max(3 * m.scale, hpBarH * 0.22)
            local hpFillRadius = math.max(2 * m.scale, hpBarInnerH * 0.18)
            local monsterRef = monster
            local shouldPlaySpawnAnim = VisualState.ShouldPlayMonsterSpawn(state, monster)
            local monsterPanel = UI.Panel {
                position = "absolute",
                left = r.x,
                top = r.y,
                width = r.w,
                height = r.h,
                alignItems = "center",
                justifyContent = "flex-end",
                overflow = "visible",
                pointerEvents = "auto",
                transformOrigin = "center",
                scale = shouldPlaySpawnAnim and 0.2 or 1.0,
                opacity = shouldPlaySpawnAnim and 0.0 or 1.0,
                translateY = shouldPlaySpawnAnim and (-16 * m.scale) or 0,
                transition = shouldPlaySpawnAnim and {
                    properties = { "scale", "opacity", "translateY" },
                    duration = 0.42,
                    easing = "easeOutBack",
                } or nil,
                onClick = function()
                    if callbacks and callbacks.onMonsterClick then
                        callbacks.onMonsterClick(monsterRef)
                    end
                end,
                children = {
                    UI.Panel {
                        position = "absolute",
                        bottom = 12 * m.scale,
                        width = r.w * 0.78,
                        aspectRatio = 5 / 6,
                        backgroundImage = img,
                        backgroundFit = "contain",
                        pointerEvents = "none",
                    },
                    UI.Panel {
                        position = "absolute",
                        bottom = 0,
                        width = hpBarW,
                        height = hpBarH,
                        backgroundColor = {24, 16, 14, 240},
                        borderRadius = hpBarRadius,
                        borderWidth = hpBarBorder,
                        borderColor = {50, 30, 24, 255},
                        pointerEvents = "none",
                        children = {
                            UI.Panel {
                                position = "absolute",
                                left = hpBarInset,
                                top = hpBarInset,
                                width = hpBarInnerW,
                                height = hpBarInnerH,
                                backgroundColor = {48, 22, 20, 255},
                                borderRadius = hpFillRadius,
                                overflow = "hidden",
                                pointerEvents = "none",
                                children = {
                                    UI.Panel {
                                        position = "absolute",
                                        left = 0,
                                        top = 0,
                                        width = tostring(math.floor(hpRatio * 100)) .. "%",
                                        height = "100%",
                                        backgroundColor = {150, 28, 26, 255},
                                        borderRadius = hpFillRadius,
                                        pointerEvents = "none",
                                    },
                                },
                            },
                            UI.Panel {
                                position = "absolute",
                                left = 0,
                                top = 0,
                                width = "100%",
                                height = "100%",
                                alignItems = "center",
                                justifyContent = "center",
                                pointerEvents = "none",
                                children = {
                                    UI.Label {
                                        text = tostring(math.max(0, math.floor(monster.hp + 0.5))),
                                        fontSize = math.floor(27 * m.scale),
                                        fontColor = {255, 250, 235, 255},
                                        fontWeight = "bold",
                                        textAlign = "center",
                                        pointerEvents = "none",
                                    },
                                },
                            },
                        },
                    },
                },
            }
            if shouldPlaySpawnAnim then
                if callbacks and callbacks.onMonsterSpawnAnimationPlayed then
                    callbacks.onMonsterSpawnAnimationPlayed(monsterRef)
                end
                monsterPanel:SetStyle({
                    scale = 1.0,
                    opacity = 1.0,
                    translateY = 0,
                })
            end
            boardPanel:AddChild(monsterPanel)
        end
    end

    for _, fieldReward in ipairs(state.fieldRewards) do
        if fieldReward.row >= 1 and fieldReward.row <= Config.FIELD_ROWS then
            local r = CellRect(m, fieldReward.row, fieldReward.col, false)
            local rewardItem = fieldReward.rewardItem
            local rewardRef = fieldReward
            if rewardItem then
                AddDeployItemVisual(boardPanel, rewardItem, r, m.scale)
                AddDeployStatLabel(boardPanel, rewardItem, r, m.scale)
            else
                local rewardQuality = fieldReward.quality or 1
                local qColor = Config.QUALITY[rewardQuality] and Config.QUALITY[rewardQuality].color or {180, 150, 100, 255}
                boardPanel:AddChild(UI.Panel {
                    position = "absolute",
                    left = r.x,
                    top = r.y,
                    width = r.w,
                    height = r.h,
                    alignItems = "center",
                    justifyContent = "center",
                    pointerEvents = "none",
                    children = {
                        UI.Label {
                            text = "奖",
                            fontSize = math.floor(r.w * 0.2),
                            fontColor = qColor,
                            fontWeight = "bold",
                            pointerEvents = "none",
                        },
                    },
                })
            end
            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = r.x,
                top = r.y,
                width = r.w,
                height = r.h,
                backgroundColor = {0, 0, 0, 0},
                pointerEvents = "auto",
                onClick = function()
                    if callbacks and callbacks.onFieldRewardClick then
                        callbacks.onFieldRewardClick(rewardRef)
                    end
                end,
            })
        end
    end

    for i = 1, Config.TOTAL_SLOTS do
        local item = state.slots[i]
        local row = math.ceil(i / Config.GRID_COLS)
        local col = ((i - 1) % Config.GRID_COLS) + 1
        local r = CellRect(m, row, col, true)
        if item then
            AddDeployItemVisual(boardPanel, item, r, m.scale)
            AddDeployStatLabel(boardPanel, item, r, m.scale, state, i)
        end
    end

    if state.dropQueue[1] then
        local item = state.dropQueue[1]
        local s = D({ x = 450, y = 2065, w = 180, h = 150 }, m.scale)
        boardPanel:AddChild(UI.Panel {
            position = "absolute",
            left = m.originX + s.x,
            top = m.originY + s.y,
            width = s.w,
            height = s.h,
            backgroundImage = SlotAdapter.GetItemImage(item),
            backgroundFit = "contain",
            pointerEvents = "none",
        })
    end

    for i = 1, Config.TOTAL_SLOTS do
        local row = math.ceil(i / Config.GRID_COLS)
        local col = ((i - 1) % Config.GRID_COLS) + 1
        local r = CellRect(m, row, col, true)
        local slot = slots[i]
        if slot then
            slot:SetStyle({
                position = "absolute",
                left = r.x,
                top = r.y,
                width = r.w,
                height = r.h,
            })
            slot:SetItem(SlotAdapter.ItemToSlotData(state.slots[i]))
            slot.props.backgroundColor = {0, 0, 0, 0}
            slot.props.borderWidth = 0
            slot.props.borderColor = {0, 0, 0, 0}
            slot.props.borderRadius = 0
            if slot.iconLabel_ then slot.iconLabel_:SetText("") end
            boardPanel:AddChild(slot)
        end
    end

    if storageSlot then
        local s = D({ x = 430, y = 2065, w = 220, h = 132 }, m.scale)
        storageSlot:SetStyle({
            position = "absolute",
            left = m.originX + s.x,
            top = m.originY + s.y,
            width = s.w,
            height = s.h,
        })
        storageSlot:SetItem(SlotAdapter.ItemToSlotData(state.dropQueue[1]))
        storageSlot.props.backgroundColor = {0, 0, 0, 0}
        storageSlot.props.borderWidth = 0
        storageSlot.props.borderColor = {0, 0, 0, 0}
        storageSlot.props.borderRadius = 0
        if storageSlot.iconLabel_ then storageSlot.iconLabel_:SetText("") end
        boardPanel:AddChild(storageSlot)
    end

    if decomposeSlot then
        local d = D({ x = 28, y = 2010, w = 376, h = 197 }, m.scale)
        decomposeSlot:SetStyle({
            position = "absolute",
            left = m.originX + d.x,
            top = m.originY + d.y,
            width = d.w,
            height = d.h,
        })
        decomposeSlot:SetItem(nil)
        decomposeSlot.props.backgroundColor = {0, 0, 0, 0}
        decomposeSlot.props.borderWidth = 0
        decomposeSlot.props.borderColor = {0, 0, 0, 0}
        decomposeSlot.props.borderRadius = 0
        if decomposeSlot.iconLabel_ then decomposeSlot.iconLabel_:SetText("") end
        boardPanel:AddChild(decomposeSlot)
    end
end

return BoardView
