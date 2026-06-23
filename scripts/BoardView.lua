-- BoardView.lua
-- 统一游戏面板视图 - 战场+部署+暂存全部用绝对定位
-- 一个面板，一套坐标，一个 cellSize

local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")
local SlotAdapter = require("SlotAdapter")

local BoardView = {}

-- 总行数 = 战场7行 + 部署2行 + 暂存1行
local TOTAL_ROWS = Config.FIELD_ROWS + Config.DEPLOY_ROWS + 1

--- 计算棋盘度量
function BoardView.CalcMetrics(panelW, panelH)
    -- 以宽度为基准计算正方形格子
    local cellSize = panelW / Config.GRID_COLS
    local totalGridH = TOTAL_ROWS * cellSize

    -- 如果总高度超出面板，以高度为基准
    if totalGridH > panelH then
        cellSize = panelH / TOTAL_ROWS
    end

    return {
        cellSize = cellSize,
        cols = Config.GRID_COLS,
        fieldRows = Config.FIELD_ROWS,
        deployRows = Config.DEPLOY_ROWS,
        totalRows = TOTAL_ROWS,
    }
end

--- 获取怪物图片
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

local function GetMonsterImage(monster)
    local q = monster.quality or 1
    if monster.monsterType == Config.MONSTER_TYPE.MELEE then
        return MELEE_IMAGES[q] or MELEE_IMAGES[1]
    else
        return RANGED_IMAGES[q] or RANGED_IMAGES[1]
    end
end

--- 更新整个面板
function BoardView.Update(boardPanel, state, slots, storageSlot, callbacks)
    boardPanel:ClearChildren()

    local layout = boardPanel:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    local m = BoardView.CalcMetrics(layout.w, layout.h)
    local cellSize = m.cellSize
    local boardW = cellSize * Config.GRID_COLS
    local offsetX = (layout.w - boardW) / 2

    -- ================================================================
    -- 1. 战场区格子 (row 0-6)
    -- ================================================================
    for row = 0, Config.FIELD_ROWS - 1 do
        for col = 0, Config.GRID_COLS - 1 do
            local isA = (row + col) % 2 == 0
            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = offsetX + col * cellSize,
                top = row * cellSize,
                width = cellSize,
                height = cellSize,
                backgroundColor = isA and STYLE.FIELD_CELL_A or STYLE.FIELD_CELL_B,
                pointerEvents = "none",
            })
        end
    end

    -- ================================================================
    -- 2. 部署区格子 (row 7-8)
    -- ================================================================
    for row = 0, Config.DEPLOY_ROWS - 1 do
        for col = 0, Config.GRID_COLS - 1 do
            local globalRow = Config.FIELD_ROWS + row
            local isA = (globalRow + col) % 2 == 0
            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = offsetX + col * cellSize,
                top = globalRow * cellSize,
                width = cellSize,
                height = cellSize,
                backgroundColor = isA and STYLE.DEPLOY_CELL_A or STYLE.DEPLOY_CELL_B,
                pointerEvents = "none",
            })
        end
    end

    -- ================================================================
    -- 3. 暂存区格子 (row 9, 中间1格)
    -- ================================================================
    local storageRow = Config.FIELD_ROWS + Config.DEPLOY_ROWS
    local storageCol = 2 -- 中间列
    boardPanel:AddChild(UI.Panel {
        position = "absolute",
        left = offsetX + storageCol * cellSize,
        top = storageRow * cellSize,
        width = cellSize,
        height = cellSize,
        backgroundColor = STYLE.DEPLOY_CELL_A,
        pointerEvents = "none",
    })

    -- ================================================================
    -- 4. 怪物（视觉+交互）
    -- ================================================================
    for _, monster in ipairs(state.monsters) do
        if monster.row >= 1 and monster.row <= Config.FIELD_ROWS and monster.hp > 0 then
            local x = offsetX + (monster.col - 1) * cellSize
            local y = (monster.row - 1) * cellSize
            local img = GetMonsterImage(monster)
            local hpRatio = math.max(0.02, monster.hp / monster.maxHp)
            local monsterRef = monster

            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = x, top = y,
                width = cellSize, height = cellSize,
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
                    -- 立绘
                    UI.Panel {
                        position = "absolute",
                        bottom = 6,
                        width = cellSize * 0.9,
                        aspectRatio = 5/6,
                        backgroundImage = img,
                        backgroundFit = "contain",
                        pointerEvents = "none",
                    },
                    -- 血条
                    UI.Panel {
                        position = "absolute",
                        bottom = 2,
                        width = "72%",
                        height = 10,
                        backgroundColor = {50, 40, 30, 220},
                        borderRadius = 5,
                        borderWidth = 5,
                        borderColor = {35, 28, 20, 255},
                        pointerEvents = "none",
                        children = {
                            UI.Panel {
                                width = tostring(math.floor(hpRatio * 100)) .. "%",
                                height = "100%",
                                backgroundColor = {220, 55, 40, 255},
                                borderRadius = 3.5,
                                pointerEvents = "none",
                            },
                        },
                    },
                },
            })
        end
    end

    -- ================================================================
    -- 5. 宝箱
    -- ================================================================
    for _, chest in ipairs(state.chests) do
        if chest.row >= 1 and chest.row <= Config.FIELD_ROWS then
            local x = offsetX + (chest.col - 1) * cellSize
            local y = (chest.row - 1) * cellSize
            local chestQ = chest.quality or 1
            local qColor = Config.QUALITY[chestQ] and Config.QUALITY[chestQ].color or {180, 150, 100, 255}
            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = x, top = y,
                width = cellSize, height = cellSize,
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
                        width = cellSize * 0.5,
                        height = cellSize * 0.4,
                        backgroundColor = {120, 85, 45, 240},
                        borderRadius = 4,
                        borderWidth = 2,
                        borderColor = qColor,
                        alignItems = "center",
                        justifyContent = "center",
                        pointerEvents = "none",
                        children = {
                            UI.Label {
                                text = "宝",
                                fontSize = math.floor(cellSize * 0.2),
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

    -- ================================================================
    -- 6. 部署区道具图片（视觉层）
    -- ================================================================
    for i = 1, Config.TOTAL_SLOTS do
        local item = state.slots[i]
        if item then
            local row = math.ceil(i / Config.GRID_COLS) - 1
            local col = (i - 1) % Config.GRID_COLS
            local globalRow = Config.FIELD_ROWS + row
            local x = offsetX + col * cellSize
            local y = globalRow * cellSize
            local img = SlotAdapter.GetItemImage(item)
            local qColor = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].color
                or {200, 200, 200, 255}

            boardPanel:AddChild(UI.Panel {
                position = "absolute",
                left = x,
                top = y,
                width = cellSize,
                height = cellSize,
                backgroundImage = img,
                backgroundFit = "contain",
                pointerEvents = "none",
            })
        end
    end

    -- ================================================================
    -- 7. 暂存区道具图片
    -- ================================================================
    if state.dropQueue[1] then
        local item = state.dropQueue[1]
        local img = SlotAdapter.GetItemImage(item)
        local x = offsetX + storageCol * cellSize
        local y = storageRow * cellSize
        boardPanel:AddChild(UI.Panel {
            position = "absolute",
            left = x, top = y,
            width = cellSize, height = cellSize,
            alignItems = "center",
            justifyContent = "center",
            overflow = "visible",
            pointerEvents = "none",
            children = {
                UI.Panel {
                    width = cellSize * 0.8,
                    aspectRatio = 5/6,
                    backgroundImage = img,
                    backgroundFit = "contain",
                    pointerEvents = "none",
                },
            },
        })
    end

    -- ================================================================
    -- 8. ItemSlot 交互层（全部透明，最上层）
    -- ================================================================
    for i = 1, Config.TOTAL_SLOTS do
        local row = math.ceil(i / Config.GRID_COLS) - 1
        local col = (i - 1) % Config.GRID_COLS
        local globalRow = Config.FIELD_ROWS + row
        local x = offsetX + col * cellSize
        local y = globalRow * cellSize
        local slot = slots[i]
        if slot then
            slot:SetStyle({
                position = "absolute",
                left = x, top = y,
                width = cellSize, height = cellSize,
            })
            slot:SetItem(SlotAdapter.ItemToSlotData(state.slots[i]))
            -- SetItem 内部会覆盖 backgroundColor，必须在之后再强制透明
            slot.props.backgroundColor = {0, 0, 0, 0}
            slot.props.borderWidth = 0
            slot.props.borderColor = {0, 0, 0, 0}
            slot.props.borderRadius = 0
            if slot.iconLabel_ then
                slot.iconLabel_:SetText("")
            end
            boardPanel:AddChild(slot)
        end
    end

    -- 暂存 slot
    if storageSlot then
        local x = offsetX + storageCol * cellSize
        local y = storageRow * cellSize
        storageSlot:SetStyle({
            position = "absolute",
            left = x, top = y,
            width = cellSize, height = cellSize,
        })
        storageSlot:SetItem(SlotAdapter.ItemToSlotData(state.dropQueue[1]))
        -- SetItem 之后强制透明
        storageSlot.props.backgroundColor = {0, 0, 0, 0}
        storageSlot.props.borderWidth = 0
        storageSlot.props.borderColor = {0, 0, 0, 0}
        storageSlot.props.borderRadius = 0
        if storageSlot.iconLabel_ then
            storageSlot.iconLabel_:SetText("")
        end
        boardPanel:AddChild(storageSlot)
    end
end

return BoardView
