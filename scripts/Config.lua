-- Config.lua
-- 仙侠合成塔防 - 全局数值配置

local Config = {}

-- ============================================================================
-- 战场布局（参考花花僵尸：统一网格，底部放法宝，上方怪物行进）
-- ============================================================================
Config.GRID_COLS = 5           -- 列数
Config.FIELD_ROWS = 7          -- 怪物行进区行数（从顶部 row=1 到 row=7）
Config.DEPLOY_ROWS = 2         -- 布政区行数（底部2行放法宝/道具）
Config.TOTAL_ROWS = Config.FIELD_ROWS + Config.DEPLOY_ROWS  -- 总行数 = 9
Config.TOTAL_SLOTS = Config.GRID_COLS * Config.DEPLOY_ROWS   -- 布政区格子数 = 10

-- ============================================================================
-- 品质阶梯
-- ============================================================================
Config.QUALITY = {
    { id = 1, name = "凡器", color = {200, 200, 200, 255} },   -- 白色
    { id = 2, name = "良品", color = {100, 210, 120, 255} },   -- 绿色
    { id = 3, name = "上品", color = {80, 160, 255, 255} },    -- 蓝色
    { id = 4, name = "灵宝", color = {180, 100, 255, 255} },   -- 紫色
    { id = 5, name = "圣器", color = {230, 70, 60, 255} },     -- 红色
    { id = 6, name = "仙器", color = {255, 200, 50, 255} },    -- 金色
    { id = 7, name = "神器", color = {180, 140, 40, 255} },    -- 暗金
    { id = 8, name = "太古", color = {200, 130, 255, 255} },   -- 紫金
    { id = 9, name = "鸿蒙", color = {255, 160, 200, 255} },   -- 粉霞
}
Config.MAX_QUALITY = #Config.QUALITY

-- ============================================================================
-- 道具类型
-- ============================================================================
Config.ITEM_TYPE = {
    ATTACK = 1,    -- 攻击法宝
    DEFENSE = 2,   -- 防御法宝
    PILL = 3,      -- 丹药
}

-- 攻击法宝数值（按品质索引，9级）
Config.ATTACK_ITEMS = {
    { name = "飞剑", atk = 8,  crit = 0.05 },
    { name = "灵剑", atk = 20, crit = 0.10 },
    { name = "仙剑", atk = 45, crit = 0.15 },
    { name = "神剑", atk = 100, crit = 0.25 },
    { name = "天剑", atk = 220, crit = 0.35 },
    { name = "圣剑", atk = 500, crit = 0.50 },
    { name = "太古剑", atk = 1000, crit = 0.60 },
    { name = "混沌剑", atk = 2000, crit = 0.70 },
    { name = "鸿蒙剑", atk = 5000, crit = 0.85 },
}

-- 防御法宝数值（符箓，9级）
Config.DEFENSE_ITEMS = {
    { name = "镇灵符", shield = 5,  slow = 0.1 },
    { name = "青木符", shield = 12, slow = 0.2 },
    { name = "星辰符", shield = 30, slow = 0.3 },
    { name = "紫霄符", shield = 60, slow = 0.5 },
    { name = "烈焰符", shield = 120, slow = 0.7 },
    { name = "鎏金符", shield = 250, slow = 0.8 },
    { name = "太古符", shield = 500, slow = 0.9 },
    { name = "紫金符", shield = 1000, slow = 0.95 },
    { name = "鸿蒙符", shield = 2000, slow = 1.0 },
}

-- 丹药数值（锦囊，9级）
Config.PILL_ITEMS = {
    { name = "回灵丹", buff = "heal",    value = 10, duration = 3 },
    { name = "聚气丹", buff = "atkUp",   value = 0.2, duration = 4 },
    { name = "护体丹", buff = "defUp",   value = 0.3, duration = 4 },
    { name = "破魔丹", buff = "critUp",  value = 0.25, duration = 5 },
    { name = "天元丹", buff = "allUp",   value = 0.3, duration = 5 },
    { name = "太乙丹", buff = "allUp",   value = 0.6, duration = 6 },
    { name = "太古丹", buff = "allUp",   value = 0.9, duration = 7 },
    { name = "混沌丹", buff = "allUp",   value = 1.2, duration = 8 },
    { name = "鸿蒙丹", buff = "allUp",   value = 1.8, duration = 10 },
}

-- ============================================================================
-- 怪物
-- ============================================================================
Config.MONSTER_TYPE = {
    MELEE = 1,
    RANGED = 2,
}

Config.WAVE_INTERVAL = 3  -- 每3回合刷新一波

Config.MELEE_TEMPLATES = {
    { name = "小妖", hp = 30, atk = 15, exp = 5, dropChance = 0.3 },
    { name = "妖将", hp = 60, atk = 25, exp = 10, dropChance = 0.4 },
    { name = "妖王", hp = 120, atk = 45, exp = 20, dropChance = 0.6 },
    { name = "魔尊", hp = 250, atk = 80, exp = 40, dropChance = 0.8 },
}

Config.RANGED_TEMPLATES = {
    { name = "邪修", hp = 20, atk = 5, exp = 5, dropChance = 0.3, attackRange = 3 },
    { name = "妖道", hp = 35, atk = 8, exp = 10, dropChance = 0.4, attackRange = 4 },
    { name = "魔修", hp = 60, atk = 12, exp = 20, dropChance = 0.6, attackRange = 5 },
    { name = "邪仙", hp = 100, atk = 20, exp = 40, dropChance = 0.8, attackRange = 6 },
}

-- ============================================================================
-- 修士境界系统
-- ============================================================================
Config.REALMS = {
    { name = "练气", expRequired = 0,   hpBonus = 0,   atkMul = 1.0, defMul = 1.0, pillMul = 1.0, dropBonus = 0 },
    { name = "筑基", expRequired = 50,  hpBonus = 20,  atkMul = 1.1, defMul = 1.1, pillMul = 1.05, dropBonus = 0.02 },
    { name = "金丹", expRequired = 150, hpBonus = 50,  atkMul = 1.25, defMul = 1.2, pillMul = 1.1, dropBonus = 0.05 },
    { name = "元婴", expRequired = 350, hpBonus = 100, atkMul = 1.4, defMul = 1.35, pillMul = 1.2, dropBonus = 0.08 },
    { name = "化神", expRequired = 600, hpBonus = 180, atkMul = 1.6, defMul = 1.5, pillMul = 1.3, dropBonus = 0.12 },
    { name = "炼虚", expRequired = 1000, hpBonus = 300, atkMul = 1.8, defMul = 1.7, pillMul = 1.4, dropBonus = 0.15 },
    { name = "合体", expRequired = 1500, hpBonus = 500, atkMul = 2.0, defMul = 2.0, pillMul = 1.5, dropBonus = 0.18 },
    { name = "大乘", expRequired = 2200, hpBonus = 800, atkMul = 2.5, defMul = 2.5, pillMul = 1.7, dropBonus = 0.22 },
    { name = "渡劫", expRequired = 3500, hpBonus = 1200, atkMul = 3.0, defMul = 3.0, pillMul = 2.0, dropBonus = 0.30 },
}

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
    SPAWN_CHANCE = 0.3,
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
-- 颜色主题（粗线条简约可爱 + 仙侠清新风）
-- ============================================================================
Config.COLORS = {
    -- 天空背景
    SKY_TOP = {173, 216, 240, 255},          -- 浅天蓝
    SKY_BOTTOM = {210, 235, 220, 255},       -- 淡青绿

    -- 草地/泥土
    GRASS = {130, 195, 110, 255},            -- 明亮草绿
    EARTH = {160, 120, 75, 255},             -- 泥土棕

    -- 战场网格
    FIELD_BG = {220, 240, 250, 40},          -- 极淡天蓝
    FIELD_GRID = {180, 200, 210, 150},       -- 淡灰十字标
    FIELD_BORDER = {100, 120, 140, 120},     -- 柔和边框

    -- 格子（粗圆角白底黑描边）
    SLOT_BG = {255, 255, 255, 220},          -- 半透白底
    SLOT_BORDER = {80, 80, 80, 200},         -- 粗黑描边
    SLOT_SELECTED = {255, 240, 150, 255},    -- 选中金色

    -- 怪物（可爱色调）
    MONSTER_MELEE = {200, 80, 70, 220},      -- 暖红
    MONSTER_RANGED = {100, 70, 180, 220},    -- 深紫
    MONSTER_HP_BG = {50, 40, 40, 150},

    -- HUD
    HUD_BG = {50, 50, 60, 200},             -- 深灰胶囊
    HP_BAR = {230, 70, 60, 255},             -- 血条红
    EXP_BAR = {160, 100, 220, 255},          -- 修为紫
    TEXT_PRIMARY = {50, 45, 40, 255},
    TEXT_SECONDARY = {100, 95, 90, 200},
    TEXT_WHITE = {255, 255, 255, 255},
    TEXT_GOLD = {255, 210, 80, 255},          -- 境界金
    BORDER_HIGHLIGHT = {255, 200, 50, 255},
}

return Config
