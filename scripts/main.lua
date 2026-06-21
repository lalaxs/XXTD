-- main.lua
-- 仙侠合成塔防 - 手机竖屏版
-- 使用 UI.DragDropContext + UI.ItemSlot 实现拖拽

local UI = require("urhox-libs/UI")
local Config = require("Config")
local GameState = require("GameState")

-- ============================================================================
-- 全局状态
-- ============================================================================
local state_ = nil
local uiRoot_ = nil

-- UI 引用
local hpBar_ = nil
local hpLabel_ = nil
local expBar_ = nil
local realmLabel_ = nil
local turnLabel_ = nil
local fieldPanel_ = nil
local deploySlots_ = {}       -- [1..TOTAL_SLOTS] = ItemSlot widget
local storageSlots_ = {}      -- [1..STORAGE_SIZE] = ItemSlot widget
local gameOverPanel_ = nil
local decomposeBtn_ = nil
local dragContext_ = nil
local inventoryMgr_ = nil

-- 道具缓冲区大小（只有1格）
local STORAGE_SIZE = 1

-- ============================================================================
-- 生命周期
-- ============================================================================
function Start()
    graphics.windowTitle = "仙侠合成塔防"

    UI.Init({
        theme = "default-dark",
        scale = UI.Scale.DEFAULT,
    })

    StartNewGame()
    CreateUI()
    SubscribeToEvent("Update", "HandleUpdate")

    print("=== 仙侠合成塔防 启动 ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 游戏初始化
-- ============================================================================
function StartNewGame()
    state_ = GameState.New()

    -- 初始道具
    state_.slots[1] = GameState.CreateItem(Config.ITEM_TYPE.ATTACK, 1)
    state_.slots[3] = GameState.CreateItem(Config.ITEM_TYPE.ATTACK, 1)
    state_.slots[5] = GameState.CreateItem(Config.ITEM_TYPE.DEFENSE, 1)

    -- 初始怪物
    state_.waveCount = 1
    table.insert(state_.monsters, {
        monsterType = Config.MONSTER_TYPE.MELEE, name = "小妖",
        hp = 30, maxHp = 30, atk = 15, exp = 5, dropChance = 0.3,
        col = 2, row = 1, charging = false, chargeTimer = 0,
    })
    table.insert(state_.monsters, {
        monsterType = Config.MONSTER_TYPE.RANGED, name = "邪修",
        hp = 20, maxHp = 20, atk = 5, exp = 5, dropChance = 0.3,
        col = 4, row = 2, charging = false, chargeTimer = 0, attackRange = 3,
    })
end

-- ============================================================================
-- UI 构建
-- ============================================================================
function CreateUI()
    -- 创建 InventoryManager（用于管理格子数据）
    inventoryMgr_ = UI.InventoryManager.new({
        inventorySize = Config.TOTAL_SLOTS + STORAGE_SIZE,
        equipmentSlots = {},
    })

    -- 同步数据到 InventoryManager
    SyncDataToManager()

    -- 创建拖拽上下文
    dragContext_ = UI.DragDropContext {
        onDragStart = OnDragStart,
        onDragEnd = OnDragEnd,
        canDrop = CanDrop,
    }

    local topHUD = CreateTopHUD()
    fieldPanel_ = CreateFieldPanel()
    local deployPanel = CreateDeployPanel()
    local storagePanel = CreateStoragePanel()
    gameOverPanel_ = CreateGameOverPanel()

    uiRoot_ = UI.Panel {
        width = "100%",
        height = "100%",
        backgroundColor = {8, 6, 14, 255},
        children = {
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
                            fieldPanel_,
                            deployPanel,
                            storagePanel,
                        },
                    },
                    gameOverPanel_,
                },
            },
            dragContext_,
        }
    }

    UI.SetRoot(uiRoot_)
    UpdateAllUI()
end

-- ============================================================================
-- 顶部 HUD
-- ============================================================================
function CreateTopHUD()
    realmLabel_ = UI.Label {
        text = "【练气】",
        fontSize = 14,
        fontColor = {255, 240, 200, 255},
        fontWeight = "bold",
    }
    turnLabel_ = UI.Label {
        text = "第0回合",
        fontSize = 10,
        fontColor = {200, 190, 160, 200},
    }
    hpLabel_ = UI.Label {
        text = "100/100",
        fontSize = 10,
        fontColor = {255, 180, 180, 255},
    }
    hpBar_ = UI.ProgressBar {
        value = 1.0,
        width = "100%",
        height = 8,
        backgroundColor = {40, 20, 20, 180},
        fillColor = "#CC3030",
        borderRadius = 4,
        transition = "value 0.3s easeOut",
    }
    expBar_ = UI.ProgressBar {
        value = 0,
        width = "100%",
        height = 5,
        backgroundColor = {20, 20, 40, 180},
        fillGradient = {direction = "to-right", from = "#5580DD", to = "#AA55EE"},
        borderRadius = 3,
        transition = "value 0.3s easeOut",
    }

    return UI.Panel {
        width = "100%",
        paddingHorizontal = 12,
        paddingVertical = 6,
        gap = 3,
        backgroundColor = {0, 0, 0, 120},
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = { realmLabel_, turnLabel_, hpLabel_ },
            },
            hpBar_,
            expBar_,
        }
    }
end

-- ============================================================================
-- 怪物行进区（透明背景）
-- ============================================================================
function CreateFieldPanel()
    return UI.Panel {
        id = "fieldPanel",
        width = "100%",
        flex = 1,
        flexBasis = 0,
        pointerEvents = "none",
    }
end

-- ============================================================================
-- 布阵区（2行×5列 ItemSlot）
-- ============================================================================
function CreateDeployPanel()
    deploySlots_ = {}
    local rows = {}

    for row = 1, Config.DEPLOY_ROWS do
        local rowCells = {}
        for col = 1, Config.GRID_COLS do
            local idx = (row - 1) * Config.GRID_COLS + col
            local slot = UI.ItemSlot {
                slotId = "deploy_" .. idx,
                slotCategory = "deploy",
                flex = 1,
                aspectRatio = 1,
                dragContext = dragContext_,
                showTypeIcon = false,
            }
            deploySlots_[idx] = slot
            table.insert(rowCells, slot)
        end
        table.insert(rows, UI.Panel {
            width = "100%",
            flexDirection = "row",
            gap = 6,
            children = rowCells,
        })
    end

    return UI.Panel {
        id = "deployPanel",
        width = "100%",
        paddingHorizontal = 10,
        paddingVertical = 6,
        gap = 6,
        children = rows,
    }
end

-- ============================================================================
-- 临时储藏区（1行×5列 + 分解按钮）
-- ============================================================================
function CreateStoragePanel()
    storageSlots_ = {}
    local cells = {}

    for i = 1, STORAGE_SIZE do
        local slot = UI.ItemSlot {
            slotId = "storage_" .. i,
            slotCategory = "storage",
            width = "17%",   -- 约等于布阵区 1/5 宽度（扣除 gap 后）
            aspectRatio = 1,
            dragContext = dragContext_,
            showTypeIcon = false,
        }
        storageSlots_[i] = slot
        table.insert(cells, slot)
    end

    decomposeBtn_ = UI.Button {
        text = "分解",
        visible = false,  -- 暂时隐藏
        fontSize = 14,
        height = 44,
        backgroundColor = {60, 30, 20, 230},
        pressedBackgroundColor = {40, 15, 8, 255},
        borderRadius = 8,
        onClick = function()
            -- 分解缓冲区队列头部道具
            if state_.dropQueue and #state_.dropQueue > 0 then
                local item = table.remove(state_.dropQueue, 1)
                local expGain = Config.DECOMPOSE_EXP[item.quality] or 2
                GameState.AddExp(state_, expGain)
                print(string.format("[Decompose] 分解 %s → +%d修为", item.name, expGain))
                UpdateAllUI()
            end
        end,
    }

    return UI.Panel {
        id = "storagePanel",
        width = "100%",
        paddingHorizontal = 10,
        paddingVertical = 8,
        alignItems = "center",  -- 居中对齐（与布阵区第3列对齐）
        children = {
            cells[1],
        },
    }
end

-- ============================================================================
-- Game Over
-- ============================================================================
function CreateGameOverPanel()
    return UI.Panel {
        id = "gameOverPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 180},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = "80%",
                maxWidth = 300,
                padding = 24,
                gap = 12,
                backgroundColor = {30, 25, 15, 245},
                borderRadius = 16,
                borderWidth = 2,
                borderColor = {200, 150, 50, 200},
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "道陨身殒",
                        fontSize = 22,
                        fontColor = {255, 80, 60, 255},
                        fontWeight = "bold",
                    },
                    UI.Label {
                        id = "goScore",
                        text = "积分: 0",
                        fontSize = 15,
                        fontColor = {255, 230, 180, 255},
                    },
                    UI.Label {
                        id = "goRealm",
                        text = "最终境界: 练气",
                        fontSize = 13,
                        fontColor = {200, 180, 140, 220},
                    },
                    UI.Button {
                        text = "再修一世",
                        variant = "primary",
                        width = 140,
                        height = 46,
                        fontSize = 15,
                        marginTop = 8,
                        borderRadius = 10,
                        onClick = function()
                            RestartGame()
                        end,
                    },
                }
            }
        }
    }
end

-- ============================================================================
-- 拖拽回调
-- ============================================================================
function OnDragStart(itemData, sourceSlot)
    print(string.format("[Drag] 开始拖拽: %s", itemData.name or "?"))
end

function CanDrop(itemData, sourceSlot, targetSlot)
    -- 所有格子都可以放
    return true
end

function OnDragEnd(itemData, sourceSlot, targetSlot, success)
    print(string.format("[DragEnd] success=%s, hasTarget=%s", tostring(success), tostring(targetSlot ~= nil)))
    if not targetSlot then return end
    if state_.isGameOver then return end

    local fromCat = sourceSlot:GetSlotCategory()
    local fromId = sourceSlot:GetSlotId()
    local toCat = targetSlot:GetSlotCategory()
    local toId = targetSlot:GetSlotId()

    -- 同一个格子不处理
    if fromCat == toCat and fromId == toId then return end

    -- 解析索引
    local fromIdx = ParseSlotIndex(fromId)
    local toIdx = ParseSlotIndex(toId)
    if not fromIdx or not toIdx then
        print("[DragEnd] 无法解析索引: " .. tostring(fromId) .. " → " .. tostring(toId))
        return
    end

    local srcItem = GetItemFromSlot(fromCat, fromIdx)
    local dstItem = GetItemFromSlot(toCat, toIdx)

    if not srcItem then
        print("[DragEnd] 源格子无道具")
        return
    end

    print(string.format("[DragEnd] %s(%s_%d) → %s(%s_%d)",
        srcItem.name, fromCat, fromIdx,
        dstItem and dstItem.name or "空", toCat, toIdx))

    -- 尝试合成
    if dstItem and srcItem.itemType == dstItem.itemType
       and srcItem.quality == dstItem.quality
       and srcItem.quality < Config.MAX_QUALITY then
        -- 合成升阶
        local newItem = GameState.CreateItem(srcItem.itemType, srcItem.quality + 1)
        SetItemToSlot(toCat, toIdx, newItem)
        SetItemToSlot(fromCat, fromIdx, nil)
        if newItem.itemType == Config.ITEM_TYPE.PILL then
            GameState.AddBuff(state_, newItem.buff, newItem.value, newItem.duration)
        end
        print(string.format("[Merge] %s + %s → %s", srcItem.name, dstItem.name, newItem.name))
        GameState.ExecuteTurn(state_)
    elseif not dstItem then
        -- 移动到空位
        SetItemToSlot(toCat, toIdx, srcItem)
        SetItemToSlot(fromCat, fromIdx, nil)
        -- 部署/换位消耗回合（缓冲区到布阵区消耗）
        if fromCat == "storage" or toCat == "deploy" then
            GameState.ExecuteTurn(state_)
        end
    else
        -- 交换（不能合成的两个道具）
        SetItemToSlot(fromCat, fromIdx, dstItem)
        SetItemToSlot(toCat, toIdx, srcItem)
        GameState.ExecuteTurn(state_)
    end

    UpdateAllUI()
end

-- ============================================================================
-- 数据辅助
-- ============================================================================
function ParseSlotIndex(slotId)
    local num = string.match(tostring(slotId), "%d+")
    return num and tonumber(num) or nil
end

function GetItemFromSlot(category, idx)
    if category == "deploy" then
        return state_.slots[idx]
    elseif category == "storage" then
        -- 缓冲区显示队列头部
        return state_.dropQueue[1]
    end
    return nil
end

function SetItemToSlot(category, idx, item)
    if category == "deploy" then
        state_.slots[idx] = item
    elseif category == "storage" then
        if item == nil then
            -- 从队列头部弹出
            table.remove(state_.dropQueue, 1)
        end
        -- 不支持"设置"缓冲区，只能弹出
    end
end

-- 同步游戏数据到 InventoryManager
function SyncDataToManager()
    for i = 1, Config.TOTAL_SLOTS do
        inventoryMgr_:SetInventoryItem(i, state_.slots[i])
    end
end

-- 将游戏数据转为 ItemSlot 可用的 item 格式
function ItemToSlotData(item)
    if not item then return nil end
    local icon = "⚔"
    if item.itemType == Config.ITEM_TYPE.DEFENSE then icon = "🛡"
    elseif item.itemType == Config.ITEM_TYPE.PILL then icon = "💊"
    end
    return {
        name = item.name,
        icon = icon,
        type = "any",
        rarity = ({"common", "uncommon", "rare", "epic", "legendary", "mythic"})[item.quality] or "common",
        -- 保留原始数据
        _raw = item,
    }
end

-- ============================================================================
-- UI 刷新
-- ============================================================================
function UpdateAllUI()
    UpdateHUD()
    UpdateFieldPanel()
    UpdateSlots()
    ShowDropMessages()
    if state_.isGameOver then
        ShowGameOver()
    end
end

-- 显示掉落飘字提示
function ShowDropMessages()
    if not state_.dropMessages or #state_.dropMessages == 0 then return end
    
    local msg = "获得: " .. table.concat(state_.dropMessages, "、")
    UI.Toast.Show(msg, {
        duration = 2,
        variant = "success",
        position = "top",
    })
    -- 清空消息
    state_.dropMessages = {}
end

function UpdateHUD()
    hpLabel_:SetText(string.format("%d/%d", state_.hp, state_.maxHp))
    hpBar_:SetValue(state_.hp / state_.maxHp)

    local realm = Config.REALMS[state_.realmIndex]
    realmLabel_:SetText("【" .. realm.name .. "】")

    local nextExp = 9999
    if state_.realmIndex < #Config.REALMS then
        nextExp = Config.REALMS[state_.realmIndex + 1].expRequired
    end
    local base = realm.expRequired
    local progress = (state_.exp - base) / math.max(1, nextExp - base)
    expBar_:SetValue(math.min(1.0, math.max(0, progress)))

    turnLabel_:SetText("第" .. state_.turn .. "回合")
end

function UpdateSlots()
    -- 更新布阵区
    for i = 1, Config.TOTAL_SLOTS do
        local slot = deploySlots_[i]
        if slot then
            local item = state_.slots[i]
            slot:SetItem(ItemToSlotData(item))
            -- 设置品质边框色
            if item then
                local qColor = Config.QUALITY[item.quality].color
                slot.props.borderColor = qColor
            else
                slot.props.borderColor = {60, 65, 75, 255}
            end
        end
    end
    -- 更新缓冲区（显示队列头部）
    local bufSlot = storageSlots_[1]
    if bufSlot then
        local item = state_.dropQueue[1]
        bufSlot:SetItem(ItemToSlotData(item))
        if item then
            bufSlot.props.borderColor = Config.QUALITY[item.quality].color
        else
            bufSlot.props.borderColor = {60, 65, 75, 255}
        end
    end
end

function UpdateFieldPanel()
    fieldPanel_:ClearChildren()

    local layout = fieldPanel_:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    local cellW = layout.w / Config.GRID_COLS
    local cellH = layout.h / Config.FIELD_ROWS

    -- 怪物
    for _, monster in ipairs(state_.monsters) do
        if monster.row >= 1 and monster.row <= Config.FIELD_ROWS then
            local isMelee = monster.monsterType == Config.MONSTER_TYPE.MELEE
            local icon = isMelee and "👹" or "🧙"
            local x = (monster.col - 1) * cellW + cellW * 0.1
            local y = (monster.row - 1) * cellH + cellH * 0.1

            fieldPanel_:AddChild(UI.Panel {
                position = "absolute",
                left = x, top = y,
                width = cellW * 0.8, height = cellH * 0.8,
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = icon, fontSize = 24,
                        textAlign = "center", pointerEvents = "none",
                    },
                    UI.Panel {
                        position = "absolute", bottom = 0, left = "10%", right = "10%",
                        height = 14, backgroundColor = {0, 0, 0, 150},
                        borderRadius = 4, justifyContent = "center", alignItems = "center",
                        pointerEvents = "none",
                        children = {
                            UI.Label {
                                text = tostring(monster.hp), fontSize = 10,
                                fontColor = {255, 255, 255, 255}, fontWeight = "bold",
                                textAlign = "center", pointerEvents = "none",
                            },
                        }
                    },
                    monster.charging and UI.Panel {
                        position = "absolute", top = 0, right = 0,
                        width = 14, height = 14, borderRadius = 7,
                        backgroundColor = {255, 200, 0, 240}, pointerEvents = "none",
                    } or nil,
                }
            })
        end
    end

    -- 宝箱
    for _, chest in ipairs(state_.chests) do
        if chest.row >= 1 and chest.row <= Config.FIELD_ROWS then
            local x = (chest.col - 1) * cellW + cellW * 0.15
            local y = (chest.row - 1) * cellH + cellH * 0.15
            fieldPanel_:AddChild(UI.Panel {
                position = "absolute", left = x, top = y,
                width = cellW * 0.7, height = cellH * 0.7,
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = "📦",
                        fontSize = 22,
                        textAlign = "center",
                        pointerEvents = "none",
                    },
                }
            })
        end
    end
end

function ShowGameOver()
    gameOverPanel_:SetVisible(true)
    local s = gameOverPanel_:FindById("goScore")
    local r = gameOverPanel_:FindById("goRealm")
    if s then s:SetText("积分: " .. state_.score) end
    if r then r:SetText("最终境界: " .. Config.REALMS[state_.realmIndex].name) end
end

function RestartGame()
    StartNewGame()
    gameOverPanel_:SetVisible(false)
    UpdateAllUI()
end

-- ============================================================================
-- 帧更新
-- ============================================================================
---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    -- 回合制无帧逻辑
end
