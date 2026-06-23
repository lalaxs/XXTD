-- VectorIcons.lua
-- 仙侠合成塔防 - NanoVG 纯矢量图标绘制模块
-- 所有图标使用 NanoVG 路径绘制，无外部图片、无 emoji

local Config = require("Config")

local VectorIcons = {}

-- ============================================================================
-- 工具函数
-- ============================================================================
local function QualityColor(quality)
    local c = Config.QUALITY[quality]
    if c then return c.color[1], c.color[2], c.color[3], c.color[4] end
    return 200, 200, 200, 255
end

-- ============================================================================
-- 道具图标
-- ============================================================================

--- 绘制宝剑（攻击类）
function VectorIcons.DrawSword(vg, cx, cy, size, quality)
    local r, g, b = QualityColor(quality)
    local s = size * 0.4

    -- 剑身
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.2)          -- 剑尖
    nvgLineTo(vg, cx + s * 0.2, cy - s * 0.3) -- 右刃
    nvgLineTo(vg, cx + s * 0.15, cy + s * 0.2) -- 右身
    nvgLineTo(vg, cx - s * 0.15, cy + s * 0.2) -- 左身
    nvgLineTo(vg, cx - s * 0.2, cy - s * 0.3) -- 左刃
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(220, 230, 245, 255))
    nvgFill(vg)
    -- 剑刃高光
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.1)
    nvgLineTo(vg, cx + s * 0.06, cy - s * 0.3)
    nvgLineTo(vg, cx + s * 0.04, cy + s * 0.15)
    nvgLineTo(vg, cx - s * 0.04, cy + s * 0.15)
    nvgLineTo(vg, cx - s * 0.06, cy - s * 0.3)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 120))
    nvgFill(vg)

    -- 护手
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.45, cy + s * 0.2, s * 0.9, s * 0.18, 2)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgFill(vg)

    -- 剑柄
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.08, cy + s * 0.38, s * 0.16, s * 0.55, 2)
    nvgFillColor(vg, nvgRGBA(100, 70, 40, 255))
    nvgFill(vg)
    -- 缠绕纹
    for i = 0, 2 do
        local ly = cy + s * 0.45 + i * s * 0.15
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - s * 0.07, ly)
        nvgLineTo(vg, cx + s * 0.07, ly + s * 0.06)
        nvgStrokeColor(vg, nvgRGBA(r, g, b, 180))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
    end

    -- 剑首（圆球）
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy + s * 0.98, s * 0.1)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgFill(vg)
end

--- 绘制盾牌（防御类）
function VectorIcons.DrawShield(vg, cx, cy, size, quality)
    local r, g, b = QualityColor(quality)
    local s = size * 0.4

    -- 盾牌主体（倒三角圆润形）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + s * 1.1)            -- 底尖
    nvgBezierTo(vg, cx - s * 0.3, cy + s * 0.6,
        cx - s * 0.8, cy - s * 0.1,
        cx - s * 0.7, cy - s * 0.7)             -- 左弧
    nvgLineTo(vg, cx - s * 0.5, cy - s * 0.95)  -- 左上
    nvgLineTo(vg, cx, cy - s * 0.8)              -- 顶中
    nvgLineTo(vg, cx + s * 0.5, cy - s * 0.95)  -- 右上
    nvgLineTo(vg, cx + s * 0.7, cy - s * 0.7)   -- 右弧起点
    nvgBezierTo(vg, cx + s * 0.8, cy - s * 0.1,
        cx + s * 0.3, cy + s * 0.6,
        cx, cy + s * 1.1)                        -- 右弧回底
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(r, g, b, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(math.min(255, r + 40), math.min(255, g + 40), math.min(255, b + 40), 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 盾面十字纹
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 0.6)
    nvgLineTo(vg, cx, cy + s * 0.6)
    nvgMoveTo(vg, cx - s * 0.4, cy - s * 0.1)
    nvgLineTo(vg, cx + s * 0.4, cy - s * 0.1)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 100))
    nvgStrokeWidth(vg, 2.5)
    nvgStroke(vg)

    -- 中心宝石
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 0.1, s * 0.15)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)
end

--- 绘制丹药（回血类）
function VectorIcons.DrawPill(vg, cx, cy, size, quality)
    local r, g, b = QualityColor(quality)
    local s = size * 0.35

    -- 丹炉/丹药容器轮廓
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, s * 0.85)
    nvgFillColor(vg, nvgRGBA(r, g, b, 180))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(math.min(255, r + 60), math.min(255, g + 60), math.min(255, b + 60), 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 丹药内部光晕
    local innerPaint = nvgRadialGradient(vg, cx - s * 0.2, cy - s * 0.2, 0, s * 0.6,
        nvgRGBA(255, 255, 255, 120),
        nvgRGBA(r, g, b, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, s * 0.7)
    nvgFillPaint(vg, innerPaint)
    nvgFill(vg)

    -- 太极纹（丹药标志）
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy, s * 0.45, 0, math.pi, 1)  -- 上半弧
    nvgArc(vg, cx + s * 0.225, cy, s * 0.225, math.pi, 0, 1) -- 右小弧
    nvgArc(vg, cx - s * 0.225, cy, s * 0.225, 0, math.pi, 1) -- 左小弧
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 80))
    nvgFill(vg)

    -- 飘散灵气点
    for i = 1, 3 do
        local angle = i * 2.09 -- 120度间隔
        local px = cx + math.cos(angle) * s * 0.5
        local py = cy + math.sin(angle) * s * 0.5
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, s * 0.08)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 160))
        nvgFill(vg)
    end
end

--- 绘制符箓（AOE类）
function VectorIcons.DrawTalisman(vg, cx, cy, size, quality)
    local r, g, b = QualityColor(quality)
    local s = size * 0.38

    -- 符纸主体（长方形微斜）
    nvgSave(vg)
    nvgTranslate(vg, cx, cy)
    nvgRotate(vg, -0.1) -- 微微倾斜

    -- 符纸底色
    nvgBeginPath(vg)
    nvgRoundedRect(vg, -s * 0.5, -s * 0.9, s * 1.0, s * 1.8, 3)
    nvgFillColor(vg, nvgRGBA(245, 230, 180, 240))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(r, g, b, 220))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 符文（中央大字笔画）
    nvgStrokeColor(vg, nvgRGBA(r, g, b, 255))
    nvgStrokeWidth(vg, 2.5)
    -- 横笔
    nvgBeginPath(vg)
    nvgMoveTo(vg, -s * 0.3, -s * 0.4)
    nvgLineTo(vg, s * 0.3, -s * 0.4)
    nvgStroke(vg)
    -- 竖笔
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, -s * 0.6)
    nvgLineTo(vg, 0, s * 0.3)
    nvgStroke(vg)
    -- 撇
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, -s * 0.2)
    nvgLineTo(vg, -s * 0.25, s * 0.4)
    nvgStroke(vg)
    -- 捺
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, -s * 0.2)
    nvgLineTo(vg, s * 0.25, s * 0.4)
    nvgStroke(vg)

    -- 边角装饰小点
    nvgFillColor(vg, nvgRGBA(r, g, b, 200))
    for _, pos in ipairs({{-s*0.35, -s*0.7}, {s*0.35, -s*0.7}, {-s*0.35, s*0.7}, {s*0.35, s*0.7}}) do
        nvgBeginPath(vg)
        nvgCircle(vg, pos[1], pos[2], s * 0.06)
        nvgFill(vg)
    end

    nvgRestore(vg)
end

-- ============================================================================
-- 怪物图标
-- ============================================================================

--- 绘制近战怪物（妖兽形态）
function VectorIcons.DrawMeleeMonster(vg, cx, cy, size, quality)
    local s = size * 0.38
    -- 根据品质决定颜色深浅
    local intensity = math.min(1.0, 0.5 + quality * 0.06)
    local baseR = math.floor(200 * intensity)
    local baseG = math.floor(60 * intensity)
    local baseB = math.floor(50 * intensity)

    -- 身体（圆形主体）
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy + s * 0.1, s * 0.75)
    nvgFillColor(vg, nvgRGBA(baseR, baseG, baseB, 230))
    nvgFill(vg)

    -- 角（左右两只）
    nvgStrokeWidth(vg, 3)
    nvgStrokeColor(vg, nvgRGBA(80, 50, 30, 255))
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.4, cy - s * 0.3)
    nvgLineTo(vg, cx - s * 0.6, cy - s * 0.9)
    nvgLineTo(vg, cx - s * 0.3, cy - s * 0.6)
    nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.4, cy - s * 0.3)
    nvgLineTo(vg, cx + s * 0.6, cy - s * 0.9)
    nvgLineTo(vg, cx + s * 0.3, cy - s * 0.6)
    nvgStroke(vg)

    -- 眼睛（两只红色发光眼）
    nvgBeginPath(vg)
    nvgCircle(vg, cx - s * 0.22, cy - s * 0.05, s * 0.12)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgCircle(vg, cx + s * 0.22, cy - s * 0.05, s * 0.12)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgFill(vg)
    -- 瞳孔
    nvgBeginPath(vg)
    nvgCircle(vg, cx - s * 0.22, cy - s * 0.05, s * 0.05)
    nvgFillColor(vg, nvgRGBA(20, 10, 5, 255))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgCircle(vg, cx + s * 0.22, cy - s * 0.05, s * 0.05)
    nvgFillColor(vg, nvgRGBA(20, 10, 5, 255))
    nvgFill(vg)

    -- 嘴巴（獠牙）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.25, cy + s * 0.25)
    nvgLineTo(vg, cx - s * 0.1, cy + s * 0.5)
    nvgLineTo(vg, cx, cy + s * 0.3)
    nvgLineTo(vg, cx + s * 0.1, cy + s * 0.5)
    nvgLineTo(vg, cx + s * 0.25, cy + s * 0.25)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)
end

--- 绘制远程怪物（法师/邪修形态）
function VectorIcons.DrawRangedMonster(vg, cx, cy, size, quality)
    local s = size * 0.38
    local intensity = math.min(1.0, 0.5 + quality * 0.06)
    local baseR = math.floor(80 * intensity)
    local baseG = math.floor(50 * intensity)
    local baseB = math.floor(180 * intensity)

    -- 斗篷/身体（三角形斗篷）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 0.9)            -- 头顶
    nvgLineTo(vg, cx + s * 0.7, cy + s * 0.8)   -- 右下
    nvgLineTo(vg, cx - s * 0.7, cy + s * 0.8)   -- 左下
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(baseR, baseG, baseB, 220))
    nvgFill(vg)

    -- 斗篷边框
    nvgStrokeColor(vg, nvgRGBA(math.min(255, baseR + 60), math.min(255, baseG + 40), math.min(255, baseB + 40), 200))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 中间法球/眼睛（发光圆）
    local eyeGlow = nvgRadialGradient(vg, cx, cy, 0, s * 0.3,
        nvgRGBA(200, 150, 255, 255),
        nvgRGBA(baseR, baseG, baseB, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, s * 0.3)
    nvgFillPaint(vg, eyeGlow)
    nvgFill(vg)

    -- 中心瞳孔
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, s * 0.12)
    nvgFillColor(vg, nvgRGBA(255, 200, 255, 255))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, s * 0.05)
    nvgFillColor(vg, nvgRGBA(40, 10, 60, 255))
    nvgFill(vg)

    -- 灵气线条
    nvgStrokeColor(vg, nvgRGBA(180, 120, 255, 150))
    nvgStrokeWidth(vg, 1.2)
    for i = 1, 3 do
        local angle = i * 2.09 - 1.0
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + math.cos(angle) * s * 0.35, cy + math.sin(angle) * s * 0.35)
        nvgLineTo(vg, cx + math.cos(angle) * s * 0.65, cy + math.sin(angle) * s * 0.65)
        nvgStroke(vg)
    end
end

-- ============================================================================
-- 宝箱图标
-- ============================================================================

function VectorIcons.DrawChest(vg, cx, cy, size, quality)
    local r, g, b = QualityColor(quality)
    local s = size * 0.35

    -- 箱体（下半部分）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.65, cy - s * 0.1, s * 1.3, s * 0.8, 4)
    nvgFillColor(vg, nvgRGBA(120, 80, 40, 250))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 50, 25, 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 箱盖（上半部分，弧形）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.65, cy - s * 0.1)
    nvgLineTo(vg, cx - s * 0.65, cy - s * 0.4)
    nvgBezierTo(vg, cx - s * 0.6, cy - s * 0.7, cx + s * 0.6, cy - s * 0.7, cx + s * 0.65, cy - s * 0.4)
    nvgLineTo(vg, cx + s * 0.65, cy - s * 0.1)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(150, 100, 50, 250))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 50, 25, 255))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 金属箍（横条）
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.65, cy - s * 0.15, s * 1.3, s * 0.12)
    nvgFillColor(vg, nvgRGBA(r, g, b, 200))
    nvgFill(vg)

    -- 锁扣
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.12, cy - s * 0.3, s * 0.24, s * 0.3, 3)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(math.min(255, r + 50), math.min(255, g + 50), math.min(255, b + 50), 255))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
end

-- ============================================================================
-- 高层调度接口
-- ============================================================================

--- 根据道具类型绘制对应图标
function VectorIcons.DrawItem(vg, cx, cy, size, itemType, quality)
    if itemType == Config.ITEM_TYPE.ATTACK then
        VectorIcons.DrawSword(vg, cx, cy, size, quality)
    elseif itemType == Config.ITEM_TYPE.DEFENSE then
        VectorIcons.DrawShield(vg, cx, cy, size, quality)
    elseif itemType == Config.ITEM_TYPE.PILL then
        VectorIcons.DrawPill(vg, cx, cy, size, quality)
    elseif itemType == Config.ITEM_TYPE.TALISMAN then
        VectorIcons.DrawTalisman(vg, cx, cy, size, quality)
    end
end

--- 根据怪物类型绘制对应图标
function VectorIcons.DrawMonster(vg, cx, cy, size, monsterType, quality)
    if monsterType == Config.MONSTER_TYPE.MELEE then
        VectorIcons.DrawMeleeMonster(vg, cx, cy, size, quality)
    else
        VectorIcons.DrawRangedMonster(vg, cx, cy, size, quality)
    end
end

return VectorIcons
