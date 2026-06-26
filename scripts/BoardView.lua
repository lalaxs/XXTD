-- BoardView.lua
-- 新版战斗页面：使用拆分 UI 素材拼装完整战斗场景

local UI = require("urhox-libs/UI")
local Config = require("Config")
local SlotAdapter = require("SlotAdapter")

local BoardView = {}

local DESIGN_W = 1080
local DESIGN_H = 2284

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
    local q = monster.quality or 1
    if monster.monsterType == Config.MONSTER_TYPE.MELEE then
        return MELEE_IMAGES[q] or MELEE_IMAGES[1]
    end
    return RANGED_IMAGES[q] or RANGED_IMAGES[1]
end

local function D(layout, scale)
    return {
        x = layout.x * scale,
        y = layout.y * scale,
        w = layout.w * scale,
        h = layout.h * scale,
    }
end

function BoardView.CalcMetrics(panelW, panelH)
    -- 以 1080x2284 为设计稿做 CONTAIN 等比适配：
    -- 手机、平板、电脑统一使用同一套缩放和居中偏移，宽屏两侧留空但不拉伸变形。
    local scale = math.min(panelW / DESIGN_W, panelH / DESIGN_H)
    local pageW = DESIGN_W * scale
    local pageH = DESIGN_H * scale
    local originX = (panelW - pageW) / 2
    local originY = (panelH - pageH) / 2

    local gridX = 46
    local fieldY = 172
    local cellW = 197
    local fieldCellH = 190
    local deployY = 1590
    local deployCellH = 178

    return {
        scale = scale,
        pageW = pageW,
        pageH = pageH,
        originX = originX,
        originY = originY,
        gridX = gridX,
        fieldY = fieldY,
        deployY = deployY,
        cellW = cellW,
        fieldCellH = fieldCellH,
        deployCellH = deployCellH,
        hpBar = { x = 70, y = 1522, w = 940, h = 40 },
        expCircle = { x = 690, y = 2054, w = 150, h = 150 },
        decomposeArea = { x = 28, y = 2058, w = 376, h = 148 },
        decomposeIcon = { x = 142, y = 2038, w = 128, h = 136 },
        storage = { x = 430, y = 2115, w = 220, h = 82 },
        menu = { x = 887, y = 2058, w = 118, h = 118 },
    }
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
    local x = m.gridX + (col - 1) * m.cellW
    local y
    local h
    if isDeploy then
        y = m.deployY + (row - 1) * m.deployCellH
        h = m.deployCellH
    else
        y = m.fieldY + (row - 1) * m.fieldCellH
        h = m.fieldCellH
    end
    local rect = D({ x = x, y = y, w = m.cellW, h = h }, m.scale)
    return {
        x = m.originX + rect.x,
        y = m.originY + rect.y,
        w = rect.w,
        h = rect.h,
    }
end

BoardView.CellRect = CellRect

local function AddStatusBars(boardPanel, state, m)
    local hpRatio = Clamp01(state.hp / math.max(1, state.maxHp))
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
                        text = tostring(state.hp),
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

    local realm = Config.REALMS[state.realmIndex]
    local nextExp = 9999
    if state.realmIndex < #Config.REALMS then
        nextExp = Config.REALMS[state.realmIndex + 1].expRequired
    end
    local base = realm.expRequired
    local progress = Clamp01((state.exp - base) / math.max(1, nextExp - base))
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
    AddImage(boardPanel, m, m.decomposeArea, UI_ASSETS.decomposeArea, "stretch")
    AddImage(boardPanel, m, m.decomposeIcon, UI_ASSETS.decomposeIcon, "contain")
    AddImage(boardPanel, m, m.storage, UI_ASSETS.storage, "stretch")
    AddImage(boardPanel, m, m.menu, UI_ASSETS.menu, "contain")

    for _, monster in ipairs(state.monsters) do
        if monster.row >= 1 and monster.row <= Config.FIELD_ROWS and monster.hp > 0 then
            local r = CellRect(m, monster.row, monster.col, false)
            local img = GetMonsterImage(monster)
            local hpRatio = math.max(0.02, monster.hp / monster.maxHp)
            local monsterRef = monster
            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = r.x,
                top = r.y,
                width = r.w,
                height = r.h,
                alignItems = "center",
                justifyContent = "flex-end",
                overflow = "visible",
                pointerEvents = "auto",
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
                        bottom = 8 * m.scale,
                        width = r.w * 0.74,
                        height = 18 * m.scale,
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
                                        width = r.w * 0.74,
                                        height = 18 * m.scale,
                                        backgroundImage = UI_ASSETS.hpBarFill,
                                        backgroundFit = "stretch",
                                        pointerEvents = "none",
                                    },
                                },
                            },
                        },
                    },
                },
            })
        end
    end

    for _, chest in ipairs(state.chests) do
        if chest.row >= 1 and chest.row <= Config.FIELD_ROWS then
            local r = CellRect(m, chest.row, chest.col, false)
            local chestQ = chest.quality or 1
            local qColor = Config.QUALITY[chestQ] and Config.QUALITY[chestQ].color or {180, 150, 100, 255}
            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = r.x,
                top = r.y,
                width = r.w,
                height = r.h,
                alignItems = "center",
                justifyContent = "center",
                pointerEvents = "auto",
                onClick = function()
                    if callbacks and callbacks.onChestClick then
                        callbacks.onChestClick(chestQ)
                    end
                end,
                children = {
                    UI.Panel {
                        width = r.w * 0.48,
                        height = r.h * 0.38,
                        backgroundColor = {120, 85, 45, 240},
                        borderRadius = 8 * m.scale,
                        borderWidth = 3 * m.scale,
                        borderColor = qColor,
                        alignItems = "center",
                        justifyContent = "center",
                        pointerEvents = "none",
                        children = {
                            UI.Label {
                                text = "宝",
                                fontSize = math.floor(r.w * 0.2),
                                fontColor = qColor,
                                fontWeight = "bold",
                                pointerEvents = "none",
                            },
                        },
                    },
                },
            })
        end
    end

    for i = 1, Config.TOTAL_SLOTS do
        local item = state.slots[i]
        local row = math.ceil(i / Config.GRID_COLS)
        local col = ((i - 1) % Config.GRID_COLS) + 1
        local r = CellRect(m, row, col, true)
        if item then
            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = r.x,
                top = r.y,
                width = r.w,
                height = r.h,
                backgroundImage = SlotAdapter.GetItemImage(item),
                backgroundFit = "contain",
                pointerEvents = "none",
            })
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
