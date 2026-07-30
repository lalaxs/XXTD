-- views/LeaderboardView.lua
-- 玩家分数排行榜与每日挑战入口。

local UI = require("urhox-libs/UI")

local LeaderboardView = {}
LeaderboardView.__index = LeaderboardView

local COLORS = {
    overlay = {0, 0, 0, 165},
    panel = {232, 218, 185, 255},
    panelInner = {248, 239, 215, 255},
    listBackground = {232, 228, 210, 255},
    border = {132, 95, 52, 235},
    borderDark = {80, 56, 34, 255},
    title = {55, 38, 25, 255},
    text = {72, 52, 32, 255},
    muted = {116, 88, 56, 255},
    header = {73, 121, 102, 255},
    headerLight = {109, 159, 144, 255},
    gold = {216, 171, 67, 255},
    silver = {142, 157, 137, 255},
    bronze = {176, 130, 76, 255},
    green = {109, 159, 144, 255},
    greenDark = {55, 116, 95, 255},
    greenRow = {217, 232, 220, 255},
    goldRow = {246, 229, 179, 255},
    bronzeRow = {235, 210, 171, 255},
    plainRow = {243, 240, 230, 255},
    myRow = {250, 230, 166, 255},
}

local function WithAlpha(color, alpha)
    return {color[1], color[2], color[3], alpha}
end

local function SoftShadow()
    return {{x = 0, y = 5, blur = 14, spread = 0, color = {0, 0, 0, 70}}}
end

local function HardShadow(color)
    return {{x = 2, y = 3, blur = 0, spread = 0, color = color or {80, 56, 34, 75}}}
end

local function GetRankStyle(rank)
    if rank == 1 then
        return COLORS.gold, COLORS.goldRow, {255, 248, 220, 255}, true
    end
    if rank == 2 then
        return COLORS.silver, COLORS.greenRow, COLORS.title, true
    end
    if rank == 3 then
        return COLORS.bronze, COLORS.bronzeRow, COLORS.title, true
    end
    return COLORS.muted, COLORS.plainRow, COLORS.muted, false
end

local function GetRankColor(rank)
    local color = GetRankStyle(rank)
    return color
end

local function GetRowColor(rank)
    local _, rowColor = GetRankStyle(rank)
    return rowColor
end

local function CreateRankBadge(rank, isMe)
    if not rank and isMe then
        return UI.Label {
            text = "未上榜",
            width = 48,
            flexShrink = 0,
            fontSize = 11,
            fontWeight = "bold",
            fontColor = COLORS.muted,
        }
    end

    local color, _, textColor, isPodium = GetRankStyle(rank)
    if not isPodium then
        return UI.Label {
            text = tostring(rank),
            width = 48,
            flexShrink = 0,
            fontSize = rank > 999 and 12 or 17,
            fontWeight = "bold",
            fontColor = textColor,
            textAlign = "center",
        }
    end

    return UI.Panel {
        width = 52,
        height = 52,
        flexShrink = 0,
        alignItems = "center",
        justifyContent = "center",
        borderRadius = 10,
        borderWidth = 2,
        borderColor = WithAlpha(color, 235),
        backgroundColor = WithAlpha(color, rank == 1 and 210 or 90),
        boxShadow = HardShadow(WithAlpha(color, 60)),
        children = {
            UI.Label {
                text = tostring(rank),
                fontSize = 19,
                fontWeight = "bold",
                fontColor = textColor,
            },
        },
    }
end

local function CreateIdentityIcon(entry, isMe)
    local color = isMe and COLORS.gold or GetRankColor(entry.rank)
    return UI.Panel {
        width = 46,
        height = 46,
        flexShrink = 0,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = WithAlpha(color, 72),
        borderRadius = 7,
        borderWidth = 2,
        borderColor = WithAlpha(color, 210),
        children = {
            UI.Label {
                text = isMe and "我" or "修",
                fontSize = 20,
                fontWeight = "bold",
                fontColor = COLORS.title,
            },
        },
    }
end

local function CreateLeaderboardRow(entry, isMe)
    local rankColor, rowColor, _, isPodium = GetRankStyle(entry.rank)
    local nickname = entry.nickname or "未知玩家"
    return UI.Panel {
        width = "100%",
        height = 72,
        paddingHorizontal = 14,
        flexShrink = 0,
        flexDirection = "row",
        alignItems = "center",
        gap = 12,
        backgroundColor = rowColor,
        borderRadius = 10,
        borderWidth = isMe and 3 or (isPodium and 2 or 1),
        borderColor = isMe and rankColor or WithAlpha(rankColor, isPodium and 175 or 100),
        boxShadow = isMe and HardShadow(WithAlpha(rankColor, 65)) or nil,
        children = {
            CreateRankBadge(entry.rank, isMe),
            UI.Label {
                text = nickname,
                flexGrow = 1,
                flexShrink = 1,
                fontSize = 17,
                fontWeight = "bold",
                fontColor = COLORS.title,
                maxLines = 1,
            },
            UI.Label {
                text = tostring(entry.score or 0),
                width = 84,
                flexShrink = 0,
                fontSize = 18,
                fontWeight = "bold",
                fontColor = rankColor,
                textAlign = "right",
            },
        },
    }
end

local function CreateMessageCard(text)
    return UI.Panel {
        width = "100%",
        flexGrow = 1,
        minHeight = 260,
        padding = 24,
        alignItems = "center",
        justifyContent = "center",
        pointerEvents = "none",
        children = {
            UI.Label {
                text = text,
                width = "100%",
                fontSize = 16,
                lineHeight = 1.55,
                fontColor = COLORS.muted,
                textAlign = "center",
                whiteSpace = "normal",
            },
        },
    }
end

function LeaderboardView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        selectedTab = "score",
        scoreTab = nil,
        dailyTab = nil,
        refreshButton = nil,
        listPanel = nil,
        myScorePanel = nil,
        dailyChallengeId = nil,
        selectTab = nil,
    }, LeaderboardView)

    self.listPanel = UI.Panel {
        width = "100%",
        gap = 7,
        padding = 7,
        backgroundColor = {0, 0, 0, 0},
        borderWidth = 0,
    }
    local scrollView = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
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
    }
    self.myScorePanel = UI.Panel {
        width = "100%",
        flexShrink = 0,
        gap = 5,
    }

    local function SelectTab(tab)
        self.selectedTab = tab
        local scoreSelected = tab == "score"
        self.scoreTab:SetStyle({
            backgroundColor = scoreSelected and COLORS.header or COLORS.panelInner,
            textColor = scoreSelected and {255, 248, 225, 255} or COLORS.muted,
            borderColor = scoreSelected and COLORS.header or COLORS.border,
        })
        self.dailyTab:SetStyle({
            backgroundColor = scoreSelected and COLORS.panelInner or COLORS.header,
            textColor = scoreSelected and COLORS.muted or {255, 248, 225, 255},
            borderColor = scoreSelected and COLORS.border or COLORS.header,
        })
        self.refreshButton:SetVisible(true)
        if scoreSelected then
            self:ShowLoading()
            if self.callbacks.onRefresh then self.callbacks.onRefresh() end
        else
            self:ShowDailyLoading()
            if self.callbacks.onRefreshDaily then self.callbacks.onRefreshDaily() end
        end
    end

    self.scoreTab = UI.Button {
        text = "玩家排行",
        width = 86,
        height = 35,
        fontSize = 13,
        fontWeight = "bold",
        borderRadius = 8,
        borderWidth = 2,
        borderColor = COLORS.header,
        backgroundColor = COLORS.header,
        textColor = {255, 248, 225, 255},
        onClick = function() SelectTab("score") end,
    }
    self.dailyTab = UI.Button {
        text = "每日挑战",
        height = 35,
        width = 86,
        fontSize = 13,
        fontWeight = "bold",
        borderRadius = 8,
        borderWidth = 2,
        borderColor = COLORS.border,
        backgroundColor = COLORS.panelInner,
        textColor = COLORS.muted,
        onClick = function() SelectTab("daily") end,
    }
    self.refreshButton = UI.Button {
        text = "刷新",
        width = 58,
        height = 35,
        fontSize = 12,
        fontWeight = "bold",
        borderRadius = 8,
        borderWidth = 2,
        borderColor = COLORS.borderDark,
        backgroundColor = COLORS.green,
        textColor = {255, 248, 225, 255},
        onClick = function()
            if self.selectedTab == "daily" then
                self:ShowDailyLoading()
                if self.callbacks.onRefreshDaily then self.callbacks.onRefreshDaily() end
            else
                self:ShowLoading()
                if self.callbacks.onRefresh then self.callbacks.onRefresh() end
            end
        end,
    }

    self.selectTab = SelectTab

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        zIndex = 2100,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        paddingHorizontal = 7,
        children = {
            UI.Panel {
                width = "96%",
                maxWidth = 720,
                height = "88%",
                padding = 11,
                gap = 8,
                backgroundColor = COLORS.panel,
                borderRadius = 15,
                borderWidth = 3,
                borderColor = COLORS.borderDark,
                boxShadow = SoftShadow(),
                children = {
                    UI.Panel {
                        width = "100%",
                        height = 42,
                        flexShrink = 0,
                        flexDirection = "row",
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "排行榜",
                                fontSize = 25,
                                fontWeight = "bold",
                                fontColor = COLORS.title,
                            },
                            UI.Button {
                                text = "×",
                                position = "absolute",
                                right = 5,
                                top = 4,
                                width = 34,
                                height = 34,
                                fontSize = 20,
                                borderRadius = 8,
                                borderWidth = 2,
                                borderColor = {239, 212, 174, 255},
                                backgroundColor = COLORS.greenDark,
                                pressedBackgroundColor = COLORS.green,
                                textColor = {255, 248, 225, 255},
                                onClick = function() self:Hide() end,
                            },
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            UI.Panel {
                                flexDirection = "row",
                                gap = 6,
                                children = {self.scoreTab, self.dailyTab},
                            },
                            self.refreshButton,
                        },
                    },
                    UI.Panel {
                        width = "100%",
                        height = 28,
                        flexShrink = 0,
                        paddingHorizontal = 12,
                        flexDirection = "row",
                        alignItems = "center",
                        backgroundColor = COLORS.headerLight,
                        borderRadius = 7,
                        children = {
                            UI.Label {text = "排名", width = 55, fontSize = 12, fontWeight = "bold", fontColor = {255, 248, 225, 255}},
                            UI.Label {text = "玩家昵称", flexGrow = 1, fontSize = 12, fontWeight = "bold", fontColor = {255, 248, 225, 255}},
                            UI.Label {text = "积分", width = 72, fontSize = 12, fontWeight = "bold", fontColor = {255, 248, 225, 255}, textAlign = "right"},
                        },
                    },
                    scrollView,
                    self.myScorePanel,
                },
            },
        },
    }

    return self
end

function LeaderboardView:GetRoot()
    return self.root
end

function LeaderboardView:SetDailyChallengeId(challengeId)
    self.dailyChallengeId = challengeId
end

function LeaderboardView:ShowDaily()
    if self.selectTab then
        self.selectTab("daily")
    end
end

function LeaderboardView:ShowLoading()
    if self.selectedTab ~= "score" then return end
    self.listPanel:RemoveAllChildren()
    self.listPanel:AddChild(CreateMessageCard("正在读取云端成绩…"))
    self.myScorePanel:RemoveAllChildren()
    self.myScorePanel:AddChild(UI.Label {
        text = "我的排名",
        fontSize = 12,
        fontWeight = "bold",
        fontColor = COLORS.title,
    })
    self.myScorePanel:AddChild(CreateLeaderboardRow({
        rank = nil,
        nickname = "我",
        score = 0,
        difficulty = 1,
        turns = 0,
        waves = 0,
        victory = false,
    }, true))
    self.root:SetVisible(true)
end

function LeaderboardView:SetEntries(entries, myEntry, errorMessage)
    if self.selectedTab ~= "score" then return end
    self.listPanel:RemoveAllChildren()
    self.myScorePanel:RemoveAllChildren()

    if errorMessage then
        self.listPanel:AddChild(CreateMessageCard(errorMessage .. "\n请稍后点击刷新重试"))
    elseif not entries or #entries == 0 then
        self.listPanel:AddChild(CreateMessageCard("暂无玩家成绩\n完成一局游戏后会自动上传你的最佳成绩"))
    else
        for _, entry in ipairs(entries) do
            self.listPanel:AddChild(CreateLeaderboardRow(entry, false))
        end
    end

    if not myEntry then
        myEntry = {
            rank = nil,
            nickname = "我",
            score = 0,
            difficulty = 1,
            turns = 0,
            waves = 0,
            victory = false,
        }
    end
    self.myScorePanel:AddChild(UI.Label {
        text = "我的排名",
        fontSize = 12,
        fontWeight = "bold",
        fontColor = COLORS.title,
    })
    self.myScorePanel:AddChild(CreateLeaderboardRow(myEntry, true))
end

function LeaderboardView:ShowDailyLoading()
    if self.selectedTab ~= "daily" then return end
    self.listPanel:RemoveAllChildren()
    self.listPanel:AddChild(CreateMessageCard("正在读取今日挑战排行榜…"))
    self.myScorePanel:RemoveAllChildren()
    self.myScorePanel:AddChild(UI.Label {
        text = "我的排名",
        fontSize = 12,
        fontWeight = "bold",
        fontColor = COLORS.title,
    })
    self.myScorePanel:AddChild(CreateLeaderboardRow({
        rank = nil,
        nickname = "我",
        score = 0,
    }, true))
    self.root:SetVisible(true)
end

function LeaderboardView:SetDailyEntries(entries, myEntry, errorMessage)
    if self.selectedTab ~= "daily" then return end
    self.listPanel:RemoveAllChildren()
    self.myScorePanel:RemoveAllChildren()

    if errorMessage then
        self.listPanel:AddChild(CreateMessageCard(errorMessage .. "\n请稍后点击刷新重试"))
    elseif not entries or #entries == 0 then
        self.listPanel:AddChild(CreateMessageCard("今日暂无玩家成绩\n完成每日挑战后即可登榜"))
    else
        for _, entry in ipairs(entries) do
            self.listPanel:AddChild(CreateLeaderboardRow(entry, false))
        end
    end

    if not myEntry then
        myEntry = {
            rank = nil,
            nickname = "我",
            score = 0,
        }
    end
    self.myScorePanel:AddChild(UI.Label {
        text = "我的今日排名",
        fontSize = 12,
        fontWeight = "bold",
        fontColor = COLORS.title,
    })
    self.myScorePanel:AddChild(CreateLeaderboardRow(myEntry, true))
end

function LeaderboardView:Hide()
    self.root:SetVisible(false)
end

return LeaderboardView
