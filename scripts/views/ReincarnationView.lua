-- views/ReincarnationView.lua
-- 局外轮回强化面板。

local UI = require("urhox-libs/UI")
local ReincarnationSystem = require("ReincarnationSystem")

local ReincarnationView = {}
ReincarnationView.__index = ReincarnationView

local COLORS = {
    overlay = { 0, 0, 0, 150 },
    panel = { 236, 218, 184, 252 },
    panelInner = { 250, 238, 210, 255 },
    card = { 244, 235, 212, 255 },
    border = { 132, 95, 52, 235 },
    borderDark = { 80, 56, 34, 255 },
    title = { 55, 38, 25, 255 },
    text = { 72, 52, 32, 255 },
    muted = { 116, 88, 56, 255 },
    gold = { 228, 166, 42, 255 },
    red = { 165, 62, 50, 255 },
}

local function SoftShadow()
    return {
        { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 55 } },
    }
end

local function HardShadow()
    return {
        { x = 3, y = 3, blur = 0, spread = 0, color = { 80, 56, 34, 90 } },
    }
end

local function Percent(value)
    return string.format("%.1f%%", (value or 0) * 100):gsub("%.0%%", "%%")
end

function ReincarnationView.Create(onUpgrade, onUIClick)
    local self = setmetatable({
        root = nil,
        pointsLabel = nil,
        cardsPanel = nil,
        onUpgrade = onUpgrade,
        onUIClick = onUIClick,
    }, ReincarnationView)
    self.pointsLabel = UI.Label {
        text = "轮回点：0",
        width = "100%",
        fontSize = 18,
        fontWeight = "bold",
        fontColor = COLORS.red,
        textAlign = "center",
    }
    self.cardsPanel = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 10,
        justifyContent = "flex-start",
        paddingRight = 4,
    }
    local cardsScrollView = UI.ScrollView {
        width = "100%",
        height = "100%",
        scrollY = true,
        scrollX = false,
        showScrollbar = false,
        children = { self.cardsPanel },
    }
    cardsScrollView.OnPanStart = function(scrollView, event)
        if not scrollView.props.scrollX and not scrollView.props.scrollY then
            return false
        end

        scrollView:CancelSnap_()
        UI.CancelPointer(event.pointerId, event.pointerType)
        scrollView.state.isDragging = true
        scrollView.dragStartScrollX_ = scrollView.state.scrollX
        scrollView.dragStartScrollY_ = scrollView.state.scrollY
        scrollView.state.velocityX = 0
        scrollView.state.velocityY = 0
        return true
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
                width = "92%",
                maxWidth = 620,
                height = "78%",
                padding = 16,
                gap = 10,
                backgroundColor = COLORS.panel,
                borderWidth = 3,
                borderColor = COLORS.borderDark,
                borderRadius = 20,
                boxShadow = SoftShadow(),
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                flexGrow = 1,
                                flexShrink = 1,
                                gap = 3,
                                children = {
                                    UI.Label {
                                        text = "强化",
                                        fontSize = 25,
                                        fontWeight = "bold",
                                        fontColor = COLORS.title,
                                    },
                                    UI.Label {
                                        text = "以轮回点铸就不灭道基",
                                        fontSize = 13,
                                        fontColor = COLORS.muted,
                                    },
                                },
                            },
                            UI.Button {
                                text = "×",
                                width = 42,
                                height = 38,
                                fontSize = 22,
                                borderRadius = 10,
                                borderWidth = 2,
                                borderColor = COLORS.borderDark,
                                backgroundColor = { 92, 63, 36, 255 },
                                pressedBackgroundColor = { 55, 40, 28, 255 },
                                textColor = { 235, 218, 185, 255 },
                                onClick = function()
                                    if self.onUIClick then self.onUIClick() end
                                    self:Hide()
                                end,
                            },
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        height = 2,
                        borderRadius = 1,
                        backgroundColor = COLORS.border,
                    },
                    self.pointsLabel,
                    UI.Panel {
                        width = "100%",
                        flexGrow = 1,
                        flexBasis = 0,
                        children = {
                            cardsScrollView,
                        },
                    },
                },
            },
        },
    }
    return self
end

function ReincarnationView:GetRoot()
    return self.root
end

function ReincarnationView:Show(state)
    self.cardsPanel:RemoveAllChildren()
    self.pointsLabel:SetText(string.format("轮回点：%d · 已历%d次轮回", state.reincarnationPoints or 0, state.reincarnationCount or 0))
    for _, def in ipairs(ReincarnationSystem.GetDefinitions()) do
        local level = ReincarnationSystem.GetLevel(state, def.id)
        local total = ReincarnationSystem.GetValue(state, def.id)
        local full = level >= def.maxLevel
        self.cardsPanel:AddChild(UI.Panel {
            width = "47%",
            height = 200,
            padding = 10,
            gap = 5,
            alignItems = "center",
            backgroundColor = COLORS.card,
            borderWidth = 2,
            borderColor = full and COLORS.gold or COLORS.border,
            borderRadius = 14,
            boxShadow = HardShadow(),
            children = {
                UI.Label {
                    text = def.name,
                    width = "100%",
                    fontSize = 16,
                    fontWeight = "bold",
                    fontColor = COLORS.title,
                    textAlign = "center",
                    maxLines = 1,
                    flexShrink = 0,
                },
                UI.Label {
                    text = string.format("等级 %d / %d", level, def.maxLevel),
                    width = "100%",
                    fontSize = 13,
                    fontWeight = "bold",
                    fontColor = COLORS.muted,
                    textAlign = "center",
                    flexShrink = 0,
                },
                UI.Panel {
                    width = "100%",
                    height = 2,
                    flexShrink = 0,
                    borderRadius = 1,
                    backgroundColor = full and COLORS.gold or COLORS.border,
                },
                UI.Label {
                    text = string.format("当前总效果：%s", Percent(total)),
                    width = "100%",
                    fontSize = 13,
                    fontWeight = "bold",
                    fontColor = COLORS.text,
                    textAlign = "center",
                    maxLines = 1,
                    flexShrink = 0,
                },
                UI.Panel {
                    width = "100%",
                    flexGrow = 1,
                    flexBasis = 0,
                    flexShrink = 1,
                },
                UI.Panel {
                    width = "100%",
                    height = 58,
                    flexShrink = 0,
                    justifyContent = "flex-end",
                    alignItems = "center",
                    gap = 5,
                    children = {
                        UI.Label {
                            text = full and "已满级" or "消耗1点",
                            fontSize = 11,
                            fontWeight = "bold",
                            fontColor = full and COLORS.gold or COLORS.muted,
                            textAlign = "center",
                            flexShrink = 0,
                        },
                        UI.Button {
                            text = full and "已满级" or "升级",
                            width = 76,
                            height = 34,
                            fontSize = 13,
                            fontWeight = "bold",
                            borderRadius = 9,
                            borderWidth = 1,
                            borderColor = COLORS.borderDark,
                            backgroundColor = full and COLORS.muted or COLORS.red,
                            pressedBackgroundColor = full and COLORS.muted or { 130, 45, 38, 255 },
                            textColor = { 255, 245, 230, 255 },
                            onClick = function()
                                if not full and self.onUpgrade then
                                    if self.onUIClick then self.onUIClick() end
                                    self.onUpgrade(def.id)
                                end
                            end,
                        },
                    },
                },
            },
        })
    end
    self.root:SetVisible(true)
end

function ReincarnationView:Hide()
    self.root:SetVisible(false)
end

return ReincarnationView
