local Config = require("Config")
local BuffSystem = require("BuffSystem")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local TalentSystem = require("TalentSystem")
local Stats = require("combat.Stats")
local GameEvents = require("GameEvents")

local MonsterSystem = {}

local function TurnsFromSeconds(seconds)
    return math.max(1, math.ceil(seconds or 1))
end

local function ClearPlayerDebuffs(state)
    state.debuffs = {}
    state.playerDebuffs = {}
    state.sealedSlots = {}
    state.poisonStacks = 0
    state.poisonDamageRatio = 0
    state.pendingPlayerDebuffs = nil
    state.pendingSealedSlots = nil
end

local function ClearOnePlayerDebuff(state)
    if state.playerDebuffs then
        for key, _ in pairs(state.playerDebuffs) do
            state.playerDebuffs[key] = nil
            return true
        end
    end
    if state.sealedSlots then
        for slotIdx, _ in pairs(state.sealedSlots) do
            state.sealedSlots[slotIdx] = nil
            return true
        end
    end
    if (state.poisonStacks or 0) > 0 then
        state.poisonStacks = 0
        state.poisonDamageRatio = 0
        if state.debuffs then
            state.debuffs.poisonStacks = nil
        end
        return true
    end
    return false
end

local function AddPlayerPoison(state, monster, stacks)
    if (state.debuffImmunityTurns or 0) > 0 then
        state.debuffImmunityTurns = math.max(0, (state.debuffImmunityTurns or 0) - 1)
        print(string.format("  [Skill] %s 的腐毒被净化免疫抵挡", monster.name))
        return
    end

    local skill = monster.skill or {}
    local addStacks = stacks or 1
    state.poisonStacks = (state.poisonStacks or 0) + addStacks
    state.poisonDamageRatio = math.max(state.poisonDamageRatio or 0, skill.poisonPerStack or 0.04)
    state.debuffs = state.debuffs or {}
    state.debuffs.poisonStacks = state.poisonStacks
    GameEvents.AddPlayerStatus(state, "腐毒", "debuff")
    print(string.format("  [Skill] %s 叠加腐毒%d层，当前%d层", monster.name, addStacks, state.poisonStacks))
end

local function ApplyPoisonDamage(state)
    local stacks = state.poisonStacks or 0
    if stacks <= 0 then return 0 end

    local ratio = state.poisonDamageRatio or 0.04
    local damage = math.max(1, math.floor(state.maxHp * ratio * stacks))
    table.insert(state.lastMonsterAttackEvents, {
        col = 0,
        row = 0,
        monsterType = "poison",
        name = "腐毒侵蚀",
        damage = damage,
    })
    print(string.format("  [Debuff] 腐毒%d层造成%d伤害", stacks, damage))
    return damage
end

local function ApplySurvivalSkill(stateOrMonster, maybeMonster)
    local state = maybeMonster and stateOrMonster or nil
    local monster = maybeMonster or stateOrMonster
    local skill = monster.skill
    if not skill or skill.id ~= "holy_revival" or monster.revivalTriggered then return end

    local threshold = skill.hpThreshold or 0.35
    if monster.hp <= monster.maxHp * threshold then
        local heal = math.floor(monster.maxHp * (skill.healPercent or 0.35))
        monster.hp = math.min(monster.maxHp, math.max(monster.hp, 0) + heal)
        monster.revivalTriggered = true
        if state then
            GameEvents.AddMonsterStatus(state, monster, "复苏", "buff")
        end
        print(string.format("  [Skill] %s 触发圣躯复苏，恢复%d", monster.name, heal))
    end
end

local function ShouldSkipMovement(monster)
    if (monster.rootTurns or 0) > 0 then
        monster.slowed = nil
        monster.plannedSkipMovement = nil
        return true
    end

    if monster.slowed and monster.slowed >= 1.0 then
        monster.slowed = nil
        monster.plannedSkipMovement = nil
        return true
    elseif monster.slowed and monster.slowed > 0 then
        local skipped = monster.plannedSkipMovement
        if skipped == nil then
            skipped = math.random() < monster.slowed
        end
        monster.slowed = nil
        monster.plannedSkipMovement = nil
        return skipped
    end

    monster.plannedSkipMovement = nil
    return false
end

local function ApplyShockField(state, monster)
    local skill = monster.skill or {}
    state.shockedSlots = state.shockedSlots or {}
    state.shockedSlotReduction = state.shockedSlotReduction or {}

    local duration = TurnsFromSeconds(skill.effectDuration or 1.5) + 1
    local reduction = skill.atkSpeedReduction or 0.18
    local affected = 0
    for slotIdx = 1, Config.TOTAL_SLOTS do
        local slotCol = ((slotIdx - 1) % Config.GRID_COLS) + 1
        if math.abs(slotCol - monster.col) <= 1 then
            state.shockedSlots[slotIdx] = math.max(state.shockedSlots[slotIdx] or 0, duration)
            state.shockedSlotReduction[slotIdx] = math.max(state.shockedSlotReduction[slotIdx] or 0, reduction)
            affected = affected + 1
        end
    end

    print(string.format("  [Skill] %s 释放震荡领域，压制%d个法宝位", monster.name, affected))
    if affected > 0 then
        GameEvents.AddPlayerStatus(state, "震荡压制", "debuff")
    end
end

local function ApplyMovementSkill(state, monster, moved)
    local skill = monster.skill
    if not skill then return end

    if moved and skill.id == "heavy_step" then
        local triggerEvery = skill.triggerEveryRows or 2
        if triggerEvery > 0 and (monster.rowsWalked or 0) > 0 and monster.rowsWalked % triggerEvery == 0 then
            local shield = math.floor(monster.maxHp * (skill.shieldPercent or 0.05))
            monster.shieldAmount = (monster.shieldAmount or 0) + shield
            GameEvents.AddMonsterStatus(state, monster, "护盾", "buff")
            print(string.format("  [Skill] %s 重压踏行获得护盾%d", monster.name, shield))
        end
    elseif moved and skill.id == "poison_erode" then
        AddPlayerPoison(state, monster, skill.stackPerRow or 1)
    elseif moved and skill.id == "void_stealth" then
        local triggerEvery = skill.triggerEveryRows or 3
        if triggerEvery > 0 and (monster.rowsWalked or 0) > 0 and monster.rowsWalked % triggerEvery == 0 then
            monster.stealthTurns = math.max(monster.stealthTurns or 0, TurnsFromSeconds(skill.stealthDuration or 1.5) + 1)
            GameEvents.AddMonsterStatus(state, monster, "隐身", "buff")
            print(string.format("  [Skill] %s 进入虚空隐匿", monster.name))
        end
    elseif moved and skill.id == "disaster_pulse" then
        local triggerEvery = skill.triggerEveryRows or 4
        if triggerEvery > 0 and (monster.rowsWalked or 0) > 0 and monster.rowsWalked % triggerEvery == 0 then
            state.itemSilenceTurns = math.max(state.itemSilenceTurns or 0, TurnsFromSeconds(skill.silenceDuration or 1.0))
            GameEvents.AddPlayerStatus(state, "灾厄压制", "debuff")
            print(string.format("  [Skill] %s 释放灾厄脉冲，压制法宝%d回合", monster.name, state.itemSilenceTurns))
        end
    end

    if skill.id == "war_cry" and not monster.skillTriggered and monster.row >= (skill.triggerRow or Config.FIELD_ROWS - 1) then
        monster.skillTriggered = true
        monster.tauntTurns = math.max(monster.tauntTurns or 0, TurnsFromSeconds(skill.tauntDuration or 2.0) + 1)
        monster.tauntRange = skill.tauntRange or 2
        GameEvents.AddMonsterStatus(state, monster, "嘲讽", "buff")
        print(string.format("  [Skill] %s 发动战吼嘲讽", monster.name))
    elseif skill.id == "shock_field" then
        monster.shockCounter = (monster.shockCounter or 0) + 1
        local cooldown = TurnsFromSeconds(skill.cooldown or 3.0)
        if monster.shockCounter >= cooldown then
            monster.shockCounter = 0
            ApplyShockField(state, monster)
        end
    end

    ApplySurvivalSkill(state, monster)
end

local function CellKey(col, row)
    return tostring(col) .. "_" .. tostring(row)
end

local function AddMonsterOccupancy(occupied, col, row, delta)
    if not col or not row or row < 1 or row > Config.FIELD_ROWS then return end
    local key = CellKey(col, row)
    occupied[key] = (occupied[key] or 0) + delta
    if occupied[key] <= 0 then
        occupied[key] = nil
    end
end

local function BuildMonsterOccupancy(state)
    local occupied = {}
    for _, monster in ipairs(state.monsters) do
        if monster.hp > 0 then
            AddMonsterOccupancy(occupied, monster.col, monster.row, 1)
        end
    end
    for _, fieldReward in ipairs(state.fieldRewards or {}) do
        if fieldReward.hp > 0 then
            AddMonsterOccupancy(occupied, fieldReward.col, fieldReward.row, 1)
        end
    end
    return occupied
end

local function EnsureMeleeBottomCharge(monster, delay)
    if monster.monsterType ~= Config.MONSTER_TYPE.MELEE then return end
    if monster.row < Config.FIELD_ROWS then return end

    monster.row = Config.FIELD_ROWS
    if not monster.charging then
        monster.charging = true
        monster.chargeTimer = delay or 1
        print(string.format("  [Charge] %s 抵达底线，开始压制！", monster.name))
    end
end

function MonsterSystem.MoveMonsters(state)
    local toRemove = {}
    local occupied = BuildMonsterOccupancy(state)
    local order = {}

    for i, _ in ipairs(state.monsters) do
        table.insert(order, i)
    end

    table.sort(order, function(a, b)
        local ma = state.monsters[a]
        local mb = state.monsters[b]
        local rowA = ma and ma.row or 0
        local rowB = mb and mb.row or 0
        if rowA == rowB then return a < b end
        return rowA > rowB
    end)

    for _, i in ipairs(order) do
        local monster = state.monsters[i]
        if monster and monster.hp > 0 then
            local moved = false
            local removed = false
            local oldCol = monster.col
            local oldRow = monster.row

            if monster.monsterType == Config.MONSTER_TYPE.MELEE and monster.row >= Config.FIELD_ROWS then
                EnsureMeleeBottomCharge(monster, 0)
            elseif ShouldSkipMovement(monster) then
                print(string.format("  [Control] %s 被控制，跳过移动", monster.name))
            else
                local targetRow = monster.row + 1
                if targetRow > Config.FIELD_ROWS then
                    AddMonsterOccupancy(occupied, oldCol, oldRow, -1)
                    table.insert(toRemove, i)
                    removed = true
                    print(string.format("  [Monster] %s 离场消失，不再攻击", monster.name))
                else
                    local targetKey = CellKey(monster.col, targetRow)
                    if occupied[targetKey] then
                        print(string.format("  [Block] %s 前方被阻挡，停留在第%d行", monster.name, monster.row))
                    else
                        AddMonsterOccupancy(occupied, oldCol, oldRow, -1)
                        monster.row = targetRow
                        AddMonsterOccupancy(occupied, monster.col, monster.row, 1)
                        moved = true
                    end
                end
            end

            if moved then
                monster.rowsWalked = (monster.rowsWalked or 0) + 1
            end

            if not removed then
                EnsureMeleeBottomCharge(monster, moved and 1 or 0)

                if monster.hp > 0 and monster.row <= Config.FIELD_ROWS then
                    ApplyMovementSkill(state, monster, moved)
                end
            end
        end
    end

    for i = #toRemove, 1, -1 do
        table.remove(state.monsters, toRemove[i])
    end
end

local function ApplyPlayerDebuff(state, debuff, monster)
    if not debuff then return end
    if (state.debuffImmunityTurns or 0) > 0 then
        state.debuffImmunityTurns = math.max(0, (state.debuffImmunityTurns or 0) - 1)
        print(string.format("  [Debuff] %s 的负面状态被免疫", monster.name))
        return
    end

    local pending = state.pendingPlayerDebuffs or {}
    local pendingSeals = state.pendingSealedSlots or {}
    if debuff.type == Config.PLAYER_DEBUFFS.ATTACK_DOWN then
        pending.attackDown = {
            value = math.min(0.20, debuff.value or 0),
            turns = debuff.duration or 1,
        }
        GameEvents.AddPlayerStatus(state, "法宝虚弱", "debuff")
        print(string.format("  [Debuff] %s 施加减攻%d%%（下次伤害起生效）", monster.name, math.floor((debuff.value or 0) * 100)))
    elseif debuff.type == Config.PLAYER_DEBUFFS.VULNERABLE then
        pending.vulnerable = {
            value = debuff.value or 0,
            turns = debuff.duration or 1,
        }
        GameEvents.AddPlayerStatus(state, "易伤", "debuff")
        print(string.format("  [Debuff] %s 施加易伤%d%%（下次伤害起生效）", monster.name, math.floor((debuff.value or 0) * 100)))
    elseif debuff.type == Config.PLAYER_DEBUFFS.SEAL then
        local weaponSlots = {}
        for slotIdx = 1, Config.TOTAL_SLOTS do
            local item = state.slots[slotIdx]
            if item and item.itemType == Config.ITEM_TYPE.ATTACK then
                table.insert(weaponSlots, slotIdx)
            end
        end
        if #weaponSlots > 0 then
            local slotIdx = weaponSlots[math.random(#weaponSlots)]
            pendingSeals[slotIdx] = math.max(pendingSeals[slotIdx] or 0, debuff.duration or 1)
            GameEvents.AddPlayerStatus(state, "法宝封印", "debuff")
            print(string.format("  [Debuff] %s 封印第%d格法宝%d回合（下回合起生效）", monster.name, slotIdx, debuff.duration or 1))
        end
    end
    state.pendingPlayerDebuffs = pending
    state.pendingSealedSlots = pendingSeals
end

local function ApplyPlayerDebuffs(state, monster)
    if monster.playerDebuffs then
        for _, debuff in ipairs(monster.playerDebuffs) do
            ApplyPlayerDebuff(state, debuff, monster)
        end
    end
end

local function CalculateMonsterAttackDamage(monster)
    local damage = monster.atk or 0
    local attackDown = monster.attackDown or 0
    if attackDown > 0 then
        damage = math.floor(damage * math.max(0, 1 - attackDown))
    end
    local critChance = math.max(0, (monster.critChance or 0) - (monster.critChanceDown or 0))
    local didCrit = false
    if math.random() < critChance then
        didCrit = true
        damage = math.floor(damage * (monster.critMultiplier or 1.5))
    end
    return math.max(0, damage), didCrit
end

local function AddMonsterAttackEvent(state, monster, damage, nameSuffix, didCrit)
    if damage <= 0 then return 0 end

    local skill = monster.skill or {}
    local eventName = monster.name
    if didCrit then
        eventName = eventName .. "·暴击"
    end
    if nameSuffix then
        eventName = eventName .. nameSuffix
    end

    table.insert(state.lastMonsterAttackEvents, {
        col = monster.col,
        row = monster.row,
        monsterType = monster.monsterType,
        name = eventName,
        damage = damage,
        crit = didCrit == true,
        attacker = monster,
        defenseIgnore = skill.id == "armor_pierce" and (skill.defenseIgnore or 0) or 0,
    })
    return damage
end

local function ApplyAttackSkill(state, monster, baseDamage)
    local skill = monster.skill
    if not skill then return 0 end

    local extraDamage = 0
    if skill.id == "arrow_split" then
        local splitDamage = math.floor(baseDamage * (skill.splashDamagePercent or 0.5))
        local range = skill.splashRange or 1
        for offset = -range, range do
            if offset ~= 0 then
                local col = monster.col + offset
                if col >= 1 and col <= Config.GRID_COLS then
                    extraDamage = extraDamage + AddMonsterAttackEvent(state, monster, splitDamage, "·分裂")
                end
            end
        end
        if extraDamage > 0 then
            print(string.format("  [Skill] %s 箭矢分裂追加%d伤害", monster.name, extraDamage))
        end
    elseif skill.id == "poison_erode" then
        AddPlayerPoison(state, monster, 1)
    end

    return extraDamage
end

local function AttackWithMonster(state, monster, label)
    local damage, didCrit = CalculateMonsterAttackDamage(monster)
    AddMonsterAttackEvent(state, monster, damage, nil, didCrit)
    local extraDamage = ApplyAttackSkill(state, monster, damage)
    ApplyPlayerDebuffs(state, monster)
    print(string.format("  [%s] %s 攻击! -%d%s", label, monster.name, damage + extraDamage, didCrit and " 暴击" or ""))
    return damage + extraDamage
end

function MonsterSystem.RangedAttack(state)
    local totalDmg = ApplyPoisonDamage(state)

    for _, monster in ipairs(state.monsters) do
        if monster.hp > 0
            and monster.row >= 1
            and monster.row <= Config.FIELD_ROWS
            and monster.monsterType == Config.MONSTER_TYPE.RANGED
            and monster.row >= (Config.FIELD_ROWS - (monster.attackRange or 3)) then
            totalDmg = totalDmg + AttackWithMonster(state, monster, "Ranged")
        end
    end

    state.lastPlayerDamage = (state.lastPlayerDamage or 0) + totalDmg
    return totalDmg
end

function MonsterSystem.MeleeAttack(state)
    local totalDmg = 0

    for _, monster in ipairs(state.monsters) do
        if monster.hp > 0
            and monster.row >= 1
            and monster.row <= Config.FIELD_ROWS
            and monster.monsterType == Config.MONSTER_TYPE.MELEE
            and monster.charging then
            if monster.chargeTimer <= 0 then
                totalDmg = totalDmg + AttackWithMonster(state, monster, "Melee")
            else
                monster.chargeTimer = monster.chargeTimer - 1
            end
        end
    end

    state.lastPlayerDamage = (state.lastPlayerDamage or 0) + totalDmg
    return totalDmg
end

function MonsterSystem.MonsterAttack(state)
    state.lastPlayerDamage = 0
    state.lastPlayerDamageCrit = false
    MonsterSystem.RangedAttack(state)
    MonsterSystem.MeleeAttack(state)
end

function MonsterSystem.GetDefenseStats(state)
    local realm = Config.GetRealm(state.realmIndex)
    local totalDefense = 0
    local defenses = {}

    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots[slotIdx]
        if item and item.itemType == Config.ITEM_TYPE.DEFENSE then
            local itemDefense = math.max(0, item.defense or item.power or 0)
            local rogueDefenseBuff = RogueRewardSystem.GetModifierValue(state, "armorDefensePct")
            local talentDefenseBuff = TalentSystem.GetModifierValue(state, "armorDefensePct")
            local scaledDefense = itemDefense * realm.defMul * (1 + rogueDefenseBuff + talentDefenseBuff)
            totalDefense = totalDefense + scaledDefense
            table.insert(defenses, {
                slotIdx = slotIdx,
                item = item,
                defense = scaledDefense,
            })
        end
    end

    return totalDefense, defenses
end

local function FindLiveMonster(state, monster)
    if not monster then return nil end
    for _, current in ipairs(state.monsters) do
        if current == monster and current.hp > 0 then
            return current
        end
    end
    return nil
end

local function ReflectDamage(state, attack, amount, sourceName)
    local attacker = FindLiveMonster(state, attack and attack.attacker)
    amount = math.floor(amount or 0)
    if not attacker or amount <= 0 then return 0 end

    attacker.hp = attacker.hp - amount
    ApplySurvivalSkill(state, attacker)
    table.insert(state.lastDamageDealt, {
        col = attacker.col,
        row = attacker.row,
        dmg = amount,
        target = attacker,
    })
    print(string.format("  [Armor] %s 反伤 %s %d", sourceName, attacker.name, amount))
    return amount
end

local function ApplyArmorHitEffect(state, item, attack, rawDmg, absorbed, blocked)
    local effect = item.armorEffect
    if not effect then return end

    if effect.type == "block" then
        if blocked and (effect.reflectRatio or 0) > 0 then
            ReflectDamage(state, attack, rawDmg * effect.reflectRatio, item.name)
        end
    elseif effect.type == "thorns" then
        local reflectMul = 1 + RogueRewardSystem.GetModifierValue(state, "thornsReflectPct")
        local reflect = rawDmg * (effect.reflectRatio or 0) * reflectMul
        if (effect.bleedRatio or 0) > 0 then
            reflect = reflect + absorbed * effect.bleedRatio * reflectMul
        end
        ReflectDamage(state, attack, reflect, item.name)
    elseif effect.type == "regen" then
        local heal = effect.onHit or 0
        if heal > 0 then
            local actualHeal = Stats.Heal(state, heal)
            print(string.format("  [Armor] %s 受击恢复%d气血", item.name, actualHeal))
        end
    end
end

local function ApplyArmorHitEffects(state, defenses, attack, rawDmg, mitigationScale)
    local blocked = false
    local usedNames = {}
    local defenseIgnore = math.min(1.0, attack and attack.defenseIgnore or 0)

    for _, defense in ipairs(defenses) do
        local item = defense.item
        local effect = item and item.armorEffect
        local blockedByItem = false
        local itemMitigated = (defense.defense or 0) * (1 - defenseIgnore) * mitigationScale

        if item then
            local defenseValue = math.floor(itemMitigated + 0.5)
            if defenseValue > 0 then
                table.insert(usedNames, string.format("%s防御%d", item.name, defenseValue))
            end
        end

        if effect and effect.type == "block" and math.random() < (effect.blockChance or 0) then
            blockedByItem = true
            blocked = true
            table.insert(usedNames, item.name .. "(格挡)")
        end

        if item then
            ApplyArmorHitEffect(state, item, attack, rawDmg, itemMitigated, blockedByItem)
        end
    end

    return blocked, table.concat(usedNames, "、")
end

local function ConsumeArmorShieldPool(state, damage)
    local shield = state.armorShield or 0
    if shield <= 0 or damage <= 0 then return damage, 0 end

    local absorbed = math.min(damage, shield)
    state.armorShield = shield - absorbed
    return damage - absorbed, absorbed
end

local function ConsumeBuffShields(state, damage)
    local remainingDamage = damage
    local absorbed = 0
    local remainingBuffs = {}

    for _, buff in ipairs(state.buffs) do
        if remainingDamage > 0 and buff.type == "shield" and (buff.value or 0) > 0 then
            local absorb = math.min(remainingDamage, buff.value)
            buff.value = buff.value - absorb
            remainingDamage = remainingDamage - absorb
            absorbed = absorbed + absorb
        end

        if buff.type ~= "shield" or (buff.value or 0) > 0 then
            table.insert(remainingBuffs, buff)
        end
    end

    state.buffs = remainingBuffs
    return remainingDamage, absorbed
end

local function ActivatePendingPlayerDebuffs(state)
    local pending = state.pendingPlayerDebuffs
    local pendingSeals = state.pendingSealedSlots

    if pending then
        state.playerDebuffs = state.playerDebuffs or {}
        for key, debuff in pairs(pending) do
            local current = state.playerDebuffs[key]
            state.playerDebuffs[key] = {
                value = math.max(current and current.value or 0, debuff.value or 0),
                turns = math.max(current and current.turns or 0, (debuff.turns or 0) + 1),
            }
        end
        state.pendingPlayerDebuffs = nil
    end

    if pendingSeals then
        state.sealedSlots = state.sealedSlots or {}
        for slotIdx, turns in pairs(pendingSeals) do
            state.sealedSlots[slotIdx] = math.max(state.sealedSlots[slotIdx] or 0, (turns or 0) + 1)
        end
        state.pendingSealedSlots = nil
    end
end

function MonsterSystem.ApplyDamage(state)
    state.lastPlayerDamageCrit = false
    if state.lastPlayerDamage <= 0 then
        ActivatePendingPlayerDebuffs(state)
        return
    end

    local totalFinalDmg = 0
    local totalMitigated = 0
    local totalShieldAbsorbed = 0

    for _, attack in ipairs(state.lastMonsterAttackEvents or {}) do
        local rawDmg = attack.damage or 0
        if rawDmg > 0 then
            local totalDefense, defenses = MonsterSystem.GetDefenseStats(state)
            local defenseIgnore = math.min(1.0, attack.defenseIgnore or 0)
            local effectiveDefense = totalDefense * (1 - defenseIgnore)
            local allBuff = BuffSystem.GetBuffValue(state, "allUp")
            local damageReduction = TalentSystem.GetModifierValue(state, "damageTakenReduction") + RogueRewardSystem.GetModifierValue(state, "damageTakenReduction")
            local vulnerable = state.playerDebuffs and state.playerDebuffs.vulnerable
            local vulnerableMul = (vulnerable and (vulnerable.turns or 0) > 0) and (1 + (vulnerable.value or 0)) or 1
            local reducedRawDmg = math.floor(rawDmg * vulnerableMul * math.max(0, 1 - math.min(0.95, allBuff + damageReduction)))
            local afterArmorShield, armorShieldAbsorbed = ConsumeArmorShieldPool(state, reducedRawDmg)
            local afterBuffShield, buffShieldAbsorbed = ConsumeBuffShields(state, afterArmorShield)
            local defenseCap = rawDmg * 0.60
            local maxUsefulDefense = math.max(0, afterBuffShield - 1)
            local defenseMitigated = math.min(effectiveDefense, defenseCap, maxUsefulDefense)
            local mitigationScale = effectiveDefense > 0 and defenseMitigated / effectiveDefense or 0
            local blocked, usedNames = ApplyArmorHitEffects(state, defenses, attack, rawDmg, mitigationScale)
            local finalDmg = 0
            if afterBuffShield > 0 then
                finalDmg = blocked and 0 or math.max(1, math.floor(afterBuffShield - defenseMitigated))
            end
            local shieldAbsorbed = armorShieldAbsorbed + buffShieldAbsorbed

            totalFinalDmg = totalFinalDmg + finalDmg
            totalMitigated = totalMitigated + defenseMitigated
            totalShieldAbsorbed = totalShieldAbsorbed + shieldAbsorbed
            if finalDmg > 0 and attack.crit then
                state.lastPlayerDamageCrit = true
            end

            print(string.format(
                "  [Damage] %s 原始%d 忽防%.0f%% 丹减%.0f%% 临盾%d 丹盾%d 护甲%.0f/上限%.0f 最终%d 来源:%s",
                attack.name or "怪物",
                rawDmg,
                defenseIgnore * 100,
                math.min(0.95, allBuff) * 100,
                armorShieldAbsorbed,
                buffShieldAbsorbed,
                defenseMitigated,
                defenseCap,
                finalDmg,
                usedNames ~= "" and usedNames or "无"
            ))
        end
    end

    state.hp = state.hp - totalFinalDmg
    state.lastPlayerDamage = totalFinalDmg

    if totalFinalDmg > 0 or totalMitigated > 0 or totalShieldAbsorbed > 0 then
        print(string.format("  [Damage Total] 最终扣血%d 护甲减算%.0f 护盾吸收%d", totalFinalDmg, totalMitigated, totalShieldAbsorbed))
    end

    ActivatePendingPlayerDebuffs(state)
end

local function TickStatus(monster, turnsField, valueField)
    local turns = monster[turnsField]
    if not turns or turns <= 0 then return end

    turns = turns - 1
    if turns > 0 then
        monster[turnsField] = turns
    else
        monster[turnsField] = nil
        if valueField then
            monster[valueField] = nil
        end
    end
end

local function TickSlotEffects(state)
    if state.shockedSlots then
        for slotIdx, turns in pairs(state.shockedSlots) do
            turns = turns - 1
            if turns > 0 then
                state.shockedSlots[slotIdx] = turns
            else
                state.shockedSlots[slotIdx] = nil
                if state.shockedSlotReduction then
                    state.shockedSlotReduction[slotIdx] = nil
                end
            end
        end
    end
end

local function TickPlayerDebuffs(state)
    if state.playerDebuffs then
        for key, debuff in pairs(state.playerDebuffs) do
            debuff.turns = (debuff.turns or 0) - 1
            if debuff.turns <= 0 then
                state.playerDebuffs[key] = nil
            end
        end
    end

    if state.sealedSlots then
        for slotIdx, turns in pairs(state.sealedSlots) do
            turns = turns - 1
            if turns > 0 then
                state.sealedSlots[slotIdx] = turns
            else
                state.sealedSlots[slotIdx] = nil
            end
        end
    end
end

local function TickRootShock(monster)
    local turns = monster.rootShockTurns
    if not turns or turns <= 0 then return end

    turns = turns - 1
    if turns > 0 then
        monster.rootShockTurns = turns
    else
        monster.rootShockTurns = nil
        monster.rootShockDamage = nil
        monster.rootShockLabel = nil
        monster.rootShockTriggeredTurn = nil
    end
end

local function TickPoisonExplosionMark(monster)
    local turns = monster.poisonExplosionTurns
    if not turns or turns <= 0 or monster.hp <= 0 then return end

    turns = turns - 1
    if turns > 0 then
        monster.poisonExplosionTurns = turns
    else
        monster.poisonExplosionTurns = nil
        monster.poisonExplosionDamage = nil
        monster.poisonExplosionPattern = nil
        monster.poisonExplosionLabel = nil
    end
end

local function TickMonsterDot(state, monster)
    local turns = monster.dotTurns or 0
    local damage = monster.dotDamage or 0
    if turns <= 0 or damage <= 0 or monster.hp <= 0 then return end

    monster.hp = monster.hp - damage
    table.insert(state.lastDamageDealt, {
        col = monster.col,
        row = monster.row,
        dmg = damage,
        target = monster,
    })
    print(string.format("  [DoT] %s 持续伤害%d", monster.name, damage))

    turns = turns - 1
    if turns > 0 then
        monster.dotTurns = turns
    else
        monster.dotTurns = nil
        monster.dotDamage = nil
    end
end

function MonsterSystem.TickStatuses(state)
    for _, monster in ipairs(state.monsters) do
        TickMonsterDot(state, monster)
        TickRootShock(monster)
        TickPoisonExplosionMark(monster)
        TickStatus(monster, "rootTurns", nil)
        TickStatus(monster, "defenseDownTurns", "defenseDown")
        TickStatus(monster, "attackDownTurns", "attackDown")
        TickStatus(monster, "critChanceDownTurns", "critChanceDown")
        TickStatus(monster, "vulnerableTurns", "vulnerable")
        TickStatus(monster, "stealthTurns", nil)
        TickStatus(monster, "tauntTurns", nil)
        ApplySurvivalSkill(state, monster)
    end
    TickPlayerDebuffs(state)
    TickSlotEffects(state)
end

function MonsterSystem.ApplyArmorTurnEffects(state)
    local shieldGain = 0
    local shieldCap = 0
    local totalRegen = 0
    local immunityTurns = 0
    local cleanseAll = false
    local cleanseCount = 0

    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots[slotIdx]
        if item and item.itemType == Config.ITEM_TYPE.DEFENSE and item.armorEffect then
            local effect = item.armorEffect
            if effect.type == "turnShield" then
                local shieldMul = 1 + RogueRewardSystem.GetModifierValue(state, "armorShieldPct")
                shieldGain = shieldGain + (effect.shield or 0) * shieldMul
                shieldCap = shieldCap + ((effect.shield or 0) + (effect.carryBonus or 0)) * shieldMul
            elseif effect.type == "regen" then
                totalRegen = totalRegen + (effect.perTurn or 0)
            elseif effect.type == "cleanse" then
                cleanseAll = cleanseAll or effect.cleanseAll == true
                cleanseCount = math.max(cleanseCount, effect.cleanseCount or 0)
                immunityTurns = math.max(immunityTurns, effect.immunityTurns or 0)
            end
        end
    end

    if shieldCap > 0 then
        state.armorShield = math.min((state.armorShield or 0) + shieldGain, shieldCap)
        if shieldGain > 0 then
            GameEvents.AddPlayerStatus(state, "护盾", "buff")
            print(string.format("  [Armor] 获得临时护盾%d 当前%d/%d", shieldGain, state.armorShield, shieldCap))
        end
    else
        state.armorShield = 0
    end

    if totalRegen > 0 then
        local actualHeal = Stats.Heal(state, totalRegen)
        if actualHeal > 0 then
            GameEvents.AddPlayerStatus(state, "回春", "buff")
        end
        print(string.format("  [Armor] 回合恢复%d气血", actualHeal))
    end

    if cleanseAll then
        ClearPlayerDebuffs(state)
        GameEvents.AddPlayerStatus(state, "净化", "buff")
    elseif cleanseCount > 0 then
        local cleared = 0
        for _ = 1, cleanseCount do
            if ClearOnePlayerDebuff(state) then
                cleared = cleared + 1
            else
                break
            end
        end
        if cleared > 0 then
            GameEvents.AddPlayerStatus(state, "净化", "buff")
            print(string.format("  [Armor] 净化%d个负面状态", cleared))
        end
    end
    if immunityTurns > 0 then
        state.debuffImmunityTurns = math.max(state.debuffImmunityTurns or 0, immunityTurns)
        GameEvents.AddPlayerStatus(state, "负面免疫", "buff")
    elseif (state.debuffImmunityTurns or 0) > 0 then
        state.debuffImmunityTurns = state.debuffImmunityTurns - 1
    end
end

return MonsterSystem
