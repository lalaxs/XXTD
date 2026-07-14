-- views/MainMenuView.lua
-- 右下角功能入口弹窗：天赋 / 设置 / 当前难度 / 放弃当前轮回。

local UI = require("urhox-libs/UI")
local StatusPresenter = require("views.StatusPresenter")

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
    gold = {255, 200, 60, 255},
}

local function MakeButton(text, color, onClick)
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
        onClick = onClick,
    }
end

local function MakeSectionTitle(text)
    return UI.Label {
        text = text,
        width = "100%",
        fontSize = 16,
        fontWeight = "bold",
        fontColor = COLORS.title,
    }
end

local function MakeStatusChip(status)
    local isDebuff = status.kind == "debuff"
    local isShield = status.name == "护盾"
    local bgColor = isShield and {72, 118, 162, 245} or (isDebuff and {155, 70, 58, 245} or {83, 132, 88, 245})
    local borderColor = isShield and {42, 76, 112, 255} or (isDebuff and {110, 44, 38, 255} or {50, 92, 56, 255})
    local valueColor = isShield and {210, 238, 255, 255} or (isDebuff and {255, 224, 194, 255} or {236, 255, 207, 255})
    local descColor = isShield and {224, 242, 255, 230} or (isDebuff and {255, 236, 218, 230} or {232, 250, 222, 230})
    local valueText = status.valueText or (status.turns and status.turns > 0 and tostring(status.turns) .. "回合") or ""
    return UI.Panel {
        width = "48%",
        minHeight = 50,
        paddingHorizontal = 10,
        paddingVertical = 7,
        gap = 3,
        backgroundColor = bgColor,
        borderRadius = 10,
        borderWidth = 2,
        borderColor = borderColor,
        flexShrink = 0,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                gap = 6,
                children = {
                    UI.Label {
                        text = status.name or "状态",
                        flexGrow = 1,
                        flexShrink = 1,
                        fontSize = 14,
                        fontWeight = "bold",
                        fontColor = {255, 250, 235, 255},
                        maxLines = 1,
                    },
                    UI.Label {
                        text = valueText,
                        fontSize = 12,
                        fontWeight = "bold",
                        fontColor = valueColor,
                        flexShrink = 0,
                    },
                },
            },
            UI.Label {
                text = status.turns and status.valueText and tostring(status.turns) .. "回合" or (status.desc or ""),
                width = "100%",
                fontSize = 11,
                fontColor = descColor,
                maxLines = 1,
            },
        },
    }
end

local function RebuildStatusArea(container, state)
    container:RemoveAllChildren()
    local statuses = StatusPresenter.BuildPreviewStatuses()

    container:AddChild(MakeSectionTitle("当前状态（预览）"))
    local hint = "展示游戏中已设计的全部增益与减益状态"
    if state and state.__useRealStatuses then
        statuses = StatusPresenter.BuildStatuses(state)
        hint = "当前生效的临时增益与减益"
    end
    container:AddChild(UI.Label {
        text = hint,
        width = "100%",
        fontSize = 12,
        fontColor = COLORS.muted,
    })
    if #statuses == 0 then
        container:AddChild(UI.Label {
            text = "暂无临时增益或减益",
            width = "100%",
            fontSize = 13,
            fontColor = COLORS.muted,
            textAlign = "center",
        })
    else
        local statusWrap = UI.Panel {
            width = "100%",
            flexDirection = "row",
            flexWrap = "wrap",
            gap = 8,
        }
        for i = 1, #statuses do
            statusWrap:AddChild(MakeStatusChip(statuses[i]))
        end
        container:AddChild(UI.ScrollView {
            width = "100%",
            flexGrow = 1,
            flexBasis = 0,
            scrollY = true,
            scrollX = false,
            showScrollbar = true,
            children = { statusWrap },
        })
    end
end

local function GetOpportunityButtonText(state)
    local history = state and state.rogueRewardHistory or nil
    local latest = history and history[#history]
    if latest and latest.name and latest.name ~= "" then
        return latest.name
    end
    return "机缘"
end

function MainMenuView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        infoLabel = nil,
        statusArea = nil,
        opportunityButton = nil,
    }, MainMenuView)

    self.infoLabel = UI.Label {
        text = "",
        width = "100%",
        height = 22,
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
    end)

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
                        height = 118,
                        flexShrink = 0,
                        flexDirection = "row",
                        flexWrap = "wrap",
                        gap = 10,
                        children = {
                            UI.Panel {
                                width = "48%",
                                children = {
                                    MakeButton("天赋", COLORS.button, function()
                                        self:Hide()
                                        if self.callbacks.onTalent then self.callbacks.onTalent() end
                                    end),
                                },
                            },
                            UI.Panel {
                                width = "48%",
                                children = {
                                    self.opportunityButton,
                                },
                            },
                            UI.Panel {
                                width = "48%",
                                children = {
                                    MakeButton("设置", COLORS.button, function()
                                        if self.callbacks.onSettings then self.callbacks.onSettings() end
                                    end),
                                },
                            },
                            UI.Panel {
                                width = "48%",
                                children = {
                                    MakeButton("放弃当前轮回", COLORS.danger, function()
                                        self:Hide()
                                        if self.callbacks.onAbandonRun then self.callbacks.onAbandonRun() end
                                    end),
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    return self
end

function MainMenuView:GetRoot()
    return self.root
end

function MainMenuView:Show(state)
    local difficulty = state and (state.difficulty or 1) or 1
    local reincarnation = state and (state.reincarnationCount or 0) or 0
    local talentPoints = state and (state.talentPoints or 0) or 0
    self.infoLabel:SetText(string.format("难度 %d · 轮回 %d · 可用天赋点 %d", difficulty, reincarnation, talentPoints))
    self.opportunityButton:SetText(GetOpportunityButtonText(state))
    RebuildStatusArea(self.statusArea, state)
    self.root:SetVisible(true)
end

function MainMenuView:Hide()
    self.root:SetVisible(false)
end

return MainMenuView
