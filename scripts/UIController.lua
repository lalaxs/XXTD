local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")
local SlotAdapter = require("SlotAdapter")
local Views = require("Views")
local BoardView = require("BoardView")
local InfoPanelView = require("InfoPanelView")

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
end

local function CaptureLayout(element)
    if not element then return nil end
    local layout = element:GetAbsoluteLayout()
    if not layout or layout.w <= 0 or layout.h <= 0 then return nil end
    return { x = layout.x, y = layout.y, w = layout.w, h = layout.h }
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
                    backgroundColor = {60, 60, 80, 220},
                })
            end
            if self.callbacks.onDragEnd then
                self.callbacks.onDragEnd(itemData, sourceSlot, targetSlot, success)
            end
        end,
        canDrop = self.callbacks.canDrop,
    }

    local topHUD = self:CreateTopHUD()
    self.fieldPanel = Views.CreateFieldPanel()
    self:CreateSlots()
    self.gameOverPanel = Views.CreateGameOverPanel(self.callbacks.onRestart)
    self.infoPanel = InfoPanelView.Create()

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
                    self.infoPanel:GetRoot(),
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
                self:ShowItemInfo(self.currentState_.slots[i])
            end
        end
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
    self.storageSlots[1].props.onSlotClick = function()
        if self.currentState_ then
            self:ShowItemInfo(self.currentState_.dropQueue[1])
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

function UIController:ShowItemInfo(item)
    self.infoPanel:ShowItem(item)
end

function UIController:ShowChestInfo(quality)
    self.infoPanel:ShowChest(quality)
end

function UIController:ShowMonsterInfo(monster)
    self.infoPanel:ShowMonster(monster)
end

function UIController:HideItemInfo()
    self.infoPanel:Hide()
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
    self:UpdateFieldPanel(state)
    self:UpdateSlots(state)
    self:ShowDropMessages(state)
    if state.isGameOver then
        self:ShowGameOver(state)
    end
end

function UIController:ShowDropMessages(state)
    if state.pillConsumeMessages and #state.pillConsumeMessages > 0 then
        for _, info in ipairs(state.pillConsumeMessages) do
            local msg = string.format("您已自动使用了%s，恢复%d血", info.name, info.heal)
            UI.Toast.Show(msg, { duration = 2.5, variant = "info", position = "top" })
        end
        state.pillConsumeMessages = {}
    end

    if not state.dropMessages or #state.dropMessages == 0 then return end
    local msg = "获得: " .. table.concat(state.dropMessages, "、")
    UI.Toast.Show(msg, { duration = 2, variant = "success", position = "top" })
    state.dropMessages = {}
end

function UIController:UpdateHUD(state)
    self.hpLabel:SetText(tostring(state.hp))
    self.hpBar:SetValue(Clamp01(state.hp / state.maxHp))
    local realm = Config.REALMS[state.realmIndex]
    self.realmLabel:SetText(realm.name)
    local nextExp = 9999
    if state.realmIndex < #Config.REALMS then
        nextExp = Config.REALMS[state.realmIndex + 1].expRequired
    end
    local base = realm.expRequired
    local progress = (state.exp - base) / math.max(1, nextExp - base)
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

function UIController:UpdateBoard(state)
    BoardView.Update(self.fieldPanel, state, self.deploySlots, self.storageSlots[1], self.decomposeSlot, {
        onMonsterClick = function(monster)
            self:ShowMonsterInfo(monster)
        end,
        onChestClick = function(quality)
            self:ShowChestInfo(quality)
        end,
    })
end

function UIController:ShowGameOver(state)
    self.gameOverPanel:SetVisible(true)
    local s = self.gameOverPanel:FindById("goScore")
    local r = self.gameOverPanel:FindById("goRealm")
    if s then s:SetText("积分: " .. state.score) end
    if r then r:SetText("最终境界: " .. Config.REALMS[state.realmIndex].name) end
end

function UIController:HideGameOver()
    self.gameOverPanel:SetVisible(false)
end

function UIController:GetEffectLayoutSnapshot()
    local deployLayouts = {}
    for i = 1, Config.TOTAL_SLOTS do
        deployLayouts[i] = CaptureLayout(self.deploySlots[i])
    end

    local storageLayouts = {}
    storageLayouts[1] = CaptureLayout(self.storageSlots[1])

    -- 捕获部署面板和存储面板的整体布局作为后备
    local deployPanelEl = self.uiRoot and self.uiRoot:FindById("deployPanel") or nil
    local storagePanelEl = self.uiRoot and self.uiRoot:FindById("storagePanel") or nil

    return {
        deploySlots = deployLayouts,
        storageSlots = storageLayouts,
        field = CaptureLayout(self.fieldPanel),
        deployPanel = CaptureLayout(deployPanelEl),
        storagePanel = CaptureLayout(storagePanelEl),
    }
end

return UIController
