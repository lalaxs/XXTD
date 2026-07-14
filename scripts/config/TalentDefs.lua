-- config/TalentDefs.lua
-- 局内天赋树节点配置，对齐设计文档 P3。

local Config = require("Config")

return {
    branches = {
        { id = "weapon", name = "法宝" },
        { id = "armor", name = "护甲" },
        { id = "pill", name = "丹药" },
        { id = "talisman", name = "符咒" },
    },
    edges = {
        { from = "common_attack", to = "common_crit" },
        { from = "common_crit", to = "common_reduce" },
        { from = "common_reduce", to = "common_armor" },
        { from = "common_armor", to = "common_hp" },
        { from = "common_hp", to = "common_regen" },

        { from = "common_attack", to = "weapon_chiyan" },
        { from = "weapon_chiyan", to = "weapon_pozhen" },
        { from = "weapon_chiyan", to = "weapon_spear_a" },
        { from = "weapon_pozhen", to = "weapon_spear_b" },

        { from = "common_crit", to = "weapon_bishui" },
        { from = "weapon_bishui", to = "weapon_taiji" },
        { from = "common_crit", to = "weapon_sword_a" },
        { from = "weapon_taiji", to = "weapon_sword_b" },

        { from = "common_reduce", to = "weapon_fuyao" },
        { from = "weapon_fuyao", to = "weapon_double_blade" },
        { from = "weapon_fuyao", to = "weapon_chain_a" },
        { from = "weapon_double_blade", to = "weapon_chain_b" },

        { from = "common_armor", to = "weapon_zhenyao" },
        { from = "weapon_zhenyao", to = "weapon_tower_a" },
        { from = "weapon_zhenyao", to = "weapon_tower_b" },

        { from = "common_hp", to = "weapon_huxin" },
        { from = "weapon_huxin", to = "weapon_guardian_a" },
        { from = "weapon_huxin", to = "weapon_guardian_b" },

        { from = "common_regen", to = "weapon_qingyu" },
        { from = "weapon_qingyu", to = "weapon_qingyin" },
        { from = "weapon_qingyin", to = "weapon_lingmo" },
        { from = "weapon_lingmo", to = "weapon_baigu" },
        { from = "weapon_baigu", to = "weapon_ziqi" },
        { from = "weapon_ziqi", to = "weapon_jinguang" },
        { from = "weapon_ziqi", to = "weapon_magic_a" },
        { from = "weapon_jinguang", to = "weapon_magic_b" },

        { from = "armor_dark_iron", to = "armor_thorn" },
        { from = "armor_dark_iron", to = "armor_yuqing" },
        { from = "armor_dark_iron", to = "armor_creation" },
        { from = "armor_dark_iron", to = "armor_purity" },

        { from = "pill_juqi", to = "pill_hutai" },
        { from = "pill_juqi", to = "pill_qingxin" },
        { from = "pill_juqi", to = "pill_zengyuan" },
        { from = "pill_juqi", to = "pill_xuming" },

        { from = "talisman_thunder", to = "talisman_root" },
        { from = "talisman_thunder", to = "talisman_armor_break" },
        { from = "talisman_thunder", to = "talisman_attack_down" },
        { from = "talisman_thunder", to = "talisman_vulnerable" },
    },
    nodes = {
        { id = "common_attack", branch = "weapon", name = "煞气·攻击", desc = "全武器伤害 +8%。开启枪修支线。", cost = 1, modifier = { stat = "talentWeaponDamagePct", value = 0.08 }, x = 340, y = 40 },
        { id = "common_crit", branch = "weapon", name = "锐气·暴击", desc = "全武器暴击率 +8%。开启剑修支线。", cost = 1, requires = { "common_attack" }, modifier = { stat = "weaponCritChance", value = 0.08 }, x = 340, y = 220 },
        { id = "common_reduce", branch = "weapon", name = "罡气·减伤", desc = "受击伤害 -8%。开启链修支线。", cost = 1, requires = { "common_crit" }, modifier = { stat = "damageTakenReduction", value = 0.08 }, x = 340, y = 400 },
        { id = "common_armor", branch = "weapon", name = "铁骨·护甲", desc = "护甲道具防御值 +15%。开启塔修支线。", cost = 1, requires = { "common_reduce" }, modifier = { stat = "armorDefensePct", value = 0.15 }, x = 340, y = 580 },
        { id = "common_hp", branch = "weapon", name = "根骨·气血", desc = "最大气血 +15%。开启御修支线。", cost = 1, requires = { "common_armor" }, modifier = { stat = "maxHpPct", value = 0.15 }, x = 340, y = 760 },
        { id = "common_regen", branch = "weapon", name = "回春·再生", desc = "每回合恢复最大气血 1.5%。开启法修支线。", cost = 1, requires = { "common_hp" }, modifier = { stat = "turnRegenPct", value = 0.015 }, x = 340, y = 940 },

        { id = "weapon_chiyan", branch = "weapon", name = "赤焰枪", desc = "解锁赤焰枪：穿透同列敌人并从极品起附加灼烧，仙品觉醒「燎原」可让灼烧跳至相邻列，圣品可跳列全场并提升灼烧伤害。", cost = 1, requires = { "common_attack" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "chiyan_spear" }, x = 525, y = 40 },
        { id = "weapon_pozhen", branch = "weapon", name = "破阵枪", desc = "解锁破阵枪：穿透同列敌人并从极品起无视目标防御，仙品觉醒「破阵无双」可穿透整列并使目标受击更重，圣品完全无视防御。", cost = 1, requires = { "weapon_chiyan" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "pozhen_spear" }, x = 650, y = 40 },
        { id = "weapon_spear_a", branch = "weapon", name = "炎枪燎原", desc = "赤焰枪灼烧持续 +2 回合；DoT 每回合 +10%。", cost = 1, requires = { "weapon_chiyan" }, exclusiveGroup = "spear_variant", variant = { school = "spear", value = "flame" }, x = 525, y = 180 },
        { id = "weapon_spear_b", branch = "weapon", name = "破阵贯虹", desc = "破阵枪穿透 +1 敌；无视防御 +20%。", cost = 1, requires = { "weapon_pozhen" }, exclusiveGroup = "spear_variant", variant = { school = "spear", value = "break" }, x = 650, y = 180 },

        { id = "weapon_bishui", branch = "weapon", name = "碧水剑", desc = "解锁碧水剑：单体攻击并从极品起降低目标攻击，仙品觉醒「碧水寒潮」延长减攻并对减攻目标增伤，圣品进一步提高减攻与增伤。", cost = 1, requires = { "common_crit" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "bishui_sword" }, x = 155, y = 220 },
        { id = "weapon_taiji", branch = "weapon", name = "太极剑", desc = "解锁太极剑：单体攻击并从极品起击退目标，仙品觉醒「太极两仪」可击退2格并落地定身，圣品提高定身与对击退目标伤害。", cost = 1, requires = { "weapon_bishui" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "taiji_sword" }, x = 30, y = 220 },
        { id = "weapon_sword_a", branch = "weapon", name = "剑意锋芒", desc = "剑修武器暴击率 +10%；青锋剑暴击倍率 ×2.0→×2.3。", cost = 1, requires = { "common_crit" }, exclusiveGroup = "sword_variant", variant = { school = "sword", value = "sharp" }, modifier = { stat = "weaponCritChance", value = 0.10 }, x = 155, y = 360 },
        { id = "weapon_sword_b", branch = "weapon", name = "太极柔劲", desc = "碧水剑减攻持续 +1 回合；太极剑击退 +1 格。", cost = 1, requires = { "weapon_taiji" }, exclusiveGroup = "sword_variant", variant = { school = "sword", value = "soft" }, x = 30, y = 360 },

        { id = "weapon_fuyao", branch = "weapon", name = "缚妖链", desc = "解锁缚妖链：单体控制并从极品起定身目标，仙品觉醒「万链缚神」提升定身并追加锁魂伤害，圣品进一步延长定身和锁魂伤害。", cost = 1, requires = { "common_reduce" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "fuyao_chain" }, x = 525, y = 400 },
        { id = "weapon_double_blade", branch = "weapon", name = "双刃锁链", desc = "解锁双刃锁链：横扫攻击并从极品起拉拽最近敌人，仙品觉醒「绞链轮回」可拉拽2格并附加绞杀，圣品大幅提升绞杀伤害。", cost = 1, requires = { "weapon_fuyao" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "double_blade_chain" }, x = 650, y = 400 },
        { id = "weapon_chain_a", branch = "weapon", name = "缚妖锁魂", desc = "缚妖链定身 +2 阶段。", cost = 1, requires = { "weapon_fuyao" }, exclusiveGroup = "chain_variant", variant = { school = "chain", value = "lock" }, x = 525, y = 540 },
        { id = "weapon_chain_b", branch = "weapon", name = "双链回旋", desc = "双刃锁链拉拽 +1 格；横扫溅射 +10%。", cost = 1, requires = { "weapon_double_blade" }, exclusiveGroup = "chain_variant", variant = { school = "chain", value = "chain" }, x = 650, y = 540 },

        { id = "weapon_zhenyao", branch = "weapon", name = "镇妖塔", desc = "解锁镇妖塔：范围伤害并从极品起降低范围内敌人攻击，仙品觉醒「塔镇八荒」使压制范围全场并追加塔威伤害，圣品强化减攻与塔威。", cost = 1, requires = { "common_armor" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "zhenyao_tower" }, x = 155, y = 580 },
        { id = "weapon_tower_a", branch = "weapon", name = "镇塔伏魔", desc = "镇妖塔伤害 +20%。", cost = 1, requires = { "weapon_zhenyao" }, exclusiveGroup = "tower_variant", variant = { school = "tower", value = "suppress" }, x = 30, y = 720 },
        { id = "weapon_tower_b", branch = "weapon", name = "镇魂玄光", desc = "镇妖塔减攻幅度 +25%。", cost = 1, requires = { "weapon_zhenyao" }, exclusiveGroup = "tower_variant", variant = { school = "tower", value = "soul" }, x = 155, y = 720 },

        { id = "weapon_huxin", branch = "weapon", name = "护心珠", desc = "解锁护心珠：造成守护范围持续伤害并从极品起降低敌人攻击，仙品觉醒「护世莲心」扩至全场并附加减暴与莲华伤害，圣品强化减攻减暴和莲华伤害。", cost = 1, requires = { "common_hp" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "huxin_pearl" }, x = 525, y = 760 },
        { id = "weapon_guardian_a", branch = "weapon", name = "护心灵照", desc = "护心珠持续伤害 +20%。", cost = 1, requires = { "weapon_huxin" }, exclusiveGroup = "guardian_variant", variant = { school = "guardian", value = "light" }, x = 525, y = 900 },
        { id = "weapon_guardian_b", branch = "weapon", name = "护体玄珠", desc = "护心珠减攻 -25%→-35%，额外减暴击 -15%。", cost = 1, requires = { "weapon_huxin" }, exclusiveGroup = "guardian_variant", variant = { school = "guardian", value = "protect" }, x = 650, y = 900 },

        { id = "weapon_qingyu", branch = "weapon", name = "青羽扇", desc = "解锁青羽扇：横扫主目标并溅射相邻列，从极品起施加风刃印记，仙品觉醒「八荒风刃」使溅射全额并提高受击，圣品进一步增强印记。", cost = 1, requires = { "common_regen" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "qingyu_fan" }, x = 155, y = 940 },
        { id = "weapon_qingyin", branch = "weapon", name = "清音琴", desc = "解锁清音琴：横扫攻击并从极品起定身命中目标，仙品觉醒「镇魂魔音」提升定身并使定身者受击震荡，圣品进一步提高定身和震荡伤害。", cost = 1, requires = { "weapon_qingyu" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "qingyin_qin" }, x = 30, y = 1080 },
        { id = "weapon_lingmo", branch = "weapon", name = "灵墨笔", desc = "解锁灵墨笔：范围攻击并从极品起施加易伤标记，仙品觉醒「墨染乾坤」使全场敌人易伤并追加墨蚀伤害，圣品进一步提高易伤与墨蚀。", cost = 1, requires = { "weapon_qingyin" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "lingmo_brush" }, x = 155, y = 1220 },
        { id = "weapon_baigu", branch = "weapon", name = "白骨杖", desc = "解锁白骨杖：远程单体攻击并从极品起降低目标防御，仙品觉醒「白骨噬魂」强化减防并对低血目标施加魂噬，圣品大幅提高减防与魂噬。", cost = 1, requires = { "weapon_lingmo" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "baigu_staff" }, x = 30, y = 1360 },
        { id = "weapon_ziqi", branch = "weapon", name = "紫气葫芦", desc = "解锁紫气葫芦：范围攻击并从极品起附加中毒，仙品觉醒「万毒归宗」使中毒翻倍并在死亡时引爆毒爆，圣品提升中毒和毒爆伤害。", cost = 1, requires = { "weapon_baigu" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "ziqi_gourd" }, x = 155, y = 1500 },
        { id = "weapon_jinguang", branch = "weapon", name = "金光环", desc = "解锁金光环：范围攻击并从极品起降低范围内敌人攻击，仙品觉醒「金光大阵」使减攻光环全场并附加减暴，圣品强化减攻、减暴和持续时间。", cost = 1, requires = { "weapon_ziqi" }, unlock = { type = "item", category = Config.ITEM_CATEGORY.WEAPON, baseId = "jinguang_ring" }, x = 30, y = 1640 },
        { id = "weapon_magic_a", branch = "weapon", name = "毒骨蚀灵", desc = "白骨杖减防 +15% 幅度；紫气葫芦毒 +1 回合。", cost = 1, requires = { "weapon_ziqi" }, exclusiveGroup = "magic_variant", variant = { school = "magic", value = "offense" }, x = 155, y = 1780 },
        { id = "weapon_magic_b", branch = "weapon", name = "清音摄魂", desc = "清音琴定身 +1 阶段；灵墨笔易伤 +10%；金光环/镇妖塔减攻 +15%。", cost = 1, requires = { "weapon_jinguang" }, exclusiveGroup = "magic_variant", variant = { school = "magic", value = "control" }, x = 30, y = 1780 },

        { id = "armor_dark_iron", branch = "armor", name = "玄铁宝盾", desc = "默认解锁玄铁宝盾：进入护甲池，占格提供防御；极品起概率格挡免伤，仙品起格挡时反伤。", cost = 0, default = true, x = 340, y = 40 },
        { id = "armor_thorn", branch = "armor", name = "荆棘战甲", desc = "解锁荆棘战甲：进入护甲池，占格提供防御；极品起反伤攻击者，仙品起将护甲吸收量转为额外反伤。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.ARMOR, baseId = "thorn_armor" }, x = 130, y = 220 },
        { id = "armor_yuqing", branch = "armor", name = "玉清道衣", desc = "解锁玉清道衣：进入护甲池，占格提供防御；极品起每回合生成护盾，仙品起提高护盾上限。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.ARMOR, baseId = "yuqing_robe" }, x = 270, y = 220 },
        { id = "armor_creation", branch = "armor", name = "生生造化袍", desc = "解锁生生造化袍：进入护甲池，占格提供防御；极品起每回合恢复气血，仙品起受击时额外回血。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.ARMOR, baseId = "creation_robe" }, x = 410, y = 220 },
        { id = "armor_purity", branch = "armor", name = "净秽宝珠", desc = "解锁净秽宝珠：进入护甲池，占格提供防御；极品起受击净化负面状态，珍品起获得负面免疫，仙品起回合净化并提高免疫。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.ARMOR, baseId = "purity_orb" }, x = 550, y = 220 },

        { id = "pill_juqi", branch = "pill", name = "聚气丹", desc = "默认解锁聚气丹：进入丹药池，主动恢复气血；极品起附加减伤，仙品起额外清除负面状态。", cost = 0, default = true, x = 340, y = 40 },
        { id = "pill_hutai", branch = "pill", name = "护体丹", desc = "解锁护体丹：进入丹药池，主动获得持续护盾，品质越高护盾值与持续回合越高。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.PILL, baseId = "hutai" }, x = 130, y = 220 },
        { id = "pill_qingxin", branch = "pill", name = "清心丹", desc = "解锁清心丹：进入丹药池，主动清除负面状态；上品起清除数量增加，仙品起附加负面免疫。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.PILL, baseId = "qingxin" }, x = 270, y = 220 },
        { id = "pill_zengyuan", branch = "pill", name = "增元丹", desc = "解锁增元丹：进入丹药池，主动提升法宝伤害，品质越高增伤幅度与持续回合越高。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.PILL, baseId = "zengyuan" }, x = 410, y = 220 },
        { id = "pill_xuming", branch = "pill", name = "续命丹", desc = "解锁续命丹：进入丹药池，主动获得免死护佑，气血归零时触发并保留一定气血。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.PILL, baseId = "xuming" }, x = 550, y = 220 },

        { id = "talisman_thunder", branch = "talisman", name = "雷符", desc = "默认解锁雷符：进入符咒池，主动随机对多个目标造成雷击伤害，品质越高目标越多。", cost = 0, default = true, x = 340, y = 40 },
        { id = "talisman_root", branch = "talisman", name = "定身符", desc = "解锁定身符：进入符咒池，主动随机定身多个目标，品质越高目标数量与定身回合越高。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.TALISMAN, baseId = "root" }, x = 130, y = 220 },
        { id = "talisman_armor_break", branch = "talisman", name = "破甲符", desc = "解锁破甲符：进入符咒池，主动随机降低多个目标防御，品质越高破甲幅度、目标数量与持续回合越高。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.TALISMAN, baseId = "armor_break" }, x = 270, y = 220 },
        { id = "talisman_attack_down", branch = "talisman", name = "削攻符", desc = "解锁削攻符：进入符咒池，主动随机降低多个目标攻击，品质越高削攻幅度、目标数量与持续回合越高。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.TALISMAN, baseId = "attack_down" }, x = 410, y = 220 },
        { id = "talisman_vulnerable", branch = "talisman", name = "易伤符", desc = "解锁易伤符：进入符咒池，主动随机使多个目标易伤，品质越高易伤幅度、目标数量与持续回合越高。", cost = 1, unlock = { type = "item", category = Config.ITEM_CATEGORY.TALISMAN, baseId = "vulnerable" }, x = 550, y = 220 },
    },
}
