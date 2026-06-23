local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")
local Assets = require("Assets")
local SlotAdapter = require("SlotAdapter")
local Views = require("Views")

local UIController = {}
UIController.__index = UIController

local STORAGE_SIZE = 1

local QUALITY_COLORS = {
    {200, 200, 200, 255},   -- 1 白
    {100, 210, 120, 255},   -- 2 绿
    {80, 160, 255, 255},    -- 3 蓝
    {180, 100, 255, 255},   -- 4 紫
    {230, 70, 60, 255},     -- 5 红
    {255, 200, 50, 255},    -- 6 金
    {180, 140, 40, 255},    -- 7 暗金
    {200, 130, 255, 255},   -- 8 紫金
    {255, 160, 200, 255},   -- 9 粉霞
}

local function ApplyItemSlotVisual(slot, item)
    slot:SetItem(SlotAdapter.ItemToSlotData(item))
    if slot.iconLabel_ then
        slot.iconLabel_:SetText("")
    end
    if item then
        slot.props.backgroundImage = Assets.GetItemIcon(item)
        slot.props.backgroundSize = "contain"
        slot.props.backgroundColor = {255, 255, 255, 30}
        slot.props.borderColor = QUALITY_COLORS[item.quality] or STYLE.CARD_BORDER
        slot.props.borderWidth = 3
    else
        slot.props.backgroundImage = nil
        slot.props.backgroundColor = STYLE.CARD_BG
        slot.props.borderColor = STYLE.CARD_BORDER
        slot.props.borderWidth = 3
    end
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
        gameOverPanel = nil,
        itemInfoPanel = nil,
        itemInfoIcon = nil,
        itemInfoTitle = nil,
        itemInfoDesc = nil,
        itemInfoTimer = 0,
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
        onDragStart = self.callbacks.onDragStart,
        onDragEnd = self.callbacks.onDragEnd,
        canDrop = self.callbacks.canDrop,
    }

    local topHUD = self:CreateTopHUD()
    self.fieldPanel = Views.CreateFieldPanel()
    local deployPanel = self:CreateDeployPanel()
    local storagePanel = self:CreateStoragePanel()
    self.gameOverPanel = Views.CreateGameOverPanel(self.callbacks.onRestart)
    self.itemInfoPanel = self:CreateItemInfoPanel()

    self.uiRoot = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = STYLE.BG_TOP,
        children = {
            UI.Panel {
                position = "absolute",
                top = 0, left = 0, right = 0, bottom = 0,
                pointerEvents = "none",
                backgroundColor = {200, 225, 240, 30},
            },
            UI.Panel {
                id = "gameContainer",
                width = "100%",
                height = "100%",
                maxWidth = 480,
                marginHorizontal = "auto",
                children = {
                    UI.SafeAreaView {
                        width = "100%",
                        height = "100%",
                        children = {
                            topHUD,
                            self.fieldPanel,
                            UI.Panel {
                                width = "100%",
                                height = 4,
                                backgroundColor = STYLE.GRASS_TOP,
                                borderRadius = 2,
                            },
                            deployPanel,
                            storagePanel,
                        },
                    },
                    self.itemInfoPanel,
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

function UIController:CreateDeployPanel()
    local panel, slots = Views.CreateDeployPanel(self.dragContext)
    self.deploySlots = slots
    for i, slot in ipairs(slots) do
        slot.props.onSlotClick = function()
            if self.currentState_ then
                self:ShowItemInfo(self.currentState_.slots[i])
            end
        end
    end
    return panel
end

function UIController:CreateStoragePanel()
    local panel, slots = Views.CreateStoragePanel(self.dragContext)
    self.storageSlots = slots
    if slots[1] then
        slots[1].props.onSlotClick = function()
            if self.currentState_ then
                self:ShowItemInfo(self.currentState_.dropQueue[1])
            end
        end
    end
    return panel
end

function UIController:CreateItemInfoPanel()
    self.itemInfoIcon = UI.Panel {
        width = 42,
        height = 42,
        backgroundSize = "contain",
        pointerEvents = "none",
    }
    self.itemInfoTitle = UI.Label {
        text = "",
        fontSize = 14,
        fontColor = STYLE.TEXT_WHITE,
        fontWeight = "bold",
        pointerEvents = "none",
    }
    self.itemInfoDesc = UI.Label {
        text = "",
        fontSize = 11,
        lineHeight = 11,
        fontColor = {210, 225, 240, 255},
        pointerEvents = "none",
    }

    return UI.Panel {
        visible = false,
        position = "absolute",
        bottom = "38%",
        left = "9%",
        width = "82%",
        zIndex = 999,
        paddingHorizontal = 12,
        paddingVertical = 2,
        flexDirection = "row",
        gap = 6,
        alignItems = "center",
        backgroundColor = {20, 35, 55, 235},
        borderRadius = 8,
        borderWidth = 2,
        borderColor = {60, 130, 220, 220},
        onClick = function()
            self:HideItemInfo()
        end,
        children = {
            self.itemInfoIcon,
            UI.Panel {
                flex = 1,
                flexShrink = 1,
                gap = 0,
                pointerEvents = "none",
                children = {
                    self.itemInfoTitle,
                    self.itemInfoDesc,
                },
            },
        },
    }
end

function UIController:ShowItemInfo(item)
    if not item then return end

    local qName = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].name or "凡器"
    local title = string.format("%s [%s]", item.name, qName)
    local desc = ""
    if item.itemType == Config.ITEM_TYPE.ATTACK then
        local defIgnoreStr = (item.defIgnore or 0) > 0 and string.format("\n无视%d%%防御", math.floor(item.defIgnore * 100)) or ""
        desc = string.format("ATK: %d  攻速: %.1fs%s\n攻击同列最前排敌人", item.atk, item.atkSpeed or 1.0, defIgnoreStr)
    elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
        local dur = item.durability or 0
        desc = string.format("护盾: %d  减伤: %d%%\n只生效五回合 (剩余%d)", item.shield, math.floor((item.damageReduction or 0) * 100), dur)
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        desc = string.format("回血: %d/秒  持续%d秒\n放置后持续生效", item.healPerSec or item.value or 0, item.duration)
    elseif item.itemType == Config.ITEM_TYPE.TALISMAN then
        desc = string.format("范围伤害: %d\n范围: %d格", item.aoeDmg or 0, item.aoeRange or 3)
    end

    self.itemInfoIcon.props.backgroundImage = Assets.GetItemIcon(item)
    self.itemInfoTitle:SetText(title)
    self.itemInfoDesc:SetText(desc)
    self.itemInfoTimer = 3.0
    self.itemInfoPanel:SetVisible(true)
end

function UIController:ShowChestInfo(quality)
    quality = quality or 1
    local qName = Config.QUALITY[quality] and Config.QUALITY[quality].name or "凡器"
    self.itemInfoIcon.props.backgroundImage = Assets.GetChestIcon(quality)
    self.itemInfoTitle:SetText(string.format("宝箱 [%s品质]", qName))
    self.itemInfoDesc:SetText("击碎后可获得\n对应品质道具\n攻击法宝可打破")
    self.itemInfoTimer = 3.0
    self.itemInfoPanel:SetVisible(true)
end

function UIController:ShowMonsterInfo(monster)
    if not monster then return end
    local typeStr = monster.monsterType == Config.MONSTER_TYPE.MELEE and "近战" or "远程"
    self.itemInfoIcon.props.backgroundImage = Assets.GetMonsterIcon(monster)
    self.itemInfoTitle:SetText(string.format("%s [%s]", monster.name, typeStr))
    self.itemInfoDesc:SetText(string.format("HP: %d/%d\nATK: %d\n击杀获得: %d修为", monster.hp, monster.maxHp, monster.atk, monster.exp or 0))
    self.itemInfoTimer = 3.0
    self.itemInfoPanel:SetVisible(true)
end

function UIController:HideItemInfo()
    self.itemInfoTimer = 0
    if self.itemInfoPanel then
        self.itemInfoPanel:SetVisible(false)
    end
end

function UIController:Update(dt)
    if self.itemInfoTimer > 0 then
        self.itemInfoTimer = self.itemInfoTimer - dt
        if self.itemInfoTimer <= 0 then
            self:HideItemInfo()
        end
    end
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
    -- 丹药消耗提示
    if state.pillConsumeMessages and #state.pillConsumeMessages > 0 then
        for _, info in ipairs(state.pillConsumeMessages) do
            local msg = string.format("您已自动使用了%s，恢复%d血", info.name, info.heal)
            UI.Toast.Show(msg, { duration = 2.5, variant = "info", position = "top" })
        end
        state.pillConsumeMessages = {}
    end

    -- 道具掉落提示
    if not state.dropMessages or #state.dropMessages == 0 then return end
    local msg = "获得: " .. table.concat(state.dropMessages, "、")
    UI.Toast.Show(msg, { duration = 2, variant = "success", position = "top" })
    state.dropMessages = {}
end

function UIController:UpdateHUD(state)
    self.hpLabel:SetText(tostring(state.hp))
    self.hpBar:SetValue(state.hp / state.maxHp)
    local realm = Config.REALMS[state.realmIndex]
    self.realmLabel:SetText(realm.name)
    local nextExp = 9999
    if state.realmIndex < #Config.REALMS then
        nextExp = Config.REALMS[state.realmIndex + 1].expRequired
    end
    local base = realm.expRequired
    local progress = (state.exp - base) / math.max(1, nextExp - base)
    self.expBar:SetValue(math.min(1.0, math.max(0, progress)))
    self.turnLabel:SetText("第" .. state.waveCount .. "波")
end

function UIController:UpdateSlots(state)
    for i = 1, Config.TOTAL_SLOTS do
        local slot = self.deploySlots[i]
        if slot then
            ApplyItemSlotVisual(slot, state.slots[i])
        end
    end

    local bufSlot = self.storageSlots[1]
    if bufSlot then
        ApplyItemSlotVisual(bufSlot, state.dropQueue[1])
    end
end

function UIController:UpdateFieldPanel(state)
    self.fieldPanel:ClearChildren()

    local layout = self.fieldPanel:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    local cellW = layout.w / Config.GRID_COLS
    local cellH = layout.h / Config.FIELD_ROWS

    for row = 0, Config.FIELD_ROWS - 1 do
        for col = 0, Config.GRID_COLS - 1 do
            local isA = (row + col) % 2 == 0
            self.fieldPanel:AddChild(UI.Panel {
                position = "absolute",
                left = col * cellW,
                top = row * cellH,
                width = cellW,
                height = cellH,
                backgroundColor = isA
                    and {230, 240, 250, 200}
                    or  {195, 228, 240, 200},
                borderWidth = 0.5,
                borderColor = {170, 205, 225, 100},
                pointerEvents = "none",
            })
        end
    end

    -- 构建宝箱位置查找表，避免怪物血条被宝箱遮挡时仍然显示
    local chestPositions = {}
    for _, chest in ipairs(state.chests) do
        chestPositions[chest.row .. "_" .. chest.col] = true
    end

    for _, monster in ipairs(state.monsters) do
        if monster.row >= 1 and monster.row <= Config.FIELD_ROWS then
            -- 如果同位置有宝箱，跳过渲染此怪物（宝箱会覆盖在上层）
            local posKey = monster.row .. "_" .. monster.col
            if chestPositions[posKey] then
                goto continue_monster
            end
            local monsterImg = Assets.GetMonsterIcon(monster)
            local x = (monster.col - 1) * cellW + cellW * 0.1
            local y = (monster.row - 1) * cellH + cellH * 0.08
            local monsterRef = monster
            self.fieldPanel:AddChild(UI.Panel {
                position = "absolute",
                left = x, top = y,
                width = cellW * 0.8, height = cellH * 0.84,
                alignItems = "center",
                justifyContent = "flex-end",
                borderRadius = 8,
                pointerEvents = "auto",
                onClick = function()
                    self:ShowMonsterInfo(monsterRef)
                end,
                children = {
                    UI.Panel {
                        width = "90%", height = "72%",
                        backgroundImage = monsterImg,
                        backgroundSize = "contain",
                        pointerEvents = "none",
                    },
                    UI.Panel {
                        width = "85%", height = 6,
                        marginBottom = 2,
                        backgroundColor = {40, 35, 35, 150},
                        borderRadius = 3,
                        pointerEvents = "none",
                        children = {
                            UI.Panel {
                                width = tostring(math.max(5, math.floor(monster.hp / monster.maxHp * 100))) .. "%",
                                height = "100%",
                                backgroundColor = STYLE.HP_RED,
                                borderRadius = 3,
                                pointerEvents = "none",
                            },
                        }
                    },
                    monster.charging and UI.Panel {
                        position = "absolute", top = 1, right = 1,
                        width = 10, height = 10, borderRadius = 5,
                        backgroundColor = {255, 200, 50, 240},
                        borderWidth = 1.5,
                        borderColor = {200, 150, 30, 255},
                        pointerEvents = "none",
                    } or nil,
                }
            })
            ::continue_monster::
        end
    end

    for _, chest in ipairs(state.chests) do
        if chest.row >= 1 and chest.row <= Config.FIELD_ROWS then
            local x = (chest.col - 1) * cellW + cellW * 0.1
            local y = (chest.row - 1) * cellH + cellH * 0.08
            local q = chest.quality or 1
            local imgPath = Assets.GetChestIcon(q)
            local chestQ = q
            self.fieldPanel:AddChild(UI.Panel {
                position = "absolute", left = x, top = y,
                width = cellW * 0.8, height = cellH * 0.84,
                backgroundImage = imgPath,
                backgroundSize = "contain",
                borderRadius = 10,
                pointerEvents = "auto",
                onClick = function()
                    self:ShowChestInfo(chestQ)
                end,
            })
        end
    end
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

function UIController:GetRenderRefs()
    return self.deploySlots, self.storageSlots, self.fieldPanel
end

return UIController
