-- config/RogueRewardDefs.lua
-- 本轮肉鸽奖励：15 把武器的解锁与专属强化，以及可重复选择的通用数值。

local WeaponDefs = require("config.WeaponDefs")

local WEAPON_ICONS = {
    qingfeng_sword = "image/weapon/weapon  (1).png",
    chiyan_spear = "image/weapon/weapon  (2).png",
    qingyu_fan = "image/weapon/weapon  (3).png",
    ziqi_gourd = "image/weapon/weapon  (4).png",
    jinguang_ring = "image/weapon/weapon  (5).png",
    qingyin_qin = "image/weapon/weapon  (6).png",
    baigu_staff = "image/weapon/weapon  (7).png",
    fuyao_chain = "image/weapon/weapon  (8).png",
    zhenyao_tower = "image/weapon/weapon  (9).png",
    double_blade_chain = "image/weapon/weapon  (10).png",
    bishui_sword = "image/weapon/weapon  (11).png",
    lingmo_brush = "image/weapon/weapon  (12).png",
    pozhen_spear = "image/weapon/weapon  (13).png",
    taiji_sword = "image/weapon/weapon  (14).png",
    huxin_pearl = "image/weapon/weapon  (15).png",
}

local ARMOR_ICONS = {
    dark_iron_shield = "image/armor/dark_iron_shield.png",
    thorn_armor = "image/armor/thorn_armor.png",
    yuqing_robe = "image/armor/yuqing_robe.png",
    creation_robe = "image/armor/creation_robe.png",
    purity_orb = "image/armor/purity_orb.png",
}

local weapons = {
    { id = "qingfeng_sword", name = "青锋剑", upgrades = { { "会心剑诀", "本武器暴击率 +10%", "critChance", 0.10 }, { "断岳剑意", "本武器暴击伤害 +25%", "critDamagePct", 0.25 }, { "剑鸣", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "chiyan_spear", name = "赤焰枪", upgrades = { { "焰枪贯穿", "本武器额外穿透 +1", "pierceBonus", 1 }, { "烬火", "本武器持续伤害 +25%", "dotDamagePct", 0.25 }, { "余烬", "本武器减益持续 +1回合", "debuffDurationBonus", 1 } } },
    { id = "qingyu_fan", name = "青羽扇", upgrades = { { "风卷", "本武器溅射伤害 +20%", "sweepSplashPct", 0.20 }, { "风痕", "本武器易伤幅度 +10%", "vulnerableBonusPct", 0.10 }, { "风眼", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "ziqi_gourd", name = "紫气葫芦", upgrades = { { "纳海", "本武器范围 +1档", "areaRangeBonus", 1 }, { "毒瘴", "本武器持续伤害 +25%", "dotDamagePct", 0.25 }, { "毒爆", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "jinguang_ring", name = "金光环", upgrades = { { "光轮扩张", "本武器范围 +1档", "areaRangeBonus", 1 }, { "摄魂金光", "本武器减益幅度 +20%", "debuffPowerPct", 0.20 }, { "长明", "本武器减益持续 +1回合", "debuffDurationBonus", 1 } } },
    { id = "qingyin_qin", name = "清音琴", upgrades = { { "余音绕梁", "本武器溅射伤害 +20%", "sweepSplashPct", 0.20 }, { "定弦", "本武器定身 +1回合", "rootTurnsBonus", 1 }, { "震魂", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "baigu_staff", name = "白骨杖", upgrades = { { "蚀骨", "本武器无视防御 +20%", "defIgnorePct", 0.20 }, { "碎甲", "本武器减益幅度 +20%", "debuffPowerPct", 0.20 }, { "阴煞", "本武器减益持续 +1回合", "debuffDurationBonus", 1 } } },
    { id = "fuyao_chain", name = "缚妖链", upgrades = { { "锁魂", "本武器定身 +2回合", "rootTurnsBonus", 2 }, { "缚灵", "本武器减益持续 +1回合", "debuffDurationBonus", 1 }, { "镇缚", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "zhenyao_tower", name = "镇妖塔", upgrades = { { "塔域", "本武器范围 +1档", "areaRangeBonus", 1 }, { "镇压", "本武器减益幅度 +20%", "debuffPowerPct", 0.20 }, { "塔威", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "double_blade_chain", name = "双刃锁链", upgrades = { { "回旋刃", "本武器溅射伤害 +20%", "sweepSplashPct", 0.20 }, { "锁链拖拽", "本武器位移距离 +1", "displaceBonus", 1 }, { "裂伤", "本武器持续伤害 +25%", "dotDamagePct", 0.25 } } },
    { id = "bishui_sword", name = "碧水剑", upgrades = { { "秋水", "本武器暴击率 +10%", "critChance", 0.10 }, { "寒意", "本武器减益幅度 +20%", "debuffPowerPct", 0.20 }, { "凝霜", "本武器减益持续 +1回合", "debuffDurationBonus", 1 } } },
    { id = "lingmo_brush", name = "灵墨笔", upgrades = { { "泼墨", "本武器范围 +1档", "areaRangeBonus", 1 }, { "墨痕", "本武器易伤幅度 +10%", "vulnerableBonusPct", 0.10 }, { "点睛", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "pozhen_spear", name = "破阵枪", upgrades = { { "破军", "本武器额外穿透 +1", "pierceBonus", 1 }, { "洞甲", "本武器无视防御 +20%", "defIgnorePct", 0.20 }, { "破绽", "本武器易伤幅度 +10%", "vulnerableBonusPct", 0.10 } } },
    { id = "taiji_sword", name = "太极剑", upgrades = { { "阴阳剑", "本武器暴击率 +10%", "critChance", 0.10 }, { "推演", "本武器位移距离 +1", "displaceBonus", 1 }, { "化劲", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
    { id = "huxin_pearl", name = "护心珠", upgrades = { { "莲台", "本武器范围 +1档", "areaRangeBonus", 1 }, { "护心灵光", "本武器减益幅度 +20%", "debuffPowerPct", 0.20 }, { "莲华", "本武器特效强度 +20%", "specialEffectPct", 0.20 } } },
}

local WEAPON_DESCRIPTIONS = {}
for _, def in ipairs(WeaponDefs) do
    if not WEAPON_DESCRIPTIONS[def.baseId] then
        WEAPON_DESCRIPTIONS[def.baseId] = def.description
    end
end

local armors = {
    { id = "dark_iron_shield", name = "玄铁宝盾" },
    { id = "thorn_armor", name = "荆棘战甲" },
    { id = "yuqing_robe", name = "玉清道衣" },
    { id = "creation_robe", name = "生生造化袍" },
    { id = "purity_orb", name = "净秽宝珠" },
}

local defs = {}
for _, armor in ipairs(armors) do
    table.insert(defs, {
        id = "unlockArmor:" .. armor.id,
        name = armor.name,
        shortName = armor.name,
        category = "防御解锁",
        desc = "解锁" .. armor.name .. "，加入本轮防具掉落与合成池。",
        abilityName = armor.name,
        abilityDesc = "解锁后，" .. armor.name .. "可以出现在本轮防具掉落与合成池中。",
        kind = "unlockArmor",
        armorId = armor.id,
        icon = ARMOR_ICONS[armor.id],
        weight = 4,
        maxStacks = 1,
        immediate = true,
    })
end

for _, weapon in ipairs(weapons) do
    local icon = WEAPON_ICONS[weapon.id]
    table.insert(defs, { id = "unlock:" .. weapon.id, name = weapon.name, shortName = weapon.name, abilityName = weapon.name, abilityDesc = WEAPON_DESCRIPTIONS[weapon.id] or "加入本轮掉落与合成池。", category = "解锁", desc = "获得" .. weapon.name .. "并加入本轮掉落与合成池。", kind = "unlock", weaponId = weapon.id, icon = icon, weight = 4, maxStacks = 1, immediate = true })
    table.insert(defs, { id = "weaponDamagePct:" .. weapon.id, name = weapon.name .. "·淬锋", shortName = "淬锋", abilityName = weapon.name .. "·淬锋", abilityDesc = "本武器伤害 +20%，强化效果可重复叠加。", category = "专属", desc = "本武器伤害 +20%，强化效果可重复叠加。", kind = "weapon", weaponId = weapon.id, icon = icon, modifier = { stat = "weaponDamagePct:" .. weapon.id, value = 0.20 }, weight = 3, maxStacks = 3, immediate = true })
    for _, upgrade in ipairs(weapon.upgrades) do
        table.insert(defs, { id = upgrade[3] .. ":" .. weapon.id, name = weapon.name .. "·" .. upgrade[1], abilityName = weapon.name .. "·" .. upgrade[1], abilityDesc = upgrade[2] .. "，最高可叠加3层。", category = "专属", desc = upgrade[2] .. "，最高可叠加3层。", kind = "weapon", weaponId = weapon.id, icon = icon, modifier = { stat = upgrade[3] .. ":" .. weapon.id, value = upgrade[4] }, weight = 2, maxStacks = 3, immediate = true })
    end
end

local common = {
    { "all_weapon_damage", "百兵共鸣", "全武器伤害 +10%", "weaponDamagePct", 0.10, 3, "attack", "image/talent/common_hp.png" },
    { "crit_chance", "灵台一闪", "暴击率 +6%", "critChance", 0.06, 3, "attack", "image/talent/common_attack.png" },
    { "crit_damage", "破妄", "暴击伤害 +25%", "critDamagePct", 0.25, 2, "attack", "image/talent/common_crit.png" },
    { "elite_damage", "斩将", "对精锐/头目伤害 +15%", "eliteDamagePct", 0.15, 2, "attack", "image/talent/common_reduce.png" },
    { "max_hp", "气海拓宽", "最大气血 +15%", "maxHpPct", 0.15, 3, "player" },
    { "armor_defense", "玄甲", "护甲防御 +15%", "armorDefensePct", 0.15, 3, "defense" },
    { "reduction", "金刚护体", "最终减伤 +6%", "damageTakenReduction", 0.06, 2, "defense" },
    { "kill_heal", "噬灵", "击杀回血 1.5%最大气血", "killHealPct", 0.015, 2, "player" },
    { "reward_spawn", "寻宝诀", "场上奖励出现率 +15%", "fieldRewardSpawnPct", 0.15, 2, "player" },
    { "reward_quality", "天运", "场上奖励品质 +1档", "fieldRewardQualityShift", 1, 2, "player" },
}
for _, reward in ipairs(common) do
    table.insert(defs, { id = "common:" .. reward[1], name = reward[2], abilityName = reward[2], abilityDesc = reward[3], category = "通用", desc = reward[3], kind = "common", icon = reward[8], modifier = { stat = reward[4], value = reward[5] }, rewardGroup = reward[7], weight = 3, maxStacks = reward[6], immediate = true })
end

local enemy = {
    { "enemy_hp", "妖躯淬炼", "敌方生命值 +20%", "enemyHpPct", 0.20, 3 },
    { "enemy_atk", "凶煞暴涨", "敌方攻击力 +15%", "enemyAtkPct", 0.15, 3 },
    { "enemy_defense", "铁壁妖甲", "敌方防御力 +20%", "enemyDefensePct", 0.20, 3 },
}
for _, reward in ipairs(enemy) do
    table.insert(defs, {
        id = "enemy:" .. reward[1],
        name = reward[2],
        category = "敌方强化",
        desc = reward[3],
        kind = "enemy",
        rewardGroup = "enemy",
        icon = "image/talent/enemy_enhance.png",
        modifier = { stat = reward[4], value = reward[5] },
        weight = 3,
        maxStacks = reward[6],
        immediate = true,
    })
end

local armorAbilities = {
    {
        armorId = "dark_iron_shield",
        armorName = "玄铁宝盾",
        abilities = {
            { "玄铁壁垒", "格挡判定获得额外 +12% 减伤效果。", "blockChancePct", 0.12 },
            { "盾御反震", "格挡成功时，反伤倍率 +20%。", "blockReflectPct", 0.20 },
        },
    },
    {
        armorId = "thorn_armor",
        armorName = "荆棘战甲",
        abilities = {
            { "荆棘回响", "荆棘反伤与吸收转伤倍率 +20%。", "thornsReflectPct", 0.20 },
            { "血棘穿心", "荆棘反伤额外附加 +10% 伤害。", "thornsBonusPct", 0.10 },
        },
    },
    {
        armorId = "yuqing_robe",
        armorName = "玉清道衣",
        abilities = {
            { "玉清护脉", "每回合护盾值与护盾上限 +20%。", "armorShieldPct", 0.20 },
            { "流云护体", "玉清道衣护盾上限额外 +10%。", "armorShieldCapPct", 0.10 },
        },
    },
    {
        armorId = "creation_robe",
        armorName = "生生造化袍",
        abilities = {
            { "造化回春", "防御法宝每回合恢复气血效果 +20%。", "armorRegenPct", 0.20 },
            { "生生不息", "受击恢复气血效果 +25%。", "armorHitHealPct", 0.25 },
        },
    },
    {
        armorId = "purity_orb",
        armorName = "净秽宝珠",
        abilities = {
            { "净秽清光", "每回合净化数量 +1；已有全净化时不再额外增加。", "cleanseCountBonus", 1 },
            { "宝珠护神", "负面状态免疫回合 +1。", "cleanseImmunityTurns", 1 },
        },
    },
}

for _, armor in ipairs(armorAbilities) do
    for index, ability in ipairs(armor.abilities) do
        table.insert(defs, {
            id = "armorAbility:" .. armor.armorId .. ":" .. index,
            name = armor.armorName .. "·" .. ability[1],
            shortName = ability[1],
            category = "防御专属",
            desc = ability[2],
            abilityName = ability[1],
            abilityDesc = ability[2],
            kind = "armor",
            armorId = armor.armorId,
            icon = ARMOR_ICONS[armor.armorId],
            rewardGroup = "defense",
            modifier = { stat = ability[3] .. ":" .. armor.armorId, value = ability[4] },
            weight = 2,
            maxStacks = 3,
            immediate = true,
        })
    end
end

return defs
