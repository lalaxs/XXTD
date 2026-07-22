-- views/DebugStatusView.lua
-- 战斗页调试状态选择面板。

local UI = require("urhox-libs/UI")
local StatusPresenter = require("views.StatusPresenter")
local DebugStatusSystem = require("debug.DebugStatusSystem")

local DebugStatusView = {}
DebugStatusView.__index = DebugStatusView

local COLORS = {
    overlay = {0, 0, 0, 165},
    panel = {240, 225, 195, 255},
    panelInner = {248, 237, 213, 255},
    border = {112, 79, 42, 240},
    title = {67, 43, 24, 255},
    text = {84, 59, 34, 255},
    muted = {125, 91, 52, 255},
    buff = {72, 126, 84, 255},
    buffPressed = {52, 96, 62, 255},
    debuff = {167, 67, 56, 255},
    debuffPressed = {128, 46, 39, 255},
    clear = {88, 70, 54, 255},
    clearPressed = {62, 46, 34, 255},
    white = {255, 246, 229, 255},
}

local function CreateStatusButton(definition, onApply)
    local isDebuff = definition.kind == "debuff"
    return UI.Button {
        text = definition.name .. "\n" .. definition.desc,
        width = "48%",
        minHeight = 64,
        flexShrink = 0,
        fontSize = 13,
        fontWeight = "bold",
        borderRadius = 11,
        borderWidth = 2,
        borderColor = COLORS.border,
        backgroundColor = isDebuff and COLORS.debuff or COLORS.buff,
        pressedBackgroundColor = isDebuff and COLORS.debuffPressed or COLORS.buffPressed,
        textColor = COLORS.white,
        onClick = function()
            onApply(definition.id)
        end,
    }
end

function DebugStatusView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        activeLabel = nil,
    }, DebugStatusView)

    self.activeLabel = UI.Label {
        text = "当前没有状态",
        width = "100%",
        fontSize = 13,
        lineHeight = 1.3,
        fontColor = COLORS.text,
        textAlign = "center",
        whiteSpace = "normal",
    }

    local buttonGrid = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }
    for _, definition in ipairs(DebugStatusSystem.GetDefinitions()) do
        buttonGrid:AddChild(CreateStatusButton(definition, function(statusId)
            if self.callbacks.onApply then
                self.callbacks.onApply(statusId)
            end
        end))
    end

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        zIndex = 1400,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingHorizontal = 12,
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 620,
                height = "88%",
                padding = 16,
                gap = 10,
                backgroundColor = COLORS.panel,
                borderRadius = 20,
                borderWidth = 3,
                borderColor = COLORS.border,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "状态调试",
                                fontSize = 24,
                                fontWeight = "bold",
                                fontColor = COLORS.title,
                            },
                            UI.Button {
                                text = "×",
                                width = 42,
                                height = 38,
                                fontSize = 22,
                                borderRadius = 10,
                                borderWidth = 2,
                                borderColor = COLORS.border,
                                backgroundColor = COLORS.clear,
                                pressedBackgroundColor = COLORS.clearPressed,
                                textColor = COLORS.white,
                                onClick = function()
                                    self:Hide()
                                end,
                            },
                        },
                    },
                    UI.Label {
                        text = "点击单独施加状态。绿色为增益，红色为减益。",
                        width = "100%",
                        fontSize = 13,
                        fontColor = COLORS.muted,
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        padding = 10,
                        backgroundColor = COLORS.panelInner,
                        borderRadius = 12,
                        borderWidth = 2,
                        borderColor = COLORS.border,
                        children = { self.activeLabel },
                    },
                    UI.ScrollView {
                        width = "100%",
                        flexGrow = 1,
                        flexBasis = 0,
                        scrollY = true,
                        scrollX = false,
                        showScrollbar = true,
                        children = { buttonGrid },
                    },
                    UI.Button {
                        text = "清空调试状态",
                        width = "100%",
                        height = 44,
                        flexShrink = 0,
                        fontSize = 15,
                        fontWeight = "bold",
                        borderRadius = 11,
                        borderWidth = 2,
                        borderColor = COLORS.border,
                        backgroundColor = COLORS.clear,
                        pressedBackgroundColor = COLORS.clearPressed,
                        textColor = COLORS.white,
                        onClick = function()
                            if self.callbacks.onClear then
                                self.callbacks.onClear()
                            end
                        end,
                    },
                },
            },
        },
    }

    return self
end

function DebugStatusView:GetRoot()
    return self.root
end

function DebugStatusView:Refresh(state)
    local statuses = StatusPresenter.BuildStatuses(state)
    if #statuses == 0 then
        self.activeLabel:SetText("当前没有状态")
        return
    end

    local names = {}
    for _, status in ipairs(statuses) do
        table.insert(names, status.name)
    end
    self.activeLabel:SetText("当前状态：" .. table.concat(names, "、"))
end

function DebugStatusView:Show(state)
    self:Refresh(state)
    self.root:SetVisible(true)
end

function DebugStatusView:Hide()
    self.root:SetVisible(false)
end

return DebugStatusView
