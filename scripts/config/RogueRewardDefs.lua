-- config/RogueRewardDefs.lua
-- 本轮肉鸽奖励：15 把武器的解锁与专属强化，以及可重复选择的通用数值。

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

local defs = {}
for _, weapon in ipairs(weapons) do
    table.insert(defs, { id = "unlock:" .. weapon.id, name = "解锁·" .. weapon.name, category = "解锁", desc = "获得一把当前境界基础品质的" .. weapon.name .. "，并将其加入本轮掉落与合成池", kind = "unlock", weaponId = weapon.id, weight = 4, maxStacks = 1, immediate = true })
    table.insert(defs, { id = "weaponDamagePct:" .. weapon.id, name = weapon.name .. "·淬锋", category = "专属", desc = "本武器伤害 +20%", kind = "weapon", weaponId = weapon.id, modifier = { stat = "weaponDamagePct:" .. weapon.id, value = 0.20 }, weight = 3, maxStacks = 3, immediate = true })
    for _, upgrade in ipairs(weapon.upgrades) do
        table.insert(defs, { id = upgrade[3] .. ":" .. weapon.id, name = weapon.name .. "·" .. upgrade[1], category = "专属", desc = upgrade[2], kind = "weapon", weaponId = weapon.id, modifier = { stat = upgrade[3] .. ":" .. weapon.id, value = upgrade[4] }, weight = 2, maxStacks = 3, immediate = true })
    end
end

local common = {
    { "all_weapon_damage", "百兵共鸣", "全武器伤害 +10%", "weaponDamagePct", 0.10, 3 },
    { "crit_chance", "灵台一闪", "暴击率 +6%", "critChance", 0.06, 3 },
    { "crit_damage", "破妄", "暴击伤害 +25%", "critDamagePct", 0.25, 2 },
    { "elite_damage", "斩将", "对精锐/头目伤害 +15%", "eliteDamagePct", 0.15, 2 },
    { "max_hp", "气海拓宽", "最大气血 +15%", "maxHpPct", 0.15, 3 },
    { "armor_defense", "玄甲", "护甲防御 +15%", "armorDefensePct", 0.15, 3 },
    { "reduction", "金刚护体", "最终减伤 +6%", "damageTakenReduction", 0.06, 2 },
    { "kill_heal", "噬灵", "击杀回血 1.5%最大气血", "killHealPct", 0.015, 2 },
    { "reward_spawn", "寻宝诀", "场上奖励出现率 +15%", "fieldRewardSpawnPct", 0.15, 2 },
    { "reward_quality", "天运", "场上奖励品质 +1档", "fieldRewardQualityShift", 1, 2 },
}
for _, reward in ipairs(common) do
    table.insert(defs, { id = "common:" .. reward[1], name = reward[2], category = "通用", desc = reward[3], kind = "common", modifier = { stat = reward[4], value = reward[5] }, weight = 3, maxStacks = reward[6], immediate = true })
end

return defs
