-- views/DailyChallengeView.lua
-- 每日挑战详情弹窗：展示今日规则、次数、最佳成绩与后续入口。

local UI = require("urhox-libs/UI")

local DailyChallengeView = {}
DailyChallengeView.__index = DailyChallengeView

local COLORS = {
    overlay = {0, 0, 0, 170},
    panel = {240, 225, 195, 255},
    panelInner = {246, 232, 198, 245},
    border = {140, 105, 60, 230},
    borderLight = {184, 143, 82, 220},
    title = {55, 40, 28, 255},
    text = {70, 52, 34, 255},
    muted = {120, 95, 68, 255},
    gold = {181, 150, 91, 255},
    benefit = {83, 132, 88, 255},
    pressure = {165, 62, 50, 255},
    neutral = {120, 95, 68, 255},
    button = {160, 120, 60, 255},
}

local function GetKindLabel(kind)
    if kind == "benefit" then return "增益" end
    if kind == "pressure" then return "压力" end
    return "混合"
end

local function GetKindColor(kind)
    if kind == "benefit" then return COLORS.benefit end
    if kind == "pressure" then return COLORS.pressure end
    return COLORS.neutral
end

local function MakeButton(text, color, onClick)
    return UI.Button {
        text = text,
        width = "100%",
        height = 48,
        fontSize = 15,
        fontWeight = "bold",
        borderRadius = 10,
        borderWidth = 2,
        borderColor = COLORS.border,
        backgroundColor = color or COLORS.button,
        pressedBackgroundColor = {120, 88, 45, 255},
        textColor = {255, 245, 230, 255},
        onClick = onClick,
    }
end

local function MakeTagCard(tag)
    local kindColor = GetKindColor(tag.kind)
    local textColor = {255, 248, 235, 255}
    local descriptionColor = {255, 242, 224, 245}
    return UI.Panel {
        width = "100%",
        padding = 10,
        gap = 5,
        backgroundColor = {kindColor[1], kindColor[2], kindColor[3], 220},
        borderRadius = 10,
        borderWidth = 2,
        borderColor = {kindColor[1], kindColor[2], kindColor[3], 255},
        flexShrink = 0,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    UI.Label {
                        text = tag.name or tag.id or "未知词条",
                        flexGrow = 1,
                        flexShrink = 1,
                        fontSize = 16,
                        fontWeight = "bold",
                        fontColor = textColor,
                    },
                    UI.Panel {
                        paddingHorizontal = 8,
                        paddingVertical = 3,
                        backgroundColor = {28, 27, 36, 95},
                        borderRadius = 7,
                        flexShrink = 0,
                        children = {
                            UI.Label {
                                text = GetKindLabel(tag.kind),
                                fontSize = 11,
                                fontWeight = "bold",
                                fontColor = textColor,
                            },
                        },
                    },
                },
            },
            UI.Label {
                text = tag.description or "暂无说明",
                width = "100%",
                fontSize = 13,
                lineHeight = 1.35,
                fontColor = descriptionColor,
                whiteSpace = "normal",
                flexShrink = 1,
            },
        },
    }
end

function DailyChallengeView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        scoreLabel = nil,
        tagList = nil,
        startButton = nil,
        startAllowed = false,
        openingDelay = 0,
    }, DailyChallengeView)

    self.scoreLabel = UI.Label {
        text = "今日最佳：暂无",
        width = "100%",
        fontSize = 15,
        fontWeight = "bold",
        fontColor = COLORS.gold,
        textAlign = "center",
    }
    self.tagList = UI.Panel {
        width = "100%",
        gap = 8,
        flexDirection = "column",
    }
    self.startButton = MakeButton("开始今日挑战", COLORS.button, function()
        if self.startAllowed and self.callbacks.onStart then
            self.startAllowed = false
            self.callbacks.onStart()
        end
    end)

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        zIndex = 2200,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = "82%",
                maxWidth = 480,
                height = "56%",
                padding = 14,
                gap = 7,
                backgroundColor = COLORS.panel,
                borderRadius = 20,
                borderWidth = 3,
                borderColor = COLORS.border,
                boxShadow = {
                    { x = 0, y = 4, blur = 16, spread = 0, color = {0, 0, 0, 55} },
                },
                children = {
                    UI.Panel {
                        width = "100%",
                        flexShrink = 0,
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "每日挑战",
                                fontSize = 24,
                                fontWeight = "bold",
                                fontColor = COLORS.title,
                            },
                            UI.Button {
                                text = "×",
                                width = 40,
                                height = 36,
                                fontSize = 22,
                                borderRadius = 9,
                                borderWidth = 2,
                                borderColor = COLORS.border,
                                backgroundColor = {55, 40, 28, 255},
                                pressedBackgroundColor = {35, 25, 18, 255},
                                textColor = {255, 245, 230, 255},
                                onClick = function()
                                    self:Hide()
                                    if self.callbacks.onClose then self.callbacks.onClose() end
                                end,
                            },
                        },
                    },
                    UI.Label {
                        text = "今日词条",
                        width = "100%",
                        fontSize = 17,
                        fontWeight = "bold",
                        fontColor = COLORS.title,
                        marginTop = 2,
                    },
                    UI.ScrollView {
                        width = "100%",
                        flexGrow = 1,
                        flexBasis = 0,
                        flexShrink = 1,
                        scrollY = true,
                        scrollX = false,
                        showScrollbar = true,
                        children = {self.tagList},
                    },
                    UI.Panel {
                        width = "100%",
                        flexShrink = 0,
                        paddingVertical = 7,
                        backgroundColor = COLORS.panelInner,
                        borderRadius = 10,
                        borderWidth = 1,
                        borderColor = COLORS.borderLight,
                        children = {self.scoreLabel},
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = 8,
                        flexShrink = 0,
                        children = {
                            UI.Panel {
                                width = "50%",
                                children = {
                                    MakeButton("查看排行榜", {107, 125, 120, 255}, function()
                                        if self.callbacks.onLeaderboard then
                                            self.callbacks.onLeaderboard()
                                        end
                                    end),
                                },
                            },
                            UI.Panel {
                                width = "50%",
                                children = {self.startButton},
                            },
                        },
                    },
                },
            },
        },
    }

    return self
end

function DailyChallengeView:GetRoot()
    return self.root
end

function DailyChallengeView:Show(challenge, progress)
    challenge = challenge or {}
    progress = progress or {}

    self.tagList:RemoveAllChildren()
    for _, tag in ipairs(challenge.tags or {}) do
        self.tagList:AddChild(MakeTagCard(tag))
    end

    local bestScore = progress.bestScore or 0
    self.scoreLabel:SetText(bestScore > 0 and ("今日最佳：" .. tostring(bestScore)) or "今日最佳：暂无")

    if progress.completed == true then
        self.startButton:SetText("今日挑战已完成")
        self.startButton:SetDisabled(true)
        self.startAllowed = false
    elseif progress.freeAttemptUsed == true then
        self.startButton:SetText("今日次数已用尽")
        self.startButton:SetDisabled(true)
        self.startAllowed = false
    else
        self.startButton:SetText("开始今日挑战")
        self.startButton:SetDisabled(true)
        self.startAllowed = false
        self.openingDelay = 0.25
    end

    self.root:SetVisible(true)
end

function DailyChallengeView:Update(dt)
    if self.openingDelay <= 0 then return end
    self.openingDelay = math.max(0, self.openingDelay - (dt or 0))
    if self.openingDelay == 0 then
        self.startAllowed = true
        self.startButton:SetDisabled(false)
    end
end

function DailyChallengeView:Hide()
    self.openingDelay = 0
    self.startAllowed = false
    self.root:SetVisible(false)
end

return DailyChallengeView
