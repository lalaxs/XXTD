local UI = require("urhox-libs/UI")
local Config = require("Config")
local BoardLayout = require("BoardLayout")

local FloatingTextView = {}
FloatingTextView.__index = FloatingTextView

local DEFAULT_MAX_ACTIVE = 48

local VARIANTS = {
    damage = {
        fontSize = 38,
        width = 180,
        height = 58,
        fontColor = {255, 92, 68, 255},
        strokeColor = {76, 22, 12, 255},
        shadowColor = {0, 0, 0, 160},
        duration = 0.88,
        rise = 92,
        jitter = 18,
        startScale = 0.78,
        popScale = 1.16,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
    crit = {
        fontSize = 48,
        width = 230,
        height = 72,
        fontColor = {255, 232, 91, 255},
        strokeColor = {126, 34, 10, 255},
        shadowColor = {0, 0, 0, 210},
        duration = 1.08,
        rise = 124,
        jitter = 34,
        startScale = 0.56,
        popScale = 1.38,
        endScale = 1.04,
        startRotate = -8,
        popRotate = 5,
        endRotate = -2,
        easing = "easeOutBack",
    },
    critTag = {
        fontSize = 34,
        width = 170,
        height = 54,
        fontColor = {255, 248, 178, 255},
        strokeColor = {166, 60, 51, 255},
        shadowColor = {0, 0, 0, 210},
        duration = 0.82,
        rise = 72,
        jitter = 16,
        startScale = 0.46,
        popScale = 1.28,
        endScale = 0.92,
        startRotate = 9,
        popRotate = -6,
        endRotate = 4,
        easing = "easeOutBack",
    },
    playerDamage = {
        fontSize = 42,
        width = 220,
        height = 66,
        fontColor = {255, 76, 76, 255},
        strokeColor = {82, 16, 16, 255},
        shadowColor = {0, 0, 0, 180},
        duration = 0.95,
        rise = 88,
        jitter = 12,
        startScale = 0.72,
        popScale = 1.22,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
    playerCrit = {
        fontSize = 46,
        width = 240,
        height = 70,
        fontColor = {255, 198, 86, 255},
        strokeColor = {112, 20, 20, 255},
        shadowColor = {0, 0, 0, 210},
        duration = 1.06,
        rise = 104,
        jitter = 22,
        startScale = 0.62,
        popScale = 1.30,
        endScale = 1.02,
        startRotate = 7,
        popRotate = -4,
        endRotate = 2,
        easing = "easeOutBack",
    },
    heal = {
        fontSize = 38,
        width = 220,
        height = 58,
        fontColor = {94, 230, 122, 255},
        strokeColor = {18, 70, 34, 255},
        shadowColor = {0, 0, 0, 150},
        duration = 0.95,
        rise = 82,
        jitter = 14,
        startScale = 0.75,
        popScale = 1.15,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
    shield = {
        fontSize = 34,
        width = 260,
        height = 56,
        fontColor = {122, 190, 255, 255},
        strokeColor = {18, 44, 82, 255},
        shadowColor = {0, 0, 0, 150},
        duration = 1.0,
        rise = 76,
        jitter = 12,
        startScale = 0.78,
        popScale = 1.12,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
    statusBuff = {
        fontSize = 30,
        width = 300,
        height = 54,
        fontColor = {107, 220, 150, 255},
        strokeColor = {18, 70, 38, 255},
        shadowColor = {0, 0, 0, 145},
        duration = 1.05,
        rise = 68,
        jitter = 8,
        startScale = 0.82,
        popScale = 1.10,
        endScale = 0.96,
        easing = "easeOutCubic",
    },
    statusDebuff = {
        fontSize = 30,
        width = 320,
        height = 54,
        fontColor = {166, 60, 51, 255},
        strokeColor = {58, 22, 18, 255},
        shadowColor = {0, 0, 0, 150},
        duration = 1.08,
        rise = 70,
        jitter = 10,
        startScale = 0.80,
        popScale = 1.12,
        endScale = 0.96,
        easing = "easeOutCubic",
    },
    statusControl = {
        fontSize = 30,
        width = 320,
        height = 54,
        fontColor = {122, 190, 255, 255},
        strokeColor = {18, 44, 82, 255},
        shadowColor = {0, 0, 0, 150},
        duration = 1.08,
        rise = 70,
        jitter = 10,
        startScale = 0.80,
        popScale = 1.12,
        endScale = 0.96,
        easing = "easeOutCubic",
    },
    exp = {
        fontSize = 34,
        width = 260,
        height = 56,
        fontColor = {202, 150, 255, 255},
        strokeColor = {58, 28, 88, 255},
        shadowColor = {0, 0, 0, 150},
        duration = 1.05,
        rise = 86,
        jitter = 12,
        startScale = 0.74,
        popScale = 1.14,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
    reward = {
        fontSize = 30,
        width = 760,
        height = 64,
        fontColor = {255, 218, 110, 255},
        strokeColor = {74, 45, 14, 255},
        shadowColor = {0, 0, 0, 170},
        duration = 1.35,
        rise = 104,
        jitter = 0,
        startScale = 0.78,
        popScale = 1.12,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
    breakthrough = {
        fontSize = 54,
        width = 820,
        height = 100,
        fontColor = {255, 224, 124, 255},
        strokeColor = {92, 48, 12, 255},
        shadowColor = {0, 0, 0, 200},
        duration = 1.75,
        rise = 128,
        jitter = 0,
        startScale = 0.52,
        popScale = 1.28,
        endScale = 1.04,
        easing = "easeOutBack",
    },
    merge = {
        fontSize = 34,
        width = 300,
        height = 58,
        fontColor = {255, 214, 76, 255},
        strokeColor = {64, 36, 12, 255},
        shadowColor = {0, 0, 0, 165},
        duration = 1.0,
        rise = 90,
        jitter = 10,
        startScale = 0.7,
        popScale = 1.22,
        endScale = 1.0,
        easing = "easeOutBack",
    },
    warning = {
        fontSize = 32,
        width = 520,
        height = 58,
        fontColor = {255, 165, 88, 255},
        strokeColor = {80, 38, 12, 255},
        shadowColor = {0, 0, 0, 155},
        duration = 1.15,
        rise = 78,
        jitter = 0,
        startScale = 0.78,
        popScale = 1.12,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
    info = {
        fontSize = 30,
        width = 540,
        height = 56,
        fontColor = {245, 234, 210, 255},
        strokeColor = {42, 32, 22, 255},
        shadowColor = {0, 0, 0, 150},
        duration = 1.1,
        rise = 76,
        jitter = 0,
        startScale = 0.78,
        popScale = 1.1,
        endScale = 1.0,
        easing = "easeOutCubic",
    },
}

local function CopyTable(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = CopyTable(v)
    end
    return copy
end

local function CopyOptions(options)
    local copy = {}
    if options then
        for k, v in pairs(options) do
            copy[k] = v
        end
    end
    return copy
end

local function Clamp(value, minValue, maxValue)
    return math.min(maxValue, math.max(minValue, value))
end

local function Round(value)
    return math.floor(value + 0.5)
end

local function FormatInteger(value)
    local n = tonumber(value) or 0
    return tostring(math.floor(n + 0.5))
end

local function QualityColor(quality)
    local q = Config.QUALITY[quality or 1]
    if q and q.color then
        return q.color
    end
    return {255, 214, 76, 255}
end

local function ResolveStyle(variant, options)
    local style = CopyTable(VARIANTS[variant or "info"] or VARIANTS.info)
    if options.fontSize then style.fontSize = options.fontSize end
    if options.width then style.width = options.width end
    if options.height then style.height = options.height end
    if options.fontColor then style.fontColor = options.fontColor end
    if options.strokeColor then style.strokeColor = options.strokeColor end
    if options.shadowColor then style.shadowColor = options.shadowColor end
    if options.duration then style.duration = options.duration end
    if options.rise then style.rise = options.rise end
    if options.jitter ~= nil then style.jitter = options.jitter end
    if options.startScale then style.startScale = options.startScale end
    if options.popScale then style.popScale = options.popScale end
    if options.endScale then style.endScale = options.endScale end
    if options.startRotate then style.startRotate = options.startRotate end
    if options.popRotate then style.popRotate = options.popRotate end
    if options.endRotate then style.endRotate = options.endRotate end
    if options.easing then style.easing = options.easing end
    return style
end

function FloatingTextView.Create(options)
    options = options or {}
    local self = setmetatable({
        anchorPanel = options.anchorPanel,
        maxActive = options.maxActive or DEFAULT_MAX_ACTIVE,
        active = {},
        sequence = 0,
    }, FloatingTextView)

    self.root = UI.Panel {
        id = options.id or "floatingTextLayer",
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        width = "100%",
        height = "100%",
        zIndex = options.zIndex or 680,
        overflow = "visible",
        pointerEvents = "none",
    }

    print("[FloatingText] 飘字层已初始化")
    return self
end

function FloatingTextView:GetRoot()
    return self.root
end

function FloatingTextView:SetAnchorPanel(panel)
    self.anchorPanel = panel
end

function FloatingTextView:RemoveActive(widget)
    for i = #self.active, 1, -1 do
        if self.active[i] == widget then
            table.remove(self.active, i)
            return
        end
    end
end

function FloatingTextView:PruneActive()
    for i = #self.active, 1, -1 do
        local widget = self.active[i]
        if not widget or not widget.node then
            table.remove(self.active, i)
        end
    end

    while #self.active >= self.maxActive do
        local widget = table.remove(self.active, 1)
        if widget and widget.node then
            widget:Destroy()
        end
    end
end

function FloatingTextView:Clear()
    for i = #self.active, 1, -1 do
        local widget = self.active[i]
        if widget and widget.node then
            widget:Destroy()
        end
    end
    self.active = {}
end

function FloatingTextView:GetLayerLayout()
    if not self.root then return nil end
    local layout = self.root:GetAbsoluteLayout()
    if not layout or layout.w <= 0 or layout.h <= 0 then return nil end
    return layout
end

function FloatingTextView:GetBoardMetrics()
    if not self.anchorPanel then return nil end
    local layout = self.anchorPanel:GetAbsoluteLayout()
    if not layout or layout.w <= 0 or layout.h <= 0 then return nil end
    return BoardLayout.CalcMetrics(layout.w, layout.h), layout
end

function FloatingTextView:BoardRectToLayer(rect)
    local layerLayout = self:GetLayerLayout()
    local _, anchorLayout = self:GetBoardMetrics()
    if not layerLayout or not anchorLayout then return nil end
    return {
        x = anchorLayout.x - layerLayout.x + rect.x,
        y = anchorLayout.y - layerLayout.y + rect.y,
        w = rect.w,
        h = rect.h,
    }
end

function FloatingTextView:ShowText(text, options)
    if not self.root or text == nil then return nil end

    options = options or {}
    local style = ResolveStyle(options.variant, options)
    local layerLayout = self:GetLayerLayout()
    local scale = options.scale or 1.0
    scale = math.max(0.05, scale)

    local width = math.max(36, (style.width or 220) * scale)
    local height = math.max(24, (style.height or 56) * scale)
    local x = options.x
    local y = options.y
    if (not x or not y) and layerLayout then
        x = x or layerLayout.w * 0.5
        y = y or layerLayout.h * 0.45
    end
    if not x or not y then return nil end

    self:PruneActive()
    self.sequence = self.sequence + 1

    local lane = math.max(1, options.lane or 1)
    local laneOffset = (lane - 1) * 18 * scale
    local jitter = style.jitter or 0
    local jitterX = 0
    if jitter ~= 0 then
        local phase = ((self.sequence * 37) % 100) / 100
        jitterX = (phase * 2 - 1) * jitter * scale
    end
    if options.driftX then
        jitterX = jitterX + options.driftX * scale
    end

    local fontSize = math.max(12, Round((style.fontSize or 30) * scale))
    local strokeWidth = math.max(1, Round((options.strokeWidth or 3) * scale))
    local shadowBlur = math.max(0, Round(4 * scale))
    local shadowOffsetY = math.max(1, Round(2 * scale))

    local label = UI.Label {
        text = tostring(text),
        position = "absolute",
        left = Round(x - width * 0.5),
        top = Round(y - height * 0.5 - laneOffset),
        width = Round(width),
        height = Round(height),
        zIndex = (options.zIndex or 1) + (self.sequence % 16),
        fontSize = fontSize,
        fontWeight = options.fontWeight or "bold",
        fontColor = style.fontColor,
        textAlign = "center",
        verticalAlign = "middle",
        opacity = 0,
        scale = style.startScale or 0.8,
        rotate = style.startRotate or 0,
        translateY = 14 * scale,
        transformOrigin = "center",
        textStroke = { width = strokeWidth, color = style.strokeColor },
        textShadow = {
            offsetX = 0,
            offsetY = shadowOffsetY,
            blur = shadowBlur,
            color = style.shadowColor,
        },
        pointerEvents = "none",
    }

    self.root:AddChild(label)
    table.insert(self.active, label)

    local rise = (style.rise or 82) * scale + laneOffset
    local duration = Clamp(style.duration or 0.9, 0.2, 4.0)
    label:Animate({
        keyframes = {
            [0] = {
                opacity = 0,
                scale = style.startScale or 0.8,
                rotate = style.startRotate or 0,
                translateX = 0,
                translateY = 16 * scale,
            },
            [0.16] = {
                opacity = 1,
                scale = style.popScale or 1.14,
                rotate = style.popRotate or 0,
                translateX = jitterX * 0.25,
                translateY = -6 * scale,
            },
            [0.72] = {
                opacity = 1,
                scale = 1.0,
                rotate = ((style.popRotate or 0) + (style.endRotate or 0)) * 0.5,
                translateX = jitterX * 0.75,
                translateY = -rise * 0.62,
            },
            [1] = {
                opacity = 0,
                scale = style.endScale or 1.0,
                rotate = style.endRotate or 0,
                translateX = jitterX,
                translateY = -rise,
            },
        },
        duration = duration,
        easing = style.easing or "easeOutCubic",
        fillMode = "forwards",
        onComplete = function()
            self:RemoveActive(label)
            if label and label.node then
                label:Destroy()
            end
        end,
    })

    return label
end

function FloatingTextView:ShowAtFieldCell(row, col, text, options)
    options = CopyOptions(options)
    local metrics = self:GetBoardMetrics()
    if not metrics then return self:ShowText(text, options) end

    row = Clamp(row or 1, 1, Config.FIELD_ROWS)
    col = Clamp(col or 1, 1, Config.GRID_COLS)
    local rect = self:BoardRectToLayer(BoardLayout.CellRect(metrics, row, col, false))
    if not rect then return self:ShowText(text, options) end

    options.x = rect.x + rect.w * (options.anchorX or 0.5)
    options.y = rect.y + rect.h * (options.anchorY or 0.32)
    options.scale = options.scale or metrics.scale
    return self:ShowText(text, options)
end

function FloatingTextView:ShowMonsterStatus(row, col, text, options)
    options = CopyOptions(options)
    local variant = options.variant or "statusDebuff"
    options.variant = variant

    local lane = math.max(1, options.lane or 1)
    local side = options.side
    if not side then
        side = (variant == "statusBuff") and 1 or -1
    end
    local spread = ((lane - 1) % 2) * 0.05

    if not options.anchorX then
        options.anchorX = side > 0 and (0.78 - spread) or (0.22 + spread)
    end
    options.anchorY = options.anchorY or 0.42
    if not options.driftX then
        options.driftX = side > 0 and 30 or -30
    end
    options.rise = options.rise or (variant == "statusBuff" and 64 or 58)
    return self:ShowAtFieldCell(row, col, text, options)
end

function FloatingTextView:ShowPlayerStatus(text, options)
    options = CopyOptions(options)
    local variant = options.variant or "statusBuff"
    options.variant = variant

    local lane = math.max(1, options.lane or 1)
    local side = options.side
    if not side then
        side = (variant == "statusBuff") and 1 or -1
    end
    local spread = ((lane - 1) % 2) * 0.04

    if not options.anchorX then
        options.anchorX = side > 0 and (0.82 - spread) or (0.18 + spread)
    end
    if not options.driftX then
        options.driftX = side > 0 and 28 or -28
    end
    options.rise = options.rise or (variant == "statusBuff" and 64 or 58)
    return self:ShowAtPlayer(text, options)
end

function FloatingTextView:ShowAtDeploySlot(slotIdx, text, options)
    options = CopyOptions(options)
    local metrics = self:GetBoardMetrics()
    if not metrics then return self:ShowText(text, options) end

    local idx = Clamp(slotIdx or 1, 1, Config.TOTAL_SLOTS)
    local rect = self:BoardRectToLayer(BoardLayout.DeploySlotRect(metrics, idx))
    if not rect then return self:ShowText(text, options) end

    options.x = rect.x + rect.w * 0.5
    options.y = rect.y + rect.h * 0.18
    options.scale = options.scale or metrics.scale
    return self:ShowText(text, options)
end

function FloatingTextView:ShowAtStorage(text, options)
    options = CopyOptions(options)
    local metrics = self:GetBoardMetrics()
    if not metrics then return self:ShowText(text, options) end

    local rect = self:BoardRectToLayer(BoardLayout.ToScreenRect(metrics, metrics.storage))
    if not rect then return self:ShowText(text, options) end

    options.x = rect.x + rect.w * 0.5
    options.y = rect.y - 18 * metrics.scale
    options.scale = options.scale or metrics.scale
    return self:ShowText(text, options)
end

function FloatingTextView:ShowAtPlayer(text, options)
    options = CopyOptions(options)
    local metrics = self:GetBoardMetrics()
    if not metrics then return self:ShowText(text, options) end

    local rect = self:BoardRectToLayer(BoardLayout.ToScreenRect(metrics, metrics.hpBar))
    if not rect then return self:ShowText(text, options) end

    options.x = rect.x + rect.w * (options.anchorX or 0.5)
    options.y = rect.y - 22 * metrics.scale
    options.scale = options.scale or metrics.scale
    return self:ShowText(text, options)
end

function FloatingTextView:ShowCenter(text, options)
    options = CopyOptions(options)
    local metrics, anchorLayout = self:GetBoardMetrics()
    local layerLayout = self:GetLayerLayout()
    if metrics and anchorLayout and layerLayout then
        options.x = anchorLayout.x - layerLayout.x + metrics.originX + metrics.pageW * 0.5
        options.y = anchorLayout.y - layerLayout.y + metrics.originY + metrics.pageH * (options.anchorY or 0.42)
        options.scale = options.scale or metrics.scale
    elseif layerLayout then
        options.x = layerLayout.w * 0.5
        options.y = layerLayout.h * 0.42
    end
    return self:ShowText(text, options)
end

function FloatingTextView:ShowDamage(row, col, amount, options)
    options = CopyOptions(options)
    options.variant = options.variant or "damage"
    return self:ShowAtFieldCell(row, col, "-" .. FormatInteger(amount), options)
end

function FloatingTextView:ShowCrit(row, col, amount, options)
    local damageOptions = CopyOptions(options)
    damageOptions.variant = "crit"
    damageOptions.anchorX = damageOptions.anchorX or 0.5
    damageOptions.anchorY = damageOptions.anchorY or 0.27
    damageOptions.rise = damageOptions.rise or 118
    local damageLabel = self:ShowAtFieldCell(row, col, "-" .. FormatInteger(amount), damageOptions)

    local tagOptions = CopyOptions(options)
    local lane = math.max(1, tagOptions.lane or 1)
    local tagSide = (lane % 2 == 0) and 1 or -1
    tagOptions.variant = "critTag"
    tagOptions.anchorX = tagOptions.anchorX or (tagSide > 0 and 0.72 or 0.28)
    tagOptions.anchorY = tagOptions.anchorY or 0.18
    tagOptions.driftX = tagOptions.driftX or (tagSide > 0 and 36 or -36)
    tagOptions.rise = tagOptions.rise or 74
    tagOptions.lane = lane + 1
    self:ShowAtFieldCell(row, col, "暴击", tagOptions)

    return damageLabel
end

function FloatingTextView:ShowPlayerDamage(amount, options)
    options = CopyOptions(options)
    options.variant = options.variant or "playerDamage"
    return self:ShowAtPlayer("-" .. FormatInteger(amount), options)
end

function FloatingTextView:ShowPlayerCrit(amount, options)
    local damageOptions = CopyOptions(options)
    damageOptions.variant = "playerCrit"
    damageOptions.anchorX = damageOptions.anchorX or 0.5
    damageOptions.rise = damageOptions.rise or 96
    local damageLabel = self:ShowAtPlayer("-" .. FormatInteger(amount), damageOptions)

    local tagOptions = CopyOptions(options)
    tagOptions.variant = "critTag"
    tagOptions.anchorX = tagOptions.anchorX or 0.82
    tagOptions.driftX = tagOptions.driftX or 30
    tagOptions.rise = tagOptions.rise or 64
    tagOptions.lane = (tagOptions.lane or 1) + 1
    self:ShowAtPlayer("暴击", tagOptions)

    return damageLabel
end

function FloatingTextView:ShowPlayerHeal(amount, options)
    options = CopyOptions(options)
    options.variant = options.variant or "heal"
    return self:ShowAtPlayer("+" .. FormatInteger(amount), options)
end

function FloatingTextView:ShowExp(amount, options)
    options = CopyOptions(options)
    options.variant = options.variant or "exp"
    return self:ShowCenter("+" .. FormatInteger(amount) .. "修为", options)
end

function FloatingTextView:ShowMerge(category, index, quality)
    local qColor = QualityColor(quality)
    local options = {
        variant = "merge",
        fontColor = qColor,
        strokeColor = {54, 34, 12, 255},
    }
    local qualityName = Config.QUALITY[quality or 1] and Config.QUALITY[quality or 1].name or "高阶"
    local text = qualityName .. "合成"

    if category == "deploy" then
        return self:ShowAtDeploySlot(index, text, options)
    elseif category == "storage" then
        return self:ShowAtStorage(text, options)
    end
    return self:ShowCenter(text, options)
end

return FloatingTextView
