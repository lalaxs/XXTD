-- views/MainMenuView.lua
-- 右下角功能入口弹窗：轮回强化 / 机缘 / 设置 / 放弃 / 保存并返回主界面。

local UI = require("urhox-libs/UI")

local MainMenuView = {}
MainMenuView.__index = MainMenuView

local COLORS = {
    overlay = {0, 0, 0, 150},
    panel = {240, 225, 195, 250},
    border = {140, 105, 60, 230},
    title = {55, 40, 28, 255},
    text = {70, 52, 34, 255},
    muted = {120, 95, 68, 255},
    button = {160, 120, 60, 255},
    danger = {165, 62, 50, 255},
}

local function MakeButton(text, color, onClick, onUIClick)
    return UI.Button {
        text = text,
        width = "100%",
        height = 54,
        fontSize = 18,
        fontWeight = "bold",
        borderRadius = 12,
        borderWidth = 2,
        borderColor = COLORS.border,
        backgroundColor = color or COLORS.button,
        pressedBackgroundColor = {120, 88, 45, 255},
        fontColor = {255, 245, 230, 255},
        onClick = function()
            if onUIClick then onUIClick() end
            if onClick then onClick() end
        end,
    }
end

local function RebuildStatusArea(container)
    container:RemoveAllChildren()
end

function MainMenuView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        infoLabel = nil,
        statusArea = nil,
        opportunityButton = nil,
        abandonConfirmPanel = nil,
        currentState = nil,
    }, MainMenuView)

    self.infoLabel = UI.Label {
        text = "",
        width = "100%",
        height = 44,
        fontSize = 14,
        lineHeight = 1.25,
        fontColor = COLORS.muted,
        textAlign = "left",
        flexShrink = 0,
    }

    self.statusArea = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        flexShrink = 1,
        padding = 14,
        gap = 9,
        backgroundColor = {246, 232, 198, 230},
        borderRadius = 14,
        borderWidth = 2,
        borderColor = {168, 122, 65, 210},
    }

    self.opportunityButton = MakeButton("机缘", COLORS.button, function()
        self:Hide()
        if self.callbacks.onBuffs then self.callbacks.onBuffs() end
    end, self.callbacks.onUIClick)

    local abandonConfirmPanel
    abandonConfirmPanel = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        zIndex = 20,
        backgroundColor = {0, 0, 0, 190},
        alignItems = "center",
        justifyContent = "center",
        onClick = function() end,
        children = {
            UI.Panel {
                width = "82%",
                maxWidth = 410,
                padding = 20,
                gap = 14,
                backgroundColor = COLORS.panel,
                borderRadius = 16,
                borderWidth = 3,
                borderColor = COLORS.border,
                children = {
                    UI.Label {
                        id = "abandonConfirmTitle",
                        text = "确认放弃当前轮回？",
                        width = "100%",
                        fontSize = 22,
                        fontWeight = "bold",
                        fontColor = COLORS.title,
                        textAlign = "center",
                    },
                    UI.Label {
                        id = "abandonConfirmDescription",
                        text = "放弃后本轮内容不会累计，也不会获得轮回点。随后将进入失败结算页面。",
                        width = "100%",
                        fontSize = 14,
                        lineHeight = 1.5,
                        fontColor = COLORS.text,
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
                                backgroundColor = COLORS.button,
                                pressedBackgroundColor = {120, 88, 45, 255},
                                textColor = {255, 245, 230, 255},
                                onClick = function()
                                    if self.callbacks.onUIClick then self.callbacks.onUIClick() end
                                    abandonConfirmPanel:SetVisible(false)
                                end,
                            },
                            UI.Button {
                                text = "确认放弃",
                                width = "48%",
                                height = 48,
                                backgroundColor = COLORS.danger,
                                pressedBackgroundColor = {120, 88, 45, 255},
                                textColor = {255, 245, 230, 255},
                                onClick = function()
                                    if self.callbacks.onUIClick then self.callbacks.onUIClick() end
                                    abandonConfirmPanel:SetVisible(false)
                                    self:Hide()
                                    if self.callbacks.onAbandonRun then self.callbacks.onAbandonRun() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    self.abandonConfirmPanel = abandonConfirmPanel

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = COLORS.overlay,
        alignItems = "center",
        justifyContent = "center",
        children = {
            UI.Panel {
                width = "90%",
                maxWidth = 520,
                height = "78%",
                padding = 20,
                gap = 12,
                backgroundColor = COLORS.panel,
                borderRadius = 20,
                borderWidth = 3,
                borderColor = COLORS.border,
                alignItems = "stretch",
                children = {
                    UI.Panel {
                        width = "100%",
                        flexShrink = 0,
                        gap = 6,
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row",
                                justifyContent = "space-between",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "功能菜单",
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
                                        borderColor = {80, 56, 34, 255},
                                        backgroundColor = {55, 40, 28, 255},
                                        pressedBackgroundColor = {35, 25, 18, 255},
                                        fontColor = {255, 245, 230, 255},
                                        onClick = function()
                                            if self.callbacks.onUIClick then self.callbacks.onUIClick() end
                                            self:Hide()
                                        end,
                                    },
                                },
                            },
                            self.infoLabel,
                        },
                    },
                    self.statusArea,
                    UI.Panel {
                        width = "100%",
                        height = 182,
                        flexShrink = 0,
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = 10,
                        children = {
                            UI.Panel {
                                width = "48%",
                                children = {
                                    MakeButton("轮回强化", COLORS.button, function()
                                        self:Hide()
                                        if self.callbacks.onReincarnation then self.callbacks.onReincarnation() end
                                    end, self.callbacks.onUIClick),
                                },
                            },
                            UI.Panel {
                                width = "48%",
                                children = { self.opportunityButton },
                            },
                            UI.Panel {
                                width = "48%",
                                children = {
                                    MakeButton("设置", COLORS.button, function()
                                        if self.callbacks.onSettings then self.callbacks.onSettings() end
                                    end, self.callbacks.onUIClick),
                                },
                            },
                            UI.Panel {
                                width = "48%",
                                children = {
                                    MakeButton("放弃", COLORS.danger, function()
                                        abandonConfirmPanel:SetVisible(true)
                                    end, self.callbacks.onUIClick),
                                },
                            },
                            UI.Panel {
                                width = "100%",
                                children = {
                                    MakeButton("保存并返回主界面", COLORS.button, function()
                                        self:Hide()
                                        if self.callbacks.onSaveAndReturnToTitle then
                                            self.callbacks.onSaveAndReturnToTitle()
                                        end
                                    end, self.callbacks.onUIClick),
                                },
                            },
                        },
                    },
                },
            },
            abandonConfirmPanel,
        },
    }

    return self
end

function MainMenuView:GetRoot()
    return self.root
end

function MainMenuView:Show(state)
    self.currentState = state
    local abandonTitle = self.abandonConfirmPanel:FindById("abandonConfirmTitle")
    local abandonDescription = self.abandonConfirmPanel:FindById("abandonConfirmDescription")
    if state and state.dailyChallenge then
        if abandonTitle then abandonTitle:SetText("确认放弃今日挑战？") end
        if abandonDescription then
            abandonDescription:SetText("放弃后立即结算当前分数，并计入今日最佳与排行榜；今日挑战次数也会消耗。")
        end
    else
        if abandonTitle then abandonTitle:SetText("确认放弃当前轮回？") end
        if abandonDescription then
            abandonDescription:SetText("放弃后本轮内容不会累计，也不会获得轮回点。随后将进入失败结算页面。")
        end
    end
    local challenge = state and state.dailyChallenge
    if challenge then
        local names = {}
        for _, tag in ipairs(challenge.tags or {}) do
            table.insert(names, tag.name or tag.id or "未知词条")
        end
        self.infoLabel:SetText("今日词条：" .. table.concat(names, " · "))
    else
        local difficulty = state and (state.difficulty or 1) or 1
        local reincarnation = state and (state.reincarnationCount or 0) or 0
        local points = state and (state.reincarnationPoints or 0) or 0
        self.infoLabel:SetText(string.format("难度 %d · 轮回 %d · 轮回点 %d", difficulty, reincarnation, points))
    end
    self.opportunityButton:SetText("机缘")
    RebuildStatusArea(self.statusArea)
    self.abandonConfirmPanel:SetVisible(false)
    self.root:SetVisible(true)
end

function MainMenuView:Hide()
    self.abandonConfirmPanel:SetVisible(false)
    self.root:SetVisible(false)
end

return MainMenuView
