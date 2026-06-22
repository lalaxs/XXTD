local Config = require("Config")
local STYLE = require("Theme")

local Effects = {}

local attackEffects_ = {}
local mergeEffects_ = {}
local effectTime_ = 0
local slotLayouts_ = {}

local vg_ = nil
local state_ = nil
local fieldPanel_ = nil
local deploySlots_ = nil
local storageSlots_ = nil

function Effects.Reset()
    attackEffects_ = {}
    mergeEffects_ = {}
    slotLayouts_ = {}
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

function Effects.TriggerAttack(state)
    for _, ev in ipairs(state.lastAttackEvents or {}) do
        table.insert(attackEffects_, {
            kind = "player",
            col = ev.col,
            slotIdx = ev.slotIdx,
            targetRow = ev.targetRow,
            targetType = ev.targetType,
            startTime = effectTime_,
            duration = 0.45,
        })
    end

    for _, ev in ipairs(state.lastMonsterAttackEvents or {}) do
        table.insert(attackEffects_, {
            kind = "monster",
            col = ev.col,
            row = ev.row,
            startTime = effectTime_,
            duration = 0.5,
        })
    end
end

-- ============================================================================
-- 怪物行进区棋盘格子
-- ============================================================================
local function DrawFieldGrid()
    if not fieldPanel_ then return end
    local layout = fieldPanel_:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    -- 棋盘区域限定在行进区面板内
    local padX = 6
    local padY = 3
    local gridW = layout.w - padX * 2
    local gridH = layout.h - padY * 2
    local ox = layout.x + padX
    local oy = layout.y + padY
    local cellW = gridW / Config.GRID_COLS
    local cellH = gridH / Config.FIELD_ROWS

    -- 棋盘外框（圆角边界线）
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, ox, oy, gridW, gridH, 8)
    nvgStrokeColor(vg_, nvgRGBA(100, 140, 160, 50))
    nvgStrokeWidth(vg_, 1.5)
    nvgStroke(vg_)

    -- 交替色方格（极淡蓝灰，不是绿色）
    for row = 0, Config.FIELD_ROWS - 1 do
        for col = 0, Config.GRID_COLS - 1 do
            local isLight = (row + col) % 2 == 0
            local x = ox + col * cellW
            local y = oy + row * cellH
            nvgBeginPath(vg_)
            nvgRect(vg_, x, y, cellW, cellH)
            if isLight then
                nvgFillColor(vg_, nvgRGBA(180, 210, 230, 20))
            else
                nvgFillColor(vg_, nvgRGBA(160, 190, 210, 15))
            end
            nvgFill(vg_)
        end
    end

    -- 网格线（素雅淡蓝灰色细线）
    nvgStrokeWidth(vg_, 0.8)
    nvgStrokeColor(vg_, nvgRGBA(120, 150, 170, 35))

    for col = 1, Config.GRID_COLS - 1 do
        local x = ox + col * cellW
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, x, oy)
        nvgLineTo(vg_, x, oy + gridH)
        nvgStroke(vg_)
    end
    for row = 1, Config.FIELD_ROWS - 1 do
        local y = oy + row * cellH
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, ox, y)
        nvgLineTo(vg_, ox + gridW, y)
        nvgStroke(vg_)
    end

    -- 格子交叉点小十字标记（仙侠风细节）
    for row = 1, Config.FIELD_ROWS - 1 do
        for col = 1, Config.GRID_COLS - 1 do
            local cx = ox + col * cellW
            local cy = oy + row * cellH
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, cx - 3, cy)
            nvgLineTo(vg_, cx + 3, cy)
            nvgMoveTo(vg_, cx, cy - 3)
            nvgLineTo(vg_, cx, cy + 3)
            nvgStrokeColor(vg_, nvgRGBA(130, 160, 180, 50))
            nvgStrokeWidth(vg_, 1.2)
            nvgStroke(vg_)
        end
    end
end

-- ============================================================================
-- 合成特效
-- ============================================================================
local function DrawMergeEffects()
    local remaining = {}
    -- 品质颜色映射
    local qColorR = {200, 100, 80, 180, 230, 255, 180, 200, 255}
    local qColorG = {200, 210, 160, 100, 70, 200, 140, 130, 160}
    local qColorB = {200, 120, 255, 255, 60, 50, 40, 255, 200}

    for _, eff in ipairs(mergeEffects_) do
        local elapsed = effectTime_ - eff.startTime
        local progress = elapsed / eff.duration

        if progress < 1.0 then
            table.insert(remaining, eff)

            -- 获取格子位置
            local slot = nil
            if eff.category == "deploy" then
                slot = deploySlots_[eff.idx]
            elseif eff.category == "storage" then
                slot = storageSlots_[1]
            end

            if slot then
                local sl = slot:GetAbsoluteLayout()
                if sl and sl.w > 0 then
                    local cx = sl.x + sl.w / 2
                    local cy = sl.y + sl.h / 2
                    local q = math.min(9, math.max(1, eff.quality))
                    local cr = qColorR[q]
                    local cg = qColorG[q]
                    local cb = qColorB[q]

                    -- 环形光浪扩散
                    local ringRadius = sl.w * 0.3 + sl.w * 0.8 * progress
                    local ringAlpha = math.floor(220 * (1.0 - progress))
                    nvgBeginPath(vg_)
                    nvgCircle(vg_, cx, cy, ringRadius)
                    nvgStrokeColor(vg_, nvgRGBA(cr, cg, cb, ringAlpha))
                    nvgStrokeWidth(vg_, 3 * (1.0 - progress * 0.5))
                    nvgStroke(vg_)

                    -- 外层柔和光晕
                    local glowR = ringRadius * 1.3
                    local glowPaint = nvgRadialGradient(vg_, cx, cy, ringRadius * 0.5, glowR,
                        nvgRGBA(cr, cg, cb, math.floor(60 * (1.0 - progress))),
                        nvgRGBA(cr, cg, cb, 0))
                    nvgBeginPath(vg_)
                    nvgCircle(vg_, cx, cy, glowR)
                    nvgFillPaint(vg_, glowPaint)
                    nvgFill(vg_)

                    -- 粒子爆发（品质越高粒子越多）
                    local particleCount = 4 + q * 2
                    for p = 1, particleCount do
                        local angle = (p / particleCount) * math.pi * 2 + effectTime_ * 2
                        local dist = sl.w * 0.2 + sl.w * progress * 0.8
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
    end
    mergeEffects_ = remaining
end

-- ============================================================================
-- 品质边框特效
-- ============================================================================
-- 缓存slot布局位置（避免拖拽期间布局失效）

local function CacheSlotLayouts()
    for i = 1, Config.TOTAL_SLOTS do
        local slot = deploySlots_[i]
        if slot then
            local layout = slot:GetAbsoluteLayout()
            if layout and layout.w > 0 then
                slotLayouts_[i] = {x = layout.x, y = layout.y, w = layout.w, h = layout.h}
            end
        end
    end
end

local DrawQualityGlow

local function DrawQualityBorderEffects()
    -- 每帧尝试更新缓存
    CacheSlotLayouts()

    for i = 1, Config.TOTAL_SLOTS do
        local item = state_.slots[i]
        if item and slotLayouts_[i] then
            local l = slotLayouts_[i]
            DrawQualityGlow(l.x, l.y, l.w, l.h, item.quality)
        end
    end
end

DrawQualityGlow = function(x, y, w, h, quality)
    local t = effectTime_
    local r = STYLE.SLOT_RADIUS

    if quality == 1 then
        -- 白色：纤细哑光微光边框，极简灵气
        local alpha = 80 + 30 * math.sin(t * 1.5)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 2, y - 2, w + 4, h + 4, r + 2)
        nvgStrokeColor(vg_, nvgRGBA(220, 220, 230, math.floor(alpha)))
        nvgStrokeWidth(vg_, 1.5)
        nvgStroke(vg_)

    elseif quality == 2 then
        -- 绿色：流动翠色薄雾光边，细碎青叶光点
        local alpha = 100 + 40 * math.sin(t * 2.0)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 3, y - 3, w + 6, h + 6, r + 3)
        nvgStrokeColor(vg_, nvgRGBA(80, 220, 100, math.floor(alpha)))
        nvgStrokeWidth(vg_, 2)
        nvgStroke(vg_)
        -- 光点
        for p = 1, 4 do
            local angle = t * 1.5 + p * 1.57
            local px = x + w / 2 + math.cos(angle) * (w / 2 + 4)
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 4)
            nvgBeginPath(vg_)
            nvgCircle(vg_, px, py, 2)
            nvgFillColor(vg_, nvgRGBA(120, 255, 140, math.floor(150 + 60 * math.sin(t * 3 + p))))
            nvgFill(vg_)
        end

    elseif quality == 3 then
        -- 蓝色：淡蓝星河流转光晕，漂浮星屑
        local alpha = 120 + 50 * math.sin(t * 1.8)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 3, y - 3, w + 6, h + 6, r + 3)
        nvgStrokeColor(vg_, nvgRGBA(80, 160, 255, math.floor(alpha)))
        nvgStrokeWidth(vg_, 2.5)
        nvgStroke(vg_)
        -- 外层柔和光晕
        local paint = nvgBoxGradient(vg_, x - 6, y - 6, w + 12, h + 12, r + 6, 10,
            nvgRGBA(80, 160, 255, math.floor(40 + 20 * math.sin(t * 2))),
            nvgRGBA(80, 160, 255, 0))
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 10, y - 10, w + 20, h + 20, r + 10)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        -- 星屑
        for p = 1, 6 do
            local angle = t * 1.2 + p * 1.05
            local dist = w / 2 + 6 + 3 * math.sin(t * 2 + p)
            local px = x + w / 2 + math.cos(angle) * dist
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 6 + 3 * math.sin(t + p))
            nvgBeginPath(vg_)
            nvgCircle(vg_, px, py, 1.5 + 0.5 * math.sin(t * 4 + p))
            nvgFillColor(vg_, nvgRGBA(180, 220, 255, math.floor(200 + 50 * math.sin(t * 3 + p * 2))))
            nvgFill(vg_)
        end

    elseif quality == 4 then
        -- 紫色：缠绕螺旋紫雾灵纹，持续流光
        local alpha = 140 + 50 * math.sin(t * 2.2)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 3, y - 3, w + 6, h + 6, r + 3)
        nvgStrokeColor(vg_, nvgRGBA(170, 80, 255, math.floor(alpha)))
        nvgStrokeWidth(vg_, 2.5)
        nvgStroke(vg_)
        -- 螺旋光点
        for p = 1, 8 do
            local angle = t * 2.0 + p * 0.785
            local dist = w / 2 + 5 + 4 * math.sin(t * 1.5 + p * 0.5)
            local px = x + w / 2 + math.cos(angle) * dist
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 5)
            local sz = 2 + math.sin(t * 3 + p)
            nvgBeginPath(vg_)
            nvgCircle(vg_, px, py, sz)
            nvgFillColor(vg_, nvgRGBA(200, 120, 255, math.floor(180 + 60 * math.sin(t * 2.5 + p))))
            nvgFill(vg_)
        end
        -- 外层紫雾
        local paint = nvgBoxGradient(vg_, x - 8, y - 8, w + 16, h + 16, r + 8, 12,
            nvgRGBA(150, 60, 220, math.floor(30 + 20 * math.sin(t * 1.5))),
            nvgRGBA(150, 60, 220, 0))
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 12, y - 12, w + 24, h + 24, r + 12)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)

    elseif quality == 5 then
        -- 红色：赤焰仙纹镶金边，浮动火灵粒子
        local alpha = 150 + 60 * math.sin(t * 2.5)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 3, y - 3, w + 6, h + 6, r + 3)
        nvgStrokeColor(vg_, nvgRGBA(230, 70, 50, math.floor(alpha)))
        nvgStrokeWidth(vg_, 2.5)
        nvgStroke(vg_)
        -- 火焰光晕
        local paint = nvgBoxGradient(vg_, x - 8, y - 8, w + 16, h + 16, r + 8, 12,
            nvgRGBA(255, 80, 30, math.floor(35 + 20 * math.sin(t * 2))),
            nvgRGBA(255, 50, 0, 0))
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 12, y - 12, w + 24, h + 24, r + 12)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        -- 火灵粒子
        for p = 1, 7 do
            local angle = t * 2.2 + p * 0.9
            local dist = w / 2 + 6 + 4 * math.sin(t * 1.8 + p)
            local px = x + w / 2 + math.cos(angle) * dist
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 6) - 3 * math.sin(t * 3 + p)
            local sz = 2 + math.sin(t * 4 + p)
            nvgBeginPath(vg_)
            nvgCircle(vg_, px, py, sz)
            nvgFillColor(vg_, nvgRGBA(255, 140, 40, math.floor(180 + 60 * math.sin(t * 3 + p))))
            nvgFill(vg_)
        end

    elseif quality == 6 then
        -- 金色：鎏金祥云环绕，缓动金色光带（原 quality 5 逻辑）
        local alpha = 160 + 60 * math.sin(t * 1.5)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 3, y - 3, w + 6, h + 6, r + 3)
        nvgStrokeColor(vg_, nvgRGBA(255, 200, 50, math.floor(alpha)))
        nvgStrokeWidth(vg_, 3)
        nvgStroke(vg_)
        local paint = nvgBoxGradient(vg_, x - 8, y - 8, w + 16, h + 16, r + 8, 14,
            nvgRGBA(255, 200, 50, math.floor(50 + 30 * math.sin(t * 1.2))),
            nvgRGBA(255, 180, 0, 0))
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 14, y - 14, w + 28, h + 28, r + 14)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        for p = 1, 10 do
            local angle = t * 0.8 + p * 0.628
            local dist = w / 2 + 8 + 5 * math.sin(t * 1.0 + p * 0.3)
            local px = x + w / 2 + math.cos(angle) * dist
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 8)
            local sz = 2.5 + 1.5 * math.sin(t * 2 + p)
            nvgBeginPath(vg_)
            nvgCircle(vg_, px, py, sz)
            nvgFillColor(vg_, nvgRGBA(255, 220, 80, math.floor(200 + 55 * math.sin(t * 2 + p))))
            nvgFill(vg_)
        end

    elseif quality == 7 then
        -- 暗金：深沉暗金太古纹路，微弱暗金色雷霆微光
        local alpha = 130 + 50 * math.sin(t * 2.5)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 3, y - 3, w + 6, h + 6, r + 3)
        nvgStrokeColor(vg_, nvgRGBA(180, 140, 40, math.floor(alpha)))
        nvgStrokeWidth(vg_, 3)
        nvgStroke(vg_)
        local paint = nvgBoxGradient(vg_, x - 6, y - 6, w + 12, h + 12, r + 6, 10,
            nvgRGBA(140, 100, 20, math.floor(40 + 25 * math.sin(t * 2))),
            nvgRGBA(100, 70, 10, 0))
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 10, y - 10, w + 20, h + 20, r + 10)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        -- 闪电微光
        for p = 1, 5 do
            local angle = t * 3.0 + p * 1.25
            local dist = w / 2 + 6
            local px = x + w / 2 + math.cos(angle) * dist
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 6)
            local flicker = math.sin(t * 8 + p * 7) > 0.7 and 1 or 0
            if flicker == 1 then
                nvgBeginPath(vg_)
                nvgMoveTo(vg_, px, py)
                nvgLineTo(vg_, px + math.cos(angle + 0.5) * 6, py + math.sin(angle + 0.5) * 6)
                nvgStrokeColor(vg_, nvgRGBA(220, 180, 60, 200))
                nvgStrokeWidth(vg_, 1.5)
                nvgStroke(vg_)
            end
        end

    elseif quality == 8 then
        -- 紫金：紫金交织星辰轨道，双层叠加光边
        local alpha1 = 140 + 50 * math.sin(t * 1.8)
        local alpha2 = 120 + 50 * math.sin(t * 2.2 + 1)
        -- 内层紫色
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 3, y - 3, w + 6, h + 6, r + 3)
        nvgStrokeColor(vg_, nvgRGBA(180, 100, 255, math.floor(alpha1)))
        nvgStrokeWidth(vg_, 2.5)
        nvgStroke(vg_)
        -- 外层金色
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 6, y - 6, w + 12, h + 12, r + 6)
        nvgStrokeColor(vg_, nvgRGBA(255, 200, 80, math.floor(alpha2)))
        nvgStrokeWidth(vg_, 1.5)
        nvgStroke(vg_)
        -- 紫金光晕
        local paint = nvgBoxGradient(vg_, x - 10, y - 10, w + 20, h + 20, r + 10, 14,
            nvgRGBA(180, 120, 255, math.floor(30 + 20 * math.sin(t * 1.5))),
            nvgRGBA(255, 200, 50, 0))
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 14, y - 14, w + 28, h + 28, r + 14)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        -- 星轨粒子
        for p = 1, 12 do
            local angle = t * 1.5 + p * 0.523
            local dist = w / 2 + 8 + 4 * math.sin(t * 1.2 + p * 0.4)
            local px = x + w / 2 + math.cos(angle) * dist
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 8)
            local isPurple = p % 2 == 0
            local cr = isPurple and 200 or 255
            local cg = isPurple and 120 or 210
            local cb = isPurple and 255 or 80
            nvgBeginPath(vg_)
            nvgCircle(vg_, px, py, 2 + math.sin(t * 3 + p))
            nvgFillColor(vg_, nvgRGBA(cr, cg, cb, math.floor(190 + 60 * math.sin(t * 2.5 + p))))
            nvgFill(vg_)
        end

    elseif quality == 9 then
        -- 粉霞：漫天粉霞花瓣、飘带、云雾环绕，大面积柔和霞光
        local alpha = 150 + 60 * math.sin(t * 1.2)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 4, y - 4, w + 8, h + 8, r + 4)
        nvgStrokeColor(vg_, nvgRGBA(255, 160, 200, math.floor(alpha)))
        nvgStrokeWidth(vg_, 3)
        nvgStroke(vg_)
        -- 大面积粉色霞光
        local paint = nvgBoxGradient(vg_, x - 12, y - 12, w + 24, h + 24, r + 12, 18,
            nvgRGBA(255, 150, 200, math.floor(45 + 25 * math.sin(t * 1.0))),
            nvgRGBA(255, 120, 180, 0))
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x - 18, y - 18, w + 36, h + 36, r + 18)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        -- 花瓣粒子（大量、柔和）
        for p = 1, 14 do
            local angle = t * 0.7 + p * 0.449
            local dist = w / 2 + 10 + 6 * math.sin(t * 0.8 + p * 0.5)
            local px = x + w / 2 + math.cos(angle) * dist
            local py = y + h / 2 + math.sin(angle) * (h / 2 + 10) - 2 * math.sin(t * 2 + p)
            local sz = 2.5 + 1.5 * math.sin(t * 1.5 + p * 0.7)
            nvgBeginPath(vg_)
            nvgCircle(vg_, px, py, sz)
            nvgFillColor(vg_, nvgRGBA(255, 180, 220, math.floor(180 + 60 * math.sin(t * 2 + p))))
            nvgFill(vg_)
        end
    end
end

-- ============================================================================
-- 攻击光波特效
-- ============================================================================
local function GetFieldMetrics()
    local fieldLayout = fieldPanel_ and fieldPanel_:GetAbsoluteLayout() or nil
    if not fieldLayout or fieldLayout.w <= 0 or fieldLayout.h <= 0 then return nil end
    return {
        x = fieldLayout.x,
        y = fieldLayout.y,
        w = fieldLayout.w,
        h = fieldLayout.h,
        cellW = fieldLayout.w / Config.GRID_COLS,
        cellH = fieldLayout.h / Config.FIELD_ROWS,
    }
end

local function FieldCellCenter(metrics, col, row)
    return metrics.x + (col - 0.5) * metrics.cellW,
        metrics.y + (row - 0.5) * metrics.cellH
end

local function DrawBeam(sx, sy, ex, ey, progress, color)
    local headX = sx + (ex - sx) * progress
    local headY = sy + (ey - sy) * progress
    local alpha = math.floor(230 * (1.0 - progress * 0.35))
    local dx = ex - sx
    local dy = ey - sy
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0.001 then return end
    local nx = -dy / len
    local ny = dx / len
    local trail = math.min(80, len * 0.35) * (1.0 - progress * 0.15)
    local tailProgress = math.max(0, progress - trail / len)
    local tailX = sx + (ex - sx) * tailProgress
    local tailY = sy + (ey - sy) * tailProgress
    local r, g, b = color[1], color[2], color[3]

    nvgBeginPath(vg_)
    nvgMoveTo(vg_, tailX + nx * 4, tailY + ny * 4)
    nvgLineTo(vg_, headX + nx * 7, headY + ny * 7)
    nvgLineTo(vg_, headX - nx * 7, headY - ny * 7)
    nvgLineTo(vg_, tailX - nx * 4, tailY - ny * 4)
    nvgClosePath(vg_)
    nvgFillColor(vg_, nvgRGBA(r, g, b, math.floor(alpha * 0.55)))
    nvgFill(vg_)

    nvgBeginPath(vg_)
    nvgMoveTo(vg_, tailX, tailY)
    nvgLineTo(vg_, headX, headY)
    nvgStrokeColor(vg_, nvgRGBA(255, 255, 255, alpha))
    nvgStrokeWidth(vg_, 3.5)
    nvgStroke(vg_)

    nvgBeginPath(vg_)
    nvgCircle(vg_, headX, headY, 5.5)
    nvgFillColor(vg_, nvgRGBA(255, 255, 255, alpha))
    nvgFill(vg_)

    local glowPaint = nvgRadialGradient(vg_, headX, headY, 1, 22,
        nvgRGBA(r, g, b, math.floor(alpha * 0.55)),
        nvgRGBA(r, g, b, 0))
    nvgBeginPath(vg_)
    nvgCircle(vg_, headX, headY, 22)
    nvgFillPaint(vg_, glowPaint)
    nvgFill(vg_)
end

local function DrawAttackWaveEffects(screenW, screenH)
    local remaining = {}
    local metrics = GetFieldMetrics()
    if not metrics then return end

    for _, eff in ipairs(attackEffects_) do
        local elapsed = effectTime_ - eff.startTime
        local progress = elapsed / eff.duration

        if progress < 1.0 then
            table.insert(remaining, eff)
            progress = math.min(1.0, math.max(0.0, progress))

            if eff.kind == "monster" then
                local sx, sy = FieldCellCenter(metrics, eff.col, eff.row)
                local ex = sx
                local ey = metrics.y + metrics.h + 18
                DrawBeam(sx, sy, ex, ey, progress, {255, 90, 180})
            else
                local slot = deploySlots_[eff.slotIdx]
                if slot then
                    local slotLayout = slot:GetAbsoluteLayout()
                    if slotLayout and slotLayout.w > 0 then
                        local sx = slotLayout.x + slotLayout.w / 2
                        local sy = slotLayout.y + slotLayout.h / 2
                        local ex, ey
                        if eff.targetType == "none" then
                            ex = metrics.x + (eff.col - 0.5) * metrics.cellW
                            ey = metrics.y + metrics.cellH * 0.5
                        else
                            ex, ey = FieldCellCenter(metrics, eff.col, eff.targetRow)
                        end

                        local weaponGlowAlpha = math.floor(150 * (1.0 - progress))
                        local weaponPaint = nvgRadialGradient(vg_, sx, sy, 2, slotLayout.w * 0.55,
                            nvgRGBA(120, 220, 255, weaponGlowAlpha),
                            nvgRGBA(120, 220, 255, 0))
                        nvgBeginPath(vg_)
                        nvgCircle(vg_, sx, sy, slotLayout.w * 0.55)
                        nvgFillPaint(vg_, weaponPaint)
                        nvgFill(vg_)

                        DrawBeam(sx, sy, ex, ey, progress, {90, 220, 255})
                    end
                end
            end
        end
    end
    attackEffects_ = remaining
end

function Effects.Render(vg, state, deploySlots, storageSlots, fieldPanel, screenW, screenH)
    vg_ = vg
    state_ = state
    deploySlots_ = deploySlots
    storageSlots_ = storageSlots
    fieldPanel_ = fieldPanel

    DrawQualityBorderEffects()
    DrawMergeEffects()
    DrawAttackWaveEffects(screenW, screenH)
end

return Effects
