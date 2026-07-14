-- main.lua
-- 仙侠合成塔防 - 手机竖屏版

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local RealmSystem = require("RealmSystem")
local TurnEngine = require("combat.TurnEngine")
local WaveSystem = require("WaveSystem")
local Effects = require("Effects")
local DragActions = require("DragActions")
local UIController = require("UIController")
local ConsumableService = require("items.ConsumableService")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local Stats = require("combat.Stats")
-- VectorIcons 和 FieldView 的图标绘制已移到 UI 层
-- NanoVG 只负责特效

---@type table|nil
local state_ = nil
local uiController_ = nil
local vg_ = nil
local firstFrameDone_ = false

local StartNewGame
local CreateUI
local TriggerMergeEffect
local TriggerAttackEffects
local OnDragStart
local CanDrop
local OnDragEnd
local OnUseConsumable
local OnSelectRogueReward
local OnAbandonRun
local UpdateAllUI
local UpdateSlots
local UpdateFieldPanel
local RestartGame
local ContinueRun
local EnterReincarnation

local function CopyTable(value)
    if type(value) ~= "table" then return value end
    local copied = {}
    for k, v in pairs(value) do
        copied[k] = CopyTable(v)
    end
    return copied
end

local function CapturePermanentProgress(state)
    if not state then return nil end
    return {
        talentPoints = state.talentPoints or 0,
        spentTalentPoints = state.spentTalentPoints or 0,
        purchasedTalents = CopyTable(state.purchasedTalents or {}),
        talentModifiers = CopyTable(state.talentModifiers or {}),
        talentVariants = CopyTable(state.talentVariants or {}),
        unlockedPools = CopyTable(state.unlockedPools or {}),
        unlockedWeaponSchools = CopyTable(state.unlockedWeaponSchools or {}),
        reincarnationCount = state.reincarnationCount or 0,
        difficulty = state.difficulty or 1,
        difficultyTalentBonus = state.difficultyTalentBonus or 0,
        maxUnlockedDifficulty = state.maxUnlockedDifficulty or 1,
    }
end

local function RestorePermanentProgress(state, progress)
    if not state or not progress then return end
    state.talentPoints = progress.talentPoints
    state.spentTalentPoints = progress.spentTalentPoints
    state.purchasedTalents = progress.purchasedTalents
    state.talentModifiers = progress.talentModifiers
    state.talentVariants = progress.talentVariants
    state.unlockedPools = progress.unlockedPools
    state.unlockedWeaponSchools = progress.unlockedWeaponSchools
    state.reincarnationCount = progress.reincarnationCount
    state.difficulty = progress.difficulty
    state.difficultyTalentBonus = progress.difficultyTalentBonus
    state.maxUnlockedDifficulty = progress.maxUnlockedDifficulty
    Stats.RecalculateMaxHp(state, { fullHeal = true })
end

local function ResetOpeningWave(state)
    if not state then return end
    state.monsters = {}
    state.pendingWaveQueue = {}
    state.pendingWaveIndex = nil
    state.pendingWaveExp = 0
    state.waveCount = 0
    state.realmWaveIndex = 0
    WaveSystem.ForceSpawnWave(state)
end

local function StartNewGameWithProgress(progress)
    StartNewGame()
    RestorePermanentProgress(state_, progress)
    if progress then
        ResetOpeningWave(state_)
    end
end

local function HasPendingRogueChoice()
    return state_ and state_.pendingRogueChoices and #state_.pendingRogueChoices > 0
end

local function HasActiveMonster()
    if not state_ then return false end
    for _, monster in ipairs(state_.monsters or {}) do
        if monster.hp and monster.hp > 0 then
            return true
        end
    end
    return false
end

local function ShowOperationUnavailable()
    if uiController_ then
        uiController_:ShowOperationWarning("该操作不可用")
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
    state_ = GameState.New()
    Effects.Reset()
    firstFrameDone_ = false

    state_.slots[1] = GameState.CreateItemByBaseId(state_, Config.ITEM_CATEGORY.WEAPON, "qingfeng_sword", 1)

    state_.waveCount = 0
    state_.realmWaveIndex = 0
    WaveSystem.ForceSpawnWave(state_)
end

CreateUI = function()
    uiController_ = UIController.Create(state_, {
        onDragStart = OnDragStart,
        onDragEnd = OnDragEnd,
        canDrop = CanDrop,
        onUseConsumable = OnUseConsumable,
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

TriggerAttackEffects = function()
    Effects.TriggerAttack(state_)
end

OnDragStart = function(itemData, sourceSlot)
end

CanDrop = function(itemData, sourceSlot, targetSlot)
    if HasPendingRogueChoice() then return false end
    return DragActions.CanDrop(state_, sourceSlot, targetSlot)
end

OnDragEnd = function(itemData, sourceSlot, targetSlot, success)
    if state_.isGameOver then return end
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

    TurnEngine.ExecuteTurn(state_)
    TriggerAttackEffects()
    UpdateAllUI()
end

OnUseConsumable = function(context)
    if state_.isGameOver or not context then return end
    if HasPendingRogueChoice() then
        ShowOperationUnavailable()
        UpdateAllUI()
        return
    end

    local result = ConsumableService.Use(state_, context.category, context.index)
    if not result.ok and result.message then
        ShowOperationUnavailable()
    end

    if result.ok then
        if uiController_ then
            uiController_:HideItemInfo()
            if (result.heal or 0) > 0 then
                uiController_:ShowPlayerHeal(result.heal)
            end
        end
        TriggerAttackEffects()
        RealmSystem.CheckRealmUp(state_)
        UpdateAllUI()
    else
        UpdateSlots()
    end
end

OnSelectRogueReward = function(rewardId)
    if state_.isGameOver then return end

    local result = RogueRewardSystem.SelectChoice(state_, rewardId)
    if result.ok then
        Stats.RecalculateMaxHp(state_, { addDeltaToHp = true })
        RealmSystem.CheckRealmUp(state_)
        if state_.shouldSpawnBreakthroughWave then
            state_.shouldSpawnBreakthroughWave = false
            WaveSystem.ForceSpawnWave(state_)
        elseif not HasPendingRogueChoice() and not HasActiveMonster() then
            state_.forceSpawnNextTurn = false
            WaveSystem.ForceSpawnWave(state_)
        end
    end

    if not result.ok and result.message then
        ShowOperationUnavailable()
    end

    UpdateAllUI()
end

OnAbandonRun = function()
    if not state_ then return end

    local progress = CapturePermanentProgress(state_)
    StartNewGameWithProgress(progress)
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
    local progress = CapturePermanentProgress(state_)
    if uiController_ then
        uiController_:ClearFloatingTexts()
    end
    StartNewGameWithProgress(progress)
    if uiController_ then
        uiController_:HideGameOver()
    end
    UpdateAllUI()
end

ContinueRun = function()
    if not state_ or not state_.canContinueRun then return end

    state_.isGameOver = false
    state_.isVictory = false
    state_.victoryReason = nil
    state_.canContinueRun = false
    state_.hp = state_.maxHp
    state_.lastPillHp = state_.maxHp
    state_.forceSpawnNextTurn = false

    if uiController_ then
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
    end

    if state_.shouldSpawnBreakthroughWave then
        state_.shouldSpawnBreakthroughWave = false
        WaveSystem.ForceSpawnWave(state_)
    elseif not HasPendingRogueChoice() and not HasActiveMonster() then
        WaveSystem.ForceSpawnWave(state_)
    end

    UpdateAllUI()
end

EnterReincarnation = function()
    if not state_ then return end

    RealmSystem.TriggerReincarnation(state_)
    local progress = CapturePermanentProgress(state_)

    if uiController_ then
        uiController_:HideGameOver()
        uiController_:ClearFloatingTexts()
    end

    StartNewGameWithProgress(progress)
    UpdateAllUI()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    Effects.Update(dt)
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
