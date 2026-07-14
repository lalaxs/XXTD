local Config = require("Config")
local BoardLayout = require("BoardLayout")

local Effects = {}

local attackEffects_ = {}
local mergeEffects_ = {}
local effectTime_ = 0

local vg_ = nil
local state_ = nil
local screenW_ = 0
local screenH_ = 0

function Effects.Reset()
    attackEffects_ = {}
    mergeEffects_ = {}
    effectTime_ = 0
end

function Effects.Update(timeStep)
    effectTime_ = effectTime_ + timeStep
end

function Effects.TriggerMerge(category, idx, quality)
    table.insert(mergeEffects_, {
        category = category,
        idx = idx,
        quality = quality,
        startTime = effectTime_,
        duration = 0.8,
    })
end

local function HasFieldTarget(state, targetType, col, row)
    if targetType == "monster" then
        for _, monster in ipairs(state.monsters or {}) do
            if monster.col == col and monster.row == row and monster.hp > 0 then
                return true
            end
        end
    elseif targetType == "fieldReward" then
        for _, fieldReward in ipairs(state.fieldRewards or {}) do
            if fieldReward.col == col and fieldReward.row == row and fieldReward.hp > 0 then
                return true
            end
        end
    end
    return false
end

function Effects.TriggerAttack(state)
    for _, ev in ipairs(state.lastAttackEvents or {}) do
        local targetRow = ev.target and ev.target.row or ev.targetRow
        if HasFieldTarget(state, ev.targetType, ev.col, targetRow) then
            table.insert(attackEffects_, {
                kind = "player",
                col = ev.col,
                slotIdx = ev.slotIdx,
                targetRow = targetRow,
                targetType = ev.targetType,
                startTime = effectTime_,
                duration = 0.45,
            })
        end
    end

    for _, ev in ipairs(state.lastMonsterAttackEvents or {}) do
        if not ev.removedAfterAttack then
            table.insert(attackEffects_, {
                kind = "monster",
                col = ev.col,
                row = ev.row,
                startTime = effectTime_,
                duration = 0.5,
            })
        end
    end
end

local function Clamp01(value)
    return math.min(1.0, math.max(0.0, value or 0))
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function GetBoardMetrics()
    if screenW_ <= 0 or screenH_ <= 0 then return nil end
    return BoardLayout.CalcMetrics(screenW_, screenH_)
end

local function DesignRectPoint(board, rect)
    return board.originX + (rect.x + rect.w * 0.5) * board.scale,
        board.originY + (rect.y + rect.h * 0.5) * board.scale,
        rect.w * board.scale,
        rect.h * board.scale
end

local function DeployItemPoint(board, slotIdx)
    if not slotIdx or slotIdx < 1 or slotIdx > Config.TOTAL_SLOTS then return nil end
    local row = math.ceil(slotIdx / Config.GRID_COLS)
    local col = ((slotIdx - 1) % Config.GRID_COLS) + 1
    local cell = BoardLayout.CellRect(board, row, col, true)
    return cell.x + cell.w * 0.5,
        cell.y + cell.h * 0.5,
        cell.w,
        cell.h
end

local function StoragePoint(board)
    return DesignRectPoint(board, { x = 430, y = 2065, w = 220, h = 132 })
end

local function FieldTargetPoint(board, col, row)
    row = math.min(Config.FIELD_ROWS, math.max(1, row or 1))
    local cell = BoardLayout.CellRect(board, row, col, false)
    return cell.x + cell.w * 0.5,
        cell.y + cell.h * 0.55,
        cell.w,
        cell.h
end

local function DrawMergeEffects()
    local board = GetBoardMetrics()
    if not board then return end

    local remaining = {}
    local qColorR = {200, 100, 80, 180, 230, 255, 180, 200, 255}
    local qColorG = {200, 210, 160, 100, 70, 200, 140, 130, 160}
    local qColorB = {200, 120, 255, 255, 60, 50, 40, 255, 200}

    for _, eff in ipairs(mergeEffects_) do
        local elapsed = effectTime_ - eff.startTime
        local progress = elapsed / eff.duration

        if progress < 1.0 then
            table.insert(remaining, eff)
            progress = Clamp01(progress)

            local cx, cy, slotW
            if eff.category == "deploy" then
                cx, cy, slotW = DeployItemPoint(board, eff.idx)
            elseif eff.category == "storage" then
                cx, cy, slotW = StoragePoint(board)
            end

            if cx and cy and slotW then
                local q = math.min(9, math.max(1, eff.quality or 1))
                local cr = qColorR[q]
                local cg = qColorG[q]
                local cb = qColorB[q]

                local ringRadius = slotW * 0.3 + slotW * 0.8 * progress
                local ringAlpha = math.floor(220 * (1.0 - progress))
                nvgBeginPath(vg_)
                nvgCircle(vg_, cx, cy, ringRadius)
                nvgStrokeColor(vg_, nvgRGBA(cr, cg, cb, ringAlpha))
                nvgStrokeWidth(vg_, 3 * (1.0 - progress * 0.5))
                nvgStroke(vg_)

                local glowR = ringRadius * 1.3
                local glowPaint = nvgRadialGradient(vg_, cx, cy, ringRadius * 0.5, glowR,
                    nvgRGBA(cr, cg, cb, math.floor(60 * (1.0 - progress))),
                    nvgRGBA(cr, cg, cb, 0))
                nvgBeginPath(vg_)
                nvgCircle(vg_, cx, cy, glowR)
                nvgFillPaint(vg_, glowPaint)
                nvgFill(vg_)

                local particleCount = 4 + q * 2
                for particle = 1, particleCount do
                    local angle = (particle / particleCount) * math.pi * 2 + effectTime_ * 2
                    local dist = slotW * 0.2 + slotW * progress * 0.8
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pAlpha = math.floor(200 * (1.0 - progress * progress))
                    local pSize = (2 + q * 0.3) * (1.0 - progress * 0.7)
                    nvgBeginPath(vg_)
                    nvgCircle(vg_, px, py, pSize)
                    nvgFillColor(vg_, nvgRGBA(cr, cg, cb, pAlpha))
                    nvgFill(vg_)
                end
            end
        end
    end
    mergeEffects_ = remaining
end

local function DrawVectorProjectile(sx, sy, ex, ey, progress, color, thickness)
    local t = Clamp01(progress)
    local dx = ex - sx
    local dy = ey - sy
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0.001 then return end

    local ux = dx / len
    local uy = dy / len
    local nx = -uy
    local ny = ux
    local headX = Lerp(sx, ex, t)
    local headY = Lerp(sy, ey, t)
    local tailX = sx
    local tailY = sy
    local r, g, b = color[1], color[2], color[3]
    local alpha = math.floor(235 * (1.0 - t * 0.18))
    local halfTail = thickness * 0.48
    local halfHead = thickness * 1.05

    nvgBeginPath(vg_)
    nvgMoveTo(vg_, tailX, tailY)
    nvgLineTo(vg_, headX, headY)
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, math.floor(alpha * 0.23)))
    nvgStrokeWidth(vg_, thickness * 4.2)
    nvgStroke(vg_)

    nvgBeginPath(vg_)
    nvgMoveTo(vg_, tailX + nx * halfTail, tailY + ny * halfTail)
    nvgLineTo(vg_, headX + nx * halfHead, headY + ny * halfHead)
    nvgLineTo(vg_, headX - nx * halfHead, headY - ny * halfHead)
    nvgLineTo(vg_, tailX - nx * halfTail, tailY - ny * halfTail)
    nvgClosePath(vg_)
    nvgFillColor(vg_, nvgRGBA(r, g, b, math.floor(alpha * 0.62)))
    nvgFill(vg_)

    nvgBeginPath(vg_)
    nvgMoveTo(vg_, tailX, tailY)
    nvgLineTo(vg_, headX, headY)
    nvgStrokeColor(vg_, nvgRGBA(255, 255, 255, math.floor(alpha * 0.95)))
    nvgStrokeWidth(vg_, math.max(2.0, thickness * 0.55))
    nvgStroke(vg_)

    local arrowLen = math.min(24, len * 0.12)
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, headX + ux * arrowLen * 0.55, headY + uy * arrowLen * 0.55)
    nvgLineTo(vg_, headX - ux * arrowLen + nx * thickness * 1.9, headY - uy * arrowLen + ny * thickness * 1.9)
    nvgLineTo(vg_, headX - ux * arrowLen - nx * thickness * 1.9, headY - uy * arrowLen - ny * thickness * 1.9)
    nvgClosePath(vg_)
    nvgFillColor(vg_, nvgRGBA(255, 255, 255, alpha))
    nvgFill(vg_)

    local headGlow = nvgRadialGradient(vg_, headX, headY, 1, thickness * 5.5,
        nvgRGBA(r, g, b, math.floor(alpha * 0.50)),
        nvgRGBA(r, g, b, 0))
    nvgBeginPath(vg_)
    nvgCircle(vg_, headX, headY, thickness * 5.5)
    nvgFillPaint(vg_, headGlow)
    nvgFill(vg_)
end

local function DrawCastPulse(cx, cy, radius, progress, color)
    local t = Clamp01(progress)
    local r, g, b = color[1], color[2], color[3]
    local alpha = math.floor(160 * (1.0 - t))
    if alpha <= 0 then return end

    nvgBeginPath(vg_)
    nvgCircle(vg_, cx, cy, radius * (0.25 + t * 0.35))
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, alpha))
    nvgStrokeWidth(vg_, math.max(1.5, radius * 0.035))
    nvgStroke(vg_)
end

local function DrawAttackWaveEffects()
    local remaining = {}
    local board = GetBoardMetrics()
    if not board then return end

    local firstCell = BoardLayout.CellRect(board, 1, 1, false)
    local lastCell = BoardLayout.CellRect(board, Config.FIELD_ROWS, Config.GRID_COLS, false)
    local fieldBottom = lastCell.y + lastCell.h

    for _, eff in ipairs(attackEffects_) do
        local elapsed = effectTime_ - eff.startTime
        local progress = elapsed / eff.duration

        if progress < 1.0 then
            table.insert(remaining, eff)
            progress = Clamp01(progress)

            if eff.kind == "monster" then
                local sx, sy = FieldTargetPoint(board, eff.col, eff.row)
                DrawVectorProjectile(sx, sy, sx, fieldBottom + firstCell.h * 0.12, progress, {255, 90, 180}, math.max(4, firstCell.w * 0.06))
            else
                local sx, sy, slotW = DeployItemPoint(board, eff.slotIdx)
                if sx and sy then
                    local ex, ey
                    if eff.targetType == "none" then
                        ex, ey = FieldTargetPoint(board, eff.col, 1)
                    else
                        ex, ey = FieldTargetPoint(board, eff.col, eff.targetRow)
                    end
                    local thickness = math.max(4, slotW * 0.055)
                    DrawCastPulse(sx, sy, slotW * 0.48, progress, {90, 220, 255})
                    DrawVectorProjectile(sx, sy, ex, ey, progress, {90, 220, 255}, thickness)
                end
            end
        end
    end
    attackEffects_ = remaining
end

function Effects.Render(vg, state, screenW, screenH)
    vg_ = vg
    state_ = state
    screenW_ = screenW
    screenH_ = screenH

    DrawMergeEffects()
    DrawAttackWaveEffects()
end

return Effects
