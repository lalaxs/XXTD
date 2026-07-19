local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")
local SlotAdapter = require("SlotAdapter")
local Views = require("Views")
local BoardView = require("BoardView")
local BoardLayout = require("BoardLayout")
local InfoPanelView = require("InfoPanelView")
local RogueRewardView = require("views.RogueRewardView")
local MainMenuView = require("views.MainMenuView")
local ReincarnationView = require("views.ReincarnationView")
local RogueBuffListView = require("views.RogueBuffListView")
local FloatingTextView = require("views.FloatingTextView")
local ReincarnationActions = require("actions.ReincarnationActions")
local GameEvents = require("GameEvents")
local VisualState = require("VisualState")

local UIController = {}
UIController.__index = UIController

local STORAGE_SIZE = 1

local QUALITY_COLORS = {
    {200, 200, 200, 255},
    {100, 210, 120, 255},
    {80, 160, 255, 255},
    {180, 100, 255, 255},
    {230, 70, 60, 255},
    {255, 200, 50, 255},
    {180, 140, 40, 255},
    {200, 130, 255, 255},
    {255, 160, 200, 255},
}

local function Clamp01(value)
    return math.min(1.0, math.max(0.0, value))
end

local function FindLiveDamageTarget(state, target)
    if not state or not target or not target.hp or target.hp <= 0 then return nil end
    for _, monster in ipairs(state.monsters or {}) do
        if monster == target then
            return monster
        end
    end
    return nil
end

local function StyleQuantityBadge(slot)
    if slot.quantityBadge_ then
        slot.quantityBadge_:SetStyle({
            left = 0,
            right = 0,
            bottom = 0,
            width = "100%",
            height = 22,
            borderRadius = 0,
            backgroundColor = {45, 34, 24, 210},
        })
    end
    if slot.quantityLabel_ then
        slot.quantityLabel_:SetStyle({
            width = "100%",
            fontSize = 15,
            fontColor = {245, 213, 92, 255},
            textAlign = "center",
        })
    end
end

local function ApplyItemSlotVisual(slot, item)
    slot:SetItem(SlotAdapter.ItemToSlotData(item))
    if item then
        local qColor = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].color
            or {200, 200, 200, 255}
        local img = SlotAdapter.GetItemImage(item)
        -- 用品质色作为淡底色，不加边框
        slot.props.backgroundImage = img
        slot.props.backgroundFit = "contain"
        slot.props.backgroundColor = {qColor[1], qColor[2], qColor[3], 30}
        slot.props.borderWidth = 0
        slot.props.borderColor = {0, 0, 0, 0}
        slot.props.borderRadius = 0
        if slot.iconLabel_ then
            slot.iconLabel_:SetText("")
        end
    else
        slot.props.backgroundImage = nil
        slot.props.backgroundColor = {0, 0, 0, 0}
        slot.props.borderWidth = 0
        slot.props.borderColor = {0, 0, 0, 0}
        slot.props.borderRadius = 0
        if slot.iconLabel_ then
            slot.iconLabel_:SetText("")
        end
    end
    StyleQuantityBadge(slot)
end

function UIController.Create(state, callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        uiRoot = nil,
        hpBar = nil,
        hpLabel = nil,
        expBar = nil,
        realmLabel = nil,
        turnLabel = nil,
        fieldPanel = nil,
        deploySlots = {},
        storageSlots = {},
        decomposeSlot = nil,
        gameOverPanel = nil,
        infoPanel = nil,
        rogueRewardView = nil,
        mainMenuView = nil,
        reincarnationView = nil,
        rogueBuffListView = nil,
        floatingTextView = nil,
        dragContext = nil,
        inventoryMgr = nil,
        currentState_ = state,
    }, UIController)

    self.inventoryMgr = UI.InventoryManager.new({
        inventorySize = Config.TOTAL_SLOTS + STORAGE_SIZE,
        equipmentSlots = {},
    })
    self:SyncDataToManager(state)

    self.dragContext = UI.DragDropContext {
        onDragStart = function(itemData, sourceSlot)
            -- 拖拽开始时：用图片替换预览面板的文字显示
            if itemData and itemData._raw then
                local img = SlotAdapter.GetItemImage(itemData._raw)
                if img and self.dragContext.dragIcon_ then
                    self.dragContext.dragIcon_:SetStyle({
                        backgroundImage = img,
                        backgroundFit = "contain",
                        backgroundColor = {0, 0, 0, 0},
                        borderWidth = 0,
                        borderColor = {0, 0, 0, 0},
                        borderRadius = 0,
                    })
                end
                if self.dragContext.dragIconLabel_ then
                    self.dragContext.dragIconLabel_:SetText("")
                end
            end
            if self.callbacks.onDragStart then
                self.callbacks.onDragStart(itemData, sourceSlot)
            end
        end,
        onDragEnd = function(itemData, sourceSlot, targetSlot, success)
            -- 拖拽结束时：清除预览图片
            if self.dragContext.dragIcon_ then
                self.dragContext.dragIcon_:SetStyle({
                    backgroundImage = nil,
                    backgroundColor = {0, 0, 0, 0},
                    borderWidth = 0,
                    borderColor = {0, 0, 0, 0},
                    borderRadius = 0,
                })
            end
            if self.callbacks.onDragEnd then
                self.callbacks.onDragEnd(itemData, sourceSlot, targetSlot, success)
            end
        end,
        canDrop = self.callbacks.canDrop,
    }
    if self.dragContext.dragIcon_ then
        self.dragContext.dragIcon_:SetStyle({
            backgroundColor = {0, 0, 0, 0},
            borderWidth = 0,
            borderColor = {0, 0, 0, 0},
            borderRadius = 0,
        })
    end

    local topHUD = self:CreateTopHUD()
    self.fieldPanel = Views.CreateFieldPanel()
    self.floatingTextView = FloatingTextView.Create({ anchorPanel = self.fieldPanel })
    self:CreateSlots()
    self.gameOverPanel = Views.CreateGameOverPanel({
        onRestart = self.callbacks.onRestart,
        onContinue = self.callbacks.onContinueRun,
        onReincarnate = self.callbacks.onReincarnate,
    })
    self.infoPanel = InfoPanelView.Create()
    self.infoPanel:SetOnUse(function(context)
        if self.callbacks.onUseConsumable then
            self.callbacks.onUseConsumable(context)
        end
    end)
    self.rogueRewardView = RogueRewardView.Create(function(rewardId)
        if self.callbacks.onSelectRogueReward then
            self.callbacks.onSelectRogueReward(rewardId)
        end
    end)
    self.mainMenuView = MainMenuView.Create({
        onReincarnation = function()
            self:ShowReincarnationUpgrades()
        end,
        onBuffs = function()
            self:ShowRogueBuffList()
        end,
        onSettings = function()
            self:ShowOperationWarning("该操作不可用")
        end,
        onDifficulty = function()
            self:ShowOperationWarning("该操作不可用")
        end,
        onAbandonRun = function()
            if self.callbacks.onAbandonRun then
                self.callbacks.onAbandonRun()
            end
        end,
    })
    self.reincarnationView = ReincarnationView.Create(function(upgradeId)
        self:UpgradeReincarnation(upgradeId)
    end)
    self.rogueBuffListView = RogueBuffListView.Create()

    self.uiRoot = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = {28, 68, 64, 255},
        children = {
            UI.Panel {
                id = "gameContainer",
                width = "100%",
                height = "100%",
                children = {
                    UI.Panel {
                        width = "100%",
                        height = "100%",
                        children = {
                            self.fieldPanel,
                        },
                    },
                    self.floatingTextView:GetRoot(),
                    self.infoPanel:GetRoot(),
                    self.rogueRewardView:GetRoot(),
                    self.mainMenuView:GetRoot(),
                    self.reincarnationView:GetRoot(),
                    self.rogueBuffListView:GetRoot(),
                    self.gameOverPanel,
                },
            },
            self.dragContext,
        }
    }

    UI.SetRoot(self.uiRoot)
    self:UpdateAll(state)
    return self
end

function UIController:CreateTopHUD()
    local panel, refs = Views.CreateTopHUD()
    self.realmLabel = refs.realmLabel
    self.turnLabel = refs.turnLabel
    self.hpLabel = refs.hpLabel
    self.hpBar = refs.hpBar
    self.expBar = refs.expBar
    return panel
end

function UIController:CreateSlots()
    -- 创建部署区 ItemSlot（纯交互层，创建时就设为完全透明）
    self.deploySlots = {}
    for i = 1, Config.TOTAL_SLOTS do
        local slot = UI.ItemSlot {
            slotId = "deploy_" .. i,
            slotCategory = "deploy",
            dragContext = self.dragContext,
            showTypeIcon = false,
            backgroundColor = {0, 0, 0, 0},
            borderWidth = 0,
            borderColor = {0, 0, 0, 0},
            borderRadius = 0,
            iconColor = {0, 0, 0, 0},
        }
        slot.props.onSlotClick = function()
            if self.currentState_ then
                self:ShowItemInfo(self.currentState_.slots[i], "deploy", i)
            end
        end
        StyleQuantityBadge(slot)
        self.deploySlots[i] = slot
    end

    -- 创建暂存 ItemSlot
    self.storageSlots = {}
    self.storageSlots[1] = UI.ItemSlot {
        slotId = "storage_1",
        slotCategory = "storage",
        dragContext = self.dragContext,
        showTypeIcon = false,
        backgroundColor = {0, 0, 0, 0},
        borderWidth = 0,
        borderColor = {0, 0, 0, 0},
        borderRadius = 0,
        iconColor = {0, 0, 0, 0},
    }
    StyleQuantityBadge(self.storageSlots[1])
    self.storageSlots[1].props.onSlotClick = function()
        if self.currentState_ then
            self:ShowItemInfo(self.currentState_.dropQueue[1], "storage", 1)
        end
    end

    self.decomposeSlot = UI.ItemSlot {
        slotId = "decompose_1",
        slotCategory = "decompose",
        dragContext = self.dragContext,
        showTypeIcon = false,
        backgroundColor = {0, 0, 0, 0},
        borderWidth = 0,
        borderColor = {0, 0, 0, 0},
        borderRadius = 0,
        iconColor = {0, 0, 0, 0},
    }
end

function UIController:UpdateInfoPanelAnchor()
    if not self.infoPanel or not self.fieldPanel then return end

    local layout = self.fieldPanel:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    local metrics = BoardLayout.CalcMetrics(layout.w, layout.h)
    local fieldBottom = metrics.originY + (metrics.fieldY + Config.FIELD_ROWS * metrics.fieldCellH) * metrics.scale
    local bottom = math.floor(layout.h - fieldBottom + 0.5)
    self.infoPanel:SetBottom(bottom)
end

function UIController:ShowItemInfo(item, category, index)
    if not item then
        self:HideItemInfo()
        return
    end

    local context = nil
    if category and index then
        context = { category = category, index = index }
    end
    self:UpdateInfoPanelAnchor()
    self.infoPanel:ShowItem(item, context, self.currentState_)
end

function UIController:ShowFieldRewardInfo(fieldReward)
    self:UpdateInfoPanelAnchor()
    if fieldReward and fieldReward.rewardItem then
        self.infoPanel:ShowItem(fieldReward.rewardItem, nil, self.currentState_)
    else
        self.infoPanel:ShowFieldReward(fieldReward and fieldReward.quality or fieldReward)
    end
end

function UIController:ShowMonsterInfo(monster)
    self:UpdateInfoPanelAnchor()
    self.infoPanel:ShowMonster(monster)
end

function UIController:ShowRealmInfo()
    if self.infoPanel and self.currentState_ then
        self:UpdateInfoPanelAnchor()
        self.infoPanel:ShowRealm(self.currentState_)
    end
end

function UIController:HideItemInfo()
    self.infoPanel:Hide()
end

function UIController:ShowReincarnationUpgrades()
    if self.reincarnationView and self.currentState_ then
        self.reincarnationView:Show(self.currentState_)
    end
end

function UIController:ShowRogueBuffList()
    if self.rogueBuffListView and self.currentState_ then
        self.rogueBuffListView:Show(self.currentState_)
    end
end

function UIController:ShowMainMenu()
    if self.mainMenuView and self.currentState_ then
        self.mainMenuView:Show(self.currentState_)
    end
end

function UIController:UpgradeReincarnation(upgradeId)
    if not self.currentState_ then return end
    local result = ReincarnationActions.Upgrade(self.currentState_, upgradeId)
    if not result.ok then
        self:ShowOperationWarning(result.message)
    end
    if self.reincarnationView then
        self.reincarnationView:Show(self.currentState_)
    end
    self:UpdateAll(self.currentState_)
end

function UIController:Update(dt)
    self.infoPanel:Update(dt)
end

function UIController:SyncDataToManager(state)
    for i = 1, Config.TOTAL_SLOTS do
        self.inventoryMgr:SetInventoryItem(i, state.slots[i])
    end
end

function UIController:UpdateAll(state)
    self.currentState_ = state
    self:UpdateHUD(state)
    self:UpdateBoard(state)
    self:ShowFloatingEvents(state)
    self:UpdateRogueRewardView(state)
    if state.isGameOver then
        self:ShowGameOver(state)
    end
end

function UIController:ShowFloatingEvents(state)
    if not self.floatingTextView or not state then return end

    local events = GameEvents.ConsumeVisualEvents(state)
    local damageEvents = events.damageDealt or {}
    for i, ev in ipairs(damageEvents) do
        if ev and (ev.dmg or 0) > 0 then
            local target = FindLiveDamageTarget(state, ev.target)
            local row = (target and target.row) or ev.row
            local col = (target and target.col) or ev.col
            if row and col then
                if ev.crit then
                    self.floatingTextView:ShowCrit(row, col, ev.dmg, { lane = i })
                else
                    self.floatingTextView:ShowDamage(row, col, ev.dmg, { lane = i })
                end
            end
        end
    end

    for i, ev in ipairs(events.statusEvents or {}) do
        if ev and ev.text then
            local variant = ev.variant
            if not variant then
                if ev.kind == "buff" then
                    variant = "statusBuff"
                elseif ev.kind == "control" then
                    variant = "statusControl"
                else
                    variant = "statusDebuff"
                end
            end
            if ev.targetType == "monster" then
                local target = FindLiveDamageTarget(state, ev.target)
                local row = (target and target.row) or ev.row
                local col = (target and target.col) or ev.col
                if row and col then
                    self.floatingTextView:ShowMonsterStatus(row, col, ev.text, { lane = i, variant = variant })
                end
            elseif ev.targetType == "player" then
                self.floatingTextView:ShowPlayerStatus(ev.text, { lane = i, variant = variant })
            end
        end
    end

    if (events.playerDamage or 0) > 0 then
        if events.playerDamageCrit then
            self.floatingTextView:ShowPlayerCrit(events.playerDamage)
        else
            self.floatingTextView:ShowPlayerDamage(events.playerDamage)
        end
    end

    for i, info in ipairs(events.pillConsumeMessages or {}) do
        if info and (info.heal or 0) > 0 then
            self.floatingTextView:ShowPlayerHeal(info.heal, { lane = i })
        end
    end

    if events.breakthroughEvent then
        local event = events.breakthroughEvent
        self.floatingTextView:ShowCenter("突破·" .. tostring(event.realmName or "新境界"), {
            variant = "breakthrough",
            anchorY = 0.36,
        })
    end

    for i, msg in ipairs(events.dropMessages or {}) do
        self.floatingTextView:ShowCenter(msg, {
            variant = "reward",
            lane = i,
            anchorY = 0.62,
        })
    end

    if events.reincarnationTriggered then
        self.floatingTextView:ShowCenter("返璞归真", {
            variant = "breakthrough",
            anchorY = 0.42,
        })
    end
end

function UIController:ShowMergeFloat(category, index, quality)
    if self.floatingTextView then
        self.floatingTextView:ShowMerge(category, index, quality)
    end
end

function UIController:ShowPlayerHeal(amount, options)
    if self.floatingTextView and (amount or 0) > 0 then
        self.floatingTextView:ShowPlayerHeal(amount, options)
    end
end

function UIController:ShowOperationWarning(text)
    if not self.floatingTextView then return end
    self.floatingTextView:ShowCenter(text or "该操作不可用", {
        variant = "warning",
        anchorY = 0.48,
        duration = 1.05,
    })
end

function UIController:ShowCenterFloat(text, variant, options)
    if not self.floatingTextView then return end
    options = options or {}
    options.variant = variant or options.variant or "info"
    self.floatingTextView:ShowCenter(text, options)
end

function UIController:ClearFloatingTexts()
    if self.floatingTextView then
        self.floatingTextView:Clear()
    end
end

function UIController:UpdateRogueRewardView(state)
    if not self.rogueRewardView then return end

    local choices = state.pendingRogueChoices
    if choices and #choices > 0 then
        self.rogueRewardView:Show(state.pendingRogueEvent, choices)
    else
        self.rogueRewardView:Hide()
    end
end

function UIController:ShowDropMessages(state)
end

function UIController:UpdateHUD(state)
    self.hpLabel:SetText(tostring(state.hp))
    self.hpBar:SetValue(Clamp01(state.hp / state.maxHp))
    local realm = Config.GetRealm(state.realmIndex)
    self.realmLabel:SetText(realm.name)
    local requiredExp = realm.expRequired or 1
    local progress = state.exp / math.max(1, requiredExp)
    self.expBar:SetValue(Clamp01(progress))
    self.turnLabel:SetText("第" .. state.waveCount .. "波")
end

function UIController:UpdateSlots(state)
    -- 统一由 BoardView 渲染，调用 UpdateBoard
    self:UpdateBoard(state)
end

function UIController:UpdateFieldPanel(state)
    -- 统一由 BoardView 渲染
    self:UpdateBoard(state)
end

local function MarkMonsterSpawnAnimationPlayed(state, monster)
    VisualState.MarkMonsterSpawnPlayed(state, monster)
end

function UIController:UpdateBoard(state)
    BoardView.Update(self.fieldPanel, state, self.deploySlots, self.storageSlots[1], self.decomposeSlot, {
        onMonsterClick = function(monster)
            self:ShowMonsterInfo(monster)
        end,
        onMonsterSpawnAnimationPlayed = function(monster)
            MarkMonsterSpawnAnimationPlayed(state, monster)
        end,
        onFieldRewardClick = function(fieldReward)
            self:ShowFieldRewardInfo(fieldReward)
        end,
        onMainMenuClick = function()
            self:ShowMainMenu()
        end,
        onExpCircleClick = function()
            self:ShowRealmInfo()
        end,
        onBlankClick = function()
            self:HideItemInfo()
        end,
    })
end

function UIController:ShowGameOver(state)
    self.gameOverPanel:SetVisible(true)
    local title = self.gameOverPanel:FindById("goTitle")
    local desc = self.gameOverPanel:FindById("goDesc")
    local s = self.gameOverPanel:FindById("goScore")
    local r = self.gameOverPanel:FindById("goRealm")
    local continueButton = self.gameOverPanel:FindById("goContinueButton")
    local reincarnateButton = self.gameOverPanel:FindById("goReincarnateButton")
    local restartButton = self.gameOverPanel:FindById("goRestartButton")

    if state.isVictory then
        if title then title:SetText("飞升成功") end
        if s then s:SetText("积分: " .. state.score) end
        if r then r:SetText("已通关难度 " .. tostring(state.difficulty or 1)) end

        if state.victoryReason == "ascension_failed" then
            if desc then desc:SetText("你已证得飞升之果，此后战败亦算功成。本轮需要进入轮回。") end
            if continueButton then continueButton:SetVisible(false) end
            if reincarnateButton then reincarnateButton:SetVisible(true) end
            if restartButton then restartButton:SetVisible(false) end
        else
            if desc then desc:SetText("成功突破至飞升境界。可继续当前游戏挑战更强波次，也可进入轮回。") end
            if continueButton then continueButton:SetVisible(state.canContinueRun == true) end
            if reincarnateButton then reincarnateButton:SetVisible(true) end
            if restartButton then restartButton:SetVisible(false) end
        end
    else
        if title then title:SetText("道陨身殒") end
        if desc then desc:SetText("本轮修行失败，将直接重开，不再退回境界。") end
        if s then s:SetText("积分: " .. state.score) end
        if r then r:SetText("最终境界: " .. Config.GetRealm(state.realmIndex).name) end
        if continueButton then continueButton:SetVisible(false) end
        if reincarnateButton then reincarnateButton:SetVisible(false) end
        if restartButton then restartButton:SetVisible(true) end
    end
end

function UIController:HideGameOver()
    self.gameOverPanel:SetVisible(false)
end

return UIController
