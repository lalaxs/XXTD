local Config = require("Config")
local BuffSystem = require("BuffSystem")

local MonsterSystem = {}

function MonsterSystem.MoveMonsters(state)
    for _, monster in ipairs(state.monsters) do
        local moved = false

        -- 检查减速/禁锢
        if monster.slowed and monster.slowed >= 1.0 then
            monster.slowed = nil
        elseif monster.slowed and monster.slowed > 0 then
            if math.random() < monster.slowed then
                monster.slowed = nil
            else
                monster.slowed = nil
                monster.row = monster.row + 1
                moved = true
            end
        else
            monster.row = monster.row + 1
            moved = true
        end

        -- 追踪行走格数（技能触发用）
        if moved then
            monster.rowsWalked = (monster.rowsWalked or 0) + 1
        end

        -- 近战怪物触达布政区前一格：进入蓄力
        if monster.monsterType == Config.MONSTER_TYPE.MELEE then
            if monster.row >= Config.FIELD_ROWS then
                monster.row = Config.FIELD_ROWS
                if not monster.charging then
                    monster.charging = true
                    monster.chargeTimer = 1
                    print(string.format("  [Charge] %s 开始蓄力！", monster.name))
                end
            end
        end
    end
end

function MonsterSystem.MonsterAttack(state)
    local totalDmg = 0
    local toRemoveAfterAttack = {}

    for i, monster in ipairs(state.monsters) do
        if monster.monsterType == Config.MONSTER_TYPE.RANGED then
            -- 远程怪：进入攻击范围后每回合攻击
            if monster.row >= (Config.FIELD_ROWS - (monster.attackRange or 3)) then
                totalDmg = totalDmg + monster.atk
                table.insert(state.lastMonsterAttackEvents, {
                    col = monster.col,
                    row = monster.row,
                    monsterType = monster.monsterType,
                    name = monster.name,
                })
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

function MonsterSystem.ApplyDamage(state)
    -- 应用防御buff
    local defBuff = BuffSystem.GetBuffValue(state, "defUp")
    local allBuff = BuffSystem.GetBuffValue(state, "allUp")
    local reduction = defBuff + allBuff
    local finalDmg = math.floor(state.lastPlayerDamage * math.max(0, 1 - reduction))

    state.hp = state.hp - finalDmg
    if finalDmg > 0 then
        print(string.format("  [Damage] 玩家受到 %d 伤害 (减免%.0f%%)", finalDmg, reduction * 100))
    end
end

return MonsterSystem
