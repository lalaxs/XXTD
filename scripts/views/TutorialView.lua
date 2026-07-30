local UI = require("urhox-libs/UI")
local BoardLayout = require("BoardLayout")
local Config = require("Config")

local TutorialView = {}
TutorialView.__index = TutorialView

---@class TutorialView
---@field fieldPanel Panel
---@field presentation table|nil
---@field sourceOutline Panel
---@field targetOutline Panel
---@field messageLabel Label
---@field card Panel
---@field root Panel
---@field ResolveRect fun(self: TutorialView, target: table|nil, metrics: table): table|nil

local function MakeOutline()
    return UI.Panel {
        visible = false,
        position = "absolute",
        width = 10,
        height = 10,
        zIndex = 2,
        borderWidth = 4,
        borderColor = {255, 221, 105, 255},
        borderRadius = 16,
        backgroundColor = {255, 221, 105, 28},
        boxShadow = {
            { x = 0, y = 0, blur = 18, spread = 5, color = {255, 214, 82, 185} },
        },
        pointerEvents = "none",
    }
end

local function AddPadding(rect, padding)
    return {
        x = rect.x - padding,
        y = rect.y - padding,
        w = rect.w + padding * 2,
        h = rect.h + padding * 2,
    }
end

function TutorialView.Create(fieldPanel)
    ---@type TutorialView
    local self = setmetatable({
        fieldPanel = fieldPanel,
        presentation = nil,
        sourceOutline = MakeOutline(),
        targetOutline = MakeOutline(),
    }, TutorialView)

    self.messageLabel = UI.Label {
        text = "",
        width = "100%",
        fontSize = 19,
        lineHeight = 1.42,
        fontWeight = "bold",
        fontColor = {255, 248, 220, 255},
        textAlign = "center",
        whiteSpace = "normal",
        pointerEvents = "none",
    }

    self.card = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        width = 10,
        minHeight = 92,
        zIndex = 3,
        padding = 16,
        justifyContent = "center",
        backgroundColor = {35, 57, 52, 242},
        borderWidth = 3,
        borderColor = {255, 221, 105, 255},
        borderRadius = 18,
        boxShadow = {
            { x = 0, y = 6, blur = 18, spread = 0, color = {0, 0, 0, 120} },
        },
        pointerEvents = "none",
        children = { self.messageLabel },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        zIndex = 1180,
        pointerEvents = "box-none",
        children = {
            self.sourceOutline,
            self.targetOutline,
            self.card,
        },
    }
    return self
end

function TutorialView:GetRoot()
    ---@cast self TutorialView
    return self.root
end

function TutorialView:SetPresentation(presentation)
    ---@cast self TutorialView
    self.presentation = presentation
    self.root:SetVisible(presentation ~= nil)
    if not presentation then
        self.sourceOutline:SetVisible(false)
        self.targetOutline:SetVisible(false)
        return
    end
    self.messageLabel:SetText(presentation.text or "")
end

function TutorialView:ResolveRect(target, metrics)
    ---@cast self TutorialView
    if not target then return nil end
    if target.kind == "deploy" then
        return BoardLayout.DeploySlotRect(metrics, target.slot)
    elseif target.kind == "deployColumn" then
        local top = BoardLayout.CellRect(metrics, 1, target.col, true)
        return {
            x = top.x,
            y = top.y,
            w = top.w,
            h = metrics.deployCellH * Config.DEPLOY_ROWS * metrics.scale,
        }
    elseif target.kind == "fieldCell" then
        return BoardLayout.CellRect(metrics, target.row, target.col, false)
    elseif target.kind == "storage" then
        return BoardLayout.ToScreenRect(metrics, metrics.storageSlot)
    elseif target.kind == "shop" then
        return BoardLayout.ToScreenRect(metrics, metrics.shopEntry)
    end
    return nil
end

local function ApplyRect(widget, rect)
    if not rect then
        widget:SetVisible(false)
        return
    end
    local padded = AddPadding(rect, 7)
    widget:SetVisible(true)
    widget:SetStyle({
        left = padded.x,
        top = padded.y,
        width = padded.w,
        height = padded.h,
    })
end

local function ResolveCardRect(metrics)
    local row = BoardLayout.CellRect(metrics, 6, 1, false)
    local lastColumn = BoardLayout.CellRect(metrics, 6, Config.GRID_COLS, false)
    local horizontalPadding = 16 * metrics.scale
    return {
        x = row.x + horizontalPadding,
        y = row.y + row.h * 0.42,
        w = lastColumn.x + lastColumn.w - row.x - horizontalPadding * 2,
    }
end

local function ApplyCardRect(widget, rect)
    widget:SetStyle({
        left = rect.x,
        top = rect.y,
        width = rect.w,
    })
end

function TutorialView:UpdateLayout()
    ---@cast self TutorialView
    if not self.presentation or not self.fieldPanel then return end
    local layout = self.fieldPanel:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end
    local metrics = BoardLayout.CalcMetrics(layout.w, layout.h)
    ApplyRect(self.sourceOutline, self:ResolveRect(self.presentation.source, metrics))
    ApplyRect(self.targetOutline, self:ResolveRect(self.presentation.target, metrics))
    ApplyCardRect(self.card, ResolveCardRect(metrics))
end

return TutorialView
