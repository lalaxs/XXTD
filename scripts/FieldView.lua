-- FieldView.lua
-- 战场区域视图 - 所有视觉内容都在 UI 层内渲染
-- 不再依赖 NanoVG 绘制图标，消除坐标系对齐问题

local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")

local FieldView = {}

--- 计算正方形格子度量
function FieldView.CalcGridMetrics(panelW, panelH)
    local cellSize = panelW / Config.GRID_COLS
    local gridW = panelW
    local gridH = cellSize * Config.FIELD_ROWS
    local offsetX = 0
    if gridH > panelH then
        cellSize = panelH / Config.FIELD_ROWS
        gridW = cellSize * Config.GRID_COLS
        gridH = panelH
        offsetX = (panelW - gridW) / 2
    end
    local offsetY = panelH - gridH
    return {
        cellSize = cellSize,
        gridW = gridW,
        gridH = gridH,
        offsetX = offsetX,
        offsetY = offsetY,
    }
end

-- 敌人立绘映射：按品质分配不同图片
-- 近战怪：1-9阶各取不同图片
local MELEE_IMAGES = {
    "image/enemy/enemy_ (1).png",   -- 1阶 野猪
    "image/enemy/enemy_ (2).png",   -- 2阶
    "image/enemy/enemy_ (3).png",   -- 3阶
    "image/enemy/enemy_ (5).png",   -- 4阶 黑狼
    "image/enemy/enemy_ (7).png",   -- 5阶
    "image/enemy/enemy_ (8).png",   -- 6阶
    "image/enemy/enemy_ (9).png",   -- 7阶
    "image/enemy/enemy_ (15).png",  -- 8阶
    "image/enemy/enemy_ (16).png",  -- 9阶
}
-- 远程怪
local RANGED_IMAGES = {
    "image/enemy/enemy_ (4).png",   -- 1阶
    "image/enemy/enemy_ (6).png",   -- 2阶
    "image/enemy/enemy_ (10).png",  -- 3阶 甲兵
    "image/enemy/enemy_ (11).png",  -- 4阶
    "image/enemy/enemy_ (12).png",  -- 5阶
    "image/enemy/enemy_ (13).png",  -- 6阶
    "image/enemy/enemy_ (14).png",  -- 7阶
    "image/enemy/enemy_ (17).png",  -- 8阶
    "image/enemy/enemy_ (18).png",  -- 9阶
}

local function GetMonsterImage(monster)
    local q = monster.quality or 1
    if monster.monsterType == Config.MONSTER_TYPE.MELEE then
        return MELEE_IMAGES[q] or MELEE_IMAGES[1]
    else
        return RANGED_IMAGES[q] or RANGED_IMAGES[1]
    end
end

--- 创建怪物视觉面板
local function CreateMonsterVisual(monster, cellSize)
    local qColor = Config.QUALITY[monster.quality] and Config.QUALITY[monster.quality].color
        or {200, 80, 70, 255}
    local hpRatio = math.max(0.02, monster.hp / monster.maxHp)
    local img = GetMonsterImage(monster)

    return UI.Panel {
        width = "100%",
        height = "100%",
        alignItems = "center",
        justifyContent = "flex-end",
        pointerEvents = "none",
        overflow = "visible",
        children = {
            -- 立绘图片（5:6比例，向上破格）
            UI.Panel {
                position = "absolute",
                bottom = 6,
                width = cellSize * 0.9,
                aspectRatio = 5/6,
                backgroundImage = img,
                backgroundSize = "contain",
                pointerEvents = "none",
            },
            -- 血条（压在角色身上，粗描边Q风格）
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
    }
end

--- 创建宝箱视觉面板
local function CreateChestVisual(quality, cellSize)
    local qColor = Config.QUALITY[quality] and Config.QUALITY[quality].color
        or {180, 150, 100, 255}

    return UI.Panel {
        width = "100%",
        height = "100%",
        alignItems = "center",
        justifyContent = "center",
        pointerEvents = "none",
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
                        textAlign = "center",
                        pointerEvents = "none",
                    },
                },
            },
        },
    }
end

function FieldView.Update(fieldPanel, state, callbacks)
    fieldPanel:ClearChildren()

    local layout = fieldPanel:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    local m = FieldView.CalcGridMetrics(layout.w, layout.h)
    local cellSize = m.cellSize
    local offsetX = m.offsetX
    local offsetY = m.offsetY

    -- 棋盘格子
    for row = 0, Config.FIELD_ROWS - 1 do
        for col = 0, Config.GRID_COLS - 1 do
            local isA = (row + col) % 2 == 0
            fieldPanel:AddChild(UI.Panel {
                position = "absolute",
                left = offsetX + col * cellSize,
                top = offsetY + row * cellSize,
                width = cellSize,
                height = cellSize,
                backgroundColor = isA
                    and STYLE.FIELD_CELL_A
                    or  STYLE.FIELD_CELL_B,
                borderWidth = 0.5,
                borderColor = STYLE.FIELD_GRID_LINE,
                pointerEvents = "none",
            })
        end
    end

    -- 怪物（视觉+交互都在同一个面板内）
    for _, monster in ipairs(state.monsters) do
        if monster.row >= 1 and monster.row <= Config.FIELD_ROWS and monster.hp > 0 then
            local x = offsetX + (monster.col - 1) * cellSize
            local y = offsetY + (monster.row - 1) * cellSize
            local monsterRef = monster
            fieldPanel:AddChild(UI.Panel {
                position = "absolute",
                left = x,
                top = y,
                width = cellSize,
                height = cellSize,
                pointerEvents = "auto",
                onClick = function()
                    if callbacks and callbacks.onMonsterClick then
                        callbacks.onMonsterClick(monsterRef)
                    end
                end,
                children = {
                    CreateMonsterVisual(monster, cellSize),
                },
            })
        end
    end

    -- 宝箱
    for _, chest in ipairs(state.chests) do
        if chest.row >= 1 and chest.row <= Config.FIELD_ROWS then
            local x = offsetX + (chest.col - 1) * cellSize
            local y = offsetY + (chest.row - 1) * cellSize
            local chestQ = chest.quality or 1
            fieldPanel:AddChild(UI.Panel {
                position = "absolute",
                left = x,
                top = y,
                width = cellSize,
                height = cellSize,
                pointerEvents = "auto",
                onClick = function()
                    if callbacks and callbacks.onChestClick then
                        callbacks.onChestClick(chestQ)
                    end
                end,
                children = {
                    CreateChestVisual(chestQ, cellSize),
                },
            })
        end
    end
end

return FieldView
