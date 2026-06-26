-- main.lua
-- 仙侠合成塔防 - 手机竖屏版

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")
local Effects = require("Effects")
local DragActions = require("DragActions")
local UIController = require("UIController")
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
local UpdateAllUI
local UpdateSlots
local UpdateFieldPanel
local RestartGame

function Start()
    graphics.windowTitle = "仙侠合成塔防"

    UI.Init({
        theme = "default-dark",
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

    state_.slots[1] = GameState.CreateItem(Config.ITEM_TYPE.ATTACK, 1)
    state_.slots[3] = GameState.CreateItem(Config.ITEM_TYPE.ATTACK, 1)
    state_.slots[5] = GameState.CreateItem(Config.ITEM_TYPE.DEFENSE, 1)

    state_.waveCount = 1
    local t = Config.MELEE_TEMPLATES[1]
    table.insert(state_.monsters, {
        monsterType = Config.MONSTER_TYPE.MELEE,
        name = t.name,
        quality = t.quality or 1,
        hp = t.hp,
        maxHp = t.hp,
        atk = t.atk,
        exp = t.exp,
        dropChance = t.dropChance,
        skill = t.skill,
        col = 3,
        row = 1,
        charging = false,
        chargeTimer = 0,
        rowsWalked = 0,
        skillTriggered = false,
        shieldAmount = 0,
    })
end

CreateUI = function()
    uiController_ = UIController.Create(state_, {
        onDragStart = OnDragStart,
        onDragEnd = OnDragEnd,
        canDrop = CanDrop,
        onRestart = RestartGame,
    })
end

TriggerMergeEffect = function(category, idx, quality)
    Effects.TriggerMerge(category, idx, quality)
end

TriggerAttackEffects = function()
    Effects.TriggerAttack(state_)
end

OnDragStart = function(itemData, sourceSlot)
end

CanDrop = function(itemData, sourceSlot, targetSlot)
    return DragActions.CanDrop(state_, sourceSlot, targetSlot)
end

OnDragEnd = function(itemData, sourceSlot, targetSlot, success)
    if state_.isGameOver then return end

    if not targetSlot then
        UpdateSlots()
        return
    end

    local result = DragActions.ApplyDrop(state_, sourceSlot, targetSlot)
    if not result.changed then
        if result.message then
            UI.Toast.Show(result.message, { duration = 2, variant = "warning", position = "top" })
        end
        UpdateSlots()
        return
    end

    if result.merged then
        TriggerMergeEffect(result.mergeCategory, result.mergeIndex, result.mergeQuality)
    end

    GameState.ExecuteTurn(state_)
    TriggerAttackEffects()
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
    -- 保留天赋点（永久存档）
    local savedTalent = state_ and state_.talentPoints or 0
    local savedReincarnation = state_ and state_.reincarnationCount or 0
    StartNewGame()
    state_.talentPoints = savedTalent
    state_.reincarnationCount = savedReincarnation
    -- 天赋点影响初始血量
    local RealmSystem = require("RealmSystem")
    state_.maxHp = RealmSystem.GetMaxHp(state_)
    state_.hp = state_.maxHp
    state_.lastPillHp = state_.maxHp
    if uiController_ then
        uiController_:HideGameOver()
    end
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
