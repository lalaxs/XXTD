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
    { id = 1, name = "凡器", color = {180, 180, 180, 255} },   -- 白色
    { id = 2, name = "良品", color = {80, 210, 80, 255} },     -- 绿色
    { id = 3, name = "上品", color = {60, 140, 255, 255} },    -- 蓝色
    { id = 4, name = "灵宝", color = {170, 60, 255, 255} },    -- 紫色
    { id = 5, name = "仙器", color = {255, 200, 0, 255} },     -- 金色
    { id = 6, name = "神器", color = {255, 120, 0, 255} },     -- 橙色
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

-- 攻击法宝数值（按品质索引）
Config.ATTACK_ITEMS = {
    { name = "飞剑", atk = 8,  crit = 0.05, icon = "⚔" },
    { name = "灵剑", atk = 20, crit = 0.10, icon = "⚔" },
    { name = "仙剑", atk = 45, crit = 0.15, icon = "⚔" },
    { name = "神剑", atk = 100, crit = 0.25, icon = "⚔" },
    { name = "天剑", atk = 220, crit = 0.35, icon = "⚔" },
    { name = "混沌剑", atk = 500, crit = 0.50, icon = "⚔" },
}

-- 防御法宝数值
Config.DEFENSE_ITEMS = {
    { name = "土盾", shield = 5,  slow = 0.1, icon = "🛡" },
    { name = "灵盾", shield = 12, slow = 0.2, icon = "🛡" },
    { name = "仙盾", shield = 30, slow = 0.3, icon = "🛡" },
    { name = "神盾", shield = 60, slow = 0.5, icon = "🛡" },
    { name = "天盾", shield = 120, slow = 0.7, icon = "🛡" },
    { name = "混沌盾", shield = 250, slow = 1.0, icon = "🛡" },
}

-- 丹药数值
Config.PILL_ITEMS = {
    { name = "回灵丹", buff = "heal",    value = 10, duration = 3, icon = "💊" },
    { name = "聚气丹", buff = "atkUp",   value = 0.2, duration = 4, icon = "💊" },
    { name = "护体丹", buff = "defUp",   value = 0.3, duration = 4, icon = "💊" },
    { name = "破魔丹", buff = "critUp",  value = 0.25, duration = 5, icon = "💊" },
    { name = "天元丹", buff = "allUp",   value = 0.3, duration = 5, icon = "💊" },
    { name = "太乙丹", buff = "allUp",   value = 0.6, duration = 6, icon = "💊" },
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
Config.BUFFER_MAX = 5

-- ============================================================================
-- 分解返还修为
-- ============================================================================
Config.DECOMPOSE_EXP = { 2, 6, 15, 35, 80, 200 }

-- ============================================================================
-- 颜色主题（仙侠水墨风配色）
-- ============================================================================
Config.COLORS = {
    -- 战场网格
    FIELD_BG = {235, 225, 200, 255},         -- 沙黄色战场底色
    FIELD_GRID = {200, 185, 155, 120},       -- 网格线
    FIELD_BORDER = {140, 120, 80, 200},      -- 战场边框
    DEPLOY_BG = {180, 210, 140, 255},        -- 布政区底色（草绿）
    DEPLOY_BORDER = {120, 160, 80, 200},     -- 布政区边框

    -- 格子
    SLOT_EMPTY = {210, 200, 175, 180},       -- 空格子
    SLOT_SELECTED = {255, 230, 150, 255},    -- 选中高亮
    SLOT_BORDER = {160, 140, 100, 150},      -- 格子边框

    -- 怪物
    MONSTER_MELEE = {180, 50, 50, 255},
    MONSTER_RANGED = {80, 50, 180, 255},
    MONSTER_HP_BG = {80, 60, 60, 200},

    -- UI
    HP_BAR = {220, 50, 50, 255},
    HP_BG = {80, 40, 40, 200},
    EXP_BAR = {100, 180, 255, 255},
    TEXT_PRIMARY = {50, 40, 30, 255},
    TEXT_SECONDARY = {100, 85, 65, 200},
    TEXT_WHITE = {255, 255, 255, 255},
    ORB_GLOW = {100, 220, 160, 230},
    BORDER_HIGHLIGHT = {255, 180, 50, 255},
}

return Config
