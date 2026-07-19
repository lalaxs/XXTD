-- views/RogueRewardView.lua
-- 突破后的机缘 3 选 1 弹窗。

local UI = require("urhox-libs/UI")

local RogueRewardView = {}
RogueRewardView.__index = RogueRewardView

local COLORS = {
    overlay = {0, 0, 0, 150},
    panel = {236, 218, 184, 252},
    card = {244, 235, 212, 255},
    cardPressed = {232, 224, 202, 255},
    cardDark = {111, 78, 39, 235},
    border = {132, 95, 52, 235},
    borderDark = {80, 56, 34, 255},
    title = {55, 38, 25, 255},
    text = {72, 52, 32, 255},
    muted = {116, 88, 56, 255},
    gold = {228, 166, 42, 255},
    red = {165, 62, 50, 255},
    green = {88, 142, 88, 255},
    blue = {82, 126, 156, 255},
    purple = {124, 86, 150, 255},
}

local CATEGORY_COLOR = {
    ["解锁"] = COLORS.gold,
    ["专属"] = COLORS.red,
    ["通用"] = COLORS.blue,
    ["守势"] = COLORS.blue,
    ["续航"] = COLORS.green,
    ["控场"] = COLORS.purple,
    ["资源"] = COLORS.gold,
    ["特异"] = COLORS.borderDark,
}

local function WithAlpha(color, alpha)
    return { color[1], color[2], color[3], alpha }
end

local function SoftShadow()
    return {
        { x = 0, y = 4, blur = 12, spread = 0, color = {0, 0, 0, 55} },
    }
end

local function HardShadow(color)
    return {
        { x = 3, y = 3, blur = 0, spread = 0, color = color or {80, 56, 34, 100} },
    }
end

local function CreateCategoryBadge(text, color)
    return UI.Panel {
        alignSelf = "flex-start",
        paddingHorizontal = 10,
        paddingVertical = 5,
        backgroundColor = color,
        borderRadius = 9,
        borderWidth = 1,
        borderColor = WithAlpha(COLORS.borderDark, 180),
        flexShrink = 0,
        children = {
            UI.Label {
                text = text or "机缘",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = {255, 245, 230, 255},
            },
        },
    }
end

local function CreateLearnButton()
    return UI.Panel {
        width = "100%",
        height = 28,
        backgroundColor = COLORS.cardDark,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = COLORS.border,
        alignItems = "center",
        justifyContent = "center",
        flexShrink = 0,
        children = {
            UI.Label {
                text = "点击参悟",
                fontSize = 12,
                fontWeight = "bold",
                fontColor = COLORS.gold,
            },
        },
    }
end

local function CreateRewardCard(reward, onSelect)
    local color = CATEGORY_COLOR[reward.category] or COLORS.gold

    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        minHeight = 330,
        padding = 10,
        gap = 7,
        backgroundColor = COLORS.card,
        borderRadius = 14,
        borderWidth = 3,
        borderColor = color,
        boxShadow = HardShadow(WithAlpha(color, 75)),
        transition = "scale 0.12s easeOut, backgroundColor 0.12s easeOut",
        onPointerDown = function(event, widget)
            widget:SetStyle({ scale = 0.97, backgroundColor = COLORS.cardPressed })
        end,
        onPointerUp = function(event, widget)
            widget:SetStyle({ scale = 1.0, backgroundColor = COLORS.card })
        end,
        onPointerCancel = function(event, widget)
            widget:SetStyle({ scale = 1.0, backgroundColor = COLORS.card })
        end,
        onTap = function()
            onSelect(reward.id)
        end,
        children = {
            CreateCategoryBadge(string.format("%s %s", reward.category or "机缘", reward.maxStacks and string.format("%d/%d", reward.nextLevel or 1, reward.maxStacks) or ""), color),
            UI.Label {
                text = reward.name,
                width = "100%",
                fontSize = 17,
                fontWeight = "bold",
                fontColor = COLORS.title,
                whiteSpace = "normal",
                wordBreak = "break-word",
                lineHeight = 1.15,
                maxLines = 2,
            },
            UI.Panel {
                width = "100%",
                height = 2,
                borderRadius = 1,
                backgroundColor = WithAlpha(color, 150),
            },
            UI.Label {
                text = reward.desc,
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                fontSize = 13,
                lineHeight = 1.3,
                fontColor = COLORS.text,
                whiteSpace = "normal",
                wordBreak = "break-word",
                maxLines = 7,
            },
            CreateLearnButton(),
        },
    }
end

function RogueRewardView.Create(onSelect)
    local self = setmetatable({
        root = nil,
        title = nil,
        subtitle = nil,
        choicesPanel = nil,
        onSelect = onSelect,
    }, RogueRewardView)

    self.title = UI.Label {
        text = "突破至境界",
        fontSize = 25,
        fontWeight = "bold",
        fontColor = COLORS.title,
        textAlign = "center",
    }
    self.subtitle = UI.Label {
        text = "选择一项机缘，构筑本轮法宝流派",
        width = "100%",
        fontSize = 14,
        lineHeight = 1.35,
        fontColor = COLORS.text,
        whiteSpace = "normal",
        textAlign = "center",
    }
    self.choicesPanel = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "stretch",
        gap = 10,
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        zIndex = 1200,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingHorizontal = 10,
        children = {
            UI.Panel {
                width = "94%",
                height = 560,
                top = -55,
                maxWidth = 940,
                minHeight = 520,
                padding = 14,
                gap = 10,
                backgroundColor = COLORS.panel,
                borderRadius = 20,
                borderWidth = 3,
                borderColor = COLORS.borderDark,
                boxShadow = SoftShadow(),
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            self.title,
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        height = 2,
                        borderRadius = 1,
                        backgroundColor = COLORS.border,
                    },
                    self.subtitle,
                    self.choicesPanel,
                },
            },
        },
    }

    return self
end

function RogueRewardView:GetRoot()
    return self.root
end

function RogueRewardView:Show(event, choices)
    self.choicesPanel:RemoveAllChildren()

    local realmName = event and event.realmName or "新境界"
    self.title:SetText("突破至" .. realmName)
    self.subtitle:SetText("选择一项机缘，构筑本轮法宝流派")

    for _, reward in ipairs(choices or {}) do
        self.choicesPanel:AddChild(CreateRewardCard(reward, self.onSelect))
    end

    self.root:SetVisible(true)
end

function RogueRewardView:Hide()
    self.root:SetVisible(false)
end

return RogueRewardView
