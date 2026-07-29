-- combat/PlayerItemResolver.lua
-- 15 种攻击法宝基础效果、Q1-Q9 累计成长和具名肉鸽技能统一结算。

local Config = require("Config")
local BuffSystem = require("BuffSystem")
local FieldRewardService = require("rewards.FieldRewardService")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local ReincarnationSystem = require("ReincarnationSystem")
local GameEvents = require("GameEvents")
local DailyChallenge = require("DailyChallenge")
local Stats = require("combat.Stats")
local DefenseDown = require("combat.DefenseDown")
local KillResolver = require("combat.KillResolver")
local EnemyDamage = require("combat.EnemyDamage")

local PlayerItemResolver = {}

local ResolveSingleAttack

local function HasSkill(state, skillId)
    return (state.weaponUpgradeLevels or {})["weaponSkill:" .. skillId] ~= nil
end

local function IsLive(monster)
    return monster and monster.hp and monster.hp > 0 and (monster.stealthTurns or 0) <= 0
end

local function WeaponState(state, item)
    state.weaponCombatState = state.weaponCombatState or {}
    local id = item.combatInstanceId or ("legacy:" .. tostring(item))
    state.weaponCombatState[id] = state.weaponCombatState[id] or {}
    return state.weaponCombatState[id]
end

local function CurrentWeaponDamage(state, item, realm)
    local value = (item.atk or item.power or 0) * (realm.atkMul or 1)
    value = value * (1 + (item.weaponDamagePct or 0) + RogueRewardSystem.GetModifierValue(state, "weaponDamagePct") + ReincarnationSystem.GetValue(state, "attack"))
    value = value * (1 + BuffSystem.GetBuffValue(state, "atkUp") + BuffSystem.GetBuffValue(state, "allUp"))
    value = value * DailyChallenge.GetPlayerDamageMultiplier(state)
    local down = state.playerDebuffs and state.playerDebuffs.attackDown
    if down and (down.turns or 0) > 0 then value = value * math.max(0, 1 - math.min(0.20, down.value or 0)) end
    return math.max(1, math.floor(value + 0.5))
end

local function CritData(state, item, weaponState, options)
    options = options or {}
    local chance = (item.crit or 0) + RogueRewardSystem.GetModifierValue(state, "critChance") + ReincarnationSystem.GetValue(state, "critChance")
    if item.baseId == "fuyao_chain" then
        chance = chance + (weaponState.chainMomentum or 0) + (HasSkill(state, "chain_spirit") and 0.15 or 0)
    end
    chance = math.min(1, math.max(0, chance + (options.critChanceBonus or 0)))
    local multiplier = (item.critMultiplier or 2.0) + RogueRewardSystem.GetModifierValue(state, "critDamagePct")
    if item.baseId == "fuyao_chain" then multiplier = multiplier + (HasSkill(state, "chain_spirit") and 0.15 or 0) end
    if options.multiplier then multiplier = options.multiplier end
    local didCrit = options.forceCrit == true or (options.forceCrit ~= false and DailyChallenge.RandomFloat(state) < chance)
    return didCrit, multiplier
end

local function AddAttackEvent(state, item, slotIdx, target, didCrit, opts)
    opts = opts or {}
    table.insert(state.lastAttackEvents, {
        slotIdx = slotIdx, col = ((slotIdx - 1) % Config.GRID_COLS) + 1,
        targetType = opts.targetType or "monster", targetCol = target.col, targetRow = target.row, target = target,
        attackMode = item.attackMode or "single", baseId = item.baseId, school = item.school,
        quality = item.quality, crit = didCrit == true, visualVariant = opts.visualVariant,
        skillId = opts.skillId, effectScale = opts.effectScale or 1,
    })
end

local function IsBoss(monster) return monster.tier == Config.MONSTER_TIER.BOSS end
local function IsElite(monster) return monster.tier == Config.MONSTER_TIER.ELITE end

local function DamageMonster(state, item, monster, raw, context)
    if not IsLive(monster) or raw <= 0 then return 0, 0 end
    return EnemyDamage.Apply(state, item, monster, raw, context)
end

local function ExtraDamage(state, item, target, amount, skillId)
    local damage = DamageMonster(state, item, target, math.floor(amount + 0.5), { skillId = skillId, visualVariant = "skill" })
    if damage > 0 then print(string.format("  [Weapon Skill] %s %s 追加%d", item.name, skillId or "基础", damage)) end
    return damage
end

local function TryHardControl(state, monster, kind)
    if IsBoss(monster) then return false, "boss_immune" end
    if IsElite(monster) and DailyChallenge.RandomFloat(state) < 0.5 then return false, "elite_evade" end
    return true, kind
end

local function FindFrontTarget(state, col)
    local chosen, row, targetType = nil, -1, nil
    for _, monster in ipairs(state.monsters) do
        if IsLive(monster) and monster.col == col and monster.row > row then
            chosen, row, targetType = monster, monster.row, "monster"
        end
    end
    for _, fieldReward in ipairs(state.fieldRewards or {}) do
        if (fieldReward.hp or 0) > 0 and fieldReward.col == col and fieldReward.row > row then
            chosen, row, targetType = fieldReward, fieldReward.row, "fieldReward"
        end
    end
    return chosen, targetType
end

local function NearestTargets(state, source, count, predicate, randomize)
    local targets = {}
    for _, monster in ipairs(state.monsters) do
        if IsLive(monster) and monster ~= source and (not predicate or predicate(monster)) then table.insert(targets, monster) end
    end
    if randomize then
        for index = #targets, 2, -1 do
            local swapIndex = math.floor(DailyChallenge.RandomFloat(state) * index) + 1
            targets[index], targets[swapIndex] = targets[swapIndex], targets[index]
        end
    else
        table.sort(targets, function(a, b)
            local da = math.abs(a.col - source.col) + math.abs(a.row - source.row)
            local db = math.abs(b.col - source.col) + math.abs(b.row - source.row)
            return da == db and a.row > b.row or da < db
        end)
    end
    while #targets > count do table.remove(targets) end
    return targets
end

local function SameRowTargets(state, source)
    return NearestTargets(state, source, 99, function(monster)
        return monster.row == source.row
    end)
end

local function ApplyBurn(state, item, monster, currentDamage, turnsOverride, source)
    monster.burnInstances = monster.burnInstances or {}
    local cap = HasSkill(state, "fire_add_oil") and 10 or 5
    if #monster.burnInstances >= cap then return false end
    state.nextBurnInstanceId = (state.nextBurnInstanceId or 0) + 1
    local turns = turnsOverride or (HasSkill(state, "fire_add_oil") and 4 or 3)
    table.insert(monster.burnInstances, { id = state.nextBurnInstanceId, sourceWeaponId = item.combatInstanceId, source = source or "chiyan_spear", initialDamage = currentDamage * (item.burnDamagePct or 0.05), currentDamage = currentDamage * (item.burnDamagePct or 0.05), turns = turns, created = state.nextBurnInstanceId })
    return true
end

local function CountBurn(monster) return #(monster.burnInstances or {}) end

local function ApplyAttackDown(monster, pct, turns)
    local oldPct = monster.attackDown or 0
    local oldTurns = monster.attackDownTurns or 0
    monster.attackDown = math.max(oldPct, pct)
    monster.attackDownTurns = math.max(oldTurns, turns)
    return monster.attackDown > oldPct or monster.attackDownTurns > oldTurns
end

local function ResolveBaseStatus(state, item, monster, weaponDamage, weaponState, context)
    local id = item.baseId
    if id ~= "chiyan_spear" and not IsLive(monster) then return end
    if id == "chiyan_spear" then
        local count = 1 + ((DailyChallenge.RandomFloat(state) < (item.extraBurnChance or 0)) and 1 or 0)
        for _ = 1, count do ApplyBurn(state, item, monster, weaponDamage) end
        if IsLive(monster) and HasSkill(state, "fire_explosion") and CountBurn(monster) >= 5 and not context.noBurnExplosion then
            table.sort(monster.burnInstances, function(a, b) return a.turns == b.turns and a.created < b.created or a.turns < b.turns end)
            for _ = 1, 5 do table.remove(monster.burnInstances, 1) end
            ExtraDamage(state, item, monster, weaponDamage, "fire_explosion")
        end
    elseif id == "huxin_pearl" then
        local pct = item.attackDownPct or 0.10
        local wasDown = (monster.attackDown or 0) > 0
        local applied = ApplyAttackDown(monster, pct, 2)
        ExtraDamage(state, item, monster, (monster.baseAtk or 0) * pct, "pearl_attack_down")
        if HasSkill(state, "pearl_light_shines") then
            for _, other in ipairs(SameRowTargets(state, monster)) do ApplyAttackDown(other, pct * 0.5, 2) end
        end
        if applied and HasSkill(state, "pearl_spirit_platform") and monster.pearlShieldTurn ~= state.turn then
            monster.pearlShieldTurn = state.turn
            local gain = math.floor((state.maxHp or 0) * 0.02)
            local gainedThisTurn = state.pearlShieldGainedTurn == state.turn and (state.pearlShieldGained or 0) or 0
            local turnCap = math.floor((state.maxHp or 0) * 0.10)
            gain = math.min(gain, math.max(0, turnCap - gainedThisTurn))
            state.pearlShieldGainedTurn = state.turn
            state.pearlShieldGained = gainedThisTurn + gain
            state.armorShield = (state.armorShield or 0) + gain
        end
        if not wasDown then GameEvents.AddMonsterStatus(state, monster, "削攻", "debuff") end
        if (item.blindChance or 0) > 0 and DailyChallenge.RandomFloat(state) < item.blindChance then
            local ok = TryHardControl(state, monster, "blind")
            if ok then
                monster.blindTurns = math.max(monster.blindTurns or 0, 2)
                monster.blindWeaponDamage = weaponDamage
                monster.blindWeaponItem = item
                monster.pearlBlindness = HasSkill(state, "pearl_blindness")
            end
        end
    elseif id == "baigu_staff" then
        local hpRatio = context.hpRatioBefore or (monster.maxHp > 0 and math.max(0, monster.hp) / monster.maxHp or 0)
        local base = 0.10 + hpRatio * 0.10 + (item.defenseDownBonus or 0)
        local sourceKey = item.combatInstanceId or tostring(item)
        DefenseDown.ApplyWhiteBase(monster, sourceKey, base, 2, true)
        if HasSkill(state, "staff_erosion_marrow") then
            if weaponState.lastBoneTarget == monster then
                weaponState.boneStreak = math.min(4, (weaponState.boneStreak or 0) + 1)
            else
                weaponState.lastBoneTarget, weaponState.boneStreak = monster, 1
            end
            DefenseDown.ApplyWhiteMarrow(
                monster,
                sourceKey,
                math.min(0.20, (weaponState.boneStreak or 0) * 0.05),
                2
            )
        end
        if HasSkill(state, "staff_break_formation") then monster.formationMarkTurns = math.max(monster.formationMarkTurns or 0, 2) end
    elseif id == "qingyin_qin" then
        if (monster.qinImmuneTurns or 0) > 0 then
            if HasSkill(state, "qin_silent_wins") then
                ExtraDamage(state, item, monster, weaponDamage * 0.50, "qin_silent_wins")
            end
        else
            local chance = (item.rootChance or 0.20) + (monster.qinChanceBonus or 0)
            local success = DailyChallenge.RandomFloat(state) < chance
            local ok = success and TryHardControl(state, monster, "root") or false
            if ok then
                monster.rootTurns = math.max(monster.rootTurns or 0, 1)
                monster.qinImmuneTurns = math.max(monster.qinImmuneTurns or 0, (item.rootCooldown or 4) + 1)
                monster.qinChanceBonus = 0
                if HasSkill(state, "qin_broken_string") then
                    ExtraDamage(state, item, monster, weaponDamage * 0.80, "qin_broken_string")
                    monster.qinImmuneTurns = monster.qinImmuneTurns + 1
                end
            else
                if HasSkill(state, "qin_gradual_melody") then monster.qinChanceBonus = math.min(0.30, (monster.qinChanceBonus or 0) + 0.10) end
            end
        end
    elseif id == "jinguang_ring" and not context.noKnockback then
        local chance = (item.knockbackChance or 0.10) + (HasSkill(state, "ring_endless_turn") and 0.15 or 0) + (weaponState.ringMomentum or 0)
        if not IsBoss(monster) and DailyChallenge.RandomFloat(state) < chance then
            if IsElite(monster) and DailyChallenge.RandomFloat(state) < 0.5 then
                if HasSkill(state, "ring_store_might") then weaponState.ringMomentum = math.max(0, (weaponState.ringMomentum or 0) - 0.10) end
            else
                weaponState.ringMomentum = 0
                local shakeMountainApplies = HasSkill(state, "ring_shake_mountain")
                    and monster.tier == Config.MONSTER_TIER.NORMAL
                local distance = shakeMountainApplies and 2 or 1
                local moved = 0
                for _ = 1, distance do
                    local blocked = false
                    for _, other in ipairs(state.monsters) do if other ~= monster and IsLive(other) and other.col == monster.col and other.row == monster.row - 1 then blocked = other break end end
                    if blocked then
                        if (item.collisionDamagePct or 0) > 0 then ExtraDamage(state, item, blocked, weaponDamage * item.collisionDamagePct, "ring_collision") end
                        break
                    end
                    if monster.row <= 1 then break end
                    monster.row = monster.row - 1; moved = moved + 1
                end
                if shakeMountainApplies and moved > 0 then ExtraDamage(state, item, monster, weaponDamage * 0.30 * moved, "ring_shake_mountain") end
                if HasSkill(state, "ring_return_light") and not context.noReturnLight and IsLive(monster) then
                    ResolveSingleAttack(state, item, context.slotIdx, monster, {
                        isExtraAttack = true,
                        noKnockback = true,
                        noReturnLight = true,
                        damageRatio = 0.50,
                        skillId = "ring_return_light",
                        visualVariant = "extra_attack",
                        effectScale = 0.8,
                    })
                end
            end
        elseif not IsBoss(monster) and HasSkill(state, "ring_store_might") then
            weaponState.ringMomentum = math.min(0.30, (weaponState.ringMomentum or 0) + 0.10)
        end
    end
end

ResolveSingleAttack = function(state, item, slotIdx, monster, context)
    if not IsLive(monster) or (state.hp or 0) <= 0 then return false end
    context = context or {}
    context.slotIdx = slotIdx
    local realm = Config.GetRealm(state.realmIndex)
    local weaponState = WeaponState(state, item)
    local weaponDamage = CurrentWeaponDamage(state, item, realm)
    local id = item.baseId
    local hpBefore = math.max(0, monster.hp)
    local maxHp = math.max(1, monster.maxHp or 1)
    local hpRatioBefore = hpBefore / maxHp
    context.hpRatioBefore = hpRatioBefore
    local hadAttackDownBefore = (monster.attackDown or 0) > 0 and (monster.attackDownTurns or 0) > 0
    local hadDefenseDownBefore = (monster.defenseDown or 0) > 0 and (monster.defenseDownTurns or 0) > 0
    local wasRootedBefore = (monster.rootTurns or 0) > 0

    if id == "lingmo_brush" then
        local hpRatio = (state.maxHp or 1) > 0 and (state.hp or 0) / state.maxHp or 1
        if hpRatio <= 0.30 then
            local bonus = item.lowPlayerDamagePct or 0.20
            bonus = bonus + math.floor(math.max(0, 0.30 - hpRatio) / 0.05 + 0.000001) * (item.lowPlayerLayerPct or 0)
            if HasSkill(state, "brush_grind_ink") then bonus = bonus * 1.15 end
            weaponDamage = math.floor(weaponDamage * (1 + bonus))
        end
        if HasSkill(state, "brush_judgement") and monster.hp < math.max(0, (state.maxHp or 0) - (state.hp or 0)) then
            monster.hp = 0
            monster.lastDamageWeaponId = item.baseId
            monster.lastDamageSkillId = "brush_judgement"
            AddAttackEvent(state, item, slotIdx, monster, false, { skillId = "brush_judgement", visualVariant = "skill", effectScale = 1.3 })
            print("  [Weapon Skill] 审判直接斩杀")
            return true, false
        end
    elseif id == "huxin_pearl" and HasSkill(state, "pearl_heart_shock") and hadAttackDownBefore then
        weaponDamage = math.floor(weaponDamage * 1.25)
    elseif id == "baigu_staff" then
        if hadDefenseDownBefore then weaponDamage = math.floor(weaponDamage * (1 + (item.defenseDownDamagePct or 0))) end
        if HasSkill(state, "staff_bone_erosion") then weaponDamage = math.floor(weaponDamage * (1 + math.min(0.25, math.floor((monster.defenseDown or 0) / 0.10 + 0.000001) * 0.05))) end
    elseif id == "pozhen_spear" then
        if IsElite(monster) or IsBoss(monster) then if HasSkill(state, "spear_braver_against_sturdy") then weaponDamage = math.floor(weaponDamage * 1.25) end end
        if (monster.formationMarkTurns or 0) > 0 and HasSkill(state, "staff_break_formation") then
            weaponDamage = math.floor(weaponDamage * 1.30)
            local attackTracker = context.attackTracker or context
            if not attackTracker.formationExtensionUsed and DefenseDown.ExtendWhiteBone(monster, 1) then
                attackTracker.formationExtensionUsed = true
            end
        end
    elseif id == "chiyan_spear" and HasSkill(state, "fire_burn_body") then
        weaponDamage = math.floor(weaponDamage * (1 + math.min(0.30, CountBurn(monster) * 0.02)))
    end

    local didCrit, critMultiplier = CritData(state, item, weaponState, context)
    local raw = weaponDamage * (context.damageRatio or 1)
    local virtualCritDamage = raw * critMultiplier
    if id == "bishui_sword" then
        if HasSkill(state, "bishui_urge_wave") then
            critMultiplier = (item.quality or 1) <= 2
                and (0.90 + DailyChallenge.RandomFloat(state) * 0.60)
                or (1.00 + DailyChallenge.RandomFloat(state) * 0.60)
            virtualCritDamage = raw * critMultiplier
        end
        if HasSkill(state, "bishui_cut_current") then
            didCrit = false
            raw = raw + virtualCritDamage * 0.10
        else
            didCrit = true
            raw = virtualCritDamage
        end
    elseif didCrit then raw = raw * critMultiplier end
    if id == "fuyao_chain" and didCrit then raw = raw * (1 + (weaponState.chainCritBonus or 0)) end
    if id == "ziqi_gourd" and context.canDoubleDamage then raw = raw * 2 end
    raw = math.max(1, math.floor(raw + 0.5))
    AddAttackEvent(state, item, slotIdx, monster, didCrit, context)
    local _, overflow = DamageMonster(state, item, monster, raw, {
        skillId = context.skillId,
        visualVariant = context.isExtraAttack and "extra_attack" or "main",
        shieldMultiplier = id == "pozhen_spear" and HasSkill(state, "spear_break_wall") and 2 or 1,
    })

    if id == "qingfeng_sword" and hpRatioBefore > math.max(0, (item.highHpThreshold or 0.80) - (HasSkill(state, "qingfeng_huali") and 0.15 or 0)) then
        ExtraDamage(state, item, monster, weaponDamage * (item.highHpBonusPct or 0.20) * (HasSkill(state, "sword_edge_exposed") and 1.20 or 1), "qingfeng_high_hp")
    end
    if id == "taiji_sword" and hpRatioBefore < (item.lowHpThreshold or 0.20) then
        ExtraDamage(state, item, monster, weaponDamage * (item.lowHpBonusPct or 0.15) * (HasSkill(state, "sword_edge_exposed") and 1.20 or 1), "taiji_low_hp")
    end
    if HasSkill(state, "taqing_sword_art") then
        local thresholdBonusMultiplier = HasSkill(state, "sword_edge_exposed") and 1.20 or 1
        if id == "qingfeng_sword" and not state.runWeapons.taiji_sword and hpRatioBefore < 0.20 then
            ExtraDamage(state, item, monster, weaponDamage * 0.15 * thresholdBonusMultiplier, "taqing_sword_art")
        end
        if id == "taiji_sword" and not state.runWeapons.qingfeng_sword and hpRatioBefore > 0.80 then
            ExtraDamage(state, item, monster, weaponDamage * 0.20 * thresholdBonusMultiplier, "taqing_sword_art")
        end
    end
    if id == "qingfeng_sword" and HasSkill(state, "qingfeng_sharp") and DailyChallenge.RandomFloat(state) < 0.10 then ExtraDamage(state, item, monster, weaponDamage * 0.50, "qingfeng_sharp") end
    if id == "bishui_sword" then
        if (item.maxHpDamagePct or 0) > 0 and not context.noMaxHpDamage then ExtraDamage(state, item, monster, math.min(monster.maxHp * item.maxHpDamagePct, weaponDamage * 0.70), "bishui_max_hp") end
        if HasSkill(state, "bishui_water_force") then ExtraDamage(state, item, monster, virtualCritDamage * 0.20, "bishui_water_force") end
        if HasSkill(state, "bishui_river_stir") and overflow > 0 and not context.noOverflow then
            local others = NearestTargets(state, monster, 1, nil, true)
            if others[1] then ExtraDamage(state, item, others[1], overflow, "bishui_river_stir") end
        end
    elseif id == "pozhen_spear" and (item.baseDefenseDamagePct or 0) > 0 then
        local pct = item.baseDefenseDamagePct * (HasSkill(state, "spear_borrow_armor") and 1.30 or 1)
        ExtraDamage(state, item, monster, (monster.baseDefense or 0) * pct, "pozhen_base_defense")
    elseif id == "qingyin_qin" and HasSkill(state, "qin_lingering_sound") and wasRootedBefore and monster.qinLingeringTurn ~= state.turn then
        monster.qinLingeringTurn = state.turn
        ExtraDamage(state, item, monster, weaponDamage * 0.25, "qin_lingering_sound")
    elseif id == "lingmo_brush" and HasSkill(state, "brush_bloom") and DailyChallenge.RandomFloat(state) < 0.20 then
        ExtraDamage(state, item, monster, math.max(0, (state.maxHp or 0) - (state.hp or 0)), "brush_bloom")
    end

    ResolveBaseStatus(state, item, monster, weaponDamage, weaponState, context)
    if id == "fuyao_chain" then
        if didCrit then
            weaponState.chainMomentum = 0
            weaponState.chainCritBonus = math.min(1.50, (weaponState.chainCritBonus or 0) + (item.chainCritStep or 0))
            if HasSkill(state, "chain_fury") and DailyChallenge.RandomFloat(state) < 0.05 then ExtraDamage(state, item, monster, weaponDamage * 3, "chain_fury") end
        else
            weaponState.chainMomentum = HasSkill(state, "chain_momentum") and math.min(0.45, (weaponState.chainMomentum or 0) + 0.15) or 0
            weaponState.chainCritBonus = HasSkill(state, "chain_turn_tide") and math.max(0, (weaponState.chainCritBonus or 0) - 0.20) or 0
        end
    end
    return monster.hp <= 0, didCrit
end

local function ResolveFan(state, item, slotIdx, primary)
    local damage = CurrentWeaponDamage(state, item, Config.GetRealm(state.realmIndex))
    if HasSkill(state, "fan_wind_aids_fire") then
        for _, burn in ipairs(primary.burnInstances or {}) do if not burn.windAided then burn.currentDamage = burn.currentDamage * 1.20; burn.windAided = true end end
    end
    ResolveSingleAttack(state, item, slotIdx, primary, {})
    local splashes = NearestTargets(state, primary, item.splashCount or 1)
    if #splashes == 0 and HasSkill(state, "fan_if_wind") then ExtraDamage(state, item, primary, math.min(damage * 1.50, damage * (item.splashRatio or 0.20) * (item.splashCount or 1)), "fan_if_wind") end
    for _, target in ipairs(splashes) do
        local raw = damage * (item.splashRatio or 0.20)
        if HasSkill(state, "fan_wind_wrath") and DailyChallenge.RandomFloat(state) < 0.20 then raw = raw * 2 end
        local crit, mult = CritData(state, item, WeaponState(state, item), { critChanceBonus = HasSkill(state, "fan_wind_sough") and 0.20 or 0 })
        if not HasSkill(state, "fan_wind_sough") then crit = false end
        AddAttackEvent(state, item, slotIdx, target, crit, { skillId = "fan_splash", visualVariant = "splash" })
        DamageMonster(state, item, target, raw * (crit and mult or 1), { skillId = "fan_splash", visualVariant = "splash" })
    end
end

local function ResolveTower(state, item, slotIdx, primary)
    ResolveSingleAttack(state, item, slotIdx, primary, {})
    local weaponDamage = CurrentWeaponDamage(state, item, Config.GetRealm(state.realmIndex))
    local casts = 1 + ((DailyChallenge.RandomFloat(state) < (item.doubleCastChance or 0)) and 1 or 0)
    for _ = 1, casts do
        local targets = {}; for _, monster in ipairs(state.monsters) do if IsLive(monster) then table.insert(targets, monster) end end
        local mul = 1 + math.min(0.50, #targets * 0.10) * (HasSkill(state, "tower_demon_might") and 1 or 0)
        local crit, mult = false, 1
        if HasSkill(state, "tower_nine_heavens") then crit = DailyChallenge.RandomFloat(state) < (item.crit or 0) * 0.50; mult = 1.50 end
        for _, target in ipairs(targets) do
            AddAttackEvent(state, item, slotIdx, target, crit, { skillId = "tower_global", visualVariant = "global" })
            local before = target.hp
            DamageMonster(state, item, target, weaponDamage * ((item.globalDamagePct or 0.025) + (state.towerRefineBonusPct or 0)) * mul * (crit and mult or 1), { skillId = "tower_global", visualVariant = "global" })
            if HasSkill(state, "tower_refine") and before > 0 and target.hp <= 0 then state.towerRefineBonusPct = math.min(0.05, (state.towerRefineBonusPct or 0) + 0.0025) end
            if HasSkill(state, "tower_seal") and target.hp > 0 then target.towerSealHits = (target.towerSealHits or 0) + 1; if target.towerSealHits >= 5 then target.towerSealHits = target.towerSealHits - 5; ExtraDamage(state, item, target, weaponDamage * 0.60, "tower_seal") end end
        end
    end
end

local function ResolveGourd(state, item, slotIdx, target)
    local ws, damage = WeaponState(state, item), CurrentWeaponDamage(state, item, Config.GetRealm(state.realmIndex))
    local chance = (item.healChance or 0.08) + (HasSkill(state, "gourd_purple_fills") and (ws.gourdPity or 0) or 0)
    local healTriggered = DailyChallenge.RandomFloat(state) < chance
    local double = healTriggered and DailyChallenge.RandomFloat(state) < (item.doubleDamageChance or 0)
    ResolveSingleAttack(state, item, slotIdx, target, { canDoubleDamage = double })
    if healTriggered then
        ws.gourdPity = 0
        local lowHpAtTrigger = (state.hp or 0) <= (state.maxHp or 0) * 0.5
        local heal = math.max(1, damage * (HasSkill(state, "gourd_heal_world") and 0.03 or 0.01))
        if HasSkill(state, "gourd_medicine_poison") and lowHpAtTrigger then heal = heal * 2 end
        local actual = Stats.Heal(state, heal)
        if HasSkill(state, "gourd_purple_guard") then state.armorShield = math.min((state.armorShield or 0) + math.max(0, heal - actual), math.floor((state.maxHp or 0) * 0.15)) end
        if HasSkill(state, "gourd_medicine_poison") and not lowHpAtTrigger then ExtraDamage(state, item, target, damage * 0.50, "gourd_medicine_poison") end
    elseif HasSkill(state, "gourd_purple_fills") then ws.gourdPity = math.min(0.10, (ws.gourdPity or 0) + 0.02) end
end

local function ResolveDoubleChain(state, item, slotIdx, target)
    local count = 2 + ((DailyChallenge.RandomFloat(state) < ((item.tripleChance or 0) + (HasSkill(state, "double_chain_three_rings") and 0.10 or 0))) and 1 or 0)
    local priorCrit, current = false, target
    local firstSegmentLeftTargetAlive = false
    for segment = 1, count do
        if not IsLive(current) then
            if HasSkill(state, "double_chain_soul_chase") then
                local nexts = NearestTargets(state, current or target, 1)
                current = nexts[1]
            else
                break
            end
            if not current then break end
        end
        local force, mult = nil, nil
        if segment == 2 and priorCrit and HasSkill(state, "double_chain_twins") then
            force = true
            local _, normal = CritData(state, item, WeaponState(state, item), {})
            mult = 1 + (normal - 1) * 0.80
        end
        local damageRatio = item.segmentDamagePct or 0.45
        if segment == 2 and firstSegmentLeftTargetAlive and HasSkill(state, "double_chain_follow_win") then damageRatio = damageRatio * 1.25 end
        local _, didCrit = ResolveSingleAttack(state, item, slotIdx, current, {
            damageRatio = damageRatio,
            forceCrit = force,
            multiplier = mult,
            skillId = "double_chain_segment",
            visualVariant = "segment",
        })
        if segment == 1 then
            priorCrit = didCrit
            firstSegmentLeftTargetAlive = IsLive(current)
        end
    end
end

local function ResolveFieldRewardAttack(state, item, slotIdx, fieldReward)
    if not fieldReward or (fieldReward.hp or 0) <= 0 then return false end
    local didCrit = CritData(state, item, WeaponState(state, item), {})
    AddAttackEvent(state, item, slotIdx, fieldReward, didCrit, {
        targetType = "fieldReward",
        visualVariant = "reward",
    })
    FieldRewardService.ResolveFieldRewardHit(state, fieldReward)
    print(string.format("  [FieldReward] %s击碎第%d列奖励：%s", item.name, fieldReward.col or 0, fieldReward.rewardItem and fieldReward.rewardItem.name or "随机道具"))
    return true
end

local function ResolveAttackItem(state, item, slotIdx, col, realm, silenced)
    if silenced or (state.sealedSlots and (state.sealedSlots[slotIdx] or 0) > 0) then return end
    local target, targetType = FindFrontTarget(state, col)
    if not target then return end
    if targetType == "fieldReward" then
        ResolveFieldRewardAttack(state, item, slotIdx, target)
        return
    end
    if item.baseId == "zhenyao_tower" then ResolveTower(state, item, slotIdx, target)
    elseif item.baseId == "qingyu_fan" then ResolveFan(state, item, slotIdx, target)
    elseif item.baseId == "ziqi_gourd" then ResolveGourd(state, item, slotIdx, target)
    elseif item.baseId == "double_blade_chain" then ResolveDoubleChain(state, item, slotIdx, target)
    else ResolveSingleAttack(state, item, slotIdx, target, {}) end
    if item.baseId == "taiji_sword" and HasSkill(state, "taiji_yinyang") and IsLive(target) and DailyChallenge.RandomFloat(state) < 0.20 then ResolveSingleAttack(state, item, slotIdx, target, { isExtraAttack = true, damageRatio = 0.50, skillId = "taiji_yinyang" }) end
    if item.baseId == "taiji_sword" and HasSkill(state, "taiji_enlightenment") and IsLive(target) and target.hp < target.maxHp * 0.10 then
        target.hp = 0
        target.lastDamageWeaponId = item.baseId
        target.lastDamageSkillId = "taiji_enlightenment"
        print("  [Weapon Skill] 悟道斩杀")
    end
end

function PlayerItemResolver.Resolve(state)
    local realm = Config.GetRealm(state.realmIndex)
    local silenced = (state.itemSilenceTurns or 0) > 0
    for slotIdx = 1, Config.TOTAL_SLOTS do
        local item = state.slots[slotIdx]
        if item and item.itemType == Config.ITEM_TYPE.ATTACK then
            ResolveAttackItem(state, item, slotIdx, ((slotIdx - 1) % Config.GRID_COLS) + 1, realm, silenced)
            KillResolver.Resolve(state)
        end
    end
    if silenced then state.itemSilenceTurns = math.max(0, state.itemSilenceTurns - 1) end
end

return PlayerItemResolver
