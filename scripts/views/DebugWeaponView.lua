-- views/DebugWeaponView.lua
-- 武器特效与专属肉鸽技能测试面板。

local UI = require("urhox-libs/UI")
local Config = require("Config")
local DebugWeaponSystem = require("debug.DebugWeaponSystem")

local DebugWeaponView = {}
DebugWeaponView.__index = DebugWeaponView

local COLORS = {
    overlay = {0, 0, 0, 170},
    paper = {232, 228, 210, 255},
    inner = {243, 240, 230, 255},
    ink = {28, 27, 36, 255},
    secondary = {58, 54, 69, 255},
    muted = {122, 118, 130, 255},
    border = {28, 27, 36, 190},
    red = {166, 60, 51, 255},
    redPressed = {126, 43, 37, 255},
    gold = {181, 150, 91, 255},
    green = {107, 125, 120, 255},
    greenPressed = {79, 98, 93, 255},
    white = {255, 255, 255, 255},
}

local function MakeButton(text, onClick, options)
    options = options or {}
    return UI.Button {
        text = text,
        width = options.width or "48%",
        minHeight = options.height or 44,
        flexShrink = 0,
        fontSize = options.fontSize or 14,
        fontWeight = "bold",
        borderRadius = 6,
        borderWidth = 1,
        borderColor = options.borderColor or COLORS.border,
        backgroundColor = options.backgroundColor or COLORS.green,
        pressedBackgroundColor = options.pressedBackgroundColor or COLORS.greenPressed,
        textColor = options.textColor or COLORS.white,
        onClick = onClick,
    }
end

local function MakeSection(title, content)
    return UI.Panel {
        width = "100%",
        padding = 10,
        gap = 8,
        backgroundColor = COLORS.inner,
        borderRadius = 6,
        borderWidth = 1,
        borderColor = COLORS.border,
        boxShadow = {{ x = 3, y = 3, blur = 0, spread = 0, color = {28, 27, 36, 35} }},
        children = {
            UI.Label {
                text = title,
                width = "100%",
                fontSize = 17,
                fontWeight = "bold",
                fontColor = COLORS.ink,
            },
            content,
        },
    }
end

function DebugWeaponView.Create(callbacks)
    local self = setmetatable({}, DebugWeaponView)
    self:init(callbacks)
    return self
end

function DebugWeaponView:init(callbacks)
    self.callbacks = callbacks or {}
    self.root = nil
    self.summaryLabel = nil
    self.weaponGrid = nil
    self.skillGrid = nil
    self.qualityButtons = {}
    self.currentState = nil
    self.selectedWeaponId = DebugWeaponSystem.GetWeapons()[1].id
    self.selectedQuality = Config.MAX_QUALITY

    self.summaryLabel = UI.Label {
        text = "尚未选择测试武器",
        width = "100%",
        fontSize = 13,
        lineHeight = 1.35,
        whiteSpace = "normal",
        fontColor = COLORS.secondary,
        textAlign = "center",
    }

    self.weaponGrid = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }
    for _, weapon in ipairs(DebugWeaponSystem.GetWeapons()) do
        self.weaponGrid:AddChild(MakeButton(weapon.name, function()
            self.selectedWeaponId = weapon.id
            if self.callbacks.onEquipWeapon then self.callbacks.onEquipWeapon(weapon.id, self.selectedQuality) end
            self:Refresh(self.currentState)
        end, { width = "31%", height = 42, fontSize = 13, backgroundColor = COLORS.green }))
    end

    self.skillGrid = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }

    local qualityGrid = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
    }
    for quality = 1, Config.MAX_QUALITY do
        local selectedQuality = quality
        local button = MakeButton("Q" .. selectedQuality, function()
            self.selectedQuality = selectedQuality
            if self.callbacks.onEquipWeapon then
                self.callbacks.onEquipWeapon(self.selectedWeaponId, selectedQuality)
            end
            self:Refresh(self.currentState)
        end, {
            width = "31%",
            height = 40,
            backgroundColor = selectedQuality == self.selectedQuality and COLORS.gold or COLORS.green,
        })
        self.qualityButtons[selectedQuality] = button
        qualityGrid:AddChild(button)
    end

    local scenarioGrid = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
        children = {
            MakeButton("高血单体", function() if self.callbacks.onScenario then self.callbacks.onScenario("high_hp") end end),
            MakeButton("低血单体", function() if self.callbacks.onScenario then self.callbacks.onScenario("low_hp") end end),
            MakeButton("群体目标", function() if self.callbacks.onScenario then self.callbacks.onScenario("group") end end),
            MakeButton("掉落武器", function() if self.callbacks.onFieldRewardScenario then self.callbacks.onFieldRewardScenario("weapon") end end),
            MakeButton("掉落防具", function() if self.callbacks.onFieldRewardScenario then self.callbacks.onFieldRewardScenario("armor") end end),
            MakeButton("精锐目标", function() if self.callbacks.onScenario then self.callbacks.onScenario("elite") end end),
            MakeButton("头目目标", function() if self.callbacks.onScenario then self.callbacks.onScenario("boss") end end),
        },
    }

    local hpGrid = UI.Panel {
        width = "100%",
        flexDirection = "row",
        flexWrap = "wrap",
        gap = 8,
        children = {
            MakeButton("满血", function() if self.callbacks.onSetHp then self.callbacks.onSetHp(1.0) end end, { width = "31%" }),
            MakeButton("30%气血", function() if self.callbacks.onSetHp then self.callbacks.onSetHp(0.30) end end, { width = "31%" }),
            MakeButton("10%气血", function() if self.callbacks.onSetHp then self.callbacks.onSetHp(0.10) end end, { width = "31%" }),
        },
    }

    local content = UI.Panel {
        width = "100%",
        gap = 12,
        children = {
            MakeSection("当前测试", UI.Panel {
                width = "100%",
                gap = 8,
                children = {
                    self.summaryLabel,
                },
            }),
            MakeSection("选择等级（Q1-Q9，点击即装配）", qualityGrid),
            MakeSection("选择武器（按当前等级装配）", self.weaponGrid),
            MakeSection("修炼提升流程", UI.Panel {
                width = "100%",
                gap = 8,
                children = {
                    UI.Label {
                        text = "打开正式修炼提升三选一，并依次测试攻击法宝、防御法宝与敌方强化选择。",
                        width = "100%",
                        fontSize = 13,
                        lineHeight = 1.35,
                        whiteSpace = "normal",
                        textAlign = "center",
                        fontColor = COLORS.secondary,
                    },
                    MakeButton("测试修炼提升三选一", function()
                        if self.callbacks.onCreateSkillChoices
                            and self.callbacks.onCreateSkillChoices() then
                            self:Hide()
                        end
                    end, { width = "100%", backgroundColor = COLORS.red, pressedBackgroundColor = COLORS.redPressed }),
                },
            }),
            MakeSection("专属肉鸽技能（点击开关）", UI.Panel {
                width = "100%",
                gap = 8,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = 8,
                        children = {
                            MakeButton("开启全部", function()
                                if self.callbacks.onSetAllSkills then self.callbacks.onSetAllSkills(self.selectedWeaponId, true) end
                                self:Refresh(self.currentState)
                            end, { backgroundColor = COLORS.gold, pressedBackgroundColor = COLORS.redPressed }),
                            MakeButton("关闭全部", function()
                                if self.callbacks.onSetAllSkills then self.callbacks.onSetAllSkills(self.selectedWeaponId, false) end
                                self:Refresh(self.currentState)
                            end, { backgroundColor = COLORS.muted, pressedBackgroundColor = COLORS.secondary }),
                        },
                    },
                    self.skillGrid,
                },
            }),
            MakeSection("测试场景", scenarioGrid),
            MakeSection("玩家气血（灵墨笔/葫芦）", hpGrid),
        },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        zIndex = 1450,
        backgroundColor = COLORS.overlay,
        justifyContent = "center",
        alignItems = "center",
        padding = 12,
        children = {
            UI.SafeAreaView {
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Panel {
                        width = "96%",
                        maxWidth = 680,
                        height = "92%",
                        padding = 14,
                        gap = 10,
                        backgroundColor = COLORS.paper,
                        borderRadius = 8,
                        borderWidth = 2,
                        borderColor = COLORS.border,
                        boxShadow = {{ x = 0, y = 4, blur = 12, spread = 0, color = {0, 0, 0, 50} }},
                        children = {
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row",
                                justifyContent = "space-between",
                                alignItems = "center",
                                children = {
                                    UI.Label { text = "武器与肉鸽调试", fontSize = 24, fontWeight = "bold", fontColor = COLORS.ink },
                                    MakeButton("×", function() self:Hide() end, {
                                        width = 42,
                                        height = 38,
                                        fontSize = 22,
                                        backgroundColor = COLORS.red,
                                        pressedBackgroundColor = COLORS.redPressed,
                                    }),
                                },
                            },
                            UI.Label {
                                text = "先选武器和技能，再准备场景；关闭面板后点击“执行回合”观察特效。",
                                width = "100%",
                                fontSize = 13,
                                whiteSpace = "normal",
                                textAlign = "center",
                                fontColor = COLORS.muted,
                            },
                            UI.Panel {
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
                                        children = { content },
                                    },
                                },
                            },
                            UI.Panel {
                                width = "100%",
                                flexDirection = "row",
                                gap = 8,
                                children = {
                                    MakeButton("执行回合", function()
                                        self:Hide()
                                        if self.callbacks.onExecuteTurn then self.callbacks.onExecuteTurn() end
                                    end, { backgroundColor = COLORS.red, pressedBackgroundColor = COLORS.redPressed }),
                                    MakeButton("还原调试前状态", function()
                                        if self.callbacks.onClear then self.callbacks.onClear() end
                                        self:Refresh(self.currentState)
                                    end, { backgroundColor = COLORS.secondary, pressedBackgroundColor = COLORS.ink }),
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

function DebugWeaponView:GetRoot()
    return self.root
end

function DebugWeaponView:RebuildSkills(state)
    self.skillGrid:ClearChildren()
    for _, skill in ipairs(DebugWeaponSystem.GetSkills(self.selectedWeaponId)) do
        local enabled = state and DebugWeaponSystem.IsSkillEnabled(state, skill.id)
        self.skillGrid:AddChild(MakeButton((enabled and "已开启 · " or "未开启 · ") .. skill.name, function()
            if self.callbacks.onToggleSkill then self.callbacks.onToggleSkill(skill, not enabled) end
            self:Refresh(self.currentState)
        end, {
            backgroundColor = enabled and COLORS.gold or COLORS.muted,
            pressedBackgroundColor = enabled and COLORS.redPressed or COLORS.secondary,
        }))
    end
end

function DebugWeaponView:Refresh(state)
    if not state then return end
    self.currentState = state
    self.selectedWeaponId = state.debugSelectedWeaponId or self.selectedWeaponId
    self.selectedQuality = state.debugSelectedQuality or self.selectedQuality
    for quality, button in ipairs(self.qualityButtons) do
        button:SetStyle({
            backgroundColor = quality == self.selectedQuality and COLORS.gold or COLORS.green,
            pressedBackgroundColor = quality == self.selectedQuality and COLORS.redPressed or COLORS.greenPressed,
        })
    end
    local selectedName = self.selectedWeaponId
    for _, weapon in ipairs(DebugWeaponSystem.GetWeapons()) do
        if weapon.id == self.selectedWeaponId then selectedName = weapon.name break end
    end
    local equipped = state.slots and state.slots[1]
    local equippedText = equipped and string.format("第一列：%s Q%d", equipped.name, equipped.quality or 1) or "第一列：空"
    self.summaryLabel:SetText(string.format("选择：%s｜%s｜目标%d｜气血%d/%d", selectedName, equippedText, #(state.monsters or {}), state.hp or 0, state.maxHp or 0))
    self:RebuildSkills(state)
end

function DebugWeaponView:Show(state)
    self:Refresh(state)
    self.root:SetVisible(true)
end

function DebugWeaponView:Hide()
    self.root:SetVisible(false)
end

return DebugWeaponView
