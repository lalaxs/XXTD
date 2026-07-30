-- views/RogueBuffListView.lua
-- 本次轮回已获得的机缘增益列表。

local UI = require("urhox-libs/UI")
local RogueRewardDefs = require("config.RogueRewardDefs")

local RogueBuffListView = {}
RogueBuffListView.__index = RogueBuffListView

local COLORS = {
    overlay = {0, 0, 0, 150},
    panel = {236, 218, 184, 252},
    panelInner = {250, 238, 210, 255},
    card = {244, 235, 212, 255},
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
        { x = 3, y = 3, blur = 0, spread = 0, color = color or {80, 56, 34, 90} },
    }
end

local function CreateSeal(text, color, size, fontSize)
    return UI.Panel {
        width = size,
        height = size,
        borderWidth = 2,
        borderColor = WithAlpha(color, 210),
        borderRadius = 4,
        rotate = -5,
        alignItems = "center",
        justifyContent = "center",
        flexShrink = 0,
        children = {
            UI.Label {
                text = text,
                fontSize = fontSize,
                fontWeight = "bold",
                fontColor = WithAlpha(color, 220),
            },
        },
    }
end

local function CreateCategoryBadge(text, color)
    return UI.Panel {
        paddingHorizontal = 8,
        paddingVertical = 4,
        backgroundColor = color,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = WithAlpha(COLORS.borderDark, 180),
        flexShrink = 0,
        children = {
            UI.Label {
                text = text or "增益",
                fontSize = 12,
                fontWeight = "bold",
                fontColor = {255, 245, 230, 255},
            },
        },
    }
end

local function BuildOwnedRewards(state)
    local owned = {}
    local levels = state and state.selectedRogueRewards or {}

    for _, def in ipairs(RogueRewardDefs) do
        local level = tonumber(levels[def.id]) or 0
        if level > 0 then
            table.insert(owned, {
                id = def.id,
                name = def.name,
                abilityName = def.abilityName or def.shortName or def.name,
                abilityDesc = def.cardDesc or def.abilityDesc or def.desc,
                category = def.category or "机缘",
                icon = def.icon,
            })
        end
    end

    return owned
end

local function CreateRewardRow(reward, index)
    local color = CATEGORY_COLOR[reward.category] or COLORS.gold

    return UI.Panel {
        width = "100%",
        padding = 12,
        gap = 8,
        backgroundColor = COLORS.card,
        borderRadius = 14,
        borderWidth = 2,
        borderColor = COLORS.border,
        boxShadow = HardShadow(WithAlpha(color, 55)),
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "flex-start",
                gap = 10,
                children = {
                    CreateSeal(tostring(index), COLORS.red, 34, 17),
                    UI.Panel {
                        width = 68,
                        height = 68,
                        backgroundImage = reward.icon or false,
                        backgroundFit = "contain",
                        backgroundColor = WithAlpha(color, 35),
                        borderWidth = 2,
                        borderColor = WithAlpha(color, 180),
                        borderRadius = 10,
                        flexShrink = 0,
                        children = reward.icon and {} or {
                            UI.Label {
                                text = "技能",
                                fontSize = 12,
                                fontWeight = "bold",
                                fontColor = color,
                                textAlign = "center",
                            },
                        },
                    },
                    UI.Panel {
                        flexGrow = 1,
                        flexShrink = 1,
                        gap = 4,
                        children = {
                            UI.Label {
                                text = reward.abilityName or reward.name or "未知技能",
                                width = "100%",
                                fontSize = 18,
                                fontWeight = "bold",
                                fontColor = COLORS.title,
                                whiteSpace = "normal",
                                wordBreak = "break-word",
                                maxLines = 2,
                            },
                        },
                    },
                    CreateCategoryBadge(reward.category, color),
                },
            },
            UI.Panel {
                width = "100%",
                height = 2,
                borderRadius = 1,
                backgroundColor = WithAlpha(color, 135),
            },
            UI.Label {
                text = reward.abilityDesc or reward.desc or "",
                width = "100%",
                fontSize = 14,
                lineHeight = 1.35,
                fontColor = COLORS.text,
                whiteSpace = "normal",
                wordBreak = "break-word",
            },
        },
    }
end

function RogueBuffListView.Create(onUIClick)
    local self = setmetatable({
        root = nil,
        panel = nil,
        titleLabel = nil,
        subtitleLabel = nil,
        countLabel = nil,
        listPanel = nil,
        scrollView = nil,
        onUIClick = onUIClick,
    }, RogueBuffListView)

    self.titleLabel = UI.Label {
        text = "本轮增益",
        fontSize = 25,
        fontWeight = "bold",
        fontColor = COLORS.title,
    }
    self.subtitleLabel = UI.Label {
        text = "",
        width = "100%",
        fontSize = 14,
        fontColor = COLORS.text,
        textAlign = "center",
        whiteSpace = "normal",
    }
    self.countLabel = UI.Label {
        text = "0项",
        fontSize = 13,
        fontWeight = "bold",
        fontColor = COLORS.gold,
    }
    self.listPanel = UI.Panel {
        width = "100%",
        minHeight = "100%",
        gap = 10,
        paddingRight = 4,
    }
    self.scrollView = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        padding = 10,
        backgroundColor = COLORS.panelInner,
        borderRadius = 14,
        borderWidth = 2,
        borderColor = COLORS.border,
        overflow = "hidden",
        children = {
            UI.ScrollView {
                width = "100%",
                height = "100%",
                scrollY = true,
                scrollX = false,
                showScrollbar = true,
                children = { self.listPanel },
            },
        },
    }

    self.panel = UI.Panel {
        width = "92%",
        maxWidth = 620,
        height = "78%",
        padding = 16,
        gap = 10,
        backgroundColor = COLORS.panel,
        borderRadius = 20,
        borderWidth = 3,
        borderColor = COLORS.borderDark,
        boxShadow = SoftShadow(),
        transition = "opacity 0.22s easeOutCubic, scale 0.22s easeOutCubic",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    CreateSeal("技", COLORS.red, 42, 22),
                    self.titleLabel,
                    UI.Button {
                        text = "×",
                        width = 42,
                        height = 38,
                        fontSize = 22,
                        borderRadius = 10,
                        borderWidth = 2,
                        borderColor = COLORS.borderDark,
                        backgroundColor = {92, 63, 36, 255},
                        textColor = {235, 218, 185, 255},
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
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                gap = 10,
                children = {
                    UI.Panel {
                        flexGrow = 1,
                        flexShrink = 1,
                        paddingHorizontal = 10,
                        paddingVertical = 7,
                        backgroundColor = COLORS.panelInner,
                        borderRadius = 12,
                        borderWidth = 2,
                        borderColor = COLORS.border,
                        children = { self.subtitleLabel },
                    },
                    UI.Panel {
                        width = 78,
                        height = 38,
                        borderRadius = 12,
                        borderWidth = 2,
                        borderColor = COLORS.border,
                        backgroundColor = COLORS.cardDark,
                        alignItems = "center",
                        justifyContent = "center",
                        children = { self.countLabel },
                    },
                },
            },
            self.scrollView,
        },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        zIndex = 1250,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingHorizontal = 12,
        children = { self.panel },
    }

    return self
end

function RogueBuffListView:GetRoot()
    return self.root
end

function RogueBuffListView:Show(state)
    local rewards = BuildOwnedRewards(state)
    self.listPanel:RemoveAllChildren()
    self.titleLabel:SetText("机缘")
    self.subtitleLabel:SetText("本轮已获得的技能")
    self.countLabel:SetText(string.format("%d项", #rewards))
    print(string.format("[Rogue Skills] 打开已拥有技能面板，共%d项", #rewards))

    if #rewards == 0 then
        self.listPanel:AddChild(UI.Label {
            text = "尚未拥有技能",
            width = "100%",
            flexGrow = 1,
            fontSize = 16,
            fontWeight = "bold",
            fontColor = COLORS.muted,
            textAlign = "center",
            verticalAlign = "middle",
        })
    else
        for i, reward in ipairs(rewards) do
            self.listPanel:AddChild(CreateRewardRow(reward, i))
        end
    end

    self.root:SetVisible(true)
    self.panel:Animate({
        keyframes = {
            [0] = { opacity = 0, scale = 0.88 },
            [1] = { opacity = 1, scale = 1.0 },
        },
        duration = 0.22,
        easing = "easeOutCubic",
        fillMode = "forwards",
    })
end

function RogueBuffListView:Hide()
    self.root:SetVisible(false)
end

return RogueBuffListView
