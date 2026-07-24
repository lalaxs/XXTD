-- BoardLayout.lua
-- 战斗棋盘布局坐标计算：BoardView 与 NanoVG 特效共用，避免表现层互相依赖。

local Config = require("Config")

local BoardLayout = {}

BoardLayout.DESIGN_W = 1080
BoardLayout.DESIGN_H = 2284

function BoardLayout.ScaleRect(rect, scale)
    return {
        x = rect.x * scale,
        y = rect.y * scale,
        w = rect.w * scale,
        h = rect.h * scale,
    }
end

function BoardLayout.CalcMetrics(panelW, panelH)
    local scale = math.min(panelW / BoardLayout.DESIGN_W, panelH / BoardLayout.DESIGN_H)
    local pageW = BoardLayout.DESIGN_W * scale
    local pageH = BoardLayout.DESIGN_H * scale
    local originX = (panelW - pageW) / 2
    local originY = (panelH - pageH) / 2

    local fieldGridX = 67
    local fieldY = 172
    local fieldCellW = (1011 - fieldGridX) / Config.GRID_COLS
    local fieldCellH = 190
    local deployGridX = 46
    local deployY = 1590
    local deployCellW = 197
    local deployCellH = 178

    return {
        scale = scale,
        pageW = pageW,
        pageH = pageH,
        originX = originX,
        originY = originY,
        gridX = deployGridX,
        cellW = deployCellW,
        fieldGridX = fieldGridX,
        fieldCellW = fieldCellW,
        deployGridX = deployGridX,
        deployCellW = deployCellW,
        fieldY = fieldY,
        deployY = deployY,
        fieldCellH = fieldCellH,
        deployCellH = deployCellH,
        hpBar = { x = 92, y = 1522, w = 918, h = 40 },
        coin = { x = 245, y = 36, w = 220, h = 94 },
        shopEntry = { x = 67, y = 36, w = 150, h = 94 },
        shieldBadge = { x = 26, y = 1496, w = 96, h = 96 },
        expCircle = { x = 690, y = 2054, w = 150, h = 150 },
        decomposeArea = { x = 28, y = 2058, w = 376, h = 148 },
        decomposeIcon = { x = 142, y = 2038, w = 128, h = 136 },
        storage = { x = 430, y = 2115, w = 220, h = 82 },
        menu = { x = 887, y = 2058, w = 118, h = 118 },
    }
end

function BoardLayout.ToScreenRect(metrics, designRect)
    local rect = BoardLayout.ScaleRect(designRect, metrics.scale)
    return {
        x = metrics.originX + rect.x,
        y = metrics.originY + rect.y,
        w = rect.w,
        h = rect.h,
    }
end

function BoardLayout.CellRect(metrics, row, col, isDeploy)
    local gridX = isDeploy and (metrics.deployGridX or metrics.gridX) or (metrics.fieldGridX or metrics.gridX)
    local cellW = isDeploy and (metrics.deployCellW or metrics.cellW) or (metrics.fieldCellW or metrics.cellW)
    local x = gridX + (col - 1) * cellW
    local y
    local h
    if isDeploy then
        y = metrics.deployY + (row - 1) * metrics.deployCellH
        h = metrics.deployCellH
    else
        y = metrics.fieldY + (row - 1) * metrics.fieldCellH
        h = metrics.fieldCellH
    end
    return BoardLayout.ToScreenRect(metrics, { x = x, y = y, w = cellW, h = h })
end

function BoardLayout.DeploySlotRect(metrics, slotIdx)
    local row = math.ceil(slotIdx / Config.GRID_COLS)
    local col = ((slotIdx - 1) % Config.GRID_COLS) + 1
    return BoardLayout.CellRect(metrics, row, col, true)
end

function BoardLayout.CenterOfRect(metrics, designRect)
    local rect = BoardLayout.ToScreenRect(metrics, designRect)
    return rect.x + rect.w * 0.5, rect.y + rect.h * 0.5, rect.w, rect.h
end

return BoardLayout
