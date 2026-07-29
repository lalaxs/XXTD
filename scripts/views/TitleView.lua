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

    local titleLogo = UI.Panel {
        width = "78%",
        maxWidth = 640,
        aspectRatio = 1472 / 940,
        flexShrink = 0,
        backgroundImage = "image/logo.png",
        backgroundFit = "contain",
        backgroundColor = {0, 0, 0, 0},
        pointerEvents = "none",
    }

    local mainButtonPanel = UI.Panel {
        width = "68.2%",
        maxWidth = 433,
        gap = 14,
        alignItems = "center",
        flexShrink = 0,
        backgroundColor = {0, 0, 0, 0},
        children = {
            MakeMenuButton(
                "继续游戏",
                COLORS.parchment,
                COLORS.parchmentPressed,
                COLORS.parchmentBorder,
                COLORS.darkText,
                function()
                    Invoke("onContinue")
                end
            ),
            MakeMenuButton(
                "开始游戏",
                COLORS.green,
                COLORS.greenPressed,
                COLORS.greenBorder,
                COLORS.lightText,
                function()
                    Invoke("onStart")
                end
            ),
        },
    }

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
                children = {
                    MakeSquareEntry("每日挑战", MakeDailyChallengeIcon(), function()
                        if self.callbacks.onDailyChallenge then
                            self.callbacks.onDailyChallenge()
                        end
                    end),
                    MakeSquareEntry("排行榜", MakeLeaderboardIcon(), function()
                        if self.callbacks.onLeaderboard then
                            self.callbacks.onLeaderboard()
                        end
                    end),
                    MakeSquareEntry("游戏设置", MakeSettingsIcon(), function()
                        self.noticeLabel:SetText("游戏设置暂未开放")
                    end),
                },
            },
            self.noticeLabel,
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
                    titleLogo,
                    UI.Panel { width = "100%", height = "13%", flexShrink = 0, pointerEvents = "none" },
                    mainButtonPanel,
                    UI.Panel { width = "100%", height = "3%", flexShrink = 0, pointerEvents = "none" },
                    quickEntryPanel,
                    UI.Panel { width = "100%", flexGrow = 1, flexBasis = 0, pointerEvents = "none" },
                },
            },
        },
    }

    return self
end

function TitleView:GetRoot()
    return self.root
end

function TitleView:Show()
    self.noticeLabel:SetText("")
    self.root:SetVisible(true)
end

function TitleView:Hide()
    self.root:SetVisible(false)
end

return TitleView
