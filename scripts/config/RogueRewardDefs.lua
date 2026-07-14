-- config/RogueRewardDefs.lua
-- 突破后肉鸽 3 选 1 奖励池，对齐设计文档 P1-7。

return {
    { id = "O1", name = "剑意通玄", category = "攻势", desc = "全武器伤害 +12%", power = "small", prereq = { type = "anyWeapon" }, scalable = true, modifier = { stat = "weaponDamagePct", value = 0.12 } },
    { id = "O2", name = "流派专精", category = "攻势", desc = "指定流派武器伤害 +18%", power = "small", dynamic = "weaponSchoolSpecialization", scalable = true, variants = {
        { school = "sword", label = "剑", desc = "剑修武器伤害 +18%" },
        { school = "spear", label = "枪", desc = "枪修武器伤害 +18%" },
        { school = "magic", label = "法", desc = "法修武器伤害 +18%" },
        { school = "chain", label = "链", desc = "链修武器伤害 +18%" },
        { school = "tower", label = "塔", desc = "塔修武器伤害 +18%" },
        { school = "guardian", label = "御", desc = "御修武器伤害 +18%" },
    } },
    { id = "O3", name = "暴伤淬炼", category = "攻势", desc = "暴击伤害 +25%", power = "medium", prereq = { type = "weaponBaseAny", baseIds = { "qingfeng_sword", "bishui_sword", "taiji_sword" } }, scalable = true, modifier = { stat = "critDamagePct", value = 0.25 } },
    { id = "O4", name = "穿透延展", category = "攻势", desc = "穿透类武器额外穿透 +1 敌", power = "medium", prereq = { type = "weaponSchool", school = "spear" }, modifier = { stat = "pierceBonus", value = 1 } },
    { id = "O5", name = "横扫扩张", category = "攻势", desc = "横扫类溅射比 +15%", power = "medium", prereq = { type = "weaponBaseAny", baseIds = { "qingyu_fan", "qingyin_qin", "double_blade_chain" } }, scalable = true, modifier = { stat = "sweepSplashPct", value = 0.15 } },
    { id = "O6", name = "范围延展", category = "攻势", desc = "范围类 AoE 半径 +1 格", power = "medium", prereq = { type = "weaponBaseAny", baseIds = { "ziqi_gourd", "jinguang_ring", "lingmo_brush", "zhenyao_tower" } }, modifier = { stat = "areaRangeBonus", value = 1 } },
    { id = "O7", name = "灼毒强化", category = "攻势", desc = "灼烧 / 中毒 DoT 每回合伤害 +30%", power = "medium", prereq = { type = "weaponBaseAny", baseIds = { "chiyan_spear", "ziqi_gourd" } }, scalable = true, modifier = { stat = "dotDamagePct", value = 0.30 } },

    { id = "D1", name = "金钟罩", category = "守势", desc = "护甲道具防御值 +15%", power = "small", prereq = { type = "anyArmor" }, scalable = true, modifier = { stat = "armorDefensePct", value = 0.15 } },
    { id = "D2", name = "不灭", category = "守势", desc = "最大气血 +25% 且受击减伤 +10%", power = "large", modifier = { stat = "maxHpPct", value = 0.25 }, extraModifiers = { { stat = "damageTakenReduction", value = 0.10 } } },
    { id = "D3", name = "回春", category = "守势", desc = "突破时额外回血 +30% 最大气血", power = "medium", scalable = true, modifier = { stat = "breakthroughHealPct", value = 0.30 } },
    { id = "D4", name = "反震强化", category = "守势", desc = "荆棘战甲反伤 +50%", power = "medium", prereq = { type = "item", category = "armor", baseId = "thorn_armor" }, scalable = true, modifier = { stat = "thornsReflectPct", value = 0.50 } },
    { id = "D5", name = "护盾增厚", category = "守势", desc = "玉清道衣护盾吸收 +40%", power = "medium", prereq = { type = "item", category = "armor", baseId = "yuqing_robe" }, scalable = true, modifier = { stat = "armorShieldPct", value = 0.40 } },

    { id = "C1", name = "定身经", category = "控场", desc = "定身持续 +1 阶段", power = "small", prereq = { type = "weaponBaseAny", baseIds = { "qingyin_qin", "fuyao_chain" } }, modifier = { stat = "rootTurnsBonus", value = 1 } },
    { id = "C2", name = "削魂术", category = "控场", desc = "减益幅度 +20%", power = "small", prereq = { type = "weaponBaseAny", baseIds = { "bishui_sword", "baigu_staff", "pozhen_spear", "jinguang_ring", "lingmo_brush", "zhenyao_tower", "huxin_pearl" } }, scalable = true, modifier = { stat = "debuffPowerPct", value = 0.20 } },
    { id = "C3", name = "久滞咒", category = "控场", desc = "减益持续 +1 回合", power = "medium", prereq = { type = "weaponBaseAny", baseIds = { "bishui_sword", "baigu_staff", "pozhen_spear", "jinguang_ring", "lingmo_brush", "zhenyao_tower", "huxin_pearl" } }, modifier = { stat = "debuffDurationBonus", value = 1 } },
    { id = "C4", name = "易伤残卷", category = "控场", desc = "易伤标记增伤 +15%", power = "medium", prereq = { type = "weaponBaseAny", baseIds = { "lingmo_brush" } }, scalable = true, modifier = { stat = "vulnerableBonusPct", value = 0.15 } },

    { id = "E1", name = "寻宝鉴", category = "资源", desc = "场上奖励品质权重 +1 档", power = "medium", modifier = { stat = "fieldRewardQualityShift", value = 1 } },
    { id = "E2", name = "天降横财", category = "资源", desc = "场上奖励出现率 +20%", power = "large", modifier = { stat = "fieldRewardSpawnPct", value = 0.20 } },

    { id = "S1", name = "丹道精进", category = "续航", desc = "丹药效果 +20%", power = "small", prereq = { type = "anyPill" }, scalable = true, modifier = { stat = "pillEffectPct", value = 0.20 } },
    { id = "S2", name = "符咒通玄", category = "控场", desc = "符咒效果 +20%", power = "small", prereq = { type = "anyTalisman" }, scalable = true, modifier = { stat = "talismanEffectPct", value = 0.20 } },
    { id = "S3", name = "百宝囊", category = "续航", desc = "每5回合必定刷出1个随机物品奖励", power = "medium", modifier = { stat = "fieldRewardSupplyInterval", value = 5 } },

    { id = "U1", name = "噬魂", category = "特异", desc = "击杀怪物回复 2% 最大气血", power = "medium", scalable = true, modifier = { stat = "killHealPct", value = 0.02 } },
    { id = "U2", name = "杀伐果断", category = "特异", desc = "对精锐 / 头目伤害 +20%", power = "medium", scalable = true, modifier = { stat = "eliteDamagePct", value = 0.20 } },
    { id = "U3", name = "镇魂", category = "特异", desc = "定身目标每次受击额外承受 15% 伤害", power = "medium", prereq = { type = "weaponBaseAny", baseIds = { "qingyin_qin", "fuyao_chain" } }, scalable = true, modifier = { stat = "rootedDamagePct", value = 0.15 } },
    { id = "U4", name = "道心通明", category = "特异", desc = "所有法宝 Q5+ 附加特效数值 +20%", power = "large", prereq = { type = "highQualityWeapon" }, modifier = { stat = "specialEffectPct", value = 0.20 } },
}
