-- combat/PlayerItemResolver.lua
-- 部署区道具生效解析。负责法宝攻击、命中目标与防御道具列效果。

local Config = require("Config")
local BuffSystem = require("BuffSystem")
local FieldRewardService = require("rewards.FieldRewardService")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local TalentSystem = require("TalentSystem")
local GameEvents = require("GameEvents")

local PlayerItemResolver = {}

local function IsMonsterTargetable(monster)
    return monster and monster.hp > 0 and not ((monster.stealthTurns or 0) > 0)
end

local function FindTauntTarget(state, col)
    local picked = nil
    local pickedRow = -1
    for _, monster in ipairs(state.monsters) do
        if IsMonsterTargetable(monster) and (monster.tauntTurns or 0) > 0 then
            local range = monster.tauntRange or 2
            if math.abs(monster.col - col) <= range and monster.row > pickedRow then
                picked = monster
                pickedRow = monster.row
            end
        end
    end
    return picked
end

local function FindFrontTarget(state, col)
    local tauntTarget = FindTauntTarget(state, col)
    if tauntTarget then
        return tauntTarget, nil
    end

    local frontMonster = nil
    local frontFieldReward = nil
    local frontRow = -1

    for _, monster in ipairs(state.monsters) do
        if IsMonsterTargetable(monster) and monster.col == col and monster.row > frontRow then
            frontMonster = monster
            frontFieldReward = nil
            frontRow = monster.row
        end
    end

    for _, fieldReward in ipairs(state.fieldRewards) do
        if fieldReward.col == col and fieldReward.hp > 0 and fieldReward.row > frontRow then
            frontFieldReward = fieldReward
            frontMonster = nil
            frontRow = fieldReward.row
        end
    end

    return frontMonster, frontFieldReward
end

local function AddMonsterTarget(targets, seenMonsters, monster, multiplier)
    if not IsMonsterTargetable(monster) or seenMonsters[monster] then return end
    seenMonsters[monster] = true
    table.insert(targets, {
        targetType = "monster",
        target = monster,
        col = monster.col,
        row = monster.row,
        multiplier = multiplier or 1.0,
    })
end

local function AddFieldRewardTarget(targets, seenFieldRewards, fieldReward, multiplier)
    if not fieldReward or fieldReward.hp <= 0 or seenFieldRewards[fieldReward] then return end
    seenFieldRewards[fieldReward] = true
    table.insert(targets, {
        targetType = "fieldReward",
        target = fieldReward,
        col = fieldReward.col,
        row = fieldReward.row,
        multiplier = multiplier or 1.0,
    })
end

local function CollectSameColumnTargets(state, col, maxCount, decay)
    local tauntTarget = FindTauntTarget(state, col)
    if tauntTarget then
        return {
            {
                targetType = "monster",
                target = tauntTarget,
                row = tauntTarget.row,
                col = tauntTarget.col,
                multiplier = 1.0,
            }
        }
    end

    local entities = {}
    for _, monster in ipairs(state.monsters) do
        if IsMonsterTargetable(monster) and monster.col == col then
            table.insert(entities, { targetType = "monster", target = monster, row = monster.row, col = monster.col })
        end
    end
    for _, fieldReward in ipairs(state.fieldRewards) do
        if fieldReward.col == col and fieldReward.hp > 0 then
            table.insert(entities, { targetType = "fieldReward", target = fieldReward, row = fieldReward.row, col = fieldReward.col })
        end
    end

    table.sort(entities, function(a, b)
        return a.row > b.row
    end)

    local targets = {}
    local limit = maxCount or 1
    for i, entity in ipairs(entities) do
        if limit < 99 and i > limit then break end
        entity.multiplier = decay and (decay ^ (i - 1)) or 1.0
        table.insert(targets, entity)
    end

    return targets
end

local function CollectPatternTargets(state, centerCol, centerRow, pattern, primaryMultiplier, splashMultiplier)
    local targets = {}
    local seenMonsters = {}
    local seenFieldRewards = {}

    local function inPattern(col, row)
        if pattern == "global" then
            return true
        elseif pattern == "square_3x3" then
            return math.abs(col - centerCol) <= 1 and math.abs(row - centerRow) <= 1
        elseif pattern == "adjacent_col_same_row" then
            return math.abs(col - centerCol) <= 1 and row == centerRow
        end
        return col == centerCol and math.abs(row - centerRow) <= 1
    end

    for _, monster in ipairs(state.monsters) do
        if IsMonsterTargetable(monster) and inPattern(monster.col, monster.row) then
            local multiplier = (monster.col == centerCol and monster.row == centerRow) and primaryMultiplier or splashMultiplier
            AddMonsterTarget(targets, seenMonsters, monster, multiplier)
        end
    end
    for _, fieldReward in ipairs(state.fieldRewards) do
        if fieldReward.hp > 0 and inPattern(fieldReward.col, fieldReward.row) then
            local multiplier = (fieldReward.col == centerCol and fieldReward.row == centerRow) and primaryMultiplier or splashMultiplier
            AddFieldRewardTarget(targets, seenFieldRewards, fieldReward, multiplier)
        end
    end

    table.sort(targets, function(a, b)
        if a.row == b.row then return a.col < b.col end
        return a.row > b.row
    end)

    return targets
end

local function UpgradeAreaPattern(pattern)
    if pattern == "global" then return "global" end
    if pattern == "square_3x3" then return "global" end
    if pattern == "adjacent_col_same_row" then return "square_3x3" end
    return "adjacent_col_same_row"
end

local function CollectAttackTargets(state, item, col)
    local mode = item.attackMode or "single"

    if mode == "pierce" then
        local pierceCount = item.pierceCount or 0
        pierceCount = pierceCount + RogueRewardSystem.GetModifierValue(state, "pierceBonus")
        if item.school == "spear" and state.talentVariants and state.talentVariants.spear == "break" and item.baseId == "pozhen_spear" then
            pierceCount = pierceCount + 1
        end
        return CollectSameColumnTargets(state, col, pierceCount >= 99 and 99 or (1 + pierceCount), 0.8)
    end

    local frontMonster, frontFieldReward = FindFrontTarget(state, col)
    local primary = frontMonster or frontFieldReward
    if not primary then return {} end

    local centerRow = primary.row
    if mode == "sweep" then
        local splashRatio = (item.splashRatio or 0.5) + RogueRewardSystem.GetModifierValue(state, "sweepSplashPct")
        if item.school == "chain" and state.talentVariants and state.talentVariants.chain == "chain" and item.baseId == "double_blade_chain" then
            splashRatio = splashRatio + 0.10
        end
        if item.baseId == "qingyu_fan" and (item.quality or 0) >= 7 then
            splashRatio = math.max(splashRatio, 1.0)
        end
        return CollectPatternTargets(state, primary.col or col, centerRow, "adjacent_col_same_row", 1.0, splashRatio)
    elseif mode == "area" or mode == "guardian" then
        local pattern = item.areaPattern or "same_col_adjacent"
        if RogueRewardSystem.GetModifierValue(state, "areaRangeBonus") > 0 then
            pattern = UpgradeAreaPattern(pattern)
        end
        return CollectPatternTargets(state, primary.col or col, centerRow, pattern, 1.0, mode == "guardian" and 0.80 or 0.50)
    end

    local targets = {}
    local seenMonsters = {}
    local seenFieldRewards = {}
    if frontMonster then
        AddMonsterTarget(targets, seenMonsters, frontMonster, 1.0)
    else
        AddFieldRewardTarget(targets, seenFieldRewards, frontFieldReward, 1.0)
    end
    return targets
end

local function GetSchoolDamageBonus(state, item)
    local school = item.school
    if not school then return 0 end
    return RogueRewardSystem.GetModifierValue(state, "schoolDamagePct:" .. school)
end

local function GetTalentAttackBonus(state)
    return TalentSystem.GetModifierValue(state, "talentWeaponDamagePct")
end

local function GetTalentExtraAttackChance(state, item)
    local atkSpeed = item.atkSpeed or 1.0
    local buffBonus = BuffSystem.GetBuffValue(state, "atkSpeedUp")
    local talentBonus = TalentSystem.GetModifierValue(state, "weaponAttackSpeedPct")
    return math.max(0, atkSpeed * (1 + buffBonus + talentBonus) - 1)
end

local function GetPlayerAttackDebuff(state)
    local debuff = state.playerDebuffs and state.playerDebuffs.attackDown
    if not debuff or (debuff.turns or 0) <= 0 then return 0 end
    return math.min(0.20, debuff.value or 0)
end

local function CalculateBaseDamage(state, item, realm, slotIdx)
    local baseDmg = item.atk or item.power or 0
    local finalDmg = math.floor(baseDmg * realm.atkMul)
    local didCrit = false
    local critChance = (item.crit or 0) + TalentSystem.GetModifierValue(state, "weaponCritChance")
    if math.random() < critChance then
        didCrit = true
        local critMultiplier = item.critMultiplier or 2.0
        if item.school == "sword" and state.talentVariants and state.talentVariants.sword == "sharp" and item.baseId == "qingfeng_sword" then
            critMultiplier = math.max(critMultiplier, 2.3)
        end
        critMultiplier = critMultiplier + RogueRewardSystem.GetModifierValue(state, "critDamagePct")
        finalDmg = math.floor(finalDmg * critMultiplier)
    end

    local atkBuff = BuffSystem.GetBuffValue(state, "atkUp")
    local allBuff = BuffSystem.GetBuffValue(state, "allUp")
    local rogueDamageBuff = RogueRewardSystem.GetModifierValue(state, "weaponDamagePct")
    local schoolDamageBuff = GetSchoolDamageBonus(state, item)
    local talentAttackBuff = GetTalentAttackBonus(state)
    local globalDamageMul = 1 + atkBuff + allBuff + rogueDamageBuff + talentAttackBuff
    finalDmg = math.floor(finalDmg * globalDamageMul * (1 + schoolDamageBuff))

    if item.baseId == "zhenyao_tower" and state.talentVariants and state.talentVariants.tower == "suppress" then
        finalDmg = math.floor(finalDmg * 1.20)
    elseif item.baseId == "huxin_pearl" and state.talentVariants and state.talentVariants.guardian == "light" then
        finalDmg = math.floor(finalDmg * 1.20)
    end

    local playerAttackDown = GetPlayerAttackDebuff(state)
    if playerAttackDown > 0 then
        finalDmg = math.floor(finalDmg * (1 - playerAttackDown))
    end

    local shockedTurns = state.shockedSlots and state.shockedSlots[slotIdx]
    if shockedTurns and shockedTurns > 0 then
        local reduction = state.shockedSlotReduction and state.shockedSlotReduction[slotIdx] or 0
        finalDmg = math.floor(finalDmg * math.max(0, 1 - reduction))
    end

    return math.max(1, finalDmg), didCrit
end

local function ApplyMonsterDamageModifiers(state, item, monster, damage)
    local rawDmg = damage
    local monsterDefense = math.max(0, monster.defense or 0)
    local ignoreDefense = item.defIgnore or 0
    if item.baseId == "pozhen_spear" and state.talentVariants and state.talentVariants.spear == "break" then
        ignoreDefense = ignoreDefense + 0.20
    end
    ignoreDefense = math.min(1.0, ignoreDefense)
    local defenseDown = math.min(1.0, monster.defenseDown or 0)
    local effectiveDefense = monsterDefense * (1 - ignoreDefense) * (1 - defenseDown)
    effectiveDefense = math.min(effectiveDefense, rawDmg * 0.5)

    local finalDmg = math.max(1, math.floor(rawDmg - effectiveDefense))

    if monster.skill and monster.skill.damageReduction then
        finalDmg = math.floor(finalDmg * math.max(0, 1 - monster.skill.damageReduction))
    end

    if monster.vulnerable and monster.vulnerable > 0 then
        finalDmg = math.floor(finalDmg * (1 + monster.vulnerable))
    end

    if (monster.rootTurns or 0) > 0 then
        local rootedDamageBuff = RogueRewardSystem.GetModifierValue(state, "rootedDamagePct")
        if rootedDamageBuff > 0 then
            finalDmg = math.floor(finalDmg * (1 + rootedDamageBuff))
        end
    end

    if item.baseId == "bishui_sword" and (monster.attackDown or 0) > 0 and (item.quality or 0) >= 7 then
        local bonus = item.quality >= 9 and 0.30 or (item.quality >= 8 and 0.25 or 0.20)
        finalDmg = math.floor(finalDmg * (1 + bonus))
    end

    if item.baseId == "taiji_sword" and (item.quality or 0) >= 6 then
        local bonus = item.quality >= 9 and 0.25 or (item.quality >= 8 and 0.20 or (item.quality >= 7 and 0.15 or 0.10))
        finalDmg = math.floor(finalDmg * (1 + bonus))
    end

    if monster.tier == Config.MONSTER_TIER.ELITE or monster.tier == Config.MONSTER_TIER.BOSS then
        local eliteDamageBuff = RogueRewardSystem.GetModifierValue(state, "eliteDamagePct")
        finalDmg = math.floor(finalDmg * (1 + eliteDamageBuff))
    end

    return math.max(1, finalDmg)
end

local function ApplyMonsterShield(monster, damage)
    local shield = monster.shieldAmount or 0
    if shield <= 0 then return damage, 0 end

    local absorbed = math.min(damage, shield)
    monster.shieldAmount = shield - absorbed
    return damage - absorbed, absorbed
end

local function ApplySurvivalSkill(monster)
    local skill = monster.skill
    if not skill or skill.id ~= "holy_revival" or monster.revivalTriggered then return end
    local threshold = skill.hpThreshold or 0.35
    if monster.hp > 0 and monster.hp <= monster.maxHp * threshold then
        local heal = math.floor(monster.maxHp * (skill.healPercent or 0.35))
        monster.hp = math.min(monster.maxHp, monster.hp + heal)
        monster.revivalTriggered = true
        print(string.format("  [Skill] %s 触发圣躯复苏，恢复%d", monster.name, heal))
    end
end

local function AddDamageEvent(state, monster, damage)
    if not monster or damage <= 0 then return end
    table.insert(state.lastDamageDealt, {
        col = monster.col,
        row = monster.row,
        dmg = damage,
        target = monster,
    })
end

local function ApplyDirectMonsterDamage(state, monster, amount, label)
    local damage = math.floor(amount or 0)
    if not IsMonsterTargetable(monster) or damage <= 0 then return 0 end
    monster.hp = monster.hp - damage
    AddDamageEvent(state, monster, damage)
    ApplySurvivalSkill(monster)
    if label then
        print(string.format("  [%s] %s 受到%d伤害", label, monster.name, damage))
    end
    return damage
end

local function ApplyPoisonExplosionMark(monster, damage, pattern, label, turns)
    if not monster then return end
    monster.poisonExplosionDamage = math.max(monster.poisonExplosionDamage or 0, math.max(1, math.floor(damage or 0)))
    monster.poisonExplosionPattern = pattern or monster.poisonExplosionPattern or "same_col_adjacent"
    monster.poisonExplosionLabel = label or monster.poisonExplosionLabel or "毒爆"
    monster.poisonExplosionTurns = math.max(monster.poisonExplosionTurns or 0, turns or 1)
end

local function ApplyRootShockMark(monster, damage, turns, label)
    if not monster then return end
    monster.rootShockDamage = math.max(monster.rootShockDamage or 0, math.max(1, math.floor(damage or 0)))
    monster.rootShockTurns = math.max(monster.rootShockTurns or 0, turns or 1)
    monster.rootShockLabel = label or monster.rootShockLabel or "镇魂震荡"
end

local function TriggerRootShockOnce(state, monster)
    if not IsMonsterTargetable(monster) then return 0 end
    if (monster.rootShockTurns or 0) <= 0 or (monster.rootShockDamage or 0) <= 0 then return 0 end
    if monster.rootShockTriggeredTurn == state.turn then return 0 end

    monster.rootShockTriggeredTurn = state.turn
    return ApplyDirectMonsterDamage(state, monster, monster.rootShockDamage, monster.rootShockLabel or "镇魂震荡")
end

local function FindNextSameColumnMonster(state, col, belowRow)
    local picked = nil
    local pickedRow = -1
    for _, monster in ipairs(state.monsters) do
        if IsMonsterTargetable(monster) and monster.col == col and monster.row < belowRow and monster.row > pickedRow then
            picked = monster
            pickedRow = monster.row
        end
    end
    return picked
end

local function FindMonstersInPattern(state, centerCol, centerRow, pattern)
    local monsters = {}
    local function inPattern(col, row)
        if pattern == "global" then
            return true
        elseif pattern == "square_3x3" then
            return math.abs(col - centerCol) <= 1 and math.abs(row - centerRow) <= 1
        elseif pattern == "adjacent_col_same_row" then
            return math.abs(col - centerCol) <= 1 and row == centerRow
        end
        return col == centerCol and math.abs(row - centerRow) <= 1
    end
    for _, monster in ipairs(state.monsters) do
        if IsMonsterTargetable(monster) and inPattern(monster.col, monster.row) then
            table.insert(monsters, monster)
        end
    end
    return monsters
end

local function ApplyAreaExtraDamage(state, centerMonster, pattern, amount, label, exclude)
    local total = 0
    for _, monster in ipairs(FindMonstersInPattern(state, centerMonster.col, centerMonster.row, pattern)) do
        if monster ~= exclude then
            total = total + ApplyDirectMonsterDamage(state, monster, amount, label)
        end
    end
    return total
end

local function ApplySameColumnExtraDamage(state, sourceMonster, amount, maxTargets, label)
    local total = 0
    local currentRow = sourceMonster.row
    local limit = maxTargets or 99
    for _ = 1, limit do
        local nextMonster = FindNextSameColumnMonster(state, sourceMonster.col, currentRow)
        if not nextMonster then break end
        total = total + ApplyDirectMonsterDamage(state, nextMonster, amount, label)
        currentRow = nextMonster.row
    end
    return total
end

local function ApplyWeaponSpecialEffect(state, item, monster, damage)
    local effect = item.specialEffect
    if not effect or damage <= 0 then return 0 end

    local signature = effect.signature or item.signature
    local tier = effect.tier or item.quality or 5
    local specialMul = 1 + RogueRewardSystem.GetModifierValue(state, "specialEffectPct")
    local debuffMul = 1 + RogueRewardSystem.GetModifierValue(state, "debuffPowerPct")
    local durationBonus = RogueRewardSystem.GetModifierValue(state, "debuffDurationBonus")
    local rootBonus = RogueRewardSystem.GetModifierValue(state, "rootTurnsBonus")
    local extraDmg = 0

    local function emitMonsterStatus(target, text, kind)
        GameEvents.AddMonsterStatus(state, target, text, kind or "debuff")
    end

    local function tierValue(q5, q6, q7, q8, q9)
        if tier >= 9 then return q9 end
        if tier >= 8 then return q8 end
        if tier >= 7 then return q7 end
        if tier >= 6 then return q6 end
        return q5
    end

    local function effectDuration()
        return math.max(1, math.floor(tierValue(2, 3, 3, 4, 5) + durationBonus))
    end

    local function applyDot(target, amount, turns)
        if not IsMonsterTargetable(target) then return end
        target.dotDamage = math.max(target.dotDamage or 0, math.max(1, math.floor(amount)))
        target.dotTurns = math.max(target.dotTurns or 0, turns)
        emitMonsterStatus(target, "持续伤害", "debuff")
    end

    local function applyAttackDown(target, value, turns)
        target.attackDown = math.max(target.attackDown or 0, value)
        target.attackDownTurns = math.max(target.attackDownTurns or 0, turns)
        emitMonsterStatus(target, "削攻", "debuff")
    end

    local function applyCritDown(target, value, turns)
        target.critChanceDown = math.max(target.critChanceDown or 0, value)
        target.critChanceDownTurns = math.max(target.critChanceDownTurns or 0, turns)
        emitMonsterStatus(target, "减暴", "debuff")
    end

    if signature == "crit" then
        if item.baseId == "qingfeng_sword" and tier >= 7 and monster.hp <= 0 then
            local overflow = math.max(0, -monster.hp)
            if overflow > 0 then
                local maxTargets = tier >= 9 and 99 or 1
                extraDmg = extraDmg + ApplySameColumnExtraDamage(state, monster, overflow, maxTargets, "剑心通明")
            end
        end
    elseif signature == "root" or signature == "root_lock" then
        local rootTurns = math.min(5, math.floor(tierValue(1, 2, 3, 4, 5) + rootBonus))
        if item.baseId == "qingyin_qin" and state.talentVariants and state.talentVariants.magic == "control" then
            rootTurns = math.min(5, rootTurns + 1)
        elseif item.baseId == "fuyao_chain" and state.talentVariants and state.talentVariants.chain == "lock" then
            rootTurns = math.min(5, rootTurns + 2)
        end
        monster.slowed = 1.0
        monster.rootTurns = math.max(monster.rootTurns or 0, rootTurns)
        emitMonsterStatus(monster, "定身", "control")

        if tier >= 7 then
            local shockRatio = item.baseId == "fuyao_chain" and tierValue(0.30, 0.30, 0.30, 0.40, 0.50) or tierValue(0.20, 0.20, 0.20, 0.30, 0.40)
            local shockDamage = math.floor(damage * shockRatio * specialMul)
            if item.baseId == "qingyin_qin" then
                ApplyRootShockMark(monster, shockDamage, rootTurns, "镇魂震荡")
                emitMonsterStatus(monster, "镇魂震荡", "control")
            else
                applyDot(monster, shockDamage, rootTurns)
            end
        end
    elseif signature == "defense_down" then
        local finalValue = tierValue(0.15, 0.20, 0.25, 0.30, 0.45) * debuffMul * specialMul
        if item.baseId == "baigu_staff" and state.talentVariants and state.talentVariants.magic == "offense" then
            finalValue = finalValue + 0.15
        end
        local turns = effectDuration()
        monster.defenseDown = math.max(monster.defenseDown or 0, finalValue)
        monster.defenseDownTurns = math.max(monster.defenseDownTurns or 0, turns)
        emitMonsterStatus(monster, "破甲", "debuff")
        if item.baseId == "baigu_staff" and tier >= 7 and monster.hp <= monster.maxHp * 0.30 then
            local soulRatio = tierValue(0.05, 0.05, 0.05, 0.07, 0.10)
            applyDot(monster, math.floor(monster.maxHp * soulRatio), turns)
        end
    elseif signature == "armor_break" then
        local finalValue = tier >= 9 and 0.25 or (tier >= 8 and 0.20 or (tier >= 7 and 0.15 or 0))
        if finalValue > 0 then
            monster.vulnerable = math.max(monster.vulnerable or 0, finalValue * debuffMul * specialMul)
            monster.vulnerableTurns = math.max(monster.vulnerableTurns or 0, effectDuration())
            emitMonsterStatus(monster, "易伤", "debuff")
        end
    elseif signature == "attack_down" or signature == "attack_down_aura" or signature == "attack_down_area" or signature == "guardian_attack_down" then
        local finalValue = tierValue(0.15, 0.20, 0.25, 0.30, 0.35) * debuffMul * specialMul
        local turns = effectDuration()
        if item.baseId == "bishui_sword" and state.talentVariants and state.talentVariants.sword == "soft" then
            turns = turns + 1
        elseif item.baseId == "zhenyao_tower" and state.talentVariants and state.talentVariants.tower == "soul" then
            finalValue = finalValue + 0.25
        elseif item.baseId == "huxin_pearl" and state.talentVariants and state.talentVariants.guardian == "protect" then
            finalValue = math.max(finalValue, 0.35)
        elseif (item.baseId == "jinguang_ring" or item.baseId == "zhenyao_tower") and state.talentVariants and state.talentVariants.magic == "control" then
            finalValue = finalValue + 0.15
        end

        local targets = { monster }
        if tier >= 7 and (item.baseId == "jinguang_ring" or item.baseId == "zhenyao_tower" or item.baseId == "huxin_pearl") then
            targets = FindMonstersInPattern(state, monster.col, monster.row, "global")
        end
        for _, target in ipairs(targets) do
            applyAttackDown(target, finalValue, turns)
            if tier >= 7 and (item.baseId == "jinguang_ring" or item.baseId == "huxin_pearl") then
                applyCritDown(target, tierValue(0.15, 0.15, 0.15, 0.20, 0.25), turns)
            end
            if tier >= 7 and (item.baseId == "zhenyao_tower" or item.baseId == "huxin_pearl") then
                local auraRatio = item.baseId == "zhenyao_tower" and tierValue(0.20, 0.20, 0.20, 0.30, 0.40) or tierValue(0.20, 0.20, 0.20, 0.30, 0.40)
                applyDot(target, math.floor(damage * auraRatio * specialMul), turns)
            end
        end
    elseif signature == "vulnerability" or signature == "wind_mark" then
        local finalValue = tierValue(0.10, 0.15, signature == "wind_mark" and 0.15 or 0.20, signature == "wind_mark" and 0.20 or 0.25, signature == "wind_mark" and 0.25 or 0.30)
        finalValue = finalValue + RogueRewardSystem.GetModifierValue(state, "vulnerableBonusPct")
        if item.baseId == "lingmo_brush" and state.talentVariants and state.talentVariants.magic == "control" then
            finalValue = finalValue + 0.10
        end
        local turns = effectDuration()
        local targets = { monster }
        if item.baseId == "lingmo_brush" and tier >= 7 then
            targets = FindMonstersInPattern(state, monster.col, monster.row, "global")
        end
        for _, target in ipairs(targets) do
            target.vulnerable = math.max(target.vulnerable or 0, finalValue * specialMul)
            target.vulnerableTurns = math.max(target.vulnerableTurns or 0, turns)
            emitMonsterStatus(target, signature == "wind_mark" and "风刃易伤" or "易伤", "debuff")
            if item.baseId == "lingmo_brush" and tier >= 7 then
                applyDot(target, math.floor(damage * tierValue(0.15, 0.15, 0.15, 0.20, 0.25) * specialMul), turns)
            end
        end
    elseif signature == "burn" or signature == "poison" then
        local baseDot = signature == "poison" and tierValue(0.15, 0.18, 0.30, 0.40, 0.50) or tierValue(0.15, 0.18, 0.20, 0.25, 0.30)
        local dotValue = (baseDot + RogueRewardSystem.GetModifierValue(state, "dotDamagePct")) * specialMul
        local turns = effectDuration()
        if item.baseId == "chiyan_spear" and state.talentVariants and state.talentVariants.spear == "flame" then
            turns = turns + 2
            dotValue = dotValue + 0.10
        elseif item.baseId == "ziqi_gourd" and state.talentVariants and state.talentVariants.magic == "offense" then
            turns = turns + 1
        elseif item.baseId == "huxin_pearl" and state.talentVariants and state.talentVariants.guardian == "light" then
            dotValue = dotValue + 0.20
        end
        local dotDamage = math.max(1, math.floor(damage * dotValue))
        applyDot(monster, dotDamage, turns)

        if item.baseId == "chiyan_spear" and tier >= 7 then
            local pattern = tier >= 9 and "global" or "adjacent_col_same_row"
            for _, target in ipairs(FindMonstersInPattern(state, monster.col, monster.row, pattern)) do
                if target ~= monster then
                    applyDot(target, dotDamage, turns)
                end
            end
        elseif item.baseId == "ziqi_gourd" and tier >= 7 then
            local explosionRatio = tierValue(0.50, 0.50, 0.50, 0.70, 1.00)
            local pattern = item.areaPattern or "same_col_adjacent"
            ApplyPoisonExplosionMark(monster, damage * explosionRatio, pattern, "万毒归宗", turns)
            emitMonsterStatus(monster, "毒爆标记", "debuff")
            if monster.hp <= 0 then
                extraDmg = extraDmg + ApplyAreaExtraDamage(state, monster, pattern, damage * explosionRatio, "万毒归宗", monster)
                monster.poisonExplosionTriggered = true
            end
        end
    elseif signature == "pull" or signature == "knockback" then
        local distance = 1
        if item.baseId == "double_blade_chain" and state.talentVariants and state.talentVariants.chain == "chain" then
            distance = 2
        elseif item.baseId == "taiji_sword" and state.talentVariants and state.talentVariants.sword == "soft" then
            distance = 2
        elseif (item.quality or 0) >= 7 then
            distance = 2
        end
        if signature == "pull" then
            monster.row = math.min(Config.FIELD_ROWS, monster.row + distance)
            emitMonsterStatus(monster, "拉拽", "control")
            if monster.row >= Config.FIELD_ROWS then
                monster.charging = true
                monster.chargeTimer = math.max(monster.chargeTimer or 0, 1)
            end
        else
            monster.row = math.max(1, monster.row - distance)
            emitMonsterStatus(monster, "击退", "control")
            if monster.row < Config.FIELD_ROWS then
                monster.charging = false
                monster.chargeTimer = 0
            end
        end
        if item.baseId == "taiji_sword" and (item.quality or 0) >= 7 then
            monster.slowed = 1.0
            monster.rootTurns = math.max(monster.rootTurns or 0, item.quality >= 9 and 2 or 1)
        elseif item.baseId == "double_blade_chain" and (item.quality or 0) >= 6 then
            applyDot(monster, math.floor(damage * tierValue(0.15, 0.15, 0.25, 0.35, 0.45) * specialMul), effectDuration())
        end
    end

    return extraDmg
end

local function ResolveMonsterHit(state, item, targetInfo, damage, didCrit)
    local monster = targetInfo.target
    local finalDmg = ApplyMonsterDamageModifiers(state, item, monster, damage)
    local hpDmg, shieldAbsorbed = ApplyMonsterShield(monster, finalDmg)
    monster.hp = monster.hp - hpDmg
    local hadRootShock = (monster.rootShockTurns or 0) > 0 and (monster.rootShockDamage or 0) > 0
    local specialDmg = ApplyWeaponSpecialEffect(state, item, monster, hpDmg)
    if hadRootShock then
        specialDmg = specialDmg + TriggerRootShockOnce(state, monster)
    end
    ApplySurvivalSkill(monster)

    if specialDmg > 0 then
        print(string.format("  [Special] %s 追加造成%d伤害", item.name or "法宝", specialDmg))
    end

    if shieldAbsorbed > 0 then
        print(string.format("  [Skill] %s 护盾吸收%d", monster.name, shieldAbsorbed))
    end

    if hpDmg > 0 then
        table.insert(state.lastDamageDealt, {
            col = targetInfo.col,
            row = targetInfo.row,
            dmg = hpDmg,
            target = monster,
            crit = didCrit == true,
        })
    end
end

local function ResolveFieldRewardHit(state, targetInfo)
    FieldRewardService.ResolveFieldRewardHit(state, targetInfo.target)
end

local function IsSlotSealed(state, slotIdx)
    local sealed = state.sealedSlots and state.sealedSlots[slotIdx]
    return sealed and sealed > 0
end

local function ResolveAttackItemOnce(state, item, slotIdx, col, realm, silenced)
    if silenced or IsSlotSealed(state, slotIdx) then
        table.insert(state.lastAttackEvents, {
            slotIdx = slotIdx,
            col = col,
            targetType = "none",
            targetRow = 0,
            attackMode = silenced and "silenced" or "sealed",
        })
        return
    end

    local baseDmg, didCrit = CalculateBaseDamage(state, item, realm, slotIdx)
    local targets = CollectAttackTargets(state, item, col)

    if #targets == 0 then
        table.insert(state.lastAttackEvents, {
            slotIdx = slotIdx,
            col = col,
            targetType = "none",
            targetRow = 0,
            attackMode = item.attackMode or "single",
        })
        return
    end

    for _, targetInfo in ipairs(targets) do
        local damage = math.max(1, math.floor(baseDmg * (targetInfo.multiplier or 1.0)))
        table.insert(state.lastAttackEvents, {
            slotIdx = slotIdx,
            col = col,
            targetType = targetInfo.targetType,
            targetRow = targetInfo.row,
            target = targetInfo.target,
            attackMode = item.attackMode or "single",
        })

        if targetInfo.targetType == "monster" then
            ResolveMonsterHit(state, item, targetInfo, damage, didCrit)
        elseif targetInfo.targetType == "fieldReward" then
            ResolveFieldRewardHit(state, targetInfo)
        end
    end
end

local function ResolveAttackItem(state, item, slotIdx, col, realm, silenced)
    ResolveAttackItemOnce(state, item, slotIdx, col, realm, silenced)
    if silenced then return end

    local extraChance = GetTalentExtraAttackChance(state, item)
    if extraChance > 0 and math.random() < extraChance then
        print(string.format("  [Talent] %s 触发追加出手", item.name))
        ResolveAttackItemOnce(state, item, slotIdx, col, realm, false)
    end
end

local function ResolveDefenseItem(state, item, col, realm)
    local slowRate = (item.slowRate or 0) * realm.defMul
    if slowRate <= 0 then return end

    for _, monster in ipairs(state.monsters) do
        if IsMonsterTargetable(monster) and monster.col == col then
            monster.slowed = math.min(1.0, slowRate)
        end
    end
end

function PlayerItemResolver.Resolve(state)
    local realm = Config.GetRealm(state.realmIndex)
    local silenced = (state.itemSilenceTurns or 0) > 0

    if silenced then
        print(string.format("  [Skill] 灾厄脉冲压制法宝攻击，剩余%d回合", state.itemSilenceTurns))
    end

    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots[slotIdx]
        if item then
            local col = ((slotIdx - 1) % Config.GRID_COLS) + 1

            if item.itemType == Config.ITEM_TYPE.ATTACK then
                ResolveAttackItem(state, item, slotIdx, col, realm, silenced)
            elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
                ResolveDefenseItem(state, item, col, realm)
            end
        end
    end

    if silenced then
        state.itemSilenceTurns = math.max(0, (state.itemSilenceTurns or 0) - 1)
    end
end

return PlayerItemResolver
