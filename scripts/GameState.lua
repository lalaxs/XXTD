-- GameState.lua
-- 仙侠合成塔防 - 游戏状态管理 + 回合系统

local Config = require("Config")

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
        
        -- 回合计数
        turn = 0,
        waveCount = 0,
        
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
    state.lastPlayerDamage = 0
    
    print(string.format("[Turn %d] === 回合开始 ===", state.turn))
    
    -- Step 1: 布政区道具生效
    GameState.ExecuteItems(state)
    
    -- Step 2: 处理击杀和掉落
    GameState.ProcessKillsAndDrops(state)
    
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
                -- 攻击法宝：对同列怪物造成伤害
                local baseDmg = item.atk
                local critChance = item.crit
                -- 应用境界加成
                local finalDmg = math.floor(baseDmg * realm.atkMul)
                -- 暴击判定
                if math.random() < critChance then
                    finalDmg = finalDmg * 2
                end
                -- 应用buff加成
                local atkBuff = GameState.GetBuffValue(state, "atkUp")
                local allBuff = GameState.GetBuffValue(state, "allUp")
                finalDmg = math.floor(finalDmg * (1 + atkBuff + allBuff))
                
                -- 对同列所有怪物造成伤害
                for _, monster in ipairs(state.monsters) do
                    if monster.col == col and monster.hp > 0 then
                        monster.hp = monster.hp - finalDmg
                        table.insert(state.lastDamageDealt, {col = col, row = monster.row, dmg = finalDmg})
                    end
                end
                -- 对同列宝箱造成伤害
                for _, chest in ipairs(state.chests) do
                    if chest.col == col and chest.hp > 0 then
                        chest.hp = chest.hp - 1
                    end
                end
                
            elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
                -- 防御法宝：给同列怪物施加减速
                local slowRate = item.slow * realm.defMul
                for _, monster in ipairs(state.monsters) do
                    if monster.col == col and monster.hp > 0 then
                        monster.slowed = math.min(1.0, slowRate)
                    end
                end
                -- 给玩家增加护盾
                local shieldVal = math.floor(item.shield * realm.defMul)
                state.hp = math.min(state.maxHp, state.hp + shieldVal)
                
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
    
    -- 处理被击杀的怪物
    for i, monster in ipairs(state.monsters) do
        if monster.hp <= 0 then
            table.insert(toRemove, i)
            -- 获得修为
            GameState.AddExp(state, monster.exp)
            state.score = state.score + monster.exp
            -- 掉落判定（进入队列）
            local dropChance = monster.dropChance + realm.dropBonus
            if math.random() < dropChance then
                if #state.dropQueue < Config.BUFFER_MAX then
                    local item = GameState.GenerateRandomItem(state)
                    table.insert(state.dropQueue, item)
                    table.insert(state.dropMessages, item.name)
                end
            end
            print(string.format("  [Kill] %s 被击杀! +%d修为", monster.name, monster.exp))
        end
    end
    -- 从后往前移除
    for i = #toRemove, 1, -1 do
        table.remove(state.monsters, toRemove[i])
    end
    
    -- 处理被击碎的宝箱（掉落多个道具进队列）
    local chestRemove = {}
    for i, chest in ipairs(state.chests) do
        if chest.hp <= 0 then
            table.insert(chestRemove, i)
            local dropCount = math.random(Config.CHEST.DROP_MIN, Config.CHEST.DROP_MAX)
            for _ = 1, dropCount do
                if #state.dropQueue < Config.BUFFER_MAX then
                    local item = GameState.GenerateRandomItem(state)
                    table.insert(state.dropQueue, item)
                    table.insert(state.dropMessages, item.name)
                end
            end
            GameState.AddExp(state, 3)
            print(string.format("  [Chest] 宝箱碎裂! 掉落 %d 个道具", dropCount))
        end
    end
    for i = #chestRemove, 1, -1 do
        table.remove(state.chests, chestRemove[i])
    end
end

-- ============================================================================
-- Step 3: 怪物移动
-- ============================================================================
function GameState.MoveMonsters(state)
    for _, monster in ipairs(state.monsters) do
        -- 检查减速/禁锢
        if monster.slowed and monster.slowed >= 1.0 then
            -- 禁锢：不移动
            monster.slowed = nil
        elseif monster.slowed and monster.slowed > 0 then
            -- 减速：概率跳过移动
            if math.random() < monster.slowed then
                monster.slowed = nil
                -- 本回合不移动
            else
                monster.slowed = nil
                monster.row = monster.row + 1
            end
        else
            -- 正常移动：下移1格
            monster.row = monster.row + 1
        end
        
        -- 近战怪物触达布政区前一格：进入蓄力
        if monster.monsterType == Config.MONSTER_TYPE.MELEE then
            if monster.row >= Config.FIELD_ROWS then
                monster.row = Config.FIELD_ROWS  -- 停在边界
                if not monster.charging then
                    monster.charging = true
                    monster.chargeTimer = 1  -- 蓄力1回合
                    print(string.format("  [Charge] %s 开始蓄力！", monster.name))
                end
            end
        end
    end
end

-- ============================================================================
-- Step 4: 怪物攻击
-- ============================================================================
function GameState.MonsterAttack(state)
    local totalDmg = 0
    local toRemoveAfterAttack = {}
    
    for i, monster in ipairs(state.monsters) do
        if monster.monsterType == Config.MONSTER_TYPE.RANGED then
            -- 远程怪：进入攻击范围后每回合攻击
            if monster.row >= (Config.FIELD_ROWS - (monster.attackRange or 3)) then
                totalDmg = totalDmg + monster.atk
                print(string.format("  [Ranged] %s 施法攻击! -%d", monster.name, monster.atk))
            end
        elseif monster.monsterType == Config.MONSTER_TYPE.MELEE then
            -- 近战怪：蓄力完成后爆发
            if monster.charging then
                if monster.chargeTimer <= 0 then
                    totalDmg = totalDmg + monster.atk
                    print(string.format("  [Melee] %s 蓄力爆发! -%d", monster.name, monster.atk))
                    -- 攻击后移除（冲入阵亡）
                    table.insert(toRemoveAfterAttack, i)
                else
                    monster.chargeTimer = monster.chargeTimer - 1
                end
            end
        end
    end
    
    state.lastPlayerDamage = totalDmg
    
    -- 移除已攻击的近战怪
    for i = #toRemoveAfterAttack, 1, -1 do
        table.remove(state.monsters, toRemoveAfterAttack[i])
    end
end

-- ============================================================================
-- Step 5: 伤害结算
-- ============================================================================
function GameState.ApplyDamage(state)
    -- 应用防御buff
    local defBuff = GameState.GetBuffValue(state, "defUp")
    local allBuff = GameState.GetBuffValue(state, "allUp")
    local reduction = defBuff + allBuff
    local finalDmg = math.floor(state.lastPlayerDamage * math.max(0, 1 - reduction))
    
    state.hp = state.hp - finalDmg
    if finalDmg > 0 then
        print(string.format("  [Damage] 玩家受到 %d 伤害 (减免%.0f%%)", finalDmg, reduction * 100))
    end
end

-- ============================================================================
-- Step 7: 刷新资源和怪物
-- ============================================================================
function GameState.SpawnChests(state)
    if #state.chests >= Config.CHEST.MAX_CHESTS then return end
    if math.random() > Config.CHEST.SPAWN_CHANCE then return end
    
    -- 收集已占用的位置（怪物 + 已有宝箱）
    local occupied = {}
    for _, m in ipairs(state.monsters) do
        occupied[m.row .. "_" .. m.col] = true
    end
    for _, c in ipairs(state.chests) do
        occupied[c.row .. "_" .. c.col] = true
    end
    
    -- 找一个空位
    local attempts = 20
    for _ = 1, attempts do
        local col = math.random(1, Config.GRID_COLS)
        local row = math.random(2, Config.FIELD_ROWS - 1)
        local key = row .. "_" .. col
        if not occupied[key] then
            table.insert(state.chests, {
                col = col,
                row = row,
                hp = Config.CHEST.HP,
            })
            print("  [Spawn] 宝箱出现!")
            return
        end
    end
end

function GameState.SpawnWave(state)
    if state.turn % Config.WAVE_INTERVAL == 0 then
        state.waveCount = state.waveCount + 1
        
        -- 难度随波次递增
        local difficulty = math.min(#Config.MELEE_TEMPLATES, math.ceil(state.waveCount / 3))
        
        -- 每波生成 2-4 个怪物
        local count = math.min(Config.GRID_COLS, math.random(2, math.min(4, 1 + state.waveCount)))
        local usedCols = {}
        
        for _ = 1, count do
            local col
            repeat
                col = math.random(1, Config.GRID_COLS)
            until not usedCols[col]
            usedCols[col] = true
            
            local isMelee = math.random() < 0.6
            local template
            if isMelee then
                local idx = math.random(1, difficulty)
                template = Config.MELEE_TEMPLATES[idx]
                local monster = {
                    monsterType = Config.MONSTER_TYPE.MELEE,
                    name = template.name,
                    hp = template.hp,
                    maxHp = template.hp,
                    atk = template.atk,
                    exp = template.exp,
                    dropChance = template.dropChance,
                    col = col,
                    row = 1,
                    charging = false,
                    chargeTimer = 0,
                    slowed = nil,
                }
                table.insert(state.monsters, monster)
            else
                local idx = math.random(1, difficulty)
                template = Config.RANGED_TEMPLATES[idx]
                local monster = {
                    monsterType = Config.MONSTER_TYPE.RANGED,
                    name = template.name,
                    hp = template.hp,
                    maxHp = template.hp,
                    atk = template.atk,
                    exp = template.exp,
                    dropChance = template.dropChance,
                    col = col,
                    row = 1,
                    charging = false,
                    chargeTimer = 0,
                    slowed = nil,
                    attackRange = template.attackRange or 3,
                }
                table.insert(state.monsters, monster)
            end
        end
        
        print(string.format("  [Wave %d] 刷新 %d 个怪物 (难度 %d)", state.waveCount, count, difficulty))
    end
end

-- ============================================================================
-- Buff 系统
-- ============================================================================
function GameState.TickBuffs(state)
    local remaining = {}
    for _, buff in ipairs(state.buffs) do
        buff.remainTurns = buff.remainTurns - 1
        if buff.remainTurns > 0 then
            table.insert(remaining, buff)
        else
            print(string.format("  [Buff] %s 效果消失", buff.type))
        end
    end
    state.buffs = remaining
end

function GameState.GetBuffValue(state, buffType)
    local total = 0
    for _, buff in ipairs(state.buffs) do
        if buff.type == buffType then
            total = total + buff.value
        end
    end
    return total
end

function GameState.AddBuff(state, buffType, value, duration)
    local realm = Config.REALMS[state.realmIndex]
    local finalValue = value * realm.pillMul
    table.insert(state.buffs, {
        type = buffType,
        value = finalValue,
        remainTurns = duration,
    })
    print(string.format("  [Buff] 获得 %s (%.0f%%, %d回合)", buffType, finalValue * 100, duration))
end

-- ============================================================================
-- 修为和境界
-- ============================================================================
function GameState.AddExp(state, amount)
    state.exp = state.exp + amount
    -- 检查境界突破
    GameState.CheckRealmUp(state)
end

function GameState.CheckRealmUp(state)
    while state.realmIndex < #Config.REALMS do
        local nextRealm = Config.REALMS[state.realmIndex + 1]
        if state.exp >= nextRealm.expRequired then
            state.realmIndex = state.realmIndex + 1
            local realm = Config.REALMS[state.realmIndex]
            state.maxHp = Config.PLAYER.BASE_HP + realm.hpBonus
            state.hp = math.min(state.hp + realm.hpBonus, state.maxHp)
            print(string.format("[Realm Up] 境界突破: %s! 气血上限+%d", realm.name, realm.hpBonus))
        else
            break
        end
    end
end

-- ============================================================================
-- 道具生成
-- ============================================================================
function GameState.SpawnRandomItem(state)
    -- 通过回调让 main.lua 控制掉落位置（储藏区）
    if state.onItemDrop then
        state.onItemDrop(state)
        return true
    end
    -- 兜底：直接进布阵区空位
    local emptySlot = GameState.FindEmptySlot(state)
    if not emptySlot then
        print("  [Full] 已满，道具作废!")
        return false
    end
    local item = GameState.GenerateRandomItem(state)
    state.slots[emptySlot] = item
    print(string.format("  [Item] 获得 %s (%s)", item.name, Config.QUALITY[item.quality].name))
    return true
end

-- 生成随机道具（不放置）
function GameState.GenerateRandomItem(state)
    local roll = math.random()
    local itemType
    if roll < 0.60 then
        itemType = Config.ITEM_TYPE.ATTACK
    elseif roll < 0.85 then
        itemType = Config.ITEM_TYPE.DEFENSE
    else
        itemType = Config.ITEM_TYPE.PILL
    end
    local realm = Config.REALMS[state.realmIndex]
    local qualityRoll = math.random()
    local quality = 1
    if qualityRoll > 0.95 - realm.dropBonus then quality = 3
    elseif qualityRoll > 0.80 - realm.dropBonus then quality = 2
    end
    quality = math.min(quality, Config.MAX_QUALITY)
    return GameState.CreateItem(itemType, quality)
end

function GameState.CreateItem(itemType, quality)
    local item = {
        itemType = itemType,
        quality = quality,
    }
    
    if itemType == Config.ITEM_TYPE.ATTACK then
        local data = Config.ATTACK_ITEMS[quality]
        item.name = data.name
        item.atk = data.atk
        item.crit = data.crit
    elseif itemType == Config.ITEM_TYPE.DEFENSE then
        local data = Config.DEFENSE_ITEMS[quality]
        item.name = data.name
        item.shield = data.shield
        item.slow = data.slow
    elseif itemType == Config.ITEM_TYPE.PILL then
        local data = Config.PILL_ITEMS[quality]
        item.name = data.name
        item.buff = data.buff
        item.value = data.value
        item.duration = data.duration
        item.buffActive = true
    end
    
    return item
end

-- ============================================================================
-- 格子操作
-- ============================================================================
function GameState.FindEmptySlot(state)
    for i = 1, Config.TOTAL_SLOTS do
        if state.slots[i] == nil then
            return i
        end
    end
    return nil
end

-- 交换两个格子
function GameState.SwapSlots(state, from, to)
    if from < 1 or from > Config.TOTAL_SLOTS then return false end
    if to < 1 or to > Config.TOTAL_SLOTS then return false end
    if from == to then return false end
    
    state.slots[from], state.slots[to] = state.slots[to], state.slots[from]
    return true
end

-- 合成：同品类同品质 → 高一阶
function GameState.TryMerge(state, fromSlot, toSlot)
    local itemA = state.slots[fromSlot]
    local itemB = state.slots[toSlot]
    
    if not itemA or not itemB then return false end
    if itemA.itemType ~= itemB.itemType then return false end
    if itemA.quality ~= itemB.quality then return false end
    if itemA.quality >= Config.MAX_QUALITY then return false end
    
    -- 合成成功
    local newQuality = itemA.quality + 1
    local newItem = GameState.CreateItem(itemA.itemType, newQuality)
    
    state.slots[toSlot] = newItem
    state.slots[fromSlot] = nil
    
    -- 丹药合成时激活Buff
    if newItem.itemType == Config.ITEM_TYPE.PILL then
        GameState.AddBuff(state, newItem.buff, newItem.value, newItem.duration)
    end
    
    print(string.format("[Merge] %s + %s → %s (%s)", 
        itemA.name, itemB.name, newItem.name, Config.QUALITY[newQuality].name))
    return true
end

-- 分解道具（不消耗回合）
function GameState.DecomposeItem(state, slotIdx)
    local item = state.slots[slotIdx]
    if not item then return false end
    
    local expGain = Config.DECOMPOSE_EXP[item.quality] or 2
    GameState.AddExp(state, expGain)
    state.slots[slotIdx] = nil
    
    print(string.format("[Decompose] 分解 %s → +%d修为", item.name, expGain))
    return true
end

return GameState
