-- main.lua
-- 仙侠合成塔防 - 手机竖屏版

local UI = require("urhox-libs/UI")
local RealmSystem = require("RealmSystem")
local Effects = require("Effects")
local DragActions = require("DragActions")
local UIController = require("UIController")
local ConsumableActions = require("actions.ConsumableActions")
local ShopActions = require("actions.ShopActions")
local RogueRewardActions = require("actions.RogueRewardActions")
local RunLifecycle = require("flow.RunLifecycle")
local TurnFlowController = require("flow.TurnFlowController")
-- VectorIcons 和 FieldView 的图标绘制已移到 UI 层
-- NanoVG 只负责特效

---@type table|nil
local state_ = nil
local uiController_ = nil
local vg_ = nil
local firstFrameDone_ = false
local turnFlow_ = nil

local StartNewGame
local CreateUI
local TriggerMergeEffect
local OnDragStart
local CanDrop
local OnDragEnd
local OnUseConsumable
local OnShopClick
local OnBuyShopItem
local OnRefreshShop
local OnCloseShop
local OnSelectRogueReward
local OnAbandonRun
local UpdateAllUI
local UpdateSlots
local UpdateFieldPanel
local RestartGame
local ContinueRun
local EnterReincarnation

local function StartNewGameWithProgress(progress)
    state_ = RunLifecycle.StartNewGame(progress)
    Effects.Reset()
    firstFrameDone_ = false
end

local function HasPendingRogueChoice()
    return state_ and state_.pendingRogueChoices and #state_.pendingRogueChoices > 0
end

local function ShowOperationUnavailable()
    if uiController_ then
        uiController_:ShowOperationWarning("该操作不可用")
    end
end

local function CreateTurnFlowController()
    turnFlow_ = TurnFlowController.Create({
        onRefreshResolved = function()
            UpdateAllUI()
        end,
        onShowHitVisual = function(hitVisualState)
            if uiController_ and hitVisualState then
                uiController_:UpdateAll(hitVisualState)
            end
        end,
        onShowTurnVisual = function(turnVisualState)
            if uiController_ and turnVisualState then
                uiController_:UpdateAll(turnVisualState)
                return true
            end
            return false
        end,
        triggerAttack = function(state)
            local duration, hitDelay = Effects.TriggerAttack(state)
            Effects.TriggerCoinDrops(state, hitDelay)
            return duration or 0, hitDelay or 0
        end,
    })
end

local function ResolvePendingTurnVisual()
    if turnFlow_ and turnFlow_:IsResolving() then
        turnFlow_:RefreshResolvedTurnNow()
    end
end

function Start()
    graphics.windowTitle = "仙侠合成塔防"

    UI.Init({
        theme = "default-dark",
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/AlimamaFangYuanTi.ttf",
                bold = "Fonts/AlimamaFangYuanTi.ttf",
            }},
        },
        scale = UI.Scale.DEFAULT,
    })

    vg_ = nvgCreate(1)
    CreateTurnFlowController()

    StartNewGame()
    CreateUI()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")

    print("=== 仙侠合成塔防 启动 ===")
end

function Stop()
    UI.Shutdown()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
end

StartNewGame = function()
    StartNewGameWithProgress(nil)
end

CreateUI = function()
    uiController_ = UIController.Create(state_, {
        onDragStart = OnDragStart,
        onDragEnd = OnDragEnd,
        canDrop = CanDrop,
        onUseConsumable = OnUseConsumable,
        onShopClick = OnShopClick,
        onBuyShopItem = OnBuyShopItem,
        onRefreshShop = OnRefreshShop,
        onCloseShop = OnCloseShop,
        onSelectRogueReward = OnSelectRogueReward,
        onAbandonRun = OnAbandonRun,
        onRestart = RestartGame,
        onContinueRun = ContinueRun,
        onReincarnate = EnterReincarnation,
    })
end

TriggerMergeEffect = function(category, idx, quality)
    Effects.TriggerMerge(category, idx, quality)
    if uiController_ then
        uiController_:ShowMergeFloat(category, idx, quality)
    end
end

OnDragStart = function(itemData, sourceSlot)
end

CanDrop = function(itemData, sourceSlot, targetSlot)
    ResolvePendingTurnVisual()
    if HasPendingRogueChoice() then return false end
    return DragActions.CanDrop(state_, sourceSlot, targetSlot)
end

OnDragEnd = function(itemData, sourceSlot, targetSlot, success)
    if state_.isGameOver then return end
    ResolvePendingTurnVisual()
    if HasPendingRogueChoice() then
        ShowOperationUnavailable()
        UpdateAllUI()
        return
    end

    if not targetSlot then
        UpdateSlots()
        return
    end

    local result = DragActions.ApplyDrop(state_, sourceSlot, targetSlot)
    if not result.changed then
        if result.message then
            ShowOperationUnavailable()
        end
        UpdateSlots()
        return
    end

    if result.merged then
        TriggerMergeEffect(result.mergeCategory, result.mergeIndex, result.mergeQuality)
    end

    if result.decomposed then
        RealmSystem.CheckRealmUp(state_)
        UpdateAllUI()
        return
    end

    if turnFlow_ then
        turnFlow_:ExecutePlayerTurn(state_)
    else
        UpdateAllUI()
    end
end

OnUseConsumable = function(context)
    if state_.isGameOver or not context then return end
    ResolvePendingTurnVisual()
    if HasPendingRogueChoice() then
        ShowOperationUnavailable()
        UpdateAllUI()
        return
    end

    local result = ConsumableActions.Use(state_, context)
    if not result.ok and result.message then
        ShowOperationUnavailable()
    end

    if result.ok then
        if uiController_ then
            uiController_:HideItemInfo()
        end
        UpdateAllUI()
    else
        UpdateSlots()
    end
end

OnShopClick = function()
    if not state_ or state_.isGameOver then return end
    ResolvePendingTurnVisual()
    ShopActions.Open(state_)
    UpdateAllUI()
end

OnBuyShopItem = function(itemIndex)
    if not state_ or state_.isGameOver or not state_.pendingShop then return end
    ResolvePendingTurnVisual()

    local result = ShopActions.Buy(state_, itemIndex)
    if not result.ok and result.message and uiController_ then
        uiController_:ShowOperationWarning(result.message)
    end
    UpdateAllUI()
end

OnRefreshShop = function()
    if not state_ or state_.isGameOver or not state_.pendingShop then return end
    ResolvePendingTurnVisual()

    local result = ShopActions.Refresh(state_)
    if not result.ok and result.message and uiController_ then
        uiController_:ShowOperationWarning(result.message)
    end
    UpdateAllUI()
end

OnCloseShop = function()
    if not state_ then return end
    ShopActions.Close(state_)
    UpdateAllUI()
end

OnSelectRogueReward = function(rewardId)
    if state_.isGameOver then return end
    ResolvePendingTurnVisual()

    local result = RogueRewardActions.Select(state_, rewardId)
    if not result.ok and result.message then
        ShowOperationUnavailable()
    end

    UpdateAllUI()
end

OnAbandonRun = function()
    ResolvePendingTurnVisual()
    if not state_ then return end

    state_ = RunLifecycle.AbandonRunKeepingProgress(state_)
    Effects.Reset()
    firstFrameDone_ = false
    UpdateAllUI()
end

UpdateAllUI = function()
    if uiController_ then
        uiController_:UpdateAll(state_)
    end
end

UpdateSlots = function()
    if uiController_ then
        uiController_:UpdateSlots(state_)
    end
end

UpdateFieldPanel = function()
    if uiController_ then
        uiController_:UpdateFieldPanel(state_)
    end
end

RestartGame = function()
    if uiController_ then
        uiController_:ClearFloatingTexts()
    end
    state_ = RunLifecycle.RestartKeepingProgress(state_)
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:HideGameOver()
    end
    UpdateAllUI()
end

ContinueRun = function()
    if not state_ or not state_.canContinueRun then return end

    if uiController_ then
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
    end

    state_ = RunLifecycle.ContinueRun(state_)
    UpdateAllUI()
end

EnterReincarnation = function()
    if not state_ then return end

    if uiController_ then
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
    end

    state_ = RunLifecycle.EnterReincarnation(state_)
    Effects.Reset()
    firstFrameDone_ = false
    UpdateAllUI()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    Effects.Update(dt)
    if turnFlow_ then
        turnFlow_:Update(dt)
    end
    if uiController_ then
        uiController_:Update(dt)
    end

    if not firstFrameDone_ then
        firstFrameDone_ = true
        UpdateAllUI()
    end
end

-- 图标绘制已全部移入 UI 层（FieldView + UIController.ApplyItemSlotVisual）

function HandleNanoVGRender(eventType, eventData)
    if not vg_ or not uiController_ then return end

    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local lw = w / dpr
    local lh = h / dpr
    nvgBeginFrame(vg_, lw, lh, dpr)
    -- 只绘制特效（图标已在 UI 层渲染）
    Effects.Render(vg_, state_, lw, lh)
    nvgEndFrame(vg_)
end
