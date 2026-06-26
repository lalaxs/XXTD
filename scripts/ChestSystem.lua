local Config = require("Config")

local ChestSystem = {}

function ChestSystem.MoveChests(state)
    local toRemove = {}
    for i, chest in ipairs(state.chests) do
        if chest.hp > 0 then
            chest.row = chest.row + 1
            if chest.row > Config.FIELD_ROWS then
                table.insert(toRemove, i)
                print("  [Chest] 宝箱离场消失，不造成伤害")
            end
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(state.chests, toRemove[i])
    end
end

function ChestSystem.SpawnChests(state)
    if #state.chests >= Config.CHEST.MAX_CHESTS then return end
    if math.random() > Config.CHEST.SPAWN_CHANCE then return end

    -- 收集row=1已占用的位置（怪物 + 已有宝箱）
    local occupied = {}
    for _, m in ipairs(state.monsters) do
        if m.row == 1 then occupied["1_" .. m.col] = true end
    end
    for _, c in ipairs(state.chests) do
        if c.row == 1 then occupied["1_" .. c.col] = true end
    end

    -- 找一个空位
    local attempts = 20
    for _ = 1, attempts do
        local col = math.random(1, Config.GRID_COLS)
        local key = "1_" .. col
        if not occupied[key] then
            -- 品质随波次递增
            local qRoll = math.random()
            local chestQuality = 1
            if qRoll > 0.95 then chestQuality = math.min(6, 3 + math.floor(state.waveCount / 5))
            elseif qRoll > 0.80 then chestQuality = math.min(4, 2 + math.floor(state.waveCount / 6))
            elseif qRoll > 0.50 then chestQuality = math.min(3, 1 + math.floor(state.waveCount / 8))
            end
            table.insert(state.chests, {
                col = col,
                row = 1,
                hp = 1,
                quality = chestQuality,
            })
            print("  [Spawn] 宝箱出现!")
            return
        end
    end
end

return ChestSystem
