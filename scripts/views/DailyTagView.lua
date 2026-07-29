-- views/DailyTagView.lua
-- 每日挑战战斗内说明弹窗：展示本局实际生效的全部今日词条。

local UI = require("urhox-libs/UI")

local DailyTagView = {}
DailyTagView.__index = DailyTagView

local COLORS = {
    overlay = {0, 0, 0, 160},
    panel = {232, 228, 210, 255},
    card = {243, 240, 230, 255},
    border = {28, 27, 36, 255},
    divider = {200, 196, 178, 255},
    title = {28, 27, 36, 255},
    text = {58, 54, 69, 255},
    muted = {122, 118, 130, 255},
    red = {166, 60, 51, 255},
    gold = {181, 150, 91, 255},
}

local function CreateBuffCard(tag, index)
    return UI.Panel {
        width = "100%",
        padding = 14,
        gap = 8,
        flexShrink = 0,
        backgroundColor = COLORS.card,
        borderWidth = 1,
        borderColor = COLORS.divider,
        borderRadius = 8,
        boxShadow = {
            { x = 3, y = 3, blur = 0, spread = 0, color = {28, 27, 36, 40} },
        },
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 10,
                children = {
                    UI.Panel {
                        width = 34,
                        height = 34,
                        flexShrink = 0,
                        alignItems = "center",
                        justifyContent = "center",
                        backgroundColor = COLORS.red,
                        borderRadius = 4,
                        children = {
                            UI.Label {
                                text = tostring(index),
                                fontSize = 16,
                                fontWeight = "bold",
                                fontColor = {255, 255, 255, 255},
                            },
                        },
                    },
                    UI.Label {
                        text = tag.name or tag.id or "未知增益",
                        flexGrow = 1,
                        flexShrink = 1,
                        fontSize = 19,
                        fontWeight = "bold",
                        fontColor = COLORS.title,
                        whiteSpace = "normal",
                    },
                },
            },
            UI.Label {
                text = tag.description or "暂无说明",
                width = "100%",
                fontSize = 15,
                lineHeight = 1.4,
                fontColor = COLORS.text,
                whiteSpace = "normal",
                wordBreak = "break-word",
            },
        },
    }
end

function DailyTagView.Create()
    local self = setmetatable({
        root = nil,
        panel = nil,
        dateLabel = nil,
        countLabel = nil,
        listPanel = nil,
    }, DailyTagView)

    self.dateLabel = UI.Label {
        text = "展示本局实际生效的全部今日词条",
        flexGrow = 1,
        flexShrink = 1,
        fontSize = 14,
        fontColor = COLORS.muted,
        whiteSpace = "normal",
    }
    self.countLabel = UI.Label {
        text = "0项",
        fontSize = 14,
        fontWeight = "bold",
        fontColor = COLORS.red,
    }
    self.listPanel = UI.Panel {
        width = "100%",
        gap = 10,
        paddingRight = 4,
        flexDirection = "column",
    }

    self.panel = UI.Panel {
        width = "86%",
        maxWidth = 520,
        height = "58%",
        padding = 18,
        gap = 12,
        backgroundColor = COLORS.panel,
        borderWidth = 2,
        borderColor = COLORS.border,
        borderRadius = 10,
        boxShadow = {
            { x = 0, y = 4, blur = 16, spread = 0, color = {0, 0, 0, 50} },
        },
        transition = "opacity 0.22s easeOutCubic, scale 0.22s easeOutCubic",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "今日词条",
                        fontSize = 26,
                        fontWeight = "bold",
                        fontColor = COLORS.title,
                    },
                    UI.Button {
                        text = "×",
                        width = 42,
                        height = 38,
                        fontSize = 22,
                        borderRadius = 8,
                        borderWidth = 2,
                        borderColor = COLORS.border,
                        backgroundColor = COLORS.red,
                        pressedBackgroundColor = {126, 40, 34, 255},
                        textColor = {255, 245, 230, 255},
                        onClick = function()
                            self:Hide()
                        end,
                    },
                },
            },
            UI.Panel {
                width = "100%",
                height = 1,
                backgroundColor = COLORS.divider,
            },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                gap = 10,
                children = {
                    self.dateLabel,
                    UI.Panel {
                        paddingHorizontal = 10,
                        paddingVertical = 5,
                        flexShrink = 0,
                        backgroundColor = {166, 60, 51, 35},
                        borderRadius = 4,
                        children = {self.countLabel},
                    },
                },
            },
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                flexBasis = 0,
                flexShrink = 1,
                children = {
                    UI.ScrollView {
                        width = "100%",
                        height = "100%",
                        scrollY = true,
                        scrollX = false,
                        showScrollbar = true,
                        children = {self.listPanel},
                    },
                },
            },
        },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        zIndex = 1260,
        paddingHorizontal = 12,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        children = {self.panel},
    }

    return self
end

function DailyTagView:GetRoot()
    return self.root
end

function DailyTagView:Show(challenge)
    local tags = challenge and challenge.tags or {}
    self.listPanel:RemoveAllChildren()
    self.dateLabel:SetText(challenge and challenge.date
        and ("挑战日期：" .. tostring(challenge.date) .. " · 本局全部生效词条")
        or "展示本局实际生效的全部今日词条")
    self.countLabel:SetText(string.format("%d项", #tags))

    if #tags == 0 then
        self.listPanel:AddChild(UI.Panel {
            width = "100%",
            minHeight = 160,
            padding = 18,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = COLORS.card,
            borderWidth = 1,
            borderColor = COLORS.divider,
            borderRadius = 8,
            children = {
                UI.Label {
                    text = "今日没有额外词条",
                    width = "100%",
                    fontSize = 17,
                    fontColor = COLORS.muted,
                    textAlign = "center",
                },
            },
        })
    else
        for index, tag in ipairs(tags) do
            self.listPanel:AddChild(CreateBuffCard(tag, index))
        end
    end

    print(string.format("[Daily] 打开今日词条说明，共%d项", #tags))
    self.root:SetVisible(true)
    self.panel:Animate({
        keyframes = {
            [0] = {opacity = 0, scale = 0.88},
            [1] = {opacity = 1, scale = 1.0},
        },
        duration = 0.22,
        easing = "easeOutCubic",
        fillMode = "forwards",
    })
end

function DailyTagView:Hide()
    self.root:SetVisible(false)
end

return DailyTagView
