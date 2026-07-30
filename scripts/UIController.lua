local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")
local SlotAdapter = require("SlotAdapter")
local Views = require("Views")
local BoardView = require("BoardView")
local BoardLayout = require("BoardLayout")
local InfoPanelView = require("InfoPanelView")
local RogueRewardView = require("views.RogueRewardView")
local ShopView = require("views.ShopView")
local MainMenuView = require("views.MainMenuView")
local ReincarnationView = require("views.ReincarnationView")
local RogueBuffListView = require("views.RogueBuffListView")
local DebugStatusView = require("views.DebugStatusView")
local DebugWeaponView = require("views.DebugWeaponView")
local TitleView = require("views.TitleView")
local LeaderboardView = require("views.LeaderboardView")
local DailyChallengeView = require("views.DailyChallengeView")
local DailyTagView = require("views.DailyTagView")
local SettingsView = require("views.SettingsView")
local TutorialView = require("views.TutorialView")
local TutorialSystem = require("TutorialSystem")
local LeaderboardService = require("LeaderboardService")
local DailyChallenge = require("DailyChallenge")
local DailyChallengeProgress = require("DailyChallengeProgress")
local FloatingTextView = require("views.FloatingTextView")
local DebugStatusSystem = require("debug.DebugStatusSystem")
local DebugWeaponSystem = require("debug.DebugWeaponSystem")
local ReincarnationActions = require("actions.ReincarnationActions")
local GameEvents = require("GameEvents")
local VisualState = require("VisualState")
local Effects = require("Effects")

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
        shopView = nil,
        mainMenuView = nil,
        reincarnationView = nil,
        rogueBuffListView = nil,
        debugStatusView = nil,
        debugWeaponView = nil,
        titleView = nil,
        leaderboardView = nil,
        dailyChallengeView = nil,
        dailyTagView = nil,
        settingsView = nil,
        tutorialView = nil,
        floatingTextView = nil,
        dragContext = nil,
        inventoryMgr = nil,
        currentState_ = state,
        currentDailyChallengeId_ = nil,
        coinSoundCooldown_ = 0,
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
    self.tutorialView = TutorialView.Create(self.fieldPanel)
    self.floatingTextView = FloatingTextView.Create({ anchorPanel = self.fieldPanel })
    self:CreateSlots()
    self.gameOverPanel = Views.CreateGameOverPanel({
        onRestart = self.callbacks.onRestart,
        onContinue = self.callbacks.onContinueRun,
        onReturnToTitle = self.callbacks.onReturnToTitle,
        onReincarnate = self.callbacks.onReincarnate,
        onGameOverConfirm = self.callbacks.onGameOverConfirm,
    })
    self.infoPanel = InfoPanelView.Create()
    self.infoPanel:SetOnUse(function(context)
        if self.callbacks.onUseConsumable then
            self.callbacks.onUseConsumable(context)
        end
    end)
    self.rogueRewardView = RogueRewardView.Create(function(rewardId)
        if self.callbacks.onUIClick then
            self.callbacks.onUIClick()
        end
        if self.callbacks.onSelectRogueReward then
            self.callbacks.onSelectRogueReward(rewardId)
        end
    end, function()
        if self.callbacks.onRefreshRogueReward then
            self.callbacks.onRefreshRogueReward()
        end
    end)
    self.shopView = ShopView.Create({
        onBuy = function(itemIndex)
            if self.callbacks.onBuyShopItem then
                self.callbacks.onBuyShopItem(itemIndex)
            end
        end,
        onClaimAdItem = function(itemIndex)
            if self.callbacks.onClaimShopAdItem then
                self.callbacks.onClaimShopAdItem(itemIndex)
            end
        end,
        onClose = function()
            if self.callbacks.onCloseShop then
                self.callbacks.onCloseShop()
            end
        end,
        onRefresh = function()
            if self.callbacks.onRefreshShop then
                self.callbacks.onRefreshShop()
            end
        end,
        onAdRefresh = function()
            if self.callbacks.onAdRefreshShop then
                self.callbacks.onAdRefreshShop()
            end
        end,
    })
    self.mainMenuView = MainMenuView.Create({
        onUIClick = function()
            if self.callbacks.onUIClick then self.callbacks.onUIClick() end
        end,
        onReincarnation = function()
            self:ShowReincarnationUpgrades()
        end,
        onBuffs = function()
            self:ShowRogueBuffList()
        end,
        onSettings = function()
            self.mainMenuView:Hide()
            self:ShowSettings()
        end,
        onDifficulty = function()
            self:ShowOperationWarning("该操作不可用")
        end,
        onAbandonRun = function()
            if self.callbacks.onAbandonRun then
                self.callbacks.onAbandonRun()
            end
        end,
        onSaveAndReturnToTitle = function()
            if self.callbacks.onSaveAndReturnToTitle then
                self.callbacks.onSaveAndReturnToTitle()
            end
        end,
    })
    self.reincarnationView = ReincarnationView.Create(
        function(upgradeId)
            self:UpgradeReincarnation(upgradeId)
        end,
        function()
            if self.callbacks.onUIClick then self.callbacks.onUIClick() end
        end
    )
    self.rogueBuffListView = RogueBuffListView.Create(function()
        if self.callbacks.onUIClick then self.callbacks.onUIClick() end
    end)
    self.titleView = TitleView.Create({
        onContinue = function()
            if self.currentState_ and self.callbacks.onContinueRun then
                self.callbacks.onContinueRun()
            end
        end,
        onStart = function()
            if self.callbacks.onStartGame then
                self.callbacks.onStartGame()
            end
        end,
        onLeaderboard = function()
            self:ShowLeaderboard()
        end,
        onDailyChallenge = function()
            if self.callbacks.onOpenDailyChallenge then
                self.callbacks.onOpenDailyChallenge()
            else
                self:ShowOperationWarning("每日挑战暂不可用")
            end
        end,
        onSettings = function()
            self:ShowSettings()
        end,
    })
    self.leaderboardView = LeaderboardView.Create({
        onRefresh = function()
            self:RefreshLeaderboard()
        end,
        onRefreshDaily = function()
            self:RefreshDailyLeaderboard()
        end,
    })
    self.dailyChallengeView = DailyChallengeView.Create({
        onContinue = function()
            if self.callbacks.onContinueDailyChallenge then
                self.callbacks.onContinueDailyChallenge()
            end
        end,
        onStart = function()
            if self.callbacks.onBeginDailyChallenge then
                self.callbacks.onBeginDailyChallenge()
            end
        end,
        onClose = function()
            self:ShowTitle()
        end,
        onLeaderboard = function()
            self:HideDailyChallenge()
            self:ShowLeaderboard(self.currentDailyChallengeId_)
        end,
        onReset = function()
            if self.callbacks.onResetDailyChallenge then
                self.callbacks.onResetDailyChallenge()
            end
        end,
    })
    self.dailyTagView = DailyTagView.Create()
    self.settingsView = SettingsView.Create({
        onUIClick = function()
            if self.callbacks.onUIClick then self.callbacks.onUIClick() end
        end,
        onMusicVolumeChange = function(value, shouldSave)
            if self.callbacks.onMusicVolumeChange then
                self.callbacks.onMusicVolumeChange(value, shouldSave)
            end
        end,
        onSfxVolumeChange = function(value, shouldSave)
            if self.callbacks.onSfxVolumeChange then
                self.callbacks.onSfxVolumeChange(value, shouldSave)
            end
        end,
        onDeleteSave = function()
            if self.callbacks.onDeleteSave then
                self.callbacks.onDeleteSave()
            end
        end,
    })
    self.debugStatusView = DebugStatusView.Create({
        onApply = function(statusId)
            if self.currentState_ and DebugStatusSystem.Apply(self.currentState_, statusId) then
                self.debugStatusView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
        onClear = function()
            if self.currentState_ then
                DebugStatusSystem.ClearAll(self.currentState_)
                self.debugStatusView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
    })

    self.debugWeaponView = DebugWeaponView.Create({
        onEquipWeapon = function(weaponId, quality)
            if self.currentState_ and DebugWeaponSystem.EquipWeapon(self.currentState_, weaponId, quality) then
                self.debugWeaponView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
        onToggleSkill = function(skill, enabled)
            if self.currentState_ and DebugWeaponSystem.SetSkillEnabled(self.currentState_, skill, enabled) then
                self.debugWeaponView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
        onSetAllSkills = function(weaponId, enabled)
            if self.currentState_ then
                DebugWeaponSystem.SetAllSkills(self.currentState_, weaponId, enabled)
                self.debugWeaponView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
        onCreateSkillChoices = function()
            if not self.currentState_ then return false end
            local ok, message = DebugWeaponSystem.CreateSkillChoices(self.currentState_)
            if not ok then
                self:ShowOperationWarning(message or "无法打开修炼提升三选一")
                return false
            end
            self:UpdateAll(self.currentState_)
            return true
        end,
        onScenario = function(scenarioId)
            if self.currentState_ and DebugWeaponSystem.PrepareScenario(self.currentState_, scenarioId) then
                self.debugWeaponView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
        onFieldRewardScenario = function(rewardCategory)
            if self.currentState_ and DebugWeaponSystem.PrepareFieldRewardScenario(self.currentState_, rewardCategory) then
                self.debugWeaponView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
        onSetHp = function(ratio)
            if self.currentState_ then
                DebugWeaponSystem.SetPlayerHpRatio(self.currentState_, ratio)
                self.debugWeaponView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
        onAscensionSuccess = function()
            if self.currentState_ and DebugWeaponSystem.TriggerAscensionSuccess(self.currentState_) then
                self:UpdateAll(self.currentState_)
            end
        end,
        onExecuteTurn = function()
            if self.callbacks.onDebugExecuteTurn then
                self.callbacks.onDebugExecuteTurn()
            end
        end,
        onClear = function()
            if self.currentState_ and DebugWeaponSystem.Clear(self.currentState_) then
                self.debugWeaponView:Refresh(self.currentState_)
                self:UpdateAll(self.currentState_)
            end
        end,
    })

    local debugEntry = nil
    local weaponDebugEntry = nil
    if Config.DEBUG and Config.DEBUG.ENABLE_PLAYER_STATUS_PANEL == true then
        debugEntry = UI.Button {
            text = "状态",
            position = "absolute",
            top = 12,
            right = 12,
            width = 68,
            height = 36,
            zIndex = 1100,
            fontSize = 14,
            fontWeight = "bold",
            borderRadius = 10,
            borderWidth = 2,
            borderColor = {255, 219, 160, 255},
            backgroundColor = {165, 62, 50, 245},
            pressedBackgroundColor = {125, 42, 35, 255},
            textColor = {255, 245, 230, 255},
            onClick = function()
                if self.currentState_ then
                    self.debugStatusView:Show(self.currentState_)
                end
            end,
        }
    end

    if Config.DEBUG and Config.DEBUG.ENABLE_WEAPON_TEST_PANEL == true then
        weaponDebugEntry = UI.Button {
            text = "武器测试",
            position = "absolute",
            top = 56,
            right = 12,
            width = 88,
            height = 36,
            zIndex = 1100,
            fontSize = 13,
            fontWeight = "bold",
            borderRadius = 10,
            borderWidth = 2,
            borderColor = {255, 219, 160, 255},
            backgroundColor = {107, 125, 120, 245},
            pressedBackgroundColor = {79, 98, 93, 255},
            textColor = {255, 245, 230, 255},
            onClick = function()
                if self.currentState_ then
                    self.debugWeaponView:Show(self.currentState_)
                end
            end,
        }
    end

    local gameContainerChildren = {
        UI.Panel {
            width = "100%",
            height = "100%",
            children = {
                self.fieldPanel,
            },
        },
        self.floatingTextView:GetRoot(),
        self.tutorialView:GetRoot(),
        self.infoPanel:GetRoot(),
        self.rogueRewardView:GetRoot(),
        self.shopView:GetRoot(),
        self.mainMenuView:GetRoot(),
        self.reincarnationView:GetRoot(),
        self.rogueBuffListView:GetRoot(),
        self.titleView:GetRoot(),
        self.leaderboardView:GetRoot(),
        self.dailyChallengeView:GetRoot(),
        self.dailyTagView:GetRoot(),
        self.settingsView:GetRoot(),
        self.debugStatusView:GetRoot(),
        self.debugWeaponView:GetRoot(),
        self.gameOverPanel,
    }
    if debugEntry then
        table.insert(gameContainerChildren, debugEntry)
    end
    if weaponDebugEntry then
        table.insert(gameContainerChildren, weaponDebugEntry)
    end

    self.uiRoot = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = {28, 68, 64, 255},
        children = {
            UI.Panel {
                id = "gameContainer",
                width = "100%",
                height = "100%",
                children = gameContainerChildren,
            },
            self.dragContext,
        }
    }

    UI.SetRoot(self.uiRoot)
    self:UpdateAll(state)
    self:ShowTitle()
    print("[Title] 标题页面已显示")
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

function UIController:ShowShop()
    if self.shopView and self.currentState_ then
        self.shopView:Show(self.currentState_)
    end
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

function UIController:SetNormalSaveState(hasSave, canContinue)
    if self.titleView then
        self.titleView:SetSaveState(hasSave, canContinue)
    end
end

function UIController:SetNormalSaveLoading(loading)
    if self.titleView then
        self.titleView:SetSaveLoading(loading)
    end
end

function UIController:ShowTitle()
    if self.titleView then
        self.titleView:Show()
    end
end

function UIController:HideTitle()
    if self.titleView then
        self.titleView:Hide()
    end
end

function UIController:ShowSettings()
    if not self.settingsView then return end
    local settings = { musicVolume = 1.0, sfxVolume = 1.0 }
    if self.callbacks.getSettings then
        settings = self.callbacks.getSettings() or settings
    end
    self.settingsView:Show(settings)
end

function UIController:HideSettings()
    if self.settingsView then
        self.settingsView:Hide()
    end
end

function UIController:IsDailyChallengeVisible(challengeId)
    local visible = self.dailyChallengeView and self.dailyChallengeView.root
        and self.dailyChallengeView.root:IsVisible() == true
    if not visible then return false end
    return challengeId == nil or self.currentDailyChallengeId_ == challengeId
end

function UIController:ShowDailyChallenge(challenge, progress)
    if not self.dailyChallengeView then return end
    self.currentDailyChallengeId_ = challenge and challenge.id or nil
    self.dailyChallengeView:Show(challenge, progress)
end

function UIController:HideDailyChallenge()
    if self.dailyChallengeView then
        self.dailyChallengeView:Hide()
    end
end

function UIController:ShowLeaderboard(challengeId)
    if not self.leaderboardView then return end
    if challengeId then
        self.currentDailyChallengeId_ = challengeId
        self.leaderboardView:SetDailyChallengeId(challengeId)
        self.leaderboardView:ShowDaily()
        return
    end
    self.leaderboardView:ShowLoading()
    self:RefreshLeaderboard()
end

function UIController:RefreshLeaderboard()
    if not self.leaderboardView then return end
    LeaderboardService.LoadTop(20, function(entries, myEntry, errorMessage)
        self.leaderboardView:SetEntries(entries, myEntry, errorMessage)
    end)
end

function UIController:RefreshDailyLeaderboard()
    if not self.leaderboardView then return end
    local challengeId = self.leaderboardView.dailyChallengeId
    if not challengeId or challengeId == "" then
        local challenge = DailyChallenge.ResolveToday()
        if challenge.available ~= true then
            self.leaderboardView:SetDailyEntries(nil, nil, "服务器时间不可用，暂不能读取每日排行榜")
            return
        end
        challengeId = challenge.id
        self.currentDailyChallengeId_ = challengeId
        self.leaderboardView:SetDailyChallengeId(challengeId)
    end
    LeaderboardService.LoadDailyTop(challengeId, 20, function(entries, myEntry, errorMessage)
        self.leaderboardView:SetDailyEntries(entries, myEntry, errorMessage)
    end)
end

function UIController:ShowMainMenu()
    if self.mainMenuView and self.currentState_ then
        self.mainMenuView:Show(self.currentState_)
    end
end

function UIController:HideMainMenu()
    if self.mainMenuView then
        self.mainMenuView:Hide()
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
    self.coinSoundCooldown_ = math.max(0, self.coinSoundCooldown_ - dt)
    if self.dailyChallengeView then
        self.dailyChallengeView:Update(dt)
    end

    local arrivalCount = Effects.ConsumeCoinArrivalPulses()
    if arrivalCount > 0 and self.currentState_ then
        if self.coinSoundCooldown_ <= 0 and self.callbacks.onCoinArrival then
            self.callbacks.onCoinArrival()
            self.coinSoundCooldown_ = 0.12
        end
        self:UpdateBoard(self.currentState_)
        local coinLabel = self.fieldPanel:FindById("coinAmount")
        if coinLabel then
            coinLabel:Animate({
                keyframes = {
                    [0] = { scale = 1.0 },
                    [0.45] = { scale = 1.0 + math.min(0.24, 0.10 + arrivalCount * 0.03) },
                    [1] = { scale = 1.0 },
                },
                duration = 0.20,
                easing = "easeOutBack",
                fillMode = "forwards",
            })
        end
    end
end

function UIController:SyncDataToManager(state)
    for i = 1, Config.TOTAL_SLOTS do
        self.inventoryMgr:SetInventoryItem(i, state.slots[i])
    end
end

function UIController:UpdateTutorial(state)
    if not self.tutorialView then return end
    self.tutorialView:SetPresentation(TutorialSystem.GetPresentation(state))
    self.tutorialView:UpdateLayout()
end

function UIController:SetFirstStartGuidance(enabled)
    if self.titleView then
        self.titleView:SetFirstStartGuidance(enabled)
    end
end

function UIController:UpdateAll(state)
    self.currentState_ = state
    self:UpdateHUD(state)
    self:UpdateBoard(state)
    self:UpdateTutorial(state)
    self:ShowFloatingEvents(state)
    self:UpdateRogueRewardView(state)
    self:UpdateShopView(state)
    if state.isGameOver then
        self:ShowGameOver(state)
    else
        self:HideGameOver()
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
        self.rogueRewardView:Show(
            state.pendingRogueEvent,
            choices,
            state.pendingRogueStage,
            state.pendingRogueStageIndex,
            state.pendingRogueStages and #state.pendingRogueStages or 1
        )
    else
        self.rogueRewardView:Hide()
    end
end

function UIController:UpdateShopView(state)
    if not self.shopView then return end
    if state.pendingShop then
        self.shopView:Show(state)
    else
        self.shopView:Hide()
    end
end

function UIController:RefreshShop(state)
    if self.shopView and state and state.pendingShop then
        self.shopView:Refresh(state)
    end
end

function UIController:ShowDropMessages(state)
end

function UIController:UpdateHUD(state)
    self.hpLabel:SetText(tostring(state.hp))
    self.hpBar:SetValue(Clamp01(state.hp / state.maxHp))
    local realm = Config.GetRealm(state.realmIndex)
    if state.ascensionMode == true then
        self.realmLabel:SetText("飞升 · 无尽")
        self.expBar:SetValue(1)
        self.turnLabel:SetText("无尽第" .. tostring(state.endlessWaveIndex or state.waveCount or 1) .. "波")
        return
    end

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
        onShopClick = function()
            if self.callbacks.onShopClick then
                self.callbacks.onShopClick()
            end
        end,
        onDailyTagsClick = function(challenge)
            self:HideItemInfo()
            self.dailyTagView:Show(challenge)
        end,
        onMainMenuClick = function()
            if self.callbacks.onUIClick then self.callbacks.onUIClick() end
            self:ShowMainMenu()
        end,
        onExpCircleClick = function()
            self:ShowRealmInfo()
        end,
        onBlankClick = function()
            self:HideItemInfo()
        end,
    })
    if self.tutorialView then
        self.tutorialView:UpdateLayout()
    end
end

function UIController:ShowGameOver(state)
    local confirmButton = self.gameOverPanel:FindById("goConfirmButton")
    if confirmButton then confirmButton:SetText("确认") end
    self.gameOverPanel:SetVisible(true)
    local title = self.gameOverPanel:FindById("goTitle")
    local desc = self.gameOverPanel:FindById("goDesc")
    local reward = self.gameOverPanel:FindById("goReward")
    local s = self.gameOverPanel:FindById("goScore")
    local r = self.gameOverPanel:FindById("goRealm")
    local continueButton = self.gameOverPanel:FindById("goContinueButton")
    local reincarnateButton = self.gameOverPanel:FindById("goReincarnateButton")
    local reviveButton = self.gameOverPanel:FindById("goReviveButton")
    local restartButton = self.gameOverPanel:FindById("goRestartButton")
    local confirmButton = self.gameOverPanel:FindById("goConfirmButton")
    local totalKills = math.max(state.totalKills or 0, state.endlessKills or 0)

    if state.isVictory then
        if title then
            title:SetText(state.dailyChallenge and "每日挑战完成" or (state.victoryReason == "ascension_death" and "无尽挑战结束" or "飞升成功"))
        end
        if reward then
            reward:SetText(state.victoryReason == "ascension"
                and "飞升已成：已获得 1 轮回点"
                or "")
            reward:SetVisible(state.victoryReason == "ascension")
        end
        if s then
            s:SetVisible(true)
            s:SetText((state.dailyChallenge and "本局分数: " or "积分: ") .. state.score .. "  击杀: " .. tostring(totalKills))
        end
        if r then
            r:SetVisible(true)
            r:SetText(state.victoryReason == "ascension_death"
                and ("无尽波次: " .. tostring(state.endlessWaveIndex or 0))
                or ("已通关难度 " .. tostring(state.difficulty or 1)))
        end

        if state.victoryReason == "ascension_death" then
            if desc then desc:SetText("无尽挑战已完成。本局积分与击杀次数已结算，飞升时获得的轮回点不会重复发放。") end
            if continueButton then continueButton:SetVisible(false) end
            if reincarnateButton then
                reincarnateButton:SetText("返回主界面")
                reincarnateButton:SetVisible(true)
            end
            if reviveButton then reviveButton:SetVisible(false) end
            if confirmButton then confirmButton:SetVisible(false) end
            if restartButton then restartButton:SetVisible(false) end
        elseif state.victoryReason == "ascension_failed" then
            if desc then desc:SetText("飞升已成。本局积分与击杀次数已结算，飞升时获得的轮回点不会重复发放。") end
            if continueButton then continueButton:SetVisible(false) end
            if reincarnateButton then
                reincarnateButton:SetText("返回主界面")
                reincarnateButton:SetVisible(true)
            end
            if reviveButton then reviveButton:SetVisible(false) end
            if confirmButton then confirmButton:SetVisible(false) end
            if restartButton then restartButton:SetVisible(false) end
        else
            if desc then desc:SetText("可继续当前游戏挑战更强波次，获得更高积分。") end
            if continueButton then continueButton:SetVisible(state.canContinueRun == true) end
            if reincarnateButton then
                reincarnateButton:SetText("返回主界面")
                reincarnateButton:SetVisible(true)
            end
            if confirmButton then confirmButton:SetVisible(false) end
            if restartButton then restartButton:SetVisible(false) end
        end
    else
        if reward then
            reward:SetText("")
            reward:SetVisible(false)
        end
        local abandoned = state.settlementType == "abandoned"
        local abandonedDaily = abandoned and DailyChallenge.IsActive(state)
        if title then title:SetText(abandoned and "已放弃本局" or "道陨身殒") end
        if desc then
            desc:SetText(abandonedDaily
                and "你已放弃本次每日挑战。本局已结算，但不获得轮回点。"
                or (abandoned and "你已放弃本局。本局不获得轮回点，将返回主界面。" or "本轮修行失败，将返回主界面。"))
        end
        if s then
            s:SetVisible(true)
            local displayScore = abandonedDaily
                and state.dailyChallengeResult
                and state.dailyChallengeResult.score
                or state.score
            s:SetText((abandonedDaily and "结算分数: " or "积分: ")
                .. tostring(displayScore or 0)
                .. "  击杀: " .. tostring(totalKills))
        end
        if r then
            r:SetVisible(true)
            r:SetText("最终境界: " .. Config.GetRealm(state.realmIndex).name)
        end
        if continueButton then continueButton:SetVisible(false) end
        if reincarnateButton then reincarnateButton:SetVisible(false) end
        if reviveButton then
            local remaining = self.callbacks.getReviveRemaining and self.callbacks.getReviveRemaining() or 0
            local reviveLabel = reviveButton:FindById("goReviveButtonLabel")
            if reviveLabel then
                reviveLabel:SetText("复活（今日剩余" .. tostring(remaining) .. "次）")
            end
            reviveButton:SetVisible(state.settlementType ~= "abandoned" and state.adReviveUsed ~= true and remaining > 0)
        end
        if confirmButton then confirmButton:SetVisible(true) end
        if restartButton then restartButton:SetVisible(false) end
    end
end

function UIController:HideGameOver()
    self.gameOverPanel:SetVisible(false)
end

return UIController
