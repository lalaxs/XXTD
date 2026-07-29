local Config = require("Config")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local GameEvents = require("GameEvents")
local VisualEventQueue = require("events.VisualEventQueue")

local EnemyDamage = {}

local function ApplySurvival(state, monster)
    local skill = monster.skill
    if not skill
        or skill.id ~= "holy_revival"
        or monster.revivalTriggered
        or monster.hp <= 0
        or monster.hp > monster.maxHp * (skill.hpThreshold or 0.35) then
        return false
    end

    local heal = math.floor(monster.maxHp * (skill.healPercent or 0.35))
    monster.hp = math.min(monster.maxHp, monster.hp + heal)
    monster.revivalTriggered = true
    if state then
        GameEvents.AddMonsterStatus(state, monster, "复苏", "buff")
    end
    print(string.format("  [Skill] %s 触发圣躯复苏，恢复%d", monster.name, heal))
    return true
end

function EnemyDamage.ApplySurvival(state, monster)
    return ApplySurvival(state, monster)
end

function EnemyDamage.Apply(state, item, monster, raw, context)
    if not monster or (monster.hp or 0) <= 0 or raw <= 0 then return 0, 0, 0 end
    context = context or {}
    local defense = math.max(0, monster.defense or 0)
    local ignore = math.min(1, item and item.defIgnore or 0)
    defense = defense * (1 - ignore) * (1 - math.min(0.70, monster.defenseDown or 0))
    local damage = math.max(1, math.floor(raw - math.min(defense, raw * 0.5)))
    if (monster.vulnerable or 0) > 0 then
        damage = math.floor(damage * (1 + monster.vulnerable))
    end
    if monster.skill and monster.skill.damageReduction then
        damage = math.floor(damage * math.max(0, 1 - monster.skill.damageReduction))
    end
    if monster.tier == Config.MONSTER_TIER.ELITE or monster.tier == Config.MONSTER_TIER.BOSS then
        damage = math.floor(damage * (1 + RogueRewardSystem.GetModifierValue(state, "eliteDamagePct")))
    end

    local shield = monster.shieldAmount or 0
    local shieldMultiplier = math.max(1, context.shieldMultiplier or 1)
    local shieldAbsorbed = math.min(shield, damage * shieldMultiplier)
    monster.shieldAmount = shield - shieldAbsorbed
    local damageBudgetSpentOnShield = math.ceil(shieldAbsorbed / shieldMultiplier)
    local hpDamage = math.max(0, damage - damageBudgetSpentOnShield)
    local hpBefore = math.max(0, monster.hp)
    local overflow = math.max(0, hpDamage - hpBefore)
    monster.hp = monster.hp - hpDamage
    monster.lastDamageWeaponId = context.weaponId or (item and item.baseId)
    monster.lastDamageSkillId = context.skillId or context.weaponId or (item and item.baseId)

    if hpDamage > 0 then
        local event = {
            col = monster.col,
            row = monster.row,
            dmg = hpDamage,
            target = monster,
            skillId = context.skillId,
            visualVariant = context.visualVariant,
        }
        table.insert(state.lastDamageDealt, event)
        VisualEventQueue.PushDamageDealt(state, event)
    end

    ApplySurvival(state, monster)
    if monster.hp > 0 then overflow = 0 end
    return hpDamage, overflow, shieldAbsorbed
end

return EnemyDamage
