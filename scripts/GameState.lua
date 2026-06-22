-- GameState.lua
-- 仙侠合成塔防 - 游戏状态管理 + 回合系统

local Config = require("Config")
local BuffSystem = require("BuffSystem")
local RealmSystem = require("RealmSystem")
local BoardSystem = require("BoardSystem")
local ItemSystem = require("ItemSystem")
local MonsterSystem = require("MonsterSystem")
local ChestSystem = require("ChestSystem")
local WaveSystem = require("WaveSystem")

local GameState = {}

-- ============================================================================
-- 初始化
-- ============================================================================
function GameState.New()
    local state = {
        -- 玩家状态
        hp = Config.PLAYER.BASE_HP,
        maxHp = Config.PLAYER.BASE_HP,
        exp = Config.PLAYER.BASE_EXP,
        realmIndex = 1,  -- 当前境界索引
        lastPillHp = Config.PLAYER.BASE_HP,  -- 丹药触发HP基准点
        
        -- 回合计数
        turn = 0,
        waveCount = 0,
        waveTurnProgress = 0,  -- 独立的波次进度（击败宝箱不计入）
        
        -- 布政区格子 (1D数组，大小 = GRID_COLS * GRID_ROWS)
        -- 每个格子: nil（空）或 item 对象
        slots = {},
        
        -- 怪物列表
        -- 每个怪物: {type, name, hp, maxHp, atk, exp, dropChance, col, row, charging, attackRange}
        monsters = {},
        
        -- 宝箱列表
        -- 每个宝箱: {col, row, hp}
        chests = {},
        
        -- 掉落队列（缓冲区，最多存 BUFFER_MAX 个道具）
        dropQueue = {},
        -- 掉落飘字队列（UI读取后清空）
        dropMessages = {},
        
        -- 当前激活的丹药Buff
        -- {type, value, remainTurns}
        buffs = {},
        
        -- 精英刷新计数器
        nextYaojiangWave = math.random(3, 7),   -- 妖将：每5±2波刷新一次
        nextYaowangWave = math.random(18, 22),  -- 妖王：每20±2波刷新一次
        
        -- 游戏状态
        isGameOver = false,
        score = 0,
        
        -- 动画/UI状态
        lastDamageDealt = {},   -- 上回合造成的伤害（用于显示伤害数字）
        lastPlayerDamage = 0,   -- 上回合玩家受到的伤害
        turnLog = {},           -- 回合日志
    }
    
    -- 初始化空格子
    for i = 1, Config.TOTAL_SLOTS do
        state.slots[i] = nil
    end
    
    return state
end

-- ============================================================================
-- 回合执行（核心逻辑）
-- ============================================================================
-- 标准单回合执行流程：
-- 1. 布政区所有道具执行效果
-- 2. 命中灵材光球、击杀怪物，生成道具存入布政区空位
-- 3. 所有存活怪物统一下移1格
-- 4. 远程怪物施法攻击玩家、近战怪物蓄力判定
-- 5. 全额伤害结算，更新玩家气血值
-- 6. 判定玩家是否死亡
-- 7. 刷新场上浮空资源、刷新下一波怪物

function GameState.ExecuteTurn(state)
    if state.isGameOver then return end
    
    state.turn = state.turn + 1
    state.turnLog = {}
    state.lastDamageDealt = {}
    state.lastAttackEvents = {}
    state.lastMonsterAttackEvents = {}
    state.lastPlayerDamage = 0
    
    print(string.format("[Turn %d] === 回合开始 ===", state.turn))
    
    -- Step 1: 布政区道具生效
    GameState.ExecuteItems(state)
    
    -- Step 2: 处理击杀和掉落
    GameState.ProcessKillsAndDrops(state)
    
    -- Step 2.5: 宝箱移动
    GameState.MoveChests(state)
    
    -- Step 3: 怪物移动
    GameState.MoveMonsters(state)
    
    -- Step 4: 怪物攻击
    GameState.MonsterAttack(state)
    
    -- Step 5: 伤害结算
    GameState.ApplyDamage(state)
    
    -- Step 6: 死亡判定
    if state.hp <= 0 then
        state.hp = 0
        state.isGameOver = true
        print("[GameOver] 玩家气血归零，对局结束！")
        return
    end
    
    -- 波次进度：始终推进，除非本回合只击碎了宝箱（无怪物被攻击）
    local monstersHit = #state.lastDamageDealt > 0
    local chestOnly = (not monstersHit) and state._chestKilledThisTurn
    if not chestOnly then
        state.waveTurnProgress = state.waveTurnProgress + 1
    end
    state._chestKilledThisTurn = false
    
    -- Step 7: 刷新资源和怪物
    GameState.SpawnChests(state)
    GameState.SpawnWave(state)
    
    -- Buff 持续回合递减
    GameState.TickBuffs(state)
    
    print(string.format("[Turn %d] === 回合结束 === HP: %d/%d", state.turn, state.hp, state.maxHp))
end

-- ============================================================================
-- Step 1: 道具生效
-- ============================================================================
function GameState.ExecuteItems(state)
    local realm = Config.REALMS[state.realmIndex]
    
    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots[slotIdx]
        if item then
            local col = ((slotIdx - 1) % Config.GRID_COLS) + 1
            
            if item.itemType == Config.ITEM_TYPE.ATTACK then
                -- 攻击法宝：只对同列最前排（row最大）的一个目标造成伤害
                local baseDmg = item.atk
                local critChance = item.crit
                local finalDmg = math.floor(baseDmg * realm.atkMul)
                if math.random() < critChance then
                    finalDmg = finalDmg * 2
                end
                local atkBuff = GameState.GetBuffValue(state, "atkUp")
                local allBuff = GameState.GetBuffValue(state, "allUp")
                finalDmg = math.floor(finalDmg * (1 + atkBuff + allBuff))
                
                -- 找同列最前排目标（row最大，怪物或宝箱）
                local frontMonster = nil
                local frontChest = nil
                local frontRow = -1
                for _, monster in ipairs(state.monsters) do
                    if monster.col == col and monster.hp > 0 and monster.row > frontRow then
                        frontMonster = monster
                        frontChest = nil
                        frontRow = monster.row
                    end
                end
                for _, chest in ipairs(state.chests) do
                    if chest.col == col and chest.hp > 0 and chest.row > frontRow then
                        frontChest = chest
                        frontMonster = nil
                        frontRow = chest.row
                    end
                end
                -- 无穿透：只打最前排一个目标
                if frontMonster then
                    table.insert(state.lastAttackEvents, {
                        slotIdx = slotIdx,
                        col = col,
                        targetType = "monster",
                        targetRow = frontMonster.row,
                    })
                    frontMonster.hp = frontMonster.hp - finalDmg
                    table.insert(state.lastDamageDealt, {col = col, row = frontMonster.row, dmg = finalDmg})
                elseif frontChest then
                    table.insert(state.lastAttackEvents, {
                        slotIdx = slotIdx,
                        col = col,
                        targetType = "chest",
                        targetRow = frontChest.row,
                    })
                    -- 宝箱被击中：掉落1个物品，品质=宝箱品质
                    frontChest.hp = 0
                    state._chestKilledThisTurn = true
                    local chestQ = frontChest.quality or 1
                    -- 丹药在HP每降低15%时有50%概率出现
                    local pillEligible = false
                    local hpDrop = state.lastPillHp - state.hp
                    if hpDrop >= state.maxHp * 0.15 then
                        if math.random() < 0.5 then
                            pillEligible = true
                        end
                        state.lastPillHp = state.hp  -- 重置基准点
                    end
                    -- 随机道具类型
                    local roll = math.random()
                    local itemType
                    if pillEligible and roll < 0.40 then
                        itemType = Config.ITEM_TYPE.PILL
                    elseif roll < 0.55 then
                        itemType = Config.ITEM_TYPE.ATTACK
                    else
                        itemType = Config.ITEM_TYPE.DEFENSE
                    end
                    local newItem = GameState.CreateItem(itemType, math.min(chestQ, Config.MAX_QUALITY))
                    -- 缓冲区只保留1个，保留更高品质
                    local existing = state.dropQueue[1]
                    if not existing then
                        state.dropQueue[1] = newItem
                    elseif newItem.quality > existing.quality then
                        state.dropQueue[1] = newItem  -- 新物品品质更高，替换
                    end
                    table.insert(state.dropMessages, newItem.name)
                    GameState.AddExp(state, 3)
                else
                    table.insert(state.lastAttackEvents, {
                        slotIdx = slotIdx,
                        col = col,
                        targetType = "none",
                        targetRow = 0,
                    })
                end
                
            elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
                -- 防御法宝：给同列怪物施加减速
                local slowRate = item.slow * realm.defMul
                for _, monster in ipairs(state.monsters) do
                    if monster.col == col and monster.hp > 0 then
                        monster.slowed = math.min(1.0, slowRate)
                    end
                end
                -- 给玩家少量回复（shield的20%）
                local healVal = math.ceil(item.shield * realm.defMul * 0.2)
                state.hp = math.min(state.maxHp, state.hp + healVal)
                
            elseif item.itemType == Config.ITEM_TYPE.PILL then
                -- 丹药：应用/刷新Buff（已在放置时触发，这里tick持续效果）
                if item.buffActive then
                    -- 治疗类丹药每回合恢复
                    if item.buff == "heal" then
                        local healVal = math.floor(item.value * realm.pillMul)
                        state.hp = math.min(state.maxHp, state.hp + healVal)
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Step 2: 处理击杀和掉落
-- ============================================================================
function GameState.ProcessKillsAndDrops(state)
    local realm = Config.REALMS[state.realmIndex]
    local toRemove = {}
    
    -- 处理被击杀的怪物（只给修为，不掉落物品）
    for i, monster in ipairs(state.monsters) do
        if monster.hp <= 0 then
            table.insert(toRemove, i)
            GameState.AddExp(state, monster.exp)
            state.score = state.score + monster.exp
            print(string.format("  [Kill] %s 被击杀! +%d修为", monster.name, monster.exp))
        end
    end
    -- 从后往前移除
    for i = #toRemove, 1, -1 do
        table.remove(state.monsters, toRemove[i])
    end
    
    -- 移除已击碎的宝箱（掉落已在ExecuteItems中处理）
    local chestRemove = {}
    for i, chest in ipairs(state.chests) do
        if chest.hp <= 0 then
            table.insert(chestRemove, i)
        end
    end
    for i = #chestRemove, 1, -1 do
        table.remove(state.chests, chestRemove[i])
    end
end

-- ============================================================================
-- Step 2.5: 宝箱移动（每回合下移一格，超出行进区则消失）
-- ============================================================================
function GameState.MoveChests(state)
    return ChestSystem.MoveChests(state)
end

-- ============================================================================
-- Step 3: 怪物移动
-- ============================================================================
function GameState.MoveMonsters(state)
    return MonsterSystem.MoveMonsters(state)
end

-- ============================================================================
-- Step 4: 怪物攻击
-- ============================================================================
function GameState.MonsterAttack(state)
    return MonsterSystem.MonsterAttack(state)
end

-- ============================================================================
-- Step 5: 伤害结算
-- ============================================================================
function GameState.ApplyDamage(state)
    return MonsterSystem.ApplyDamage(state)
end

-- ============================================================================
-- Step 7: 刷新资源和怪物
-- ============================================================================
function GameState.SpawnChests(state)
    return ChestSystem.SpawnChests(state)
end

function GameState.SpawnWave(state)
    return WaveSystem.SpawnWave(state)
end

-- ============================================================================
-- Buff 系统兼容包装
-- ============================================================================
function GameState.TickBuffs(state)
    return BuffSystem.TickBuffs(state)
end

function GameState.GetBuffValue(state, buffType)
    return BuffSystem.GetBuffValue(state, buffType)
end

function GameState.AddBuff(state, buffType, value, duration)
    return BuffSystem.AddBuff(state, buffType, value, duration)
end

-- ============================================================================
-- 修为和境界兼容包装
-- ============================================================================
function GameState.AddExp(state, amount)
    return RealmSystem.AddExp(state, amount)
end

function GameState.CheckRealmUp(state)
    return RealmSystem.CheckRealmUp(state)
end

-- ============================================================================
-- 道具生成兼容包装
-- ============================================================================
function GameState.SpawnRandomItem(state)
    return ItemSystem.SpawnRandomItem(state)
end

function GameState.GenerateRandomItem(state)
    return ItemSystem.GenerateRandomItem(state)
end

function GameState.CreateItem(itemType, quality)
    return ItemSystem.CreateItem(itemType, quality)
end

-- ============================================================================
-- 格子操作兼容包装
-- ============================================================================
function GameState.FindEmptySlot(state)
    return BoardSystem.FindEmptySlot(state)
end

function GameState.SwapSlots(state, from, to)
    return BoardSystem.SwapSlots(state, from, to)
end

function GameState.TryMerge(state, fromSlot, toSlot)
    return ItemSystem.TryMerge(state, fromSlot, toSlot)
end

function GameState.DecomposeItem(state, slotIdx)
    return ItemSystem.DecomposeItem(state, slotIdx)
end

return GameState
