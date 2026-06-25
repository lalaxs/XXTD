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
        hp = Config.REALMS[1].maxHp,
        maxHp = Config.REALMS[1].maxHp,
        exp = Config.PLAYER.BASE_EXP,
        realmIndex = 1,  -- 当前境界索引
        lastPillHp = Config.REALMS[1].maxHp,  -- 丹药触发HP基准点
        
        -- 天赋点（永久存档，轮回/重置不清空）
        talentPoints = 0,
        reincarnationCount = 0,
        
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
    
    -- Step 0: 消耗布政区所有丹药（一次性回血后自动消失）
    GameState.ConsumePills(state)
    
    -- Step 1: 布政区道具生效
    GameState.ExecuteItems(state)
    
    -- Step 2: 处理击杀和掉落
    GameState.ProcessKillsAndDrops(state)
    
    -- Step 2.5: 宝箱移动
    ChestSystem.MoveChests(state)
    
    -- Step 3: 怪物移动
    MonsterSystem.MoveMonsters(state)
    
    -- Step 4: 怪物攻击
    MonsterSystem.MonsterAttack(state)
    
    -- Step 5: 伤害结算
    MonsterSystem.ApplyDamage(state)
    
    -- Step 6: 死亡判定（修为倒退机制）
    if state.hp <= 0 then
        state.hp = 0
        local survived = RealmSystem.HandleDeath(state)
        if not survived then
            state.isGameOver = true
            print("[GameOver] 练气期气血归零，对局结束！")
            return
        end
        -- 复活成功，继续本回合
    end
    
    -- 波次进度：始终推进，除非本回合只击碎了宝箱（无怪物被攻击）
    local monstersHit = #state.lastDamageDealt > 0
    local chestOnly = (not monstersHit) and state._chestKilledThisTurn
    if not chestOnly then
        state.waveTurnProgress = state.waveTurnProgress + 1
    end
    state._chestKilledThisTurn = false
    
    -- Step 7: 刷新资源和怪物
    ChestSystem.SpawnChests(state)
    WaveSystem.SpawnWave(state)
    
    -- 防止棋盘空场：如果场上无怪物也无宝箱，立即强制刷新一波
    if #state.monsters == 0 and #state.chests == 0 then
        state.waveTurnProgress = Config.WAVE_INTERVAL  -- 强制触发刷新条件
        WaveSystem.SpawnWave(state)
    end
    
    -- Buff 持续回合递减
    BuffSystem.TickBuffs(state)
    
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
                local atkBuff = BuffSystem.GetBuffValue(state, "atkUp")
                local allBuff = BuffSystem.GetBuffValue(state, "allUp")
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
                        target = frontMonster,
                    })
                    frontMonster.hp = frontMonster.hp - finalDmg
                    table.insert(state.lastDamageDealt, {col = col, row = frontMonster.row, dmg = finalDmg})
                elseif frontChest then
                    table.insert(state.lastAttackEvents, {
                        slotIdx = slotIdx,
                        col = col,
                        targetType = "chest",
                        targetRow = frontChest.row,
                        target = frontChest,
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
                    local newItem = ItemSystem.CreateItem(itemType, math.min(chestQ, Config.MAX_QUALITY))
                    -- 缓冲区只保留1个，保留更高品质
                    local existing = state.dropQueue[1]
                    if not existing then
                        state.dropQueue[1] = newItem
                    elseif newItem.quality > existing.quality then
                        state.dropQueue[1] = newItem  -- 新物品品质更高，替换
                    end
                    table.insert(state.dropMessages, newItem.name)
                    RealmSystem.AddExp(state, 3)
                else
                    table.insert(state.lastAttackEvents, {
                        slotIdx = slotIdx,
                        col = col,
                        targetType = "none",
                        targetRow = 0,
                    })
                end
                
            elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
                -- 防御法宝：提供本回合全局减伤，若配置 slowRate 则额外减速同列怪物
                local globalReduction = item.globalReduction or 0
                if globalReduction <= 0 then
                    globalReduction = item.damageReduction or 0
                end
                globalReduction = globalReduction * realm.defMul
                if globalReduction > 0 then
                    BuffSystem.AddBuff(state, "defUp", globalReduction, 1)
                end
                local slowRate = (item.slowRate or 0) * realm.defMul
                if slowRate > 0 then
                    for _, monster in ipairs(state.monsters) do
                        if monster.col == col and monster.hp > 0 then
                            monster.slowed = math.min(1.0, slowRate)
                        end
                    end
                end
                -- 每回合消耗1次耐久，耗尽后消失
                item.durability = (item.durability or 5) - 1
                if item.durability <= 0 then
                    state.slots[slotIdx] = nil
                    print(string.format("  [Defense] %s 耐久耗尽，消失!", item.name))
                end
                
            -- 丹药不在此处处理（已在 ConsumePills 中一次性消耗）
            end
        end
    end
end

-- ============================================================================
-- Step 2: 处理击杀和掉落
-- ============================================================================
function GameState.ProcessKillsAndDrops(state)
    local toRemove = {}
    
    -- 处理被击杀的怪物（只给修为，不掉落物品）
    for i, monster in ipairs(state.monsters) do
        if monster.hp <= 0 then
            table.insert(toRemove, i)
            RealmSystem.AddExp(state, monster.exp)
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
-- 道具创建对外接口
-- ============================================================================
function GameState.CreateItem(itemType, quality)
    return ItemSystem.CreateItem(itemType, quality)
end

-- ============================================================================
-- Step 0: 消耗丹药（一次性回血，回血可超出上限，消耗后消失）
-- ============================================================================
function GameState.ConsumePills(state)
    -- 前提条件：当前血量低于最大血量40%时才自动使用丹药
    if state.hp >= state.maxHp * 0.4 then
        return
    end

    local realm = Config.REALMS[state.realmIndex]
    
    for i = 1, Config.TOTAL_SLOTS do
        local item = state.slots[i]
        if item and item.itemType == Config.ITEM_TYPE.PILL then
            -- 计算总回血量 = healPerSec × duration（一次性全额）
            local totalHeal = (item.healPerSec or item.value or 0) * (item.duration or 5)
            local finalHeal = math.floor(totalHeal * realm.pillMul)
            
            -- 回血可以超出最大血量上限
            state.hp = state.hp + finalHeal
            
            -- 记录消耗信息（用于 UI 弹 Toast）
            if not state.pillConsumeMessages then
                state.pillConsumeMessages = {}
            end
            table.insert(state.pillConsumeMessages, {
                name = item.name,
                heal = finalHeal,
            })
            
            -- 从布政区移除（自动分解消失）
            state.slots[i] = nil
            
            print(string.format("  [Pill] 使用 %s，恢复 %d 血", item.name, finalHeal))
        end
    end
end

return GameState
