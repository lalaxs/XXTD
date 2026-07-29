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
    ["进阶"] = COLORS.red,
    ["通用"] = COLORS.blue,
    ["敌方强化"] = COLORS.purple,
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

local function GetDisplayCategory(reward)
    return reward.category or "机缘"
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

local function CreateRewardIcon(reward, color)
    return UI.Panel {
        width = 76,
        height = 76,
        alignSelf = "center",
        backgroundImage = reward.icon or false,
        backgroundFit = "contain",
        backgroundColor = WithAlpha(color, 35),
        borderWidth = 2,
        borderColor = WithAlpha(color, 180),
        borderRadius = 10,
        flexShrink = 0,
        children = reward.icon and {} or {
            UI.Label {
                text = "机缘",
                fontSize = 12,
                fontWeight = "bold",
                fontColor = color,
            },
        },
    }
end

local function CreateRewardCard(reward, onSelect)
    local displayCategory = GetDisplayCategory(reward)
    local color = CATEGORY_COLOR[displayCategory] or COLORS.gold

    return UI.Panel {
        flexGrow = 1,
        flexShrink = 1,
        flexBasis = 0,
        height = 330,
        padding = 12,
        gap = 8,
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
            CreateCategoryBadge(displayCategory, color),
            CreateRewardIcon(reward, color),
            UI.Label {
                text = reward.abilityName or reward.shortName or reward.name,
                width = "100%",
                height = 24,
                fontSize = 17,
                fontWeight = "bold",
                fontColor = COLORS.title,
                whiteSpace = "nowrap",
                overflow = "hidden",
                textAlign = "center",
                flexShrink = 0,
            },
            UI.Panel {
                width = "100%",
                height = 2,
                borderRadius = 1,
                backgroundColor = WithAlpha(color, 150),
            },
            UI.Label {
                text = reward.cardDesc or reward.abilityDesc or reward.desc,
                width = "100%",
                flexGrow = 1,
                flexShrink = 1,
                fontSize = 12,
                lineHeight = 1.25,
                fontColor = COLORS.text,
                whiteSpace = "normal",
                wordBreak = "break-word",
                textAlign = "left",
            },
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
        text = "解锁后加入掉落与合成池，不会立即获得物品。",
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
        gap = 12,
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
                height = 500,
                top = -45,
                maxWidth = 940,
                minHeight = 470,
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

function RogueRewardView:Show(event, choices, stage)
    self.choicesPanel:RemoveAllChildren()

    local realmName = event and event.realmName or "新境界"
    local stageInfo = {
        attack = { prefix = "突破至", title = "攻击法宝", subtitle = "选择一项攻击法宝机缘", suffix = "，完成三次选择后继续修行。" },
        armor = { prefix = "突破至", title = "防御法宝", subtitle = "选择一项防御法宝机缘", suffix = "，完成三次选择后继续修行。" },
        enemy = { prefix = "突破至", title = "敌方强化", subtitle = "选择一项敌方强化", suffix = "，完成三次选择后继续修行。" },
    }
    local currentStage = stageInfo[stage] or stageInfo.attack
    self.title:SetText(currentStage.prefix .. realmName .. " · " .. currentStage.title)
    self.subtitle:SetText(currentStage.subtitle .. currentStage.suffix)

    for _, reward in ipairs(choices or {}) do
        self.choicesPanel:AddChild(CreateRewardCard(reward, self.onSelect))
    end

    self.root:SetVisible(true)
end

function RogueRewardView:Hide()
    self.root:SetVisible(false)
end

return RogueRewardView
