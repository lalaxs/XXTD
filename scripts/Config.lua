-- Config.lua
-- 仙侠合成塔防 - 文档权威数值配置
-- 对齐 docs/仙侠合成塔防_核心设计文档.md

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
-- ============================================================================
Config.QUALITY = {
    { id = 1, name = "凡品", color = {200, 200, 200, 255} },
    { id = 2, name = "良品", color = {100, 210, 120, 255} },
    { id = 3, name = "上品", color = {80, 160, 255, 255} },
    { id = 4, name = "精品", color = {180, 100, 255, 255} },
    { id = 5, name = "极品", color = {255, 160, 50, 255} },
    { id = 6, name = "珍品", color = {230, 70, 60, 255} },
    { id = 7, name = "仙品", color = {255, 160, 200, 255} },
    { id = 8, name = "神品", color = {255, 200, 50, 255} },
    { id = 9, name = "圣品", color = {180, 140, 40, 255} },
}
Config.MAX_QUALITY = #Config.QUALITY
Config.SKILL_UNLOCK_TIER = 5
Config.MIN_DROP_QUALITY_BY_MAJOR = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }

function Config.GetDropQualityRange(realmIndex)
    local majorIndex = 1
    if Config.GetRealmMajorIndex then
        majorIndex = Config.GetRealmMajorIndex(realmIndex or 1)
    end
    local minQuality = Config.MIN_DROP_QUALITY_BY_MAJOR[majorIndex] or 1
    local maxQuality = math.min(Config.MAX_QUALITY, majorIndex)
    minQuality = math.min(maxQuality, math.max(1, minQuality))
    return minQuality, maxQuality
end

-- ============================================================================
-- 道具类型
-- ============================================================================
Config.ITEM_TYPE = {
    ATTACK = 1,
    DEFENSE = 2,
    PILL = 3,
    TALISMAN = 4,
}

Config.ITEM_CATEGORY = {
    WEAPON = "weapon",
    ARMOR = "armor",
    PILL = "pill",
    TALISMAN = "talisman",
}

-- ============================================================================
-- 怪物系统：26 种具名怪物（P1-6.5）
-- ============================================================================
Config.MONSTER_TYPE = {
    MELEE = 1,
    RANGED = 2,
}

Config.MONSTER_TIER = {
    MINION = "小妖",
    NORMAL = "普通",
    ELITE = "精锐",
    BOSS = "头目",
}

Config.PLAYER_DEBUFFS = {
    ATTACK_DOWN = "attackDown",
    VULNERABLE = "vulnerable",
    SEAL = "seal",
}

Config.MONSTER_DEFS = {
    { id = "wild_boar", name = "野猪妖", realm = 1, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.NORMAL, hp = 18, atk = 12, defense = 4, critChance = 0.05, critMultiplier = 1.5, exp = 5, tags = { "normal" }, asset = "image/enemy/enemy_ (1).png" },
    { id = "gray_wolf", name = "灰狼妖", realm = 2, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.NORMAL, hp = 90, atk = 14, defense = 7, critChance = 0.05, critMultiplier = 1.5, exp = 7, tags = { "normal" }, asset = "image/enemy/enemy_ (2).png" },
    { id = "tree_demon", name = "树妖", realm = 3, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.ELITE, hp = 220, atk = 18, defense = 12, critChance = 0.08, critMultiplier = 1.6, exp = 22, tags = { "elite", "tank" }, asset = "image/enemy/enemy_ (3).png" },
    { id = "shell_imp", name = "壳背小妖", realm = 1, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.MINION, hp = 15, atk = 6, defense = 4, critChance = 0.0, critMultiplier = 1.0, exp = 3, tags = { "minion" }, asset = "image/enemy/enemy_ (4).png" },
    { id = "black_wolf", name = "黑狼妖", realm = 2, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.ELITE, hp = 180, atk = 21, defense = 7, critChance = 0.10, critMultiplier = 1.8, exp = 18, tags = { "elite" }, asset = "image/enemy/enemy_ (5).png" },
    { id = "green_snake", name = "青蛇妖", realm = 3, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.NORMAL, hp = 95, atk = 10, defense = 6, critChance = 0.04, critMultiplier = 1.4, exp = 9, tags = { "ranged", "attack_down" }, attackRange = 3, playerDebuff = { type = Config.PLAYER_DEBUFFS.ATTACK_DOWN, value = 0.15, duration = 2 }, asset = "image/enemy/enemy_ (6).png" },
    { id = "tiger_boss", name = "虎妖头目", realm = 4, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.BOSS, hp = 840, atk = 55, defense = 21, critChance = 0.20, critMultiplier = 2.0, exp = 60, tags = { "boss" }, asset = "image/enemy/enemy_ (7).png" },
    { id = "white_fox", name = "白狐妖", realm = 5, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.ELITE, hp = 800, atk = 33, defense = 26, critChance = 0.10, critMultiplier = 1.8, exp = 40, tags = { "ranged", "elite" }, attackRange = 3, asset = "image/enemy/enemy_ (8).png" },
    { id = "white_mage", name = "白袍法师", realm = 7, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.ELITE, hp = 2400, atk = 46, defense = 79, critChance = 0.10, critMultiplier = 1.8, exp = 75, tags = { "ranged", "elite", "attack_down" }, attackRange = 3, playerDebuff = { type = Config.PLAYER_DEBUFFS.ATTACK_DOWN, value = 0.20, duration = 3 }, asset = "image/enemy/enemy_ (9).png" },
    { id = "spear_guard", name = "持枪守卫", realm = 4, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.ELITE, hp = 560, atk = 33, defense = 21, critChance = 0.10, critMultiplier = 1.8, exp = 30, tags = { "normal", "elite" }, asset = "image/enemy/enemy_ (10).png" },
    { id = "gourd_cultivator", name = "葫芦修士", realm = 3, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.NORMAL, hp = 95, atk = 10, defense = 6, critChance = 0.04, critMultiplier = 1.4, exp = 9, tags = { "ranged" }, attackRange = 3, asset = "image/enemy/enemy_ (11).png" },
    { id = "fox_fire_witch", name = "狐火妖女", realm = 5, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.ELITE, hp = 800, atk = 33, defense = 26, critChance = 0.10, critMultiplier = 1.8, exp = 40, tags = { "ranged", "elite", "vulnerable" }, attackRange = 3, playerDebuff = { type = Config.PLAYER_DEBUFFS.VULNERABLE, value = 0.20, duration = 2 }, asset = "image/enemy/enemy_ (12).png" },
    { id = "lantern_maiden", name = "提灯侍女", realm = 7, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.NORMAL, hp = 1200, atk = 31, defense = 79, critChance = 0.05, critMultiplier = 1.5, exp = 30, tags = { "ranged", "seal" }, attackRange = 3, playerDebuff = { type = Config.PLAYER_DEBUFFS.SEAL, duration = 1 }, asset = "image/enemy/enemy_ (13).png" },
    { id = "blade_cultivator", name = "持刀修士", realm = 6, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.NORMAL, hp = 860, atk = 31, defense = 65, critChance = 0.05, critMultiplier = 1.5, exp = 22, tags = { "normal" }, asset = "image/enemy/enemy_ (14).png" },
    { id = "blue_swordsman", name = "蓝剑修士", realm = 8, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.ELITE, hp = 5200, atk = 63, defense = 197, critChance = 0.10, critMultiplier = 1.8, exp = 112, tags = { "elite" }, asset = "image/enemy/enemy_ (15).png" },
    { id = "beast_tamer", name = "驯兽师", realm = 6, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.NORMAL, hp = 688, atk = 26, defense = 46, critChance = 0.05, critMultiplier = 1.5, exp = 22, tags = { "ranged", "normal" }, attackRange = 3, asset = "image/enemy/enemy_ (16).png" },
    { id = "black_assassin", name = "黑衣刺客", realm = 8, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.ELITE, hp = 5200, atk = 63, defense = 197, critChance = 0.10, critMultiplier = 1.8, exp = 112, tags = { "elite" }, asset = "image/enemy/enemy_ (17).png" },
    { id = "purple_cultivator", name = "紫袍修士", realm = 9, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.ELITE, hp = 7200, atk = 61, defense = 239, critChance = 0.10, critMultiplier = 1.8, exp = 175, tags = { "ranged", "elite", "seal", "vulnerable" }, attackRange = 3, playerDebuffs = { { type = Config.PLAYER_DEBUFFS.SEAL, duration = 2 }, { type = Config.PLAYER_DEBUFFS.VULNERABLE, value = 0.25, duration = 3 } }, asset = "image/enemy/enemy_ (18).png" },
    { id = "flame_golem", name = "火焰石人", realm = 6, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.ELITE, hp = 1720, atk = 47, defense = 98, critChance = 0.10, critMultiplier = 1.8, exp = 55, tags = { "elite", "tank" }, asset = "image/enemy/enemy_ (19).png" },
    { id = "poison_spider", name = "毒蜘蛛", realm = 4, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.NORMAL, hp = 224, atk = 19, defense = 15, critChance = 0.05, critMultiplier = 1.5, exp = 12, tags = { "ranged", "normal" }, attackRange = 3, asset = "image/enemy/enemy_ (20).png" },
    { id = "purple_scorpion", name = "紫蝎妖", realm = 5, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.NORMAL, hp = 500, atk = 26, defense = 37, critChance = 0.05, critMultiplier = 1.5, exp = 16, tags = { "normal" }, asset = "image/enemy/enemy_ (21).png" },
    { id = "three_headed_snake", name = "三头蛇妖", realm = 7, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.ELITE, hp = 2400, atk = 46, defense = 79, critChance = 0.10, critMultiplier = 1.8, exp = 75, tags = { "ranged", "elite" }, attackRange = 3, asset = "image/enemy/enemy_ (22).png" },
    { id = "ice_snake", name = "冰蛇妖", realm = 8, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.NORMAL, hp = 2080, atk = 36, defense = 138, critChance = 0.05, critMultiplier = 1.5, exp = 45, tags = { "ranged", "normal" }, attackRange = 3, asset = "image/enemy/enemy_ (23).png" },
    { id = "green_turtle", name = "青龟妖", realm = 3, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.ELITE, hp = 220, atk = 18, defense = 12, critChance = 0.08, critMultiplier = 1.6, exp = 22, tags = { "elite", "tank" }, asset = "image/enemy/enemy_ (24).png" },
    { id = "purple_spike_beast", name = "紫刺妖兽", realm = 7, monsterType = Config.MONSTER_TYPE.MELEE, tier = Config.MONSTER_TIER.NORMAL, hp = 1500, atk = 36, defense = 113, critChance = 0.05, critMultiplier = 1.5, exp = 30, tags = { "normal" }, asset = "image/enemy/enemy_ (25).png" },
    { id = "purple_fire_elder", name = "紫火老修", realm = 9, monsterType = Config.MONSTER_TYPE.RANGED, tier = Config.MONSTER_TIER.BOSS, hp = 10800, atk = 102, defense = 239, critChance = 0.20, critMultiplier = 2.0, exp = 350, tags = { "ranged", "boss" }, attackRange = 3, asset = "image/enemy/enemy_ (26).png" },
}

Config.MONSTER_BY_ID = {}
for _, def in ipairs(Config.MONSTER_DEFS) do
    Config.MONSTER_BY_ID[def.id] = def
    def.quality = def.realm
    def.dropChance = 0
end

-- ============================================================================
-- 境界系统（45 小境界）
-- expRequired = 当前小境界突破到下一小境界所需修为；渡劫九重为终局，需求为 0
-- majorBreakthrough = 突破到该小境界时是否属于大境界突破
-- expBase/expMinorGrowth/expMajorGrowth 控制同一大境界内的小境界修为曲线，避免长回合积累后过早突破
-- ============================================================================
local REALM_STAGE_SPECS = {
    { name = "练气", stages = { "前期", "中期", "后期" }, expBase = 65, expMul = 1, expMinorGrowth = 1.55, expMajorGrowth = 1.12, maxHp = 100, atkMul = 1.0, defMul = 1.0, pillMul = 1.0, dropMul = 1.00, dropBonus = 0.00 },
    { name = "筑基", stages = { "一层", "二层", "三层", "四层", "五层", "六层", "七层", "八层", "九层" }, expBase = 60, expMul = 3.4, expMinorGrowth = 1.05, expMajorGrowth = 1.06, maxHp = 120, atkMul = 1.1, defMul = 1.1, pillMul = 1.1, dropMul = 1.05, dropBonus = 0.05 },
    { name = "金丹", stages = { "前期", "中期", "后期", "圆满" }, expBase = 80, expMul = 12, expMinorGrowth = 1.45, expMajorGrowth = 1.09, maxHp = 150, atkMul = 1.2, defMul = 1.2, pillMul = 1.2, dropMul = 1.10, dropBonus = 0.10 },
    { name = "元婴", stages = { "前期", "中期", "后期", "圆满" }, expBase = 88, expMul = 30, expMinorGrowth = 1.48, expMajorGrowth = 1.08, maxHp = 180, atkMul = 1.3, defMul = 1.3, pillMul = 1.3, dropMul = 1.15, dropBonus = 0.15 },
    { name = "化神", stages = { "前期", "中期", "后期", "圆满" }, expBase = 96, expMul = 70, expMinorGrowth = 1.50, expMajorGrowth = 1.07, maxHp = 220, atkMul = 1.4, defMul = 1.4, pillMul = 1.4, dropMul = 1.20, dropBonus = 0.20 },
    { name = "炼虚", stages = { "前期", "中期", "后期", "圆满" }, expBase = 106, expMul = 160, expMinorGrowth = 1.52, expMajorGrowth = 1.06, maxHp = 260, atkMul = 1.5, defMul = 1.5, pillMul = 1.5, dropMul = 1.25, dropBonus = 0.25 },
    { name = "合体", stages = { "前期", "中期", "后期", "圆满" }, expBase = 118, expMul = 360, expMinorGrowth = 1.54, expMajorGrowth = 1.05, maxHp = 300, atkMul = 1.6, defMul = 1.6, pillMul = 1.6, dropMul = 1.30, dropBonus = 0.30 },
    { name = "大乘", stages = { "前期", "中期", "后期", "圆满" }, expBase = 132, expMul = 800, expMinorGrowth = 1.56, expMajorGrowth = 1.04, maxHp = 350, atkMul = 1.7, defMul = 1.7, pillMul = 1.7, dropMul = 1.35, dropBonus = 0.35 },
    { name = "渡劫", stages = { "一重", "二重", "三重", "四重", "五重", "六重", "七重", "八重", "九重" }, expBase = 150, expMul = 1800, expMinorGrowth = 1.24, expMajorGrowth = 1.03, maxHp = 400, atkMul = 1.8, defMul = 1.8, pillMul = 1.8, dropMul = 1.40, dropBonus = 0.40 },
}

local function RoundNumber(value)
    return math.floor(value + 0.5)
end

local function BuildRealmStage(spec, majorIndex, minorIndex)
    local minorCount = #spec.stages
    local progress = minorCount > 1 and (minorIndex - 1) / (minorCount - 1) or 0
    local expBase = spec.expBase or 50
    local expMinorGrowth = spec.expMinorGrowth or 1.35
    local expMajorGrowth = spec.expMajorGrowth or 1.0
    local expRequired = RoundNumber(expBase * spec.expMul * (minorIndex ^ expMinorGrowth) * (expMajorGrowth ^ (majorIndex - 1)))
    local statMul = 1 + 0.12 * progress

    return {
        name = spec.name .. spec.stages[minorIndex],
        majorName = spec.name,
        stageName = spec.stages[minorIndex],
        majorIndex = majorIndex,
        minorIndex = minorIndex,
        minorCount = minorCount,
        majorBreakthrough = minorIndex == 1 and majorIndex > 1,
        expRequired = expRequired,
        levelExp = expRequired,
        maxHp = RoundNumber(spec.maxHp * statMul),
        atkMul = spec.atkMul * (1 + 0.07 * progress),
        defMul = spec.defMul * (1 + 0.08 * progress),
        pillMul = spec.pillMul * (1 + 0.05 * progress),
        dropMul = spec.dropMul,
        dropBonus = spec.dropBonus,
    }
end

Config.REALMS = {}
for majorIndex, spec in ipairs(REALM_STAGE_SPECS) do
    for minorIndex = 1, #spec.stages do
        table.insert(Config.REALMS, BuildRealmStage(spec, majorIndex, minorIndex))
    end
end
Config.REALMS[#Config.REALMS].expRequired = 0
Config.REALMS[#Config.REALMS].levelExp = 0

function Config.GetRealm(realmIndex)
    local index = math.min(#Config.REALMS, math.max(1, realmIndex or 1))
    return Config.REALMS[index]
end

function Config.GetRealmMajorIndex(realmIndex)
    local realm = Config.GetRealm(realmIndex)
    return realm.majorIndex or 1
end

function Config.GetFirstRealmIndexByMajor(majorIndex)
    for index, realm in ipairs(Config.REALMS) do
        if realm.majorIndex == majorIndex then
            return index
        end
    end
    return #Config.REALMS
end

function Config.IsMajorRealmBreakthrough(realmIndex)
    local realm = Config.REALMS[realmIndex]
    return realm and realm.majorBreakthrough == true
end

-- ============================================================================
-- 难度系统（§14 / P4.2）
-- ============================================================================
Config.DIFFICULTY = {
    [1] = { id = 1, enemyMul = 1.0, talentBonus = 0, extraMonsterPerWave = 0, enemyAtkBonus = 0, fieldRewardSpawnMul = 1.0 },
    [2] = { id = 2, enemyMul = 1.25, talentBonus = 1, extraMonsterPerWave = 0, enemyAtkBonus = 0, fieldRewardSpawnMul = 1.0 },
    [3] = { id = 3, enemyMul = 1.55, talentBonus = 2, extraMonsterPerWave = 1, enemyAtkBonus = 0, fieldRewardSpawnMul = 1.0 },
    [4] = { id = 4, enemyMul = 1.9, talentBonus = 3, extraMonsterPerWave = 1, enemyAtkBonus = 0.15, fieldRewardSpawnMul = 1.0 },
    [5] = { id = 5, enemyMul = 2.3, talentBonus = 4, extraMonsterPerWave = 1, enemyAtkBonus = 0.15, fieldRewardSpawnMul = 0.8 },
}
Config.MAX_DIFFICULTY = 5

-- ============================================================================
-- P2 波次设计
-- ============================================================================
Config.WAVE_INTERVAL = 1
Config.TUTORIAL_WAVE_INTERVAL = 2
Config.WAVE_SPAWN = {
    EARLY_CHANCE = 0.28,
    DEFAULT_CHANCE = 0.50,
    EARLY_MIN_INTERVAL = 2,
    DEFAULT_MIN_INTERVAL = 1,
    EARLY_PITY_INTERVAL = 5,
    DEFAULT_PITY_INTERVAL = 3,
    CHANCE_GROWTH_PER_TURN = 0.10,
    MAX_SPAWN_CHANCE = 0.90,
    MINOR_HP_GROWTH = 1.00,
    MINOR_ATK_GROWTH = 0.45,
    MINOR_DEF_GROWTH = 0.55,
    MINOR_EXP_GROWTH = 0.75,
    ACTIVE_LIMIT_BY_MAJOR = { 3, 5, 7, 8, 9, 10, 11, 12, 14 },
    COUNT_ROLL_BY_MAJOR = {
        [1] = { { count = 1, weight = 80 }, { count = 2, weight = 20 } },
        [2] = { { count = 1, weight = 55 }, { count = 2, weight = 35 }, { count = 3, weight = 10 } },
        [3] = { { count = 1, weight = 40 }, { count = 2, weight = 40 }, { count = 3, weight = 20 } },
        [4] = { { count = 1, weight = 30 }, { count = 2, weight = 40 }, { count = 3, weight = 25 }, { count = 4, weight = 5 } },
        [5] = { { count = 1, weight = 20 }, { count = 2, weight = 40 }, { count = 3, weight = 30 }, { count = 4, weight = 10 } },
        [6] = { { count = 1, weight = 15 }, { count = 2, weight = 35 }, { count = 3, weight = 35 }, { count = 4, weight = 15 } },
        [7] = { { count = 1, weight = 10 }, { count = 2, weight = 30 }, { count = 3, weight = 40 }, { count = 4, weight = 20 } },
        [8] = { { count = 1, weight = 5 }, { count = 2, weight = 25 }, { count = 3, weight = 45 }, { count = 4, weight = 25 } },
        [9] = { { count = 2, weight = 25 }, { count = 3, weight = 45 }, { count = 4, weight = 30 } },
    },
}
Config.WAVE_BUDGET_TOLERANCE = 0.08
Config.WAVE_MAX_MONSTERS = 10
Config.MONSTER_EXP_MUL = 1.35
Config.MONSTER_EXP_EARLY_MAJOR_BONUS = 0.10
-- 敌人血攻成长只在飞升后继续游戏的无尽模式生效；普通境界内每波敌人数值保持不变。
Config.WAVE_ENEMY_HP_GROWTH = 0.04
Config.WAVE_ENEMY_ATK_GROWTH = 0.03
Config.REALM_ENEMY_ATK_SCALE = { 1.0, 1.0, 0.55, 0.72, 0.70, 0.68, 0.66, 0.64, 0.62 }
Config.ENDLESS_WAVE_BUDGET_GROWTH = 0.18

Config.WAVE_PLANS = {
    [1] = { baseBudget = 10, budgetGrowth = 0.10, candidates = { "wild_boar", "shell_imp" } },
    [2] = { baseBudget = 14, budgetGrowth = 0.11, candidates = { "gray_wolf", "black_wolf" }, locks = { [3] = { "black_wolf" } } },
    [3] = { baseBudget = 18, budgetGrowth = 0.12, candidates = { "green_snake", "gourd_cultivator", "tree_demon", "green_turtle" }, locks = { [1] = { "green_snake" }, [3] = { "tree_demon" } } },
    [4] = { baseBudget = 34, budgetGrowth = 0.12, candidates = { "poison_spider", "spear_guard" }, boss = { id = "tiger_boss", firstWave = 4, repeatEvery = 7 } },
    [5] = { baseBudget = 46, budgetGrowth = 0.13, candidates = { "purple_scorpion", "white_fox", "fox_fire_witch" }, locks = { [4] = { "fox_fire_witch" } } },
    [6] = { baseBudget = 62, budgetGrowth = 0.13, candidates = { "blade_cultivator", "beast_tamer", "flame_golem" }, locks = { [3] = { "flame_golem" } } },
    [7] = { baseBudget = 82, budgetGrowth = 0.14, candidates = { "purple_spike_beast", "lantern_maiden", "white_mage", "three_headed_snake" }, locks = { [1] = { "lantern_maiden" }, [3] = { "white_mage" } } },
    [8] = { baseBudget = 122, budgetGrowth = 0.14, candidates = { "ice_snake", "blue_swordsman", "black_assassin" } },
    [9] = { baseBudget = 220, budgetGrowth = 0.16, candidates = { "purple_cultivator" }, locks = { [1] = { "purple_cultivator", "purple_cultivator" } }, boss = { id = "purple_fire_elder", firstWave = 5, repeatEvery = 5 } },
}

-- ============================================================================
-- 掉落与场上奖励（P4.3）
-- ============================================================================
Config.DROP_RULES = {
    QUALITY_WEIGHTS = {
        { quality = 1, weight = 45 },
        { quality = 2, weight = 30 },
        { quality = 3, weight = 18 },
        { quality = 4, weight = 6 },
        { quality = 5, weight = 1 },
    },
    CATEGORY_WEIGHTS = {
        { category = Config.ITEM_CATEGORY.WEAPON, weight = 45 },
        { category = Config.ITEM_CATEGORY.ARMOR, weight = 25 },
        { category = Config.ITEM_CATEGORY.TALISMAN, weight = 20 },
        { category = Config.ITEM_CATEGORY.PILL, weight = 10 },
    },
}

Config.FIELD_REWARD = {
    SPAWN_CHANCE = 0.06,
    MAX_COUNT = 2,
    HP = 1,
    MIN_INTERVAL = 2,
    PITY_INTERVAL = 10,
    CHANCE_GROWTH_PER_TURN = 0.03,
    MAX_SPAWN_CHANCE = 0.45,
    EARLY_WEAPON_GUARANTEE_TURNS = 8,
    EARLY_WEAPON_GUARANTEE_MIN_COUNT = 2,
    EARLY_WEAPON_WEIGHT_MUL = 2.0,
    RECENT_MEMORY = 3,
    DEPLOYED_COLUMN_BONUS = 2.0,
    EMPTY_COLUMN_PENALTY = 1.2,
    RECENT_COLUMN_PENALTY = 2.0,
    MONSTER_PRESSURE_PENALTY = 0.7,
    RANDOM_JITTER = 0.5,
}

Config.SPAWN_POINT_RULES = {
    RECENT_MEMORY = 3,
    SAME_COLUMN_REPEAT_CHANCE = 0.28,
    SAME_COLUMN_PENALTY = 0.8,
    RECENT_COLUMN_PENALTY = 0.5,
    RESERVED_NEIGHBOR_PENALTY = 0.6,
    COLUMN_LOAD_PENALTY = 1.1,
    EARLY_EMPTY_DEPLOY_PENALTY = 2.5,
    LATE_EMPTY_DEPLOY_PRESSURE = 0.8,
    CENTER_COLUMN_BONUS = 0.35,
    RANDOM_JITTER = 1.4,
}

-- ============================================================================
-- 合成、消耗、分解
-- ============================================================================
Config.MERGE_RULES = {
    REQUIRED_COUNT = 2,
    REROLL_AFFIX = false,
}

Config.BUFFER_MAX = 1
Config.CONSUMABLE_USE_LIMIT = 2
Config.REINCARNATION_DROP_QUALITY_CHANCE = 0.05
Config.REINCARNATION_DROP_QUALITY_CHANCE_CAP = 0.30
Config.DECOMPOSE_EXP = { 2, 6, 15, 35, 80, 200, 500, 1200, 3000 }

-- ============================================================================
-- 天赋点系统（P3）
-- ============================================================================
Config.TALENT = {
    MAX_POINTS = 59,
    PER_POINT_ATK = 0,
    PER_POINT_ATKSPD = 0,
    PER_POINT_HP = 0,
    PER_POINT_EXP = 0,
}

Config.REINCARNATION_REALM_INDEX = Config.GetFirstRealmIndexByMajor(5)
Config.REINCARNATION_EXP_THRESHOLD = Config.GetRealm(Config.GetFirstRealmIndexByMajor(6)).expRequired

-- ============================================================================
-- 玩家
-- ============================================================================
Config.PLAYER = {
    BASE_HP = 100,
    BASE_EXP = 0,
}

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
