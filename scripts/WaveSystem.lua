local Config = require("Config")

local WaveSystem = {}

function WaveSystem.SpawnWave(state)
    if state.waveTurnProgress > 0 and state.waveTurnProgress % Config.WAVE_INTERVAL == 0 then
        state.waveCount = state.waveCount + 1

        -- 统计row=1已有实体数量（怪物+宝箱，同一行不能3个及以上）
        local row1Count = 0
        for _, m in ipairs(state.monsters) do
            if m.row == 1 then row1Count = row1Count + 1 end
        end
        for _, c in ipairs(state.chests) do
            if c.row == 1 then row1Count = row1Count + 1 end
        end
        local maxSpawn = math.max(0, 2 - row1Count)  -- 最多让row=1总共2个
        if maxSpawn == 0 then
            print("  [Wave] row=1已满，跳过刷新")
            return
        end

        -- 每波生成 1-2 个普通小怪
        local count = math.min(maxSpawn, math.random(1, 2))
        local usedCols = {}
        -- 排除row=1已占用的列（怪物+宝箱）
        for _, m in ipairs(state.monsters) do
            if m.row == 1 then usedCols[m.col] = true end
        end
        for _, c in ipairs(state.chests) do
            if c.row == 1 then usedCols[c.col] = true end
        end

        -- 生成普通小怪（默认小妖或邪修）
        for _ = 1, count do
            local col
            local attempts = 0
            repeat
                col = math.random(1, Config.GRID_COLS)
                attempts = attempts + 1
            until not usedCols[col] or attempts > 10
            if attempts > 10 then break end
            usedCols[col] = true

            local isMelee = math.random() < 0.6
            local template
            if isMelee then
                template = Config.MELEE_TEMPLATES[1]  -- 默认小妖
                table.insert(state.monsters, {
                    monsterType = Config.MONSTER_TYPE.MELEE,
                    name = template.name,
                    hp = template.hp, maxHp = template.hp,
                    atk = template.atk, exp = template.exp,
                    dropChance = template.dropChance,
                    col = col, row = 1,
                    charging = false, chargeTimer = 0, slowed = nil,
                })
            else
                template = Config.RANGED_TEMPLATES[1]  -- 默认邪修
                table.insert(state.monsters, {
                    monsterType = Config.MONSTER_TYPE.RANGED,
                    name = template.name,
                    hp = template.hp, maxHp = template.hp,
                    atk = template.atk, exp = template.exp,
                    dropChance = template.dropChance,
                    col = col, row = 1,
                    charging = false, chargeTimer = 0, slowed = nil,
                    attackRange = template.attackRange or 3,
                })
            end
        end

        -- 精英刷新：妖将（每5±2波）
        if state.waveCount >= state.nextYaojiangWave then
            local col
            local attempts = 0
            repeat
                col = math.random(1, Config.GRID_COLS)
                attempts = attempts + 1
            until not usedCols[col] or attempts > 10
            if attempts <= 10 then
                usedCols[col] = true
                local template = Config.MELEE_TEMPLATES[2]  -- 妖将
                table.insert(state.monsters, {
                    monsterType = Config.MONSTER_TYPE.MELEE,
                    name = template.name,
                    hp = template.hp, maxHp = template.hp,
                    atk = template.atk, exp = template.exp,
                    dropChance = template.dropChance,
                    col = col, row = 1,
                    charging = false, chargeTimer = 0, slowed = nil,
                })
                print(string.format("  [Elite] 妖将出现! (波次 %d)", state.waveCount))
            end
            -- 重置计数：下次在5±2波后
            state.nextYaojiangWave = state.waveCount + math.random(3, 7)
        end

        -- 精英刷新：妖王（每20±2波）
        if state.waveCount >= state.nextYaowangWave then
            local col
            local attempts = 0
            repeat
                col = math.random(1, Config.GRID_COLS)
                attempts = attempts + 1
            until not usedCols[col] or attempts > 10
            if attempts <= 10 then
                local template = Config.MELEE_TEMPLATES[3]  -- 妖王
                table.insert(state.monsters, {
                    monsterType = Config.MONSTER_TYPE.MELEE,
                    name = template.name,
                    hp = template.hp, maxHp = template.hp,
                    atk = template.atk, exp = template.exp,
                    dropChance = template.dropChance,
                    col = col, row = 1,
                    charging = false, chargeTimer = 0, slowed = nil,
                })
                print(string.format("  [BOSS] 妖王出现! (波次 %d)", state.waveCount))
            end
            -- 重置计数：下次在20±2波后
            state.nextYaowangWave = state.waveCount + math.random(18, 22)
        end

        print(string.format("  [Wave %d] 刷新完成", state.waveCount))
    end
end

return WaveSystem
