-- DailyChallenge.lua
-- 全服共享日期种子的每日挑战配置、标签与确定性随机。

local Config = require("Config")

local DailyChallenge = {}

local RULESET_VERSION = 1
local BEIJING_OFFSET_SECONDS = 8 * 60 * 60
local RNG_MODULUS = 2147483647
local RNG_MULTIPLIER = 48271

local TAG_LIBRARY = {
    {
        id = "monster_tide",
        name = "妖潮汹涌",
        description = "妖魔刷新概率提高35%，单次刷新数量提高25%。",
        kind = "pressure",
        effects = { monsterSpawnChanceMul = 1.35, monsterSpawnCountMul = 1.25 },
        conflicts = { "solitary_ogres", "monster_tide_plus" },
    },
    {
        id = "solitary_ogres",
        name = "独行大妖",
        description = "每次刷新妖魔更少，但妖魔生命与攻击提高35%。",
        kind = "pressure",
        effects = { monsterSpawnCountMul = 0.65, monsterHpMul = 1.35, monsterAtkMul = 1.35 },
        conflicts = { "monster_tide", "monster_tide_plus" },
    },
    {
        id = "monster_tide_plus",
        name = "妖潮加剧",
        description = "妖魔刷新概率提高20%，单次刷新数量提高15%，但妖魔生命降低15%。",
        kind = "pressure",
        effects = { monsterSpawnChanceMul = 1.20, monsterSpawnCountMul = 1.15, monsterHpMul = 0.85 },
        conflicts = { "solitary_ogres", "monster_tide" },
    },
    {
        id = "sharp_fangs",
        name = "锋芒毕露",
        description = "妖魔攻击提高30%，防御降低25%。",
        kind = "neutral",
        effects = { monsterAtkMul = 1.30, monsterDefenseMul = 0.75 },
    },
    {
        id = "iron_armor",
        name = "铁甲妖军",
        description = "妖魔生命提高25%，防御提高50%。",
        kind = "pressure",
        effects = { monsterHpMul = 1.25, monsterDefenseMul = 1.50 },
    },
    {
        id = "same_column_swarm",
        name = "群妖同列",
        description = "妖魔更容易沿最近出现的路线持续刷新。",
        kind = "pressure",
        effects = { sameColumnRepeatChanceAdd = 0.35 },
        conflicts = { "trapped_beast" },
    },
    {
        id = "trapped_beast",
        name = "困兽犹斗",
        description = "妖魔进入靠近下方的3格时狂暴：攻击+75%，防御+60%。",
        kind = "pressure",
        effects = {
            enrageRowsFromBottom = 3,
            enrageAttackMul = 1.75,
            enrageDefenseMul = 1.60,
        },
        conflicts = { "monster_tide", "same_column_swarm" },
    },
    {
        id = "weapons_abound",
        name = "百器初现",
        description = "场地刷新中，攻击法宝出现权重提高80%。",
        kind = "benefit",
        effects = { itemCategoryWeightMul_weapon = 1.80 },
        conflicts = { "defenses_abound" },
    },
    {
        id = "defenses_abound",
        name = "守势为先",
        description = "场地刷新中，防御法宝出现权重提高80%。",
        kind = "benefit",
        effects = { itemCategoryWeightMul_armor = 1.80 },
        conflicts = { "weapons_abound" },
    },
    {
        id = "premium_stock",
        name = "上品云集",
        description = "商品与场地奖励最低品质提高1阶，商铺刷新基础及封顶价格提高50%。",
        kind = "neutral",
        effects = { rewardQualityShift = 1, shopRefreshBaseMul = 1.50, shopRefreshMaxMul = 1.50 },
        conflicts = { "cheap_market" },
    },
    {
        id = "cheap_market",
        name = "灵市低价",
        description = "商铺刷新基础及封顶价格降低40%。",
        kind = "benefit",
        effects = { shopRefreshBaseMul = 0.60, shopRefreshMaxMul = 0.60 },
        conflicts = { "premium_stock", "restless_market", "wealth_path" },
    },
    {
        id = "restless_market",
        name = "灵市躁动",
        description = "首次刷新更便宜，但每次刷新涨价更快，封顶价格提高80%。",
        kind = "neutral",
        effects = { shopRefreshBaseMul = 0.60, shopRefreshStepMul = 1.80, shopRefreshMaxMul = 1.80 },
        conflicts = { "cheap_market" },
    },
    {
        id = "wealth_opens_paths",
        name = "财可通神",
        description = "初始金币+20，商铺刷新及封顶价格提高30%。",
        kind = "benefit",
        effects = { initialCoinsAdd = 20, shopRefreshBaseMul = 1.30, shopRefreshStepMul = 1.30, shopRefreshMaxMul = 1.30 },
    },
    {
        id = "wealth_path",
        name = "财路亨通",
        description = "妖魔击杀金币掉落概率提高15个百分点，但商铺刷新价格提高40%。",
        kind = "benefit",
        effects = {
            killCoinDropChanceAdd = 0.15,
            shopRefreshBaseMul = 1.40,
            shopRefreshStepMul = 1.40,
            shopRefreshMaxMul = 1.40,
        },
        conflicts = { "cheap_market" },
    },
    {
        id = "cultivation_tide",
        name = "修行如潮",
        description = "妖魔提供的修为提高25%，但妖魔攻击提高15%。",
        kind = "neutral",
        effects = { monsterExpMul = 1.25, monsterAtkMul = 1.15 },
    },
    {
        id = "soul_contract",
        name = "噬魂灵契",
        description = "击杀妖魔恢复最大生命的1.5%，但最大生命降低20%。",
        kind = "benefit",
        effects = { killHealPctAdd = 0.015, playerMaxHpMul = 0.80 },
        conflicts = { "endless_vitality", "desperate_gamble" },
    },
    {
        id = "desperate_gamble",
        name = "破釜沉舟",
        description = "我方法宝伤害提高30%，最大生命降低30%。",
        kind = "neutral",
        effects = { playerDamageMul = 1.30, playerMaxHpMul = 0.70 },
        conflicts = { "endless_vitality", "soul_contract" },
    },
    {
        id = "endless_vitality",
        name = "生生不息",
        description = "每回合额外恢复最大生命的3%。",
        kind = "benefit",
        effects = { turnRegenPctAdd = 0.03 },
        conflicts = { "desperate_gamble", "spirit_withering", "soul_contract" },
    },
    {
        id = "spirit_withering",
        name = "灵息枯竭",
        description = "每回合自然恢复失效。",
        kind = "pressure",
        effects = { disableTurnRegen = 1 },
        conflicts = { "endless_vitality" },
    },
    {
        id = "patient_growth",
        name = "厚积薄发",
        description = "前3回合法宝伤害降低20%，之后每回合提高8%。",
        kind = "neutral",
        effects = { patientGrowthEarlyTurns = 3, patientGrowthEarlyMul = 0.80, patientGrowthPerTurn = 0.08 },
    },
    {
        id = "attack_focus",
        name = "攻守偏锋",
        description = "攻击法宝伤害提高20%，防御法宝效果降低20%。",
        kind = "neutral",
        effects = { playerDamageMul = 1.20, armorEffectMul = 0.80 },
        conflicts = { "defense_focus" },
    },
    {
        id = "defense_focus",
        name = "固守灵台",
        description = "防御法宝效果提高25%，攻击法宝伤害降低15%。",
        kind = "neutral",
        effects = { armorEffectMul = 1.25, playerDamageMul = 0.85 },
        conflicts = { "attack_focus" },
    },
    {
        id = "wealthy_but_fragile",
        name = "财散人安",
        description = "初始金币+30，最大生命降低20%。",
        kind = "benefit",
        effects = { initialCoinsAdd = 30, playerMaxHpMul = 0.80 },
    },
}

local TAGS_BY_ID = {}
for _, tag in ipairs(TAG_LIBRARY) do
    TAGS_BY_ID[tag.id] = tag
end

local function GetAuthorityTime()
    if common and common.get_server_time then
        local ok, timestamp = pcall(common.get_server_time)
        if ok and type(timestamp) == "number" and timestamp > 0 then
            return math.floor(timestamp), true
        end
    end
    return nil, false
end

local function HashString(text)
    local hash = 146959810
    for i = 1, #text do
        hash = (hash * 16777619 + string.byte(text, i)) % RNG_MODULUS
    end
    return math.max(1, math.floor(hash))
end

local function NextSeed(seed)
    return (seed * RNG_MULTIPLIER) % RNG_MODULUS
end

local function RollLocal(seed)
    local nextSeed = NextSeed(seed)
    return nextSeed, nextSeed / RNG_MODULUS
end

local function HasConflict(tag, selected)
    for _, picked in ipairs(selected) do
        if tag.id == picked.id then return true end

        for _, conflictId in ipairs(tag.conflicts or {}) do
            if conflictId == picked.id then return true end
        end
        for _, conflictId in ipairs(picked.conflicts or {}) do
            if conflictId == tag.id then return true end
        end
    end
    return false
end

local function PickTag(seed, selected, requiredKind)
    local candidates = {}
    for _, tag in ipairs(TAG_LIBRARY) do
        if (not requiredKind or tag.kind == requiredKind) and not HasConflict(tag, selected) then
            table.insert(candidates, tag)
        end
    end
    if #candidates == 0 then return seed, nil end

    local roll
    seed, roll = RollLocal(seed)
    local index = math.min(#candidates, math.floor(roll * #candidates) + 1)
    return seed, candidates[index]
end

local function BuildEffects(tags)
    local effects = {}
    for _, tag in ipairs(tags) do
        for key, value in pairs(tag.effects or {}) do
            if key:find("Mul", 1, true) then
                effects[key] = (effects[key] or 1) * value
            else
                effects[key] = (effects[key] or 0) + value
            end
        end
    end
    return effects
end

local function BuildTags(seed)
    local selected = {}

    local benefitTag
    seed, benefitTag = PickTag(seed, selected, "benefit")
    if not benefitTag then return selected end
    table.insert(selected, benefitTag)

    local pressureTag
    seed, pressureTag = PickTag(seed, selected, "pressure")
    if not pressureTag then return {} end
    table.insert(selected, pressureTag)

    local thirdTag
    seed, thirdTag = PickTag(seed, selected, nil)
    if thirdTag then
        table.insert(selected, thirdTag)
    end

    return selected
end

function DailyChallenge.ResolveToday()
    local timestamp, isAuthorityTime = GetAuthorityTime()
    if not isAuthorityTime then
        return {
            available = false,
            isAuthorityTime = false,
        }
    end

    local date = os.date("!%Y-%m-%d", timestamp + BEIJING_OFFSET_SECONDS)
    local seed = HashString("daily-challenge:" .. date .. ":" .. tostring(RULESET_VERSION))
    local tags = BuildTags(seed)

    return {
        available = true,
        isAuthorityTime = isAuthorityTime,
        id = date .. "-v" .. tostring(RULESET_VERSION),
        date = date,
        seed = seed,
        rulesetVersion = RULESET_VERSION,
        tags = tags,
        effects = BuildEffects(tags),
        rngState = seed,
        rngCounter = 0,
    }
end

function DailyChallenge.ApplyToState(state, challenge)
    if not state or not challenge then return end
    state.runMode = "daily_challenge"
    state.dailyChallenge = challenge
    state.runSeed = challenge.seed
end

function DailyChallenge.IsActive(state)
    return state and state.runMode == "daily_challenge" and state.dailyChallenge ~= nil
end

function DailyChallenge.GetEffect(state, key, defaultValue)
    if not DailyChallenge.IsActive(state) then return defaultValue end
    local effects = state.dailyChallenge.effects or {}
    local value = effects[key]
    if value == nil then return defaultValue end
    return value
end

function DailyChallenge.RandomFloat(state)
    if not DailyChallenge.IsActive(state) then
        return math.random()
    end

    local challenge = state.dailyChallenge
    challenge.rngState = NextSeed(math.max(1, math.floor(challenge.rngState or challenge.seed or 1)))
    challenge.rngCounter = (challenge.rngCounter or 0) + 1
    return challenge.rngState / RNG_MODULUS
end

function DailyChallenge.RandomInt(state, minValue, maxValue)
    local min = minValue
    local max = maxValue
    if max == nil then
        max = min
        min = 1
    end
    if max < min then min, max = max, min end
    return min + math.floor(DailyChallenge.RandomFloat(state) * (max - min + 1))
end

function DailyChallenge.GetPlayerDamageMultiplier(state)
    local multiplier = DailyChallenge.GetEffect(state, "playerDamageMul", 1.0)
    local earlyTurns = DailyChallenge.GetEffect(state, "patientGrowthEarlyTurns", 0)
    if earlyTurns > 0 then
        if (state.turn or 0) <= earlyTurns then
            multiplier = multiplier * DailyChallenge.GetEffect(state, "patientGrowthEarlyMul", 1.0)
        else
            local growthTurns = (state.turn or 0) - earlyTurns
            multiplier = multiplier * (1 + growthTurns * DailyChallenge.GetEffect(state, "patientGrowthPerTurn", 0))
        end
    end
    return multiplier
end

function DailyChallenge.TryEnrageMonster(state, monster)
    local rows = DailyChallenge.GetEffect(state, "enrageRowsFromBottom", 0)
    if rows <= 0 or not monster or monster.enraged or (monster.hp or 0) <= 0 then
        return false
    end

    local startRow = math.max(1, Config.FIELD_ROWS - math.floor(rows) + 1)
    if (monster.row or 0) < startRow then return false end

    monster.enraged = true
    monster.atk = math.max(1, math.floor((monster.atk or 1) * DailyChallenge.GetEffect(state, "enrageAttackMul", 1.0) + 0.5))
    monster.defense = math.max(0, math.floor((monster.defense or 0) * DailyChallenge.GetEffect(state, "enrageDefenseMul", 1.0) + 0.5))
    return true
end

function DailyChallenge.GetTagById(tagId)
    return TAGS_BY_ID[tagId]
end

return DailyChallenge
