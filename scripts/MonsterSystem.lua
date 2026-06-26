local Config = require("Config")
local BuffSystem = require("BuffSystem")

local MonsterSystem = {}

function MonsterSystem.MoveMonsters(state)
    local toRemove = {}

    for i, monster in ipairs(state.monsters) do
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
        elseif monster.row > Config.FIELD_ROWS then
            table.insert(toRemove, i)
            print(string.format("  [Monster] %s 离场消失，不再攻击", monster.name))
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(state.monsters, toRemove[i])
    end
end

function MonsterSystem.MonsterAttack(state)
    local totalDmg = 0
    local toRemoveAfterAttack = {}

    for i, monster in ipairs(state.monsters) do
        if monster.hp <= 0 or monster.row < 1 or monster.row > Config.FIELD_ROWS then
            -- 已死亡或已离场怪物不能攻击
        elseif monster.monsterType == Config.MONSTER_TYPE.RANGED then
            -- 远程怪：进入攻击范围后每回合攻击
            if monster.row >= (Config.FIELD_ROWS - (monster.attackRange or 3)) then
                local damage = monster.atk
                totalDmg = totalDmg + damage
                table.insert(state.lastMonsterAttackEvents, {
                    col = monster.col,
                    row = monster.row,
                    monsterType = monster.monsterType,
                    name = monster.name,
                    damage = damage,
                })
                print(string.format("  [Ranged] %s 施法攻击! -%d", monster.name, damage))
            end
        elseif monster.monsterType == Config.MONSTER_TYPE.MELEE then
            -- 近战怪：蓄力完成后爆发
            if monster.charging then
                if monster.chargeTimer <= 0 then
                    local damage = monster.atk
                    totalDmg = totalDmg + damage
                    table.insert(state.lastMonsterAttackEvents, {
                        col = monster.col,
                        row = monster.row,
                        monsterType = monster.monsterType,
                        name = monster.name,
                        damage = damage,
                        removedAfterAttack = true,
                    })
                    print(string.format("  [Melee] %s 蓄力爆发! -%d", monster.name, damage))
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

local function GetDefenseStats(state)
    local realm = Config.REALMS[state.realmIndex]
    local reduction = 0
    local defenses = {}

    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots[slotIdx]
        if item and item.itemType == Config.ITEM_TYPE.DEFENSE then
            local itemReduction = math.max(item.damageReduction or 0, item.globalReduction or 0)
            reduction = reduction + itemReduction * realm.defMul
            table.insert(defenses, {
                slotIdx = slotIdx,
                item = item,
                shield = item.shield or 0,
            })
        end
    end

    return math.min(0.95, reduction), defenses
end

local function PickDefenseForDamage(defenses, damage)
    local bestEnoughIndex = nil
    local bestEnoughShield = nil
    local strongestIndex = nil
    local strongestShield = nil

    for i, defense in ipairs(defenses) do
        local shield = defense.shield or 0
        if shield > 0 then
            if shield >= damage and (not bestEnoughShield or shield < bestEnoughShield) then
                bestEnoughIndex = i
                bestEnoughShield = shield
            end
            if not strongestShield or shield > strongestShield then
                strongestIndex = i
                strongestShield = shield
            end
        end
    end

    return bestEnoughIndex or strongestIndex
end

local function ApplyDefenseShields(state, defenses, damage)
    local remaining = damage
    local absorbed = 0
    local usedShield = 0
    local usedNames = {}

    while remaining > 0 and #defenses > 0 do
        local pickedIndex = PickDefenseForDamage(defenses, remaining)
        if not pickedIndex then break end

        local picked = table.remove(defenses, pickedIndex)
        local item = picked.item
        local shield = picked.shield or 0
        local absorb = math.min(remaining, shield)
        remaining = remaining - absorb
        absorbed = absorbed + absorb
        usedShield = usedShield + shield
        table.insert(usedNames, item.name)

        item.durability = (item.durability or item.maxDurability or 5) - 1
        if item.durability <= 0 then
            state.slots[picked.slotIdx] = nil
            print(string.format("  [Defense] %s 生效次数耗尽，消失!", item.name))
        end
    end

    return remaining, absorbed, usedShield, table.concat(usedNames, "、")
end

function MonsterSystem.ApplyDamage(state)
    if state.lastPlayerDamage <= 0 then return end

    local totalFinalDmg = 0
    local totalAbsorbed = 0

    for _, attack in ipairs(state.lastMonsterAttackEvents or {}) do
        local rawDmg = 0
        if attack.monsterType == Config.MONSTER_TYPE.RANGED or attack.monsterType == Config.MONSTER_TYPE.MELEE then
            rawDmg = attack.damage or 0
        end
        if rawDmg > 0 then
            local directReduction, defenses = GetDefenseStats(state)
            local allBuff = BuffSystem.GetBuffValue(state, "allUp")
            local reduction = math.min(0.95, directReduction + allBuff)
            local reducedDmg = math.floor(rawDmg * math.max(0, 1 - reduction))
            local finalDmg, absorbed, usedShield, usedNames = ApplyDefenseShields(state, defenses, reducedDmg)

            totalFinalDmg = totalFinalDmg + finalDmg
            totalAbsorbed = totalAbsorbed + absorbed

            print(string.format(
                "  [Damage] %s 原始%d 减免%.0f%% 护盾%d吸收%d 最终%d 使用:%s",
                attack.name or "怪物",
                rawDmg,
                reduction * 100,
                usedShield,
                absorbed,
                finalDmg,
                usedNames ~= "" and usedNames or "无"
            ))
        end
    end

    state.hp = state.hp - totalFinalDmg
    state.lastPlayerDamage = totalFinalDmg

    if totalFinalDmg > 0 or totalAbsorbed > 0 then
        print(string.format("  [Damage Total] 最终扣血%d 护盾总吸收%d", totalFinalDmg, totalAbsorbed))
    end
end

return MonsterSystem
