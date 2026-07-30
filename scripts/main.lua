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
local GameSettings = require("GameSettings")
local SaveService = require("SaveService")
local RewardAdService = require("RewardAdService")
local TutorialSystem = require("TutorialSystem")
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
local uiClickSoundCooldown_ = 0
---@type table
local settings_ = { musicVolume = 1.0, sfxVolume = 1.0 }
local rewardAdService_ = RewardAdService.Create()
local normalSavedState_ = nil
local normalHasActiveRun_ = false
local normalSaveLoaded_ = false
local isFirstEntry_ = false
local currentRunStarted_ = false
local lastSavedNormalTurn_ = nil
local lastSavedDailyTurn_ = nil

local BGM_PLAYLIST = {
    "audio/bgm_yunxiu_chenyan_songfeng_ruxian.ogg",
    "audio/bgm_xianting_wuhou_yijuan_qingxiu.ogg",
    "audio/bgm_yuezhao_lingtai_jingye_guanxin.ogg",
}
local bgmTrackIndex_ = 1
local BGM_GAIN = 0.24
local SFX_BUTTON_PATH = "audio/sfx/sfx_ui_button_cartoon_short.mp3"
local SFX_WEAPON_PLACE_PATH = "audio/sfx/sfx_artifact_place_wood_soft_v2.mp3"
local SFX_WEAPON_MERGE_PATH = "audio/sfx/sfx_weapon_merge_cartoon_short.mp3"
local SFX_COIN_PATH = "audio/sfx/sfx_gold_coins_clink_v5.mp3"
local SFX_BUTTON_GAIN = 0.58
local SFX_WEAPON_PLACE_GAIN = 0.62
local SFX_WEAPON_MERGE_GAIN = 0.96
local SFX_COIN_GAIN = 0.78

local StartNewGame
local CreateUI
local StartBackgroundMusic
local RestartBackgroundMusic
local StopBackgroundMusic
local PlaySoundEffect
local PlayButtonSound
local PlayCoinArrivalSound
local PlayWeaponPlaceSound
local PlayWeaponMergeSound
local InstallButtonSounds
local ApplyAudioSettings
local ChangeMusicVolume
local ChangeSfxVolume
local DeleteSaveData
local TriggerMergeEffect
local CanDrop
local OnDragEnd
local OnUseConsumable
local OnShopClick
local OnBuyShopItem
local OnClaimShopAdItem
local OnRefreshShop
local OnAdRefreshShop
local OnRefreshRogueReward
local OnReviveByAd
local OnResetDailyChallenge
local OnCloseShop
local OnSelectRogueReward
local OnAbandonRun
local OnSaveAndReturnToTitle
local UpdateAllUI
local UpdateSlots
local UpdateFieldPanel
local RestartGame
local StartGame
local ContinueRun
local ContinueDailyChallenge
local ConfirmGameOver
local ReturnToTitle
local EnterReincarnation
local OpenDailyChallenge
local StartDailyChallenge

local function ShuffleBackgroundMusicPlaylist()
    for i = #BGM_PLAYLIST, 2, -1 do
        local j = Rand() % i + 1
        BGM_PLAYLIST[i], BGM_PLAYLIST[j] = BGM_PLAYLIST[j], BGM_PLAYLIST[i]
    end
    bgmTrackIndex_ = 1
    print("[Audio] 本次启动 BGM 顺序已随机排列")
end

local function RefreshNormalSaveMenuState()
    if uiController_ then
        uiController_:SetNormalSaveState(normalSavedState_ ~= nil, normalHasActiveRun_)
    end
end

local function SaveCurrentState(hasActiveRun)
    if not state_ then return false end
    if DailyChallenge.IsActive(state_) then
        local challengeId = state_.dailyChallenge and state_.dailyChallenge.id
        if not challengeId then return false end
        local saved = SaveService.SaveDaily(state_, challengeId)
        if saved then lastSavedDailyTurn_ = state_.turn or 0 end
        return saved
    end

    local saved = SaveService.SaveNormal(state_, hasActiveRun == true)
    if saved then
        normalSavedState_ = state_
        normalHasActiveRun_ = hasActiveRun == true
        lastSavedNormalTurn_ = state_.turn or 0
        RefreshNormalSaveMenuState()
    end
    return saved
end

local function LoadNormalSaveAtStartup()
    local savedState, hasActiveRun = SaveService.LoadNormal()
    if savedState then
        local restored = RunLifecycle.RestoreSavedState(savedState)
        if restored and not DailyChallenge.IsActive(restored) then
            state_ = restored
            normalSavedState_ = savedState
            normalHasActiveRun_ = hasActiveRun == true
            lastSavedNormalTurn_ = state_.turn or 0
        else
            SaveService.DeleteNormalLocalCache()
            StartNewGame()
        end
    else
        StartNewGame()
    end

    normalSaveLoaded_ = false
    currentRunStarted_ = false
    Effects.Reset()
    firstFrameDone_ = false
end

local function LoadNormalSaveFromCloud()
    if uiController_ then uiController_:SetNormalSaveLoading(true) end
    local started = SaveService.LoadNormalAsync(function(savedState, hasActiveRun, errorMessage)
        normalSaveLoaded_ = true
        local restored = savedState and RunLifecycle.RestoreSavedState(savedState) or nil
        if restored and not DailyChallenge.IsActive(restored) then
            state_ = restored
            normalSavedState_ = savedState
            normalHasActiveRun_ = hasActiveRun == true
            lastSavedNormalTurn_ = state_.turn or 0
            print("[Save] 启动时已从云端/本地恢复普通存档")
        elseif not normalSavedState_ then
            normalHasActiveRun_ = false
            if errorMessage then print("[Save] 启动存档读取回退为新玩家: " .. tostring(errorMessage)) end
        end
        isFirstEntry_ = normalSavedState_ == nil
        print("[Tutorial] 首次进入判定=" .. tostring(isFirstEntry_))
        RefreshNormalSaveMenuState()
        if uiController_ then
            uiController_:SetFirstStartGuidance(isFirstEntry_)
            uiController_:UpdateAll(state_)
        end
    end)
    if not started then
        normalSaveLoaded_ = true
        isFirstEntry_ = normalSavedState_ == nil
        RefreshNormalSaveMenuState()
        if uiController_ then uiController_:SetFirstStartGuidance(isFirstEntry_) end
    end
end

local function RestoreNormalMenuState()
    local savedState, hasActiveRun = SaveService.LoadNormal()
    local restored = savedState and RunLifecycle.RestoreSavedState(savedState) or nil
    if restored and not DailyChallenge.IsActive(restored) then
        state_ = restored
        normalSavedState_ = savedState
        normalHasActiveRun_ = hasActiveRun == true
        lastSavedNormalTurn_ = state_.turn or 0
    else
        state_ = RunLifecycle.StartNewGame(nil)
        normalSavedState_ = nil
        normalHasActiveRun_ = false
        lastSavedNormalTurn_ = nil
    end
    currentRunStarted_ = false
    Effects.Reset()
    firstFrameDone_ = false
    RefreshNormalSaveMenuState()
end

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
    graphics.windowTitle = "一把仙剑闯天关"
    settings_ = GameSettings.Load()
    ApplyAudioSettings()

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
    ShuffleBackgroundMusicPlaylist()

    LoadNormalSaveAtStartup()
    CreateUI()
    RefreshNormalSaveMenuState()
    LoadNormalSaveFromCloud()
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

ApplyAudioSettings = function()
    settings_ = GameSettings.Normalize(settings_)
    audio:SetMasterGain(SOUND_MUSIC, settings_.musicVolume)
    audio:SetMasterGain(SOUND_EFFECT, settings_.sfxVolume)
    print(string.format("[Audio] 已应用设置：音乐音量=%d%%，音效音量=%d%%",
        math.floor(settings_.musicVolume * 100 + 0.5),
        math.floor(settings_.sfxVolume * 100 + 0.5)))
end

ChangeMusicVolume = function(value, shouldSave)
    settings_.musicVolume = math.min(1.0, math.max(0.0, value or 1.0))
    audio:SetMasterGain(SOUND_MUSIC, settings_.musicVolume)
    if shouldSave then
        GameSettings.Save(settings_)
    end
end

ChangeSfxVolume = function(value, shouldSave)
    settings_.sfxVolume = math.min(1.0, math.max(0.0, value or 1.0))
    audio:SetMasterGain(SOUND_EFFECT, settings_.sfxVolume)
    if shouldSave then
        GameSettings.Save(settings_)
    end
end

DeleteSaveData = function()
    DailyChallengeProgress.DeleteSave()
    SaveService.DeleteAll()
    state_ = RunLifecycle.StartNewGame(nil)
    normalSavedState_ = nil
    normalHasActiveRun_ = false
    isFirstEntry_ = true
    currentRunStarted_ = false
    lastSavedNormalTurn_ = nil
    lastSavedDailyTurn_ = nil
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:HideSettings()
        uiController_:HideMainMenu()
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
        uiController_:ShowTitle()
        uiController_:SetFirstStartGuidance(true)
        RefreshNormalSaveMenuState()
        uiController_:UpdateAll(state_)
        uiController_:ShowCenterFloat("存档已删除", "info", { anchorY = 0.30, duration = 1.4 })
    end
    print("[Save] 当前轮回、永久成长与本地每日挑战进度已重置")
end

StartBackgroundMusic = function()
    if bgmSource_ and bgmSource_:IsPlaying() then
        return
    end

    local bgmPath = BGM_PLAYLIST[bgmTrackIndex_]
    bgmSound_ = cache:GetResource("Sound", bgmPath)
    if not bgmSound_ then
        print("[Audio] BGM 加载失败: " .. bgmPath)
        return
    end

    if not audioScene_ then
        audioScene_ = Scene()
    end
    local audioNode = audioScene_:CreateChild("BackgroundMusic")
    bgmSource_ = audioNode:CreateComponent("SoundSource")
    bgmSound_:SetLooped(false)
    bgmSource_:SetSoundType(SOUND_MUSIC)
    bgmSource_:SetGain(BGM_GAIN)
    bgmSource_:Play(bgmSound_)

    local bgmLoadedCount = 0
    for _, playlistPath in ipairs(BGM_PLAYLIST) do
        if cache:GetResource("Sound", playlistPath) then
            bgmLoadedCount = bgmLoadedCount + 1
        else
            print("[Audio] BGM 预加载失败: " .. playlistPath)
        end
    end

    local soundPaths = {
        SFX_BUTTON_PATH,
        SFX_WEAPON_PLACE_PATH,
        SFX_WEAPON_MERGE_PATH,
        SFX_COIN_PATH,
    }
    local loadedCount = 0
    for _, soundPath in ipairs(soundPaths) do
        if cache:GetResource("Sound", soundPath) then
            loadedCount = loadedCount + 1
        else
            print("[Audio] 音效预加载失败: " .. soundPath)
        end
    end
    print(string.format("[Audio] 游戏音效预加载完成: %d/%d；BGM: %d/%d",
        loadedCount, #soundPaths, bgmLoadedCount, #BGM_PLAYLIST))

    print(string.format("[Audio] BGM 播放第%d/%d首: %s，音量=%.2f",
        bgmTrackIndex_, #BGM_PLAYLIST, bgmPath, BGM_GAIN))
end

RestartBackgroundMusic = function()
    if not bgmSource_ then
        StartBackgroundMusic()
        return
    end

    bgmTrackIndex_ = bgmTrackIndex_ % #BGM_PLAYLIST + 1
    local bgmPath = BGM_PLAYLIST[bgmTrackIndex_]
    bgmSound_ = cache:GetResource("Sound", bgmPath)
    if not bgmSound_ then
        print("[Audio] 下一首 BGM 加载失败: " .. bgmPath)
        return
    end

    bgmSound_:SetLooped(false)
    bgmSource_:SetGain(BGM_GAIN)
    bgmSource_:Play(bgmSound_)
    print(string.format("[Audio] BGM 切换到第%d/%d首: %s", bgmTrackIndex_, #BGM_PLAYLIST, bgmPath))
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
    if uiClickSoundCooldown_ > 0 then return end
    PlaySoundEffect(SFX_BUTTON_PATH, SFX_BUTTON_GAIN)
    uiClickSoundCooldown_ = 0.06
end

PlayCoinArrivalSound = function()
    PlaySoundEffect(SFX_COIN_PATH, SFX_COIN_GAIN)
end

PlayWeaponPlaceSound = function()
    PlaySoundEffect(SFX_WEAPON_PLACE_PATH, SFX_WEAPON_PLACE_GAIN)
end

PlayWeaponMergeSound = function()
    PlaySoundEffect(SFX_WEAPON_MERGE_PATH, SFX_WEAPON_MERGE_GAIN)
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
        onDragEnd = OnDragEnd,
        canDrop = CanDrop,
        onUseConsumable = OnUseConsumable,
        onShopClick = OnShopClick,
        onBuyShopItem = OnBuyShopItem,
        onClaimShopAdItem = OnClaimShopAdItem,
        onRefreshShop = OnRefreshShop,
        onAdRefreshShop = OnAdRefreshShop,
        onRefreshRogueReward = OnRefreshRogueReward,
        onReviveByAd = OnReviveByAd,
        onResetDailyChallenge = OnResetDailyChallenge,
        onCloseShop = OnCloseShop,
        onSelectRogueReward = OnSelectRogueReward,
        onAbandonRun = OnAbandonRun,
        onSaveAndReturnToTitle = OnSaveAndReturnToTitle,
        onRestart = RestartGame,
        onStartGame = StartGame,
        onContinueRun = ContinueRun,
        onReturnToTitle = ReturnToTitle,
        onReincarnate = EnterReincarnation,
        onGameOverConfirm = ConfirmGameOver,
        onOpenDailyChallenge = OpenDailyChallenge,
        onBeginDailyChallenge = StartDailyChallenge,
        onContinueDailyChallenge = ContinueDailyChallenge,
        onUIClick = PlayButtonSound,
        onCoinArrival = PlayCoinArrivalSound,
        getSettings = function()
            return settings_
        end,
        getReviveRemaining = function()
            return rewardAdService_:GetReviveRemaining()
        end,
        onMusicVolumeChange = ChangeMusicVolume,
        onSfxVolumeChange = ChangeSfxVolume,
        onDeleteSave = DeleteSaveData,
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
    PlayWeaponMergeSound()
    if uiController_ then
        uiController_:ShowMergeFloat(category, idx, quality)
    end
end

CanDrop = function(itemData, sourceSlot, targetSlot)
    ResolvePendingTurnVisual()
    if HasPendingRogueChoice() then return false end
    if not TutorialSystem.CanDrop(state_, sourceSlot, targetSlot) then return false end
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

    if not TutorialSystem.CanDrop(state_, sourceSlot, targetSlot) then
        ShowOperationUnavailable()
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

    TutorialSystem.OnDropApplied(state_, sourceSlot, targetSlot, result)

    if result.merged then
        TriggerMergeEffect(result.mergeCategory, result.mergeIndex, result.mergeQuality)
    elseif result.moved and itemData and itemData.category == "weapon" then
        PlayWeaponPlaceSound()
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
    if not TutorialSystem.CanOpenShop(state_) then
        ShowOperationUnavailable()
        return
    end
    local shop = ShopActions.Open(state_)
    if shop and TutorialSystem.OnShopOpened(state_) and uiController_ then
        uiController_:ShowCenterFloat("新手引导完成，继续你的修行吧", "reward", { anchorY = 0.30, duration = 1.8 })
    end
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

OnClaimShopAdItem = function(itemIndex)
    if not state_ or state_.isGameOver or not state_.pendingShop then return end
    ResolvePendingTurnVisual()
    rewardAdService_:Show("shop_item", {
        onSuccess = function()
            local result = ShopActions.ClaimAdItem(state_, itemIndex)
            if not result.ok and result.message and uiController_ then
                uiController_:ShowOperationWarning(result.message)
            end
            UpdateAllUI()
        end,
        onFailure = function(message)
            if uiController_ then
                uiController_:ShowOperationWarning("领取失败：" .. tostring(message))
            end
            UpdateAllUI()
        end,
    })
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

OnAdRefreshShop = function()
    if not state_ or state_.isGameOver or not state_.pendingShop then return end
    ResolvePendingTurnVisual()
    rewardAdService_:Show("shop_refresh", {
        onSuccess = function()
            local result = ShopActions.RefreshByAd(state_)
            if not result.ok and result.message and uiController_ then
                uiController_:ShowOperationWarning(result.message)
            end
            UpdateAllUI()
        end,
        onFailure = function(message)
            if uiController_ then
                uiController_:ShowOperationWarning("商店刷新失败：" .. tostring(message))
            end
            UpdateAllUI()
        end,
    })
end

OnReviveByAd = function()
    if not state_ or not state_.isGameOver or state_.isVictory or state_.adReviveUsed then return end
    rewardAdService_:Show("revive", {
        onSuccess = function()
            if not state_ or not state_.isGameOver or state_.adReviveUsed then return end
            state_.adReviveUsed = true
            state_.isGameOver = false
            state_.isVictory = false
            state_.victoryReason = nil
            state_.settlementType = nil
            state_.hp = state_.maxHp
            state_.monsters = {}
            state_.fieldRewards = {}
            state_.leaderboardSubmitted = false
            state_.dailyChallengeResultRecorded = false
            state_.forceSpawnNextTurn = true
            if uiController_ then
                uiController_:HideGameOver()
                uiController_:ShowCenterFloat("复活成功，场上敌人已清空", "reward", { anchorY = 0.36, duration = 1.4 })
            end
            UpdateAllUI()
        end,
        onFailure = function(message)
            if uiController_ then
                uiController_:ShowOperationWarning("复活失败：" .. tostring(message))
            end
            UpdateAllUI()
        end,
    })
end

OnRefreshRogueReward = function()
    if not state_ or state_.isGameOver or not HasPendingRogueChoice() then return end
    ResolvePendingTurnVisual()
    rewardAdService_:Show("rogue_refresh", {
        onSuccess = function()
            local result = RogueRewardActions.Refresh(state_)
            if not result.ok and result.message and uiController_ then
                uiController_:ShowOperationWarning(result.message)
            end
            UpdateAllUI()
        end,
        onFailure = function(message)
            if uiController_ then
                uiController_:ShowOperationWarning("看广告后才可刷新：" .. tostring(message))
            end
            UpdateAllUI()
        end,
    })
end

OnResetDailyChallenge = function()
    local challenge = DailyChallenge.ResolveToday()
    if not challenge.available then
        if uiController_ then uiController_:ShowOperationWarning("服务器时间不可用，暂不能重置") end
        return
    end
    SaveService.DeleteDaily()
    lastSavedDailyTurn_ = nil
    local progress = DailyChallengeProgress.Load(challenge.id)
    local reset = DailyChallengeProgress.Reset(progress)
    if not reset then
        if uiController_ then uiController_:ShowOperationWarning("今日挑战重置失败") end
        return
    end
    LeaderboardService.ResetDailyScore(challenge.id, function(ok, message)
        if not uiController_ then return end
        if not ok then
            uiController_:ShowOperationWarning("云端排行重置失败：" .. tostring(message))
            return
        end
        uiController_:ShowDailyChallenge(challenge, reset)
        uiController_:ShowCenterFloat("今日挑战已重置，可以再次挑战", "info", { anchorY = 0.30, duration = 1.3 })
    end)
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
    if not state_ or state_.isGameOver then return end

    state_ = RunLifecycle.AbandonRun(state_)
    Effects.Reset()
    firstFrameDone_ = false
    UpdateAllUI()
end

OnSaveAndReturnToTitle = function()
    ResolvePendingTurnVisual()
    if not state_ or state_.isGameOver or not currentRunStarted_ then return end

    if not SaveCurrentState(true) then
        if uiController_ then
            uiController_:ShowMainMenu()
            uiController_:ShowOperationWarning("存档失败，请稍后重试")
        end
        print("[Save] 保存当前游戏失败，已留在功能菜单")
        return
    end

    Effects.Reset()
    firstFrameDone_ = false
    currentRunStarted_ = false
    if uiController_ then
        uiController_:HideMainMenu()
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
        uiController_:ShowTitle()
        uiController_:UpdateAll(state_)
    end
    print("[Save] 当前游戏已保存，返回主界面")
end

UpdateAllUI = function()
    TutorialSystem.RefreshProgress(state_)
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
    if currentRunStarted_ and state_ then
        if DailyChallenge.IsActive(state_) and state_.isGameOver then
            SaveService.DeleteDaily()
            lastSavedDailyTurn_ = nil
            currentRunStarted_ = false
        else
            local hasActiveRun = state_.isGameOver ~= true or state_.canContinueRun == true
            SaveCurrentState(hasActiveRun)
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

ReturnToTitle = function()
    if not state_ or not state_.isGameOver then return end

    if uiController_ then
        uiController_:HideGameOver()
        uiController_:HideMainMenu()
        uiController_:ClearFloatingTexts()
    end

    local wasDailyChallenge = DailyChallenge.IsActive(state_)
    SaveCurrentState(false)
    if wasDailyChallenge then
        SaveService.DeleteDaily()
        lastSavedDailyTurn_ = nil
        RestoreNormalMenuState()
    else
        state_ = RunLifecycle.RestartKeepingProgress(state_)
        SaveCurrentState(false)
        currentRunStarted_ = false
    end
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:ShowTitle()
    end
    UpdateAllUI()
    print("[GameOver] 成功结算完成，返回主界面")
end

ConfirmGameOver = function()
    ReturnToTitle()
end

RestartGame = function()
    if uiController_ then
        uiController_:ClearFloatingTexts()
    end
    state_ = RunLifecycle.RestartKeepingProgress(state_)
    currentRunStarted_ = true
    SaveCurrentState(true)
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:HideGameOver()
    end
    UpdateAllUI()
end

StartGame = function()
    if not normalSaveLoaded_ then
        if uiController_ then uiController_:ShowOperationWarning("正在读取存档，请稍候") end
        return
    end
    if uiController_ then
        uiController_:ClearFloatingTexts()
    end
    SaveService.DeleteNormal()
    state_ = RunLifecycle.StartNewGame(nil, { firstRunTutorial = isFirstEntry_ })
    isFirstEntry_ = false
    normalSavedState_ = nil
    normalHasActiveRun_ = false
    currentRunStarted_ = true
    lastSavedNormalTurn_ = nil
    SaveCurrentState(true)
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:SetFirstStartGuidance(false)
        uiController_:HideTitle()
        uiController_:HideGameOver()
    end
    UpdateAllUI()
    print("[Title] 开始新游戏")
end

ContinueRun = function()
    if not normalSaveLoaded_ then
        if uiController_ then uiController_:ShowOperationWarning("正在读取存档，请稍候") end
        return
    end
    if not normalSavedState_ then return end

    local savedState = SaveService.LoadNormal()
    local restored = savedState and RunLifecycle.RestoreSavedState(savedState) or nil
    if not restored or DailyChallenge.IsActive(restored) then
        normalSavedState_ = nil
        normalHasActiveRun_ = false
        RefreshNormalSaveMenuState()
        return
    end
    state_ = restored
    normalSavedState_ = savedState
    normalHasActiveRun_ = true
    currentRunStarted_ = true
    lastSavedNormalTurn_ = state_.turn or 0

    if uiController_ then
        uiController_:HideTitle()
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
    end

    if state_.canContinueRun then
        state_ = RunLifecycle.ContinueRun(state_)
    end
    Effects.Reset()
    firstFrameDone_ = false
    UpdateAllUI()
    print("[Title] 已读取普通存档并继续游戏")
end

OpenDailyChallenge = function()
    print("[Daily] 打开每日挑战详情")
    local challenge = DailyChallenge.ResolveToday()
    local progress = challenge.available and DailyChallengeProgress.Load(challenge.id) or {}
    if not challenge.available then
        if uiController_ then uiController_:ShowDailyChallenge(challenge, progress) end
        return
    end

    progress.saveLoading = true
    progress.hasRunSave = false
    if uiController_ then uiController_:ShowDailyChallenge(challenge, progress) end

    local started = SaveService.LoadDailyAsync(challenge.id, function(savedState, errorMessage)
        local refreshedProgress = DailyChallengeProgress.Load(challenge.id)
        refreshedProgress.hasRunSave = savedState ~= nil
        refreshedProgress.saveLoading = false
        if errorMessage then
            print("[Daily] 云端运行档读取回退: " .. tostring(errorMessage))
        end
        if uiController_ and uiController_:IsDailyChallengeVisible(challenge.id) then
            uiController_:ShowDailyChallenge(challenge, refreshedProgress)
        end
    end)
    if not started then
        progress.saveLoading = false
        progress.hasRunSave = SaveService.LoadDaily(challenge.id) ~= nil
        if uiController_ then uiController_:ShowDailyChallenge(challenge, progress) end
    end
end

ContinueDailyChallenge = function()
    local challenge = DailyChallenge.ResolveToday()
    if not challenge.available then return end

    local savedState = SaveService.LoadDaily(challenge.id)
    local restored = savedState and RunLifecycle.RestoreSavedState(savedState) or nil
    if not restored or not DailyChallenge.IsActive(restored)
        or not restored.dailyChallenge or restored.dailyChallenge.id ~= challenge.id then
        SaveService.DeleteDaily()
        OpenDailyChallenge()
        return
    end

    state_ = restored
    currentRunStarted_ = true
    lastSavedDailyTurn_ = state_.turn or 0
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:HideDailyChallenge()
        uiController_:HideTitle()
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
    end
    UpdateAllUI()
    print("[Daily] 已读取今日挑战存档并继续")
end

StartDailyChallenge = function()
    print("[Daily] 确认开始每日挑战")
    local challenge = DailyChallenge.ResolveToday()
    if not challenge.available then
        if uiController_ then
            uiController_:ShowCenterFloat("服务器时间不可用，暂不能开启每日挑战", "warning", { anchorY = 0.30, duration = 1.5 })
        end
        return
    end
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

    SaveService.DeleteDaily()
    state_ = RunLifecycle.StartNewGame(nil, { dailyChallenge = challenge })
    state_.dailyChallengeProgress = progress
    currentRunStarted_ = true
    lastSavedDailyTurn_ = nil
    SaveCurrentState(true)
    Effects.Reset()
    firstFrameDone_ = false
    if uiController_ then
        uiController_:HideDailyChallenge()
        uiController_:HideTitle()
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
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
    uiClickSoundCooldown_ = math.max(0, uiClickSoundCooldown_ - dt)
    if bgmSource_ and bgmSound_ and not bgmSource_:IsPlaying() then
        RestartBackgroundMusic()
    end
    Effects.Update(dt)
    rewardAdService_:Update(dt)
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
