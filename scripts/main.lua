-- main.lua
-- 一把仙剑闯天关 - 手机竖屏版

local UI = require("urhox-libs/UI")
local RawUIButton = UI.Button
local RawUIButtonNew = UI.Button.new
local RealmSystem = require("RealmSystem")
local Effects = require("Effects")
local DragActions = require("DragActions")
local UIController = require("UIController")
local ConsumableActions = require("actions.ConsumableActions")
local ShopActions = require("actions.ShopActions")
local RogueRewardActions = require("actions.RogueRewardActions")
local RunLifecycle = require("flow.RunLifecycle")
local TurnFlowController = require("flow.TurnFlowController")
local LeaderboardService = require("LeaderboardService")
local DailyChallenge = require("DailyChallenge")
local DailyChallengeProgress = require("DailyChallengeProgress")
-- 棋盘、道具和图标绘制已统一移入当前 UI 视图层。
-- NanoVG 只负责特效

---@type table|nil
local state_ = nil
local uiController_ = nil
local vg_ = nil
local firstFrameDone_ = false
local turnFlow_ = nil
---@type Scene|nil
local audioScene_ = nil
---@type SoundSource|nil
local bgmSource_ = nil
---@type Sound|nil
local bgmSound_ = nil

local BGM_PATH = "audio/bgm_zhangjian_baizhen.ogg"
local BGM_GAIN = 0.42
local SFX_BUTTON_PATH = "audio/sfx/sfx_ui_button_jianghu.mp3"
local SFX_HIT_PATH = "audio/sfx/sfx_weapon_hit_jianghu.mp3"
local SFX_CULTIVATION_PATH = "audio/sfx/sfx_cultivation_upgrade_jianghu.mp3"
local SFX_BUTTON_GAIN = 0.55
local SFX_HIT_GAIN = 0.58
local SFX_CULTIVATION_GAIN = 0.68

local StartNewGame
local CreateUI
local StartBackgroundMusic
local RestartBackgroundMusic
local StopBackgroundMusic
local PlaySoundEffect
local PlayButtonSound
local PlayHitSound
local PlayCultivationSound
local InstallButtonSounds
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
local StartGame
local ContinueRun
local EnterReincarnation
local OpenDailyChallenge
local StartDailyChallenge

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
            local damageEvents = hitVisualState and hitVisualState.visualEventQueue and hitVisualState.visualEventQueue.damageDealt or {}
            for _, damageEvent in ipairs(damageEvents) do
                if damageEvent and (damageEvent.dmg or 0) > 0 then
                    PlayHitSound()
                    break
                end
            end
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
    graphics.windowTitle = "一把仙剑闯天关"

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
    InstallButtonSounds()

    StartNewGame()
    CreateUI()
    StartBackgroundMusic()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("SoundFinished", "HandleSoundFinished")

    print("=== 一把仙剑闯天关 启动 ===")
end

function Stop()
    StopBackgroundMusic()
    UI.Shutdown()
    if vg_ then
        nvgDelete(vg_)
        vg_ = nil
    end
end

StartNewGame = function()
    StartNewGameWithProgress(nil)
end

StartBackgroundMusic = function()
    if bgmSource_ and bgmSource_:IsPlaying() then
        return
    end

    bgmSound_ = cache:GetResource("Sound", BGM_PATH)
    if not bgmSound_ then
        print("[Audio] BGM 加载失败: " .. BGM_PATH)
        return
    end

    if not audioScene_ then
        audioScene_ = Scene()
    end
    local audioNode = audioScene_:CreateChild("BackgroundMusic")
    bgmSource_ = audioNode:CreateComponent("SoundSource")
    bgmSound_:SetLooped(true)
    bgmSource_:SetSoundType(SOUND_MUSIC)
    bgmSource_:SetGain(BGM_GAIN)
    bgmSource_:Play(bgmSound_)

    local buttonSound = cache:GetResource("Sound", SFX_BUTTON_PATH)
    local hitSound = cache:GetResource("Sound", SFX_HIT_PATH)
    local cultivationSound = cache:GetResource("Sound", SFX_CULTIVATION_PATH)
    if buttonSound and hitSound and cultivationSound then
        print("[Audio] 按钮、击打、修炼音效预加载完成")
    else
        print("[Audio] 部分游戏音效预加载失败")
    end

    print(string.format("[Audio] BGM 开始循环播放: %s，音量=%.2f", BGM_PATH, BGM_GAIN))
end

RestartBackgroundMusic = function()
    if not bgmSource_ or not bgmSound_ then
        StartBackgroundMusic()
        return
    end
    bgmSource_:Play(bgmSound_)
    print("[Audio] BGM 已从开头重新循环")
end

PlaySoundEffect = function(soundPath, gain)
    if not audioScene_ then
        audioScene_ = Scene()
    end

    local sound = cache:GetResource("Sound", soundPath)
    if not sound then
        print("[Audio] 音效加载失败: " .. soundPath)
        return
    end

    local soundNode = audioScene_:CreateChild("SoundEffect")
    local source = soundNode:CreateComponent("SoundSource")
    source:SetSoundType(SOUND_EFFECT)
    source:SetGain(gain or 1.0)
    source:SetAutoRemoveMode(REMOVE_NODE)
    source:Play(sound)
end

PlayButtonSound = function()
    PlaySoundEffect(SFX_BUTTON_PATH, SFX_BUTTON_GAIN)
end

PlayHitSound = function()
    PlaySoundEffect(SFX_HIT_PATH, SFX_HIT_GAIN)
end

PlayCultivationSound = function()
    PlaySoundEffect(SFX_CULTIVATION_PATH, SFX_CULTIVATION_GAIN)
end

InstallButtonSounds = function()
    RawUIButton.new = function(self, props)
        props = props or {}
        local onClick = props.onClick
        if onClick then
            props.onClick = function(widget, event)
                PlayButtonSound()
                onClick(widget, event)
            end
        end
        return RawUIButtonNew(self, props)
    end
end

StopBackgroundMusic = function()
    if bgmSource_ then
        bgmSource_:StopImmediate()
        bgmSource_ = nil
    end
    bgmSound_ = nil
    if audioScene_ then
        audioScene_:Dispose()
        audioScene_ = nil
    end
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
        onStartGame = StartGame,
        onContinueRun = ContinueRun,
        onReincarnate = EnterReincarnation,
        onOpenDailyChallenge = OpenDailyChallenge,
        onBeginDailyChallenge = StartDailyChallenge,
        onCultivationUpgrade = PlayCultivationSound,
        onDebugExecuteTurn = function()
            ResolvePendingTurnVisual()
            if HasPendingRogueChoice() then
                ShowOperationUnavailable()
                return
            end
            if turnFlow_ then
                turnFlow_:ExecutePlayerTurn(state_)
            else
                require("combat.TurnEngine").ExecuteTurn(state_)
                UpdateAllUI()
            end
        end,
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
    if state_ and state_.isGameOver then
        if DailyChallenge.IsActive(state_) and not state_.dailyChallengeResultRecorded then
            local finalScore = LeaderboardService.CalculateFinalScore(state_)
            local progress = state_.dailyChallengeProgress
            if progress then
                local _, isNewBest = DailyChallengeProgress.Complete(progress, finalScore)
                state_.dailyChallengeResult = {
                    score = finalScore,
                    isNewBest = isNewBest,
                    challengeId = state_.dailyChallenge.id,
                }
            end
            state_.dailyChallengeResultRecorded = true
        end
        if not state_.leaderboardSubmitted then
            LeaderboardService.SubmitFinalResult(state_)
        end
    end
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

StartGame = function()
    if uiController_ then
        uiController_:ClearFloatingTexts()
    end
    state_ = RunLifecycle.RestartKeepingProgress(state_)
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:HideTitle()
        uiController_:HideGameOver()
    end
    UpdateAllUI()
    print("[Title] 开始新游戏")
end

ContinueRun = function()
    if not state_ then return end

    if uiController_ then
        uiController_:HideTitle()
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
    end

    if state_.canContinueRun then
        state_ = RunLifecycle.ContinueRun(state_)
    end
    UpdateAllUI()
    print("[Title] 继续当前游戏")
end

OpenDailyChallenge = function()
    print("[Daily] 打开每日挑战详情")
    local challenge = DailyChallenge.ResolveToday()
    local progress = DailyChallengeProgress.Load(challenge.id)
    if uiController_ then
        uiController_:ShowDailyChallenge(challenge, progress)
    end
end

StartDailyChallenge = function()
    print("[Daily] 确认开始每日挑战")
    local challenge = DailyChallenge.ResolveToday()
    local progress = DailyChallengeProgress.Load(challenge.id)
    if not DailyChallengeProgress.CanStart(progress) then
        if uiController_ then
            uiController_:ShowDailyChallenge(challenge, progress)
            uiController_:ShowCenterFloat("今日挑战次数已用尽", "warning", { anchorY = 0.30, duration = 1.2 })
        end
        return
    end

    if not DailyChallengeProgress.BeginAttempt(progress) then
        return
    end

    state_ = RunLifecycle.StartNewGame(nil, { dailyChallenge = challenge })
    state_.dailyChallengeProgress = progress
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:HideDailyChallenge()
        uiController_:HideTitle()
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
        uiController_:ShowCenterFloat("今日挑战 · " .. challenge.date, "info", { anchorY = 0.30, duration = 1.4 })
    end
    UpdateAllUI()
    print(string.format("[Daily] 开始每日挑战 %s，种子=%d", challenge.id, challenge.seed))
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

function HandleSoundFinished(eventType, eventData)
    local source = eventData:GetPtr("SoundSource")
    if source == bgmSource_ then
        RestartBackgroundMusic()
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    if bgmSource_ and bgmSound_ and not bgmSource_:IsPlaying() then
        RestartBackgroundMusic()
    end
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

-- 棋盘与道具绘制已统一移入当前 UI 视图层。
-- NanoVG 只负责特效。
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
