-- views/TitleView.lua
-- 游戏启动标题页面：场景背景、标题与主菜单入口。

local UI = require("urhox-libs/UI")

local TitleView = {}
TitleView.__index = TitleView

local COLORS = {
    fallbackBackground = {196, 220, 218, 255},
    green = {109, 159, 144, 255},
    greenPressed = {76, 144, 123, 255},
    greenBorder = {55, 116, 95, 255},
    parchment = {239, 212, 174, 255},
    parchmentPressed = {216, 175, 120, 255},
    parchmentBorder = {135, 113, 81, 255},
    darkText = {58, 39, 15, 255},
    lightText = {255, 245, 230, 255},
    icon = {80, 58, 35, 255},
    iconMuted = {135, 113, 81, 255},
    notice = {55, 116, 95, 255},
}

local function MakeMenuButton(text, color, pressedColor, borderColor, textColor, onClick)
    return UI.Button {
        text = text,
        width = "100%",
        height = 65,
        flexShrink = 0,
        fontSize = 22,
        fontWeight = "bold",
        borderRadius = 11,
        borderWidth = 3,
        borderColor = borderColor,
        backgroundColor = color,
        pressedBackgroundColor = pressedColor,
        textColor = textColor,
        boxShadow = {
            { x = 0, y = 3, blur = 5, spread = 0, color = {58, 39, 15, 105}, inset = true },
            { x = 0, y = -2, blur = 3, spread = 0, color = {255, 245, 220, 105}, inset = true },
        },
        onClick = onClick,
    }
end

local function PlayEntrance(widget, delay, startY, startScale, onComplete)
    local revealDuration = 0.9
    local duration = delay + revealDuration
    local revealStart = delay / duration
    local revealEnd = (delay + 0.62) / duration

    widget:StopAnimation()
    widget:SetStyle({
        opacity = 0,
        translateY = startY,
        scale = startScale,
    })
    widget:Animate({
        keyframes = {
            [0] = { opacity = 0, translateY = startY, scale = startScale },
            [revealStart] = { opacity = 0, translateY = startY, scale = startScale },
            [revealEnd] = { opacity = 1, translateY = 0, scale = 1.02 },
            [1] = { opacity = 1, translateY = 0, scale = 1.0 },
        },
        duration = duration,
        easing = "easeOutCubic",
        fillMode = "forwards",
        onComplete = onComplete,
    })
end

local function MakeLeaderboardIcon()
    return UI.Panel {
        width = 56,
        height = 46,
        flexShrink = 0,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "flex-end",
        gap = 5,
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = 14,
                height = 25,
                backgroundColor = COLORS.iconMuted,
                borderRadius = {5, 5, 2, 2},
                borderWidth = 2,
                borderColor = COLORS.icon,
            },
            UI.Panel {
                width = 14,
                height = 42,
                backgroundColor = COLORS.icon,
                borderRadius = {5, 5, 2, 2},
                borderWidth = 2,
                borderColor = COLORS.parchment,
            },
            UI.Panel {
                width = 14,
                height = 33,
                backgroundColor = COLORS.green,
                borderRadius = {5, 5, 2, 2},
                borderWidth = 2,
                borderColor = COLORS.icon,
            },
        },
    }
end

local function MakeDailyChallengeIcon()
    local function MakeDayDot(isHighlighted)
        return UI.Panel {
            width = 7,
            height = 7,
            borderRadius = 4,
            backgroundColor = isHighlighted and COLORS.icon or COLORS.iconMuted,
            flexShrink = 0,
        }
    end

    return UI.Panel {
        width = 51,
        height = 46,
        flexShrink = 0,
        padding = 6,
        gap = 4,
        backgroundColor = COLORS.parchmentPressed,
        borderWidth = 3,
        borderColor = COLORS.icon,
        borderRadius = 9,
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = "100%",
                height = 7,
                flexShrink = 0,
                backgroundColor = COLORS.icon,
                borderRadius = 3,
            },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                children = {
                    MakeDayDot(false),
                    MakeDayDot(true),
                    MakeDayDot(false),
                },
            },
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                children = {
                    MakeDayDot(true),
                    MakeDayDot(false),
                    MakeDayDot(true),
                },
            },
        },
    }
end

local function MakeSettingsIcon()
    local function MakeSliderRow(knobAlign)
        local beforeWidth = knobAlign == "left" and 8 or (knobAlign == "center" and 20 or 31)
        local afterWidth = 39 - beforeWidth
        return UI.Panel {
            width = 51,
            height = 11,
            flexShrink = 0,
            flexDirection = "row",
            alignItems = "center",
            pointerEvents = "none",
            children = {
                UI.Panel {
                    width = beforeWidth,
                    height = 4,
                    flexShrink = 0,
                    backgroundColor = COLORS.iconMuted,
                    borderRadius = 2,
                },
                UI.Panel {
                    width = 11,
                    height = 11,
                    flexShrink = 0,
                    borderRadius = 6,
                    backgroundColor = COLORS.icon,
                    borderWidth = 2,
                    borderColor = COLORS.parchment,
                },
                UI.Panel {
                    width = afterWidth,
                    height = 4,
                    flexShrink = 0,
                    backgroundColor = COLORS.iconMuted,
                    borderRadius = 2,
                },
            },
        }
    end

    return UI.Panel {
        width = 51,
        height = 46,
        flexShrink = 0,
        gap = 7,
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "none",
        children = {
            MakeSliderRow("left"),
            MakeSliderRow("right"),
            MakeSliderRow("center"),
        },
    }
end

local function MakeSquareEntry(text, icon, onTap)
    return UI.Panel {
        width = "24%",
        aspectRatio = 1,
        flexShrink = 0,
        padding = 8,
        gap = 6,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = COLORS.parchment,
        borderWidth = 3,
        borderColor = COLORS.parchmentBorder,
        borderRadius = 11,
        boxShadow = {
            { x = 0, y = 3, blur = 5, spread = 0, color = {58, 39, 15, 110}, inset = true },
            { x = 0, y = -2, blur = 3, spread = 0, color = {255, 245, 220, 120}, inset = true },
        },
        transition = "scale 0.1s easeOut, backgroundColor 0.1s easeOut",
        onTapStart = function(_, widget)
            widget:SetStyle({ scale = 0.96, backgroundColor = COLORS.parchmentPressed })
        end,
        onTapEnd = function(_, widget)
            widget:SetStyle({ scale = 1.0, backgroundColor = COLORS.parchment })
        end,
        onTap = function()
            onTap()
        end,
        children = {
            icon,
            UI.Label {
                text = text,
                width = "100%",
                fontSize = 13,
                fontWeight = "bold",
                fontColor = COLORS.darkText,
                textAlign = "center",
                pointerEvents = "none",
            },
        },
    }
end

function TitleView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        noticeLabel = nil,
        titleLogo = nil,
        continueButton = nil,
        startButton = nil,
        firstStartGuide = nil,
        firstStartGuideOverlay = nil,
        firstStartGuideButton = nil,
        firstStartGuidance = false,
        overwriteConfirmPanel = nil,
        hasSave = false,
        canContinueSave = false,
        saveLoading = false,
        mainButtons = {},
        quickEntries = {},
    }, TitleView)

    local function Invoke(name)
        local callback = self.callbacks[name]
        if callback then
            callback()
        end
    end

    self.noticeLabel = UI.Label {
        text = "",
        width = "100%",
        height = 28,
        fontSize = 14,
        fontWeight = "bold",
        fontColor = COLORS.notice,
        textAlign = "center",
        flexShrink = 0,
    }

    self.titleLogo = UI.Panel {
        width = "78%",
        maxWidth = 640,
        aspectRatio = 1472 / 940,
        flexShrink = 0,
        backgroundImage = "image/logo.png",
        backgroundFit = "contain",
        backgroundColor = {0, 0, 0, 0},
        transformOrigin = "center",
        pointerEvents = "none",
    }

    local function HandleStartClick()
        print("[Tutorial] 玩家点击开始游戏引导目标")
        if self.hasSave then
            self.overwriteConfirmPanel:SetVisible(true)
        else
            Invoke("onStart")
        end
    end

    local continueButton = MakeMenuButton(
        "继续游戏",
        COLORS.parchment,
        COLORS.parchmentPressed,
        COLORS.parchmentBorder,
        COLORS.darkText,
        function()
            Invoke("onContinue")
        end
    )
    continueButton:SetVisible(false)
    self.continueButton = continueButton
    local startButton = MakeMenuButton(
        "开始游戏",
        COLORS.green,
        COLORS.greenPressed,
        COLORS.greenBorder,
        COLORS.lightText,
        HandleStartClick
    )
    self.mainButtons = { continueButton, startButton }
    self.startButton = startButton

    local guideButton = MakeMenuButton(
        "开始游戏",
        {126, 187, 153, 255},
        COLORS.greenPressed,
        {255, 231, 137, 255},
        COLORS.lightText,
        HandleStartClick
    )
    guideButton:SetStyle({
        borderWidth = 4,
        boxShadow = {
            { x = 0, y = 0, blur = 18, spread = 5, color = {255, 222, 112, 210} },
            { x = 0, y = 3, blur = 5, spread = 0, color = {58, 39, 15, 105}, inset = true },
            { x = 0, y = -2, blur = 3, spread = 0, color = {255, 245, 220, 135}, inset = true },
        },
    })
    self.firstStartGuideButton = guideButton

    self.firstStartGuide = UI.Panel {
        width = "100%",
        marginTop = 16,
        padding = {14, 18},
        gap = 4,
        alignItems = "center",
        flexShrink = 0,
        backgroundColor = {245, 222, 181, 252},
        borderWidth = 3,
        borderColor = {255, 231, 137, 255},
        borderRadius = 14,
        boxShadow = {
            { x = 0, y = 5, blur = 14, spread = 0, color = {0, 0, 0, 150} },
        },
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "第一步",
                fontSize = 14,
                fontWeight = "bold",
                fontColor = COLORS.greenBorder,
                textAlign = "center",
                pointerEvents = "none",
            },
            UI.Label {
                text = "点击上方「开始游戏」",
                width = "100%",
                fontSize = 19,
                fontWeight = "bold",
                fontColor = COLORS.darkText,
                textAlign = "center",
                pointerEvents = "none",
            },
            UI.Label {
                text = "踏上修行之路",
                width = "100%",
                fontSize = 14,
                fontColor = {105, 75, 38, 255},
                textAlign = "center",
                pointerEvents = "none",
            },
        },
    }

    local mainButtonPanel = UI.Panel {
        width = "68.2%",
        maxWidth = 433,
        gap = 14,
        alignItems = "center",
        flexShrink = 0,
        backgroundColor = {0, 0, 0, 0},
        children = { continueButton, startButton },
    }

    self.firstStartGuideOverlay = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        zIndex = 30,
        backgroundColor = {10, 15, 13, 205},
        pointerEvents = "auto",
        onClick = function()
            print("[Tutorial] 已拦截开始游戏按钮之外的点击")
        end,
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                flexDirection = "column",
                alignItems = "center",
                pointerEvents = "box-none",
                children = {
                    UI.Panel { width = "100%", height = "17%", flexShrink = 0, pointerEvents = "none" },
                    UI.Panel {
                        width = "78%",
                        maxWidth = 640,
                        aspectRatio = 1472 / 940,
                        flexShrink = 0,
                        backgroundColor = {0, 0, 0, 0},
                        pointerEvents = "none",
                    },
                    UI.Panel { width = "100%", height = "13%", flexShrink = 0, pointerEvents = "none" },
                    UI.Panel {
                        width = "68.2%",
                        maxWidth = 433,
                        alignItems = "center",
                        flexShrink = 0,
                        backgroundColor = {0, 0, 0, 0},
                        pointerEvents = "box-none",
                        children = { guideButton, self.firstStartGuide },
                    },
                    UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, pointerEvents = "none" },
                },
            },
        },
    }

    local dailyEntry = MakeSquareEntry("每日挑战", MakeDailyChallengeIcon(), function()
        if self.callbacks.onDailyChallenge then
            self.callbacks.onDailyChallenge()
        end
    end)
    local leaderboardEntry = MakeSquareEntry("排行榜", MakeLeaderboardIcon(), function()
        if self.callbacks.onLeaderboard then
            self.callbacks.onLeaderboard()
        end
    end)
    local settingsEntry = MakeSquareEntry("游戏设置", MakeSettingsIcon(), function()
        if self.callbacks.onSettings then
            self.callbacks.onSettings()
        end
    end)
    self.quickEntries = { dailyEntry, leaderboardEntry, settingsEntry }

    local quickEntryPanel = UI.Panel {
        width = "86.9%",
        maxWidth = 557,
        flexShrink = 0,
        gap = 8,
        alignItems = "center",
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "center",
                alignItems = "center",
                gap = 14,
                children = self.quickEntries,
            },
            self.noticeLabel,
        },
    }

    self.overwriteConfirmPanel = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        zIndex = 20,
        backgroundColor = {0, 0, 0, 185},
        alignItems = "center",
        justifyContent = "center",
        onClick = function() end,
        children = {
            UI.Panel {
                width = "82%",
                maxWidth = 410,
                padding = 20,
                gap = 14,
                backgroundColor = COLORS.parchment,
                borderRadius = 16,
                borderWidth = 3,
                borderColor = COLORS.parchmentBorder,
                children = {
                    UI.Label {
                        text = "确认开始新游戏？",
                        width = "100%",
                        fontSize = 22,
                        fontWeight = "bold",
                        fontColor = COLORS.darkText,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "当前普通游戏进度将被丢弃，并从头开始。每日挑战存档不会受影响。此操作无法撤销。",
                        width = "100%",
                        fontSize = 14,
                        lineHeight = 1.5,
                        fontColor = COLORS.darkText,
                        whiteSpace = "normal",
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = 10,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = "48%",
                                height = 48,
                                backgroundColor = COLORS.parchmentPressed,
                                pressedBackgroundColor = COLORS.parchmentBorder,
                                textColor = COLORS.darkText,
                                onClick = function()
                                    self.overwriteConfirmPanel:SetVisible(false)
                                end,
                            },
                            UI.Button {
                                text = "丢弃并开始",
                                width = "48%",
                                height = 48,
                                backgroundColor = {165, 62, 50, 255},
                                pressedBackgroundColor = {125, 42, 35, 255},
                                textColor = COLORS.lightText,
                                onClick = function()
                                    self.overwriteConfirmPanel:SetVisible(false)
                                    Invoke("onStart")
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    self.root = UI.Panel {
        visible = true,
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        zIndex = 2000,
        backgroundColor = COLORS.fallbackBackground,
        backgroundImage = "image/title (2).png",
        backgroundFit = "cover",
        alignItems = "center",
        justifyContent = "center",
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                flexDirection = "column",
                alignItems = "center",
                children = {
                    UI.Panel { width = "100%", height = "17%", flexShrink = 0, pointerEvents = "none" },
                    self.titleLogo,
                    UI.Panel { width = "100%", height = "13%", flexShrink = 0, pointerEvents = "none" },
                    mainButtonPanel,
                    UI.Panel { width = "100%", height = "3%", flexShrink = 0, pointerEvents = "none" },
                    quickEntryPanel,
                    UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, pointerEvents = "none" },
                },
            },
            self.firstStartGuideOverlay,
            self.overwriteConfirmPanel,
        },
    }

    return self
end

function TitleView:GetRoot()
    return self.root
end

function TitleView:SetFirstStartGuidance(enabled)
    local visible = enabled == true
    self.firstStartGuidance = visible
    if self.firstStartGuideOverlay then
        self.firstStartGuideOverlay:SetVisible(visible)
    end
    if self.startButton then
        self.startButton:SetVisible(not visible)
    end
    if not self.firstStartGuideButton then return end
    self.firstStartGuideButton:StopAnimation()
    self.firstStartGuideButton:SetStyle({ opacity = 1, scale = 1.0, translateY = 0 })
    if visible then
        print("[Tutorial] 开始游戏强制引导遮罩已显示")
        self.firstStartGuideButton:Animate({
            keyframes = {
                [0] = { scale = 1.0 },
                [1] = { scale = 1.065 },
            },
            duration = 0.68,
            easing = "easeInOut",
            loop = true,
            direction = "alternate",
        })
    end
end

function TitleView:SetSaveState(hasSave, canContinue)
    self.hasSave = hasSave == true
    self.canContinueSave = self.hasSave
    self.saveLoading = false
    if self.continueButton then
        self.continueButton:SetVisible(self.hasSave)
        self.continueButton:SetDisabled(false)
    end
    if self.startButton then
        self.startButton:SetDisabled(false)
        self.startButton:SetText("开始游戏")
        self.startButton:SetVisible(not self.firstStartGuidance)
    end
    if self.firstStartGuideButton then
        self.firstStartGuideButton:SetDisabled(false)
        self.firstStartGuideButton:SetText("开始游戏")
    end
end

function TitleView:SetSaveLoading(loading)
    self.saveLoading = loading == true
    if self.continueButton then
        self.continueButton:SetDisabled(self.saveLoading)
    end
    if self.startButton then
        self.startButton:SetDisabled(self.saveLoading)
        self.startButton:SetText(self.saveLoading and "正在读取存档..." or "开始游戏")
    end
    if self.firstStartGuideButton then
        self.firstStartGuideButton:SetDisabled(self.saveLoading)
        self.firstStartGuideButton:SetText(self.saveLoading and "正在读取存档..." or "开始游戏")
    end
end

function TitleView:Show()
    self.overwriteConfirmPanel:SetVisible(false)
    self.noticeLabel:SetText("")
    self.root:SetVisible(true)

    PlayEntrance(self.titleLogo, 0, -42, 0.94, function()
        self.titleLogo:Animate({
            keyframes = {
                [0] = { opacity = 1, scale = 1.0, translateY = 0 },
                [1] = { opacity = 1, scale = 1.018, translateY = -5 },
            },
            duration = 2.4,
            easing = "easeInOut",
            loop = true,
            direction = "alternate",
        })
    end)
    for index, button in ipairs(self.mainButtons) do
        PlayEntrance(button, 0.55 + (index - 1) * 0.32, 28, 0.93)
    end
    for index, entry in ipairs(self.quickEntries) do
        PlayEntrance(entry, 1.45 + (index - 1) * 0.26, 24, 0.94)
    end

end

function TitleView:Hide()
    self.titleLogo:StopAnimation()
    self.titleLogo:SetStyle({ opacity = 1, scale = 1.0, translateY = 0 })
    for _, button in ipairs(self.mainButtons) do
        button:StopAnimation()
        button:SetStyle({ opacity = 1, scale = 1.0, translateY = 0 })
    end
    for _, entry in ipairs(self.quickEntries) do
        entry:StopAnimation()
        entry:SetStyle({ opacity = 1, scale = 1.0, translateY = 0 })
    end
    self.root:SetVisible(false)
end

return TitleView
