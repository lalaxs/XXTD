-- Config.lua
-- 仙侠合成塔防 - 全局数值配置（全面重平衡版）
-- 严格1:1复刻，禁止四舍五入、禁止私自浮动修改

local Config = {}

-- ============================================================================
-- 战场布局
-- ============================================================================
Config.GRID_COLS = 5
Config.FIELD_ROWS = 7
Config.DEPLOY_ROWS = 2
Config.TOTAL_ROWS = Config.FIELD_ROWS + Config.DEPLOY_ROWS
Config.TOTAL_SLOTS = Config.GRID_COLS * Config.DEPLOY_ROWS

-- ============================================================================
-- 品质阶梯（9阶）
-- 硬性分界：1-4阶无技能无词条；5-9阶怪物有技能、道具有词条
-- ============================================================================
Config.QUALITY = {
    { id = 1, name = "凡品",   color = {200, 200, 200, 255} },   -- 白
    { id = 2, name = "良品",   color = {100, 210, 120, 255} },   -- 绿
    { id = 3, name = "上品",   color = {80, 160, 255, 255} },    -- 蓝
    { id = 4, name = "精品",   color = {180, 100, 255, 255} },   -- 紫
    { id = 5, name = "极品",   color = {255, 160, 50, 255} },    -- 橙
    { id = 6, name = "珍品",   color = {230, 70, 60, 255} },     -- 红
    { id = 7, name = "仙品",   color = {255, 160, 200, 255} },   -- 粉
    { id = 8, name = "神品",   color = {255, 200, 50, 255} },    -- 金
    { id = 9, name = "圣品",   color = {180, 140, 40, 255} },    -- 暗金
}
Config.MAX_QUALITY = #Config.QUALITY

-- 阶梯分界线：5阶起解锁技能和词条
Config.SKILL_UNLOCK_TIER = 5

-- ============================================================================
-- 道具类型
-- ============================================================================
Config.ITEM_TYPE = {
    ATTACK = 1,    -- 宝剑（单体高伤输出）
    DEFENSE = 2,   -- 护甲（护盾减伤）
    PILL = 3,      -- 丹药（回血全队增益）
    TALISMAN = 4,  -- 符箓（范围AOE+控制）
}

-- ============================================================================
-- 一、全局怪物固定数值表（无移速，固定逐格行走）
-- 近战怪：超高血量、近身攻击、承伤干扰，前排肉盾
-- 远程怪：偏低血量、远程隔格攻击、持续debuff，后排消耗
-- ============================================================================
Config.MONSTER_TYPE = {
    MELEE = 1,
    RANGED = 2,
}

Config.WAVE_INTERVAL = 5  -- 每5回合刷新一波怪物（给玩家更多击杀/合成时间）

-- 近战怪模板（9阶）
Config.MELEE_TEMPLATES = {
    -- 1阶凡品：战力100｜概率40.00%｜血量220｜攻击22｜无技能
    {
        name = "小妖", quality = 1, power = 100,
        spawnChance = 0.4000,
        hp = 220, atk = 22, exp = 15, dropChance = 0.10,
        skill = nil,
    },
    -- 2阶良品：战力190｜概率15.00%｜血量410｜攻击40｜无技能
    {
        name = "妖兵", quality = 2, power = 190,
        spawnChance = 0.1500,
        hp = 410, atk = 40, exp = 35, dropChance = 0.10,
        skill = nil,
    },
    -- 3阶上品：战力360｜概率6.00%｜血量760｜攻击75｜无技能
    {
        name = "妖将", quality = 3, power = 360,
        spawnChance = 0.0600,
        hp = 760, atk = 75, exp = 80, dropChance = 0.10,
        skill = nil,
    },
    -- 4阶精品：战力680｜概率2.50%｜血量1420｜攻击140｜无技能
    {
        name = "妖王", quality = 4, power = 680,
        spawnChance = 0.0250,
        hp = 1420, atk = 140, exp = 180, dropChance = 0.10,
        skill = nil,
    },
    -- 5阶极品：战力1120｜概率1.00%｜血量2650｜攻击225｜技能：铁甲护体
    {
        name = "铁甲魔将", quality = 5, power = 1120,
        spawnChance = 0.0100,
        hp = 2650, atk = 225, exp = 420, dropChance = 0.10,
        skill = {
            id = "iron_armor",
            name = "铁甲护体",
            desc = "自身受到所有伤害降低22%",
            damageReduction = 0.22,
        },
    },
    -- 6阶珍品：战力2050｜概率0.40%｜血量5000｜攻击410｜技能：重压踏行
    {
        name = "重甲魔帅", quality = 6, power = 2050,
        spawnChance = 0.0040,
        hp = 5000, atk = 410, exp = 950, dropChance = 0.10,
        skill = {
            id = "heavy_step",
            name = "重压踏行",
            desc = "每向下行走2格，自身获得一层护盾（护盾值=自身5%最大血量）",
            triggerEveryRows = 2,
            shieldPercent = 0.05,
        },
    },
    -- 7阶仙品：战力3780｜概率0.15%｜血量9500｜攻击740｜技能：战吼嘲讽
    {
        name = "魔尊", quality = 7, power = 3780,
        spawnChance = 0.0015,
        hp = 9500, atk = 740, exp = 2200, dropChance = 0.10,
        skill = {
            id = "war_cry",
            name = "战吼嘲讽",
            desc = "进入我方防守核心区域后，嘲讽周围2格内道具强制攻击自身，持续2秒",
            tauntRange = 2,
            tauntDuration = 2.0,
            triggerRow = 6,  -- 进入倒数第2行触发（FIELD_ROWS-1=6）
        },
    },
    -- 8阶神品：战力7000｜概率0.06%｜血量18000｜攻击1450｜技能：震荡领域
    {
        name = "天魔王", quality = 8, power = 7000,
        spawnChance = 0.0006,
        hp = 18000, atk = 1450, exp = 5200, dropChance = 0.10,
        skill = {
            id = "shock_field",
            name = "震荡领域",
            desc = "自身所在格子每3秒触发震荡，范围内我方道具攻速降低18%，持续1.5秒",
            cooldown = 3.0,
            atkSpeedReduction = 0.18,
            effectDuration = 1.5,
        },
    },
    -- 9阶圣品：战力12950｜概率0.02%｜血量34500｜攻击2650｜技能：圣躯复苏
    {
        name = "圣魔帝", quality = 9, power = 12950,
        spawnChance = 0.0002,
        hp = 34500, atk = 2650, exp = 12000, dropChance = 0.10,
        skill = {
            id = "holy_revival",
            name = "圣躯复苏",
            desc = "血量首次低于35%时，立刻回复35%最大血量，单局仅可触发1次",
            hpThreshold = 0.35,
            healPercent = 0.35,
            maxTriggers = 1,
        },
    },
}

-- 远程怪模板（9阶）
Config.RANGED_TEMPLATES = {
    -- 1阶凡品：战力95｜概率35.00%｜血量130｜攻击16｜无技能
    {
        name = "邪修", quality = 1, power = 95,
        spawnChance = 0.3500,
        hp = 130, atk = 16, exp = 15, dropChance = 0.10,
        attackRange = 3,
        skill = nil,
    },
    -- 2阶良品：战力180｜概率12.00%｜血量240｜攻击30｜无技能
    {
        name = "妖道", quality = 2, power = 180,
        spawnChance = 0.1200,
        hp = 240, atk = 30, exp = 35, dropChance = 0.10,
        attackRange = 4,
        skill = nil,
    },
    -- 3阶上品：战力340｜概率5.00%｜血量450｜攻击58｜无技能
    {
        name = "魔修", quality = 3, power = 340,
        spawnChance = 0.0500,
        hp = 450, atk = 58, exp = 80, dropChance = 0.10,
        attackRange = 4,
        skill = nil,
    },
    -- 4阶精品：战力640｜概率2.00%｜血量820｜攻击105｜无技能
    {
        name = "邪仙", quality = 4, power = 640,
        spawnChance = 0.0200,
        hp = 820, atk = 105, exp = 180, dropChance = 0.10,
        attackRange = 5,
        skill = nil,
    },
    -- 5阶极品：战力1050｜概率0.80%｜血量1500｜攻击170｜技能：破甲射击
    {
        name = "破甲邪修", quality = 5, power = 1050,
        spawnChance = 0.0080,
        hp = 1500, atk = 170, exp = 420, dropChance = 0.10,
        attackRange = 5,
        skill = {
            id = "armor_pierce",
            name = "破甲射击",
            desc = "每次攻击无视敌方18%防御",
            defenseIgnore = 0.18,
        },
    },
    -- 6阶珍品：战力1920｜概率0.30%｜血量2850｜攻击310｜技能：箭矢分裂
    {
        name = "分裂妖道", quality = 6, power = 1920,
        spawnChance = 0.0030,
        hp = 2850, atk = 310, exp = 950, dropChance = 0.10,
        attackRange = 5,
        skill = {
            id = "arrow_split",
            name = "箭矢分裂",
            desc = "攻击命中目标后，溅射左右相邻1格怪物50%伤害",
            splashRange = 1,
            splashDamagePercent = 0.50,
        },
    },
    -- 7阶仙品：战力3550｜概率0.12%｜血量5400｜攻击560｜技能：腐毒侵蚀
    {
        name = "毒仙", quality = 7, power = 3550,
        spawnChance = 0.0012,
        hp = 5400, atk = 560, exp = 2200, dropChance = 0.10,
        attackRange = 6,
        skill = {
            id = "poison_erode",
            name = "腐毒侵蚀",
            desc = "攻击附加持续毒伤，怪物每行走1格额外叠加一层毒素，每层每秒掉4%最大血量",
            poisonPerStack = 0.04,
            stackPerRow = 1,
        },
    },
    -- 8阶神品：战力6580｜概率0.05%｜血量10200｜攻击1080｜技能：虚空隐匿
    {
        name = "虚空魔修", quality = 8, power = 6580,
        spawnChance = 0.0005,
        hp = 10200, atk = 1080, exp = 5200, dropChance = 0.10,
        attackRange = 6,
        skill = {
            id = "void_stealth",
            name = "虚空隐匿",
            desc = "每行走3格，触发1.5秒隐身，隐身期间无法被选中攻击",
            triggerEveryRows = 3,
            stealthDuration = 1.5,
        },
    },
    -- 9阶圣品：战力12150｜概率0.015%｜血量19200｜攻击2000｜技能：灾厄脉冲
    {
        name = "灾厄邪仙", quality = 9, power = 12150,
        spawnChance = 0.00015,
        hp = 19200, atk = 2000, exp = 12000, dropChance = 0.10,
        attackRange = 7,
        skill = {
            id = "disaster_pulse",
            name = "灾厄脉冲",
            desc = "每向下行走4格，释放一次全屏脉冲，全场我方道具暂停攻击1秒",
            triggerEveryRows = 4,
            silenceDuration = 1.0,
        },
    },
}

-- ============================================================================
-- 二、我方4类道具数值表（宝剑/符箓/护甲/丹药，9阶）
-- 1-4阶无词条；5阶2选1；6-7阶3选1；8-9阶3选1双词条
-- ============================================================================

-- 宝剑（单体高伤输出）
Config.ATTACK_ITEMS = {
    -- 1阶：战力100｜概率30.00%｜普攻40，攻速1.0s/次
    { name = "飞剑", quality = 1, power = 100, spawnChance = 0.3000,
      atk = 40, atkSpeed = 1.0, crit = 0, defIgnore = 0 },
    -- 2阶：战力190｜概率12.00%｜普攻76，攻速0.9s/次
    { name = "灵剑", quality = 2, power = 190, spawnChance = 0.1200,
      atk = 76, atkSpeed = 0.9, crit = 0, defIgnore = 0 },
    -- 3阶：战力360｜概率5.00%｜普攻144，攻速0.8s/次
    { name = "仙剑", quality = 3, power = 360, spawnChance = 0.0500,
      atk = 144, atkSpeed = 0.8, crit = 0, defIgnore = 0 },
    -- 4阶：战力680｜概率2.00%｜普攻270，攻速0.7s/次
    { name = "神剑", quality = 4, power = 680, spawnChance = 0.0200,
      atk = 270, atkSpeed = 0.7, crit = 0, defIgnore = 0 },
    -- 5阶：战力1135｜概率0.45%｜普攻510，攻速0.6s/次，无视20%防御
    { name = "天剑", quality = 5, power = 1135, spawnChance = 0.0045,
      atk = 510, atkSpeed = 0.6, crit = 0, defIgnore = 0.20 },
    -- 6阶：战力2080｜概率0.15%｜普攻970，攻速0.5s/次，无视30%防御
    { name = "圣剑", quality = 6, power = 2080, spawnChance = 0.0015,
      atk = 970, atkSpeed = 0.5, crit = 0, defIgnore = 0.30 },
    -- 7阶：战力3815｜概率0.04%｜普攻1840，攻速0.4s/次，无视40%防御
    { name = "太古剑", quality = 7, power = 3815, spawnChance = 0.0004,
      atk = 1840, atkSpeed = 0.4, crit = 0, defIgnore = 0.40 },
    -- 8阶：战力7065｜概率0.012%｜普攻3500，攻速0.3s/次，无视50%防御
    { name = "混沌剑", quality = 8, power = 7065, spawnChance = 0.00012,
      atk = 3500, atkSpeed = 0.3, crit = 0, defIgnore = 0.50 },
    -- 9阶：战力13090｜概率0.0025%｜普攻6640，攻速0.2s/次，无视60%防御
    { name = "鸿蒙剑", quality = 9, power = 13090, spawnChance = 0.000025,
      atk = 6640, atkSpeed = 0.2, crit = 0, defIgnore = 0.60 },
}

-- 符箓（范围AOE+控制）
Config.TALISMAN_ITEMS = {
    -- 1阶：战力95｜概率35.00%｜3格范围伤害30，无控制
    { name = "镇灵符", quality = 1, power = 95, spawnChance = 0.3500,
      aoeDmg = 30, aoeRange = 3, controlType = "none", controlDuration = 0 },
    -- 2阶：战力180｜概率12.00%｜3格范围伤害57，无控制
    { name = "青木符", quality = 2, power = 180, spawnChance = 0.1200,
      aoeDmg = 57, aoeRange = 3, controlType = "none", controlDuration = 0 },
    -- 3阶：战力340｜概率5.00%｜3格范围伤害108，无控制
    { name = "星辰符", quality = 3, power = 340, spawnChance = 0.0500,
      aoeDmg = 108, aoeRange = 3, controlType = "none", controlDuration = 0 },
    -- 4阶：战力640｜概率2.00%｜3格范围伤害205，无控制
    { name = "紫霄符", quality = 4, power = 640, spawnChance = 0.0200,
      aoeDmg = 205, aoeRange = 3, controlType = "none", controlDuration = 0 },
    -- 5阶：战力1065｜概率0.45%｜4格范围伤害385，附带1秒怪物减速
    { name = "烈焰符", quality = 5, power = 1065, spawnChance = 0.0045,
      aoeDmg = 385, aoeRange = 4, controlType = "slow", controlDuration = 1.0 },
    -- 6阶：战力1955｜概率0.15%｜4格范围伤害730，附带1.5秒怪物眩晕
    { name = "鎏金符", quality = 6, power = 1955, spawnChance = 0.0015,
      aoeDmg = 730, aoeRange = 4, controlType = "stun", controlDuration = 1.5 },
    -- 7阶：战力3590｜概率0.04%｜5格范围伤害1380，附带2秒眩晕+持续减速
    { name = "太古符", quality = 7, power = 3590, spawnChance = 0.0004,
      aoeDmg = 1380, aoeRange = 5, controlType = "stun_slow", controlDuration = 2.0 },
    -- 8阶：战力6640｜概率0.012%｜5格范围伤害2600，附带2.5秒眩晕+大范围减速
    { name = "紫金符", quality = 8, power = 6640, spawnChance = 0.00012,
      aoeDmg = 2600, aoeRange = 5, controlType = "stun_slow", controlDuration = 2.5 },
    -- 9阶：战力12285｜概率0.0025%｜全屏所有怪物伤害4950，附带3秒全屏眩晕+全局减速
    { name = "鸿蒙符", quality = 9, power = 12285, spawnChance = 0.000025,
      aoeDmg = 4950, aoeRange = 99, controlType = "stun_slow", controlDuration = 3.0 },
}

-- 护甲（护盾减伤）
Config.DEFENSE_ITEMS = {
    -- 1阶：战力85｜概率32.00%｜自身格子护盾20，固定10%常驻减伤
    { name = "铁甲", quality = 1, power = 85, spawnChance = 0.3200,
      shield = 20, damageReduction = 0.10, shareReduction = 0, globalReduction = 0 },
    -- 2阶：战力160｜概率13.00%｜自身格子护盾38，固定15%常驻减伤
    { name = "玄铁甲", quality = 2, power = 160, spawnChance = 0.1300,
      shield = 38, damageReduction = 0.15, shareReduction = 0, globalReduction = 0 },
    -- 3阶：战力300｜概率5.50%｜自身格子护盾72，固定20%常驻减伤
    { name = "星辰甲", quality = 3, power = 300, spawnChance = 0.0550,
      shield = 72, damageReduction = 0.20, shareReduction = 0, globalReduction = 0 },
    -- 4阶：战力560｜概率2.20%｜自身格子护盾135，固定25%常驻减伤
    { name = "紫霄甲", quality = 4, power = 560, spawnChance = 0.0220,
      shield = 135, damageReduction = 0.25, shareReduction = 0, globalReduction = 0 },
    -- 5阶：战力925｜概率0.50%｜自身护盾255，自身30%减伤，相邻格子共享10%减伤
    { name = "天罡甲", quality = 5, power = 925, spawnChance = 0.0050,
      shield = 255, damageReduction = 0.30, shareReduction = 0.10, globalReduction = 0 },
    -- 6阶：战力1700｜概率0.18%｜自身护盾485，自身35%减伤，相邻格子共享15%减伤
    { name = "圣光甲", quality = 6, power = 1700, spawnChance = 0.0018,
      shield = 485, damageReduction = 0.35, shareReduction = 0.15, globalReduction = 0 },
    -- 7阶：战力3115｜概率0.05%｜自身护盾920，自身40%减伤，相邻格子20%减伤，全图小额减伤光环
    { name = "太古甲", quality = 7, power = 3115, spawnChance = 0.0005,
      shield = 920, damageReduction = 0.40, shareReduction = 0.20, globalReduction = 0.05 },
    -- 8阶：战力5760｜概率0.015%｜自身护盾1750，自身45%减伤，相邻格子25%减伤，全图高额减伤光环
    { name = "紫金甲", quality = 8, power = 5760, spawnChance = 0.00015,
      shield = 1750, damageReduction = 0.45, shareReduction = 0.25, globalReduction = 0.10 },
    -- 9阶：战力10640｜概率0.003%｜自身护盾3320，自身50%减伤，相邻格子30%减伤，全屏高额减伤光环
    { name = "鸿蒙甲", quality = 9, power = 10640, spawnChance = 0.00003,
      shield = 3320, damageReduction = 0.50, shareReduction = 0.30, globalReduction = 0.15 },
}

-- 丹药（回血全队增益）
Config.PILL_ITEMS = {
    -- 1阶：战力90｜概率40.00%｜每秒回血20，持续5秒
    { name = "回灵丹", quality = 1, power = 90, spawnChance = 0.4000,
      healPerSec = 20, duration = 5, teamAtkBonus = 0, teamAtkSpeedBonus = 0, globalHealAura = false },
    -- 2阶：战力170｜概率15.00%｜每秒回血38，持续5秒
    { name = "聚气丹", quality = 2, power = 170, spawnChance = 0.1500,
      healPerSec = 38, duration = 5, teamAtkBonus = 0, teamAtkSpeedBonus = 0, globalHealAura = false },
    -- 3阶：战力320｜概率6.00%｜每秒回血72，持续5秒
    { name = "护体丹", quality = 3, power = 320, spawnChance = 0.0600,
      healPerSec = 72, duration = 5, teamAtkBonus = 0, teamAtkSpeedBonus = 0, globalHealAura = false },
    -- 4阶：战力600｜概率2.50%｜每秒回血135，持续5秒
    { name = "破魔丹", quality = 4, power = 600, spawnChance = 0.0250,
      healPerSec = 135, duration = 5, teamAtkBonus = 0, teamAtkSpeedBonus = 0, globalHealAura = false },
    -- 5阶：战力1005｜概率0.60%｜每秒回血255，持续5秒，全队10%攻击加成
    { name = "天元丹", quality = 5, power = 1005, spawnChance = 0.0060,
      healPerSec = 255, duration = 5, teamAtkBonus = 0.10, teamAtkSpeedBonus = 0, globalHealAura = false },
    -- 6阶：战力1845｜概率0.20%｜每秒回血485，持续5秒，全队15%攻击+10%攻速
    { name = "太乙丹", quality = 6, power = 1845, spawnChance = 0.0020,
      healPerSec = 485, duration = 5, teamAtkBonus = 0.15, teamAtkSpeedBonus = 0.10, globalHealAura = false },
    -- 7阶：战力3395｜概率0.06%｜每秒回血920，持续5秒，全队20%攻击+15%攻速，全图小额回血光环
    { name = "太古丹", quality = 7, power = 3395, spawnChance = 0.0006,
      healPerSec = 920, duration = 5, teamAtkBonus = 0.20, teamAtkSpeedBonus = 0.15, globalHealAura = true },
    -- 8阶：战力6295｜概率0.018%｜每秒回血1750，持续5秒，全队25%攻击+20%攻速，全图高额回血光环
    { name = "混沌丹", quality = 8, power = 6295, spawnChance = 0.00018,
      healPerSec = 1750, duration = 5, teamAtkBonus = 0.25, teamAtkSpeedBonus = 0.20, globalHealAura = true },
    -- 9阶：战力11660｜概率0.004%｜每秒回血3320，持续5秒，全队30%攻击+25%攻速，全屏超强回血光环
    { name = "鸿蒙丹", quality = 9, power = 11660, spawnChance = 0.00004,
      healPerSec = 3320, duration = 5, teamAtkBonus = 0.30, teamAtkSpeedBonus = 0.25, globalHealAura = true },
}

-- ============================================================================
-- 三、高阶道具随机词条完整库（5阶起解锁）
-- 通用词条60%概率出现 + 职业专属词条40%概率出现
-- ============================================================================

-- 词条选择数量规则
Config.AFFIX_RULES = {
    -- [品质] = { chooseFrom = 可选数量, chooseTimes = 选择次数 }
    [5] = { chooseFrom = 2, chooseTimes = 1 },  -- 5阶：2选1
    [6] = { chooseFrom = 3, chooseTimes = 1 },  -- 6阶：3选1
    [7] = { chooseFrom = 3, chooseTimes = 1 },  -- 7阶：3选1
    [8] = { chooseFrom = 3, chooseTimes = 2 },  -- 8阶：3选1双词条
    [9] = { chooseFrom = 3, chooseTimes = 2 },  -- 9阶：3选1双词条
}

-- 通用词条出现概率：60%
Config.AFFIX_GENERIC_CHANCE = 0.60
-- 专属词条出现概率：40%
Config.AFFIX_CLASS_CHANCE = 0.40

-- 通用词条池
Config.AFFIX_GENERIC = {
    { id = "atk_amp",     name = "攻击增幅", desc = "全场道具攻击力+12%",             weight = 25, effect = { stat = "globalAtk", value = 0.12 } },
    { id = "spd_amp",     name = "攻速增幅", desc = "全场道具攻击速度+10%",           weight = 25, effect = { stat = "globalAtkSpeed", value = 0.10 } },
    { id = "range_exp",   name = "范围扩张", desc = "攻击/治疗范围+1格",              weight = 20, effect = { stat = "rangeBonus", value = 1 } },
    { id = "dur_ext",     name = "效果延长", desc = "控制/治疗持续时间+20%",           weight = 20, effect = { stat = "durationBonus", value = 0.20 } },
    { id = "dmg_redux",   name = "伤害减免", desc = "我方全体受到怪物技能伤害-15%",    weight = 10, effect = { stat = "globalDmgReduction", value = 0.15 } },
}

-- 宝剑专属词条池
Config.AFFIX_SWORD = {
    { id = "crit_strike", name = "暴击一击", desc = "普攻20%概率造成双倍伤害",        weight = 35, effect = { stat = "critChance", value = 0.20 } },
    { id = "armor_break", name = "破甲加深", desc = "额外无视敌方20%防御",            weight = 35, effect = { stat = "defIgnoreBonus", value = 0.20 } },
    { id = "reset_atk",   name = "瞬斩追击", desc = "击杀怪物后立刻重置一次普攻",     weight = 30, effect = { stat = "killReset", value = 1 } },
}

-- 符箓专属词条池
Config.AFFIX_TALISMAN = {
    { id = "ctrl_ext",    name = "强控延长", desc = "眩晕/减速时长+30%",              weight = 35, effect = { stat = "controlDurationBonus", value = 0.30 } },
    { id = "aoe_amp",     name = "爆裂增幅", desc = "AOE范围伤害+25%",               weight = 35, effect = { stat = "aoeDmgBonus", value = 0.25 } },
    { id = "pull_gather", name = "聚怪牵引", desc = "技能命中小幅拉扯怪物向前聚拢",   weight = 30, effect = { stat = "pullForce", value = 1 } },
}

-- 护甲专属词条池
Config.AFFIX_ARMOR = {
    { id = "thick_armor", name = "厚甲固守", desc = "自身护盾上限+40%",              weight = 35, effect = { stat = "shieldBonus", value = 0.40 } },
    { id = "global_def",  name = "全域坚守", desc = "全图减伤光环额外+8%",            weight = 35, effect = { stat = "globalReductionBonus", value = 0.08 } },
    { id = "thorns",      name = "反伤外壳", desc = "受到攻击反弹15%伤害给攻击者",    weight = 30, effect = { stat = "thornsDamage", value = 0.15 } },
}

-- 丹药专属词条池
Config.AFFIX_PILL = {
    { id = "strong_heal", name = "强效治愈", desc = "单次治疗量+30%",                weight = 35, effect = { stat = "healBonus", value = 0.30 } },
    { id = "fast_heal",   name = "急速治愈", desc = "治疗间隔缩短15%",               weight = 35, effect = { stat = "healSpeedBonus", value = 0.15 } },
    { id = "cleanse",     name = "净化驱散", desc = "我方道具每隔5秒清除自身负面debuff", weight = 30, effect = { stat = "cleanseCooldown", value = 5.0 } },
}

-- ============================================================================
-- 四、波次难度规则
-- ============================================================================
Config.WAVE_RULES = {
    -- 波次区间 → 允许刷新的最高怪物阶级
    { maxWave = 10,  maxMonsterTier = 2 },   -- 1-10波：仅1-2阶（前期无妖将）
    { maxWave = 19,  maxMonsterTier = 4 },   -- 11-19波：开放3-4阶
    { maxWave = 29,  maxMonsterTier = 5 },   -- 20-29波：开放5阶（解锁技能）
    { maxWave = 39,  maxMonsterTier = 7 },   -- 30-39波：开放7阶
    { maxWave = 9999, maxMonsterTier = 9 },  -- 40波+：全开9阶
}

-- 掉落规则
Config.DROP_RULES = {
    RESOURCE_CHANCE = 1.00,        -- 击杀怪物100%掉落同品质基础资源
    ITEM_CHANCE = 0.10,            -- 10%概率掉落同品质随机道具
}

-- 合成规则
Config.MERGE_RULES = {
    REQUIRED_COUNT = 4,            -- 4个同品质道具合成1个高阶道具
    REROLL_AFFIX = true,           -- 合成后的高阶道具重新随机生成词条
}

-- 技能CD规则（所有怪物技能内置固定CD，防止连续触发）
Config.SKILL_GLOBAL_CD = 3.0      -- 同一技能最少间隔3秒

-- ============================================================================
-- 修士境界系统（累计总经验制）
-- expRequired = 升到本阶所需的累计总经验
-- levelExp = 本级需要的经验（用于进度条显示）
-- maxHp = 该境界玩家最大血量
-- ============================================================================
Config.REALMS = {
    -- 1阶 练气期：累计0｜本级需0｜最大血量100
    { name = "练气", expRequired = 0,      levelExp = 0,      maxHp = 100,  atkMul = 1.0,  defMul = 1.0,  pillMul = 1.0,  dropBonus = 0 },
    -- 2阶 筑基期：累计800｜本级需800｜最大血量180
    { name = "筑基", expRequired = 800,    levelExp = 800,    maxHp = 180,  atkMul = 1.1,  defMul = 1.1,  pillMul = 1.05, dropBonus = 0.02 },
    -- 3阶 金丹期：累计2000｜本级需1200｜最大血量300
    { name = "金丹", expRequired = 2000,   levelExp = 1200,   maxHp = 300,  atkMul = 1.25, defMul = 1.2,  pillMul = 1.1,  dropBonus = 0.05 },
    -- 4阶 元婴期：累计4500｜本级需2500｜最大血量480
    { name = "元婴", expRequired = 4500,   levelExp = 2500,   maxHp = 480,  atkMul = 1.4,  defMul = 1.35, pillMul = 1.2,  dropBonus = 0.08 },
    -- 5阶 化神期：累计10000｜本级需5500｜最大血量750
    { name = "化神", expRequired = 10000,  levelExp = 5500,   maxHp = 750,  atkMul = 1.6,  defMul = 1.5,  pillMul = 1.3,  dropBonus = 0.12 },
    -- 6阶 炼虚期：累计22000｜本级需12000｜最大血量1100
    { name = "炼虚", expRequired = 22000,  levelExp = 12000,  maxHp = 1100, atkMul = 1.8,  defMul = 1.7,  pillMul = 1.4,  dropBonus = 0.15 },
    -- 7阶 合体期：累计48000｜本级需26000｜最大血量1600
    { name = "合体", expRequired = 48000,  levelExp = 26000,  maxHp = 1600, atkMul = 2.0,  defMul = 2.0,  pillMul = 1.5,  dropBonus = 0.18 },
    -- 8阶 大乘期：累计105000｜本级需57000｜最大血量2300
    { name = "大乘", expRequired = 105000, levelExp = 57000,  maxHp = 2300, atkMul = 2.5,  defMul = 2.5,  pillMul = 1.7,  dropBonus = 0.22 },
    -- 9阶 渡劫期：累计230000｜本级需125000｜最大血量3300
    { name = "渡劫", expRequired = 230000, levelExp = 125000, maxHp = 3300, atkMul = 3.0,  defMul = 3.0,  pillMul = 2.0,  dropBonus = 0.30 },
}

-- ============================================================================
-- 天赋点系统（轮回获得，永久加成）
-- ============================================================================
Config.TALENT = {
    MAX_POINTS = 100,           -- 天赋点上限
    -- 每1点天赋固定加成（线性叠加，无递减无递增）
    PER_POINT_ATK = 0.003,     -- 全体道具攻击力 +0.3%
    PER_POINT_ATKSPD = 0.002,  -- 全体道具攻击速度 +0.2%
    PER_POINT_HP = 0.02,       -- 玩家最大血量 +2%
    PER_POINT_EXP = 0.004,     -- 全局怪物掉落经验 +0.4%
}

-- 轮回触发条件：渡劫满级(累计230000)后再获得任意溢出经验
Config.REINCARNATION_EXP_THRESHOLD = 230000

-- ============================================================================
-- 玩家
-- ============================================================================
Config.PLAYER = {
    BASE_HP = 100,
    BASE_EXP = 0,
}

-- ============================================================================
-- 宝箱
-- ============================================================================
Config.CHEST = {
    SPAWN_CHANCE = 0.15,   -- 15%概率刷新宝箱（降低频率避免占满格子）
    MAX_CHESTS = 2,
    HP = 1,
    DROP_MIN = 1,
    DROP_MAX = 3,
}

-- 缓冲区队列上限
Config.BUFFER_MAX = 10

-- ============================================================================
-- 分解返还修为
-- ============================================================================
Config.DECOMPOSE_EXP = { 2, 6, 15, 35, 80, 200, 500, 1200, 3000 }

-- ============================================================================
-- 颜色主题
-- ============================================================================
Config.COLORS = {
    SKY_TOP = {173, 216, 240, 255},
    SKY_BOTTOM = {210, 235, 220, 255},
    GRASS = {130, 195, 110, 255},
    EARTH = {160, 120, 75, 255},
    FIELD_BG = {220, 240, 250, 40},
    FIELD_GRID = {180, 200, 210, 150},
    FIELD_BORDER = {100, 120, 140, 120},
    SLOT_BG = {255, 255, 255, 220},
    SLOT_BORDER = {80, 80, 80, 200},
    SLOT_SELECTED = {255, 240, 150, 255},
    MONSTER_MELEE = {200, 80, 70, 220},
    MONSTER_RANGED = {100, 70, 180, 220},
    MONSTER_HP_BG = {50, 40, 40, 150},
    HUD_BG = {50, 50, 60, 200},
    HP_BAR = {230, 70, 60, 255},
    EXP_BAR = {160, 100, 220, 255},
    TEXT_PRIMARY = {50, 45, 40, 255},
    TEXT_SECONDARY = {100, 95, 90, 200},
    TEXT_WHITE = {255, 255, 255, 255},
    TEXT_GOLD = {255, 210, 80, 255},
    BORDER_HIGHLIGHT = {255, 200, 50, 255},
}

return Config
