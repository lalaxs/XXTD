-- config/TalismanDefs.lua
-- 5 张符咒定义。按设计文档 P1-5 生成 Q1-Q9 消耗池。

local DAMAGE = { 20, 40, 80, 160, 320, 640, 1280, 2560, 5120 }
local TARGET_COUNTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local ROOT_TURNS = { 1, 1, 2, 2, 3, 3, 4, 4, 5 }
local ARMOR_BREAK = { 0.20, 0.25, 0.30, 0.35, 0.40, 0.50, 0.60, 0.70, 0.80 }
local ATTACK_DOWN = { 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60 }
local VULNERABLE = { 0.10, 0.12, 0.15, 0.18, 0.20, 0.22, 0.25, 0.28, 0.30 }

local TALISMANS = {
    { id = "thunder", name = "雷符", family = "damage" },
    { id = "root", name = "定身符", family = "root" },
    { id = "armor_break", name = "破甲符", family = "armor_break" },
    { id = "attack_down", name = "削攻符", family = "attack_down" },
    { id = "vulnerable", name = "易伤符", family = "vulnerable" },
}

local function DurationByQuality(quality)
    if quality >= 9 then return 5 end
    if quality >= 7 then return 4 end
    if quality >= 5 then return 3 end
    return 2
end

local function BuildEffect(family, quality)
    local targetCount = TARGET_COUNTS[quality]
    if family == "damage" then
        return { type = "damage", value = DAMAGE[quality], targetCount = targetCount }
    elseif family == "root" then
        return { type = "root", turns = ROOT_TURNS[quality], targetCount = targetCount }
    elseif family == "armor_break" then
        return { type = "armorBreak", value = ARMOR_BREAK[quality], duration = DurationByQuality(quality), targetCount = targetCount }
    elseif family == "attack_down" then
        return { type = "attackDown", value = ATTACK_DOWN[quality], duration = DurationByQuality(quality), targetCount = targetCount }
    elseif family == "vulnerable" then
        return { type = "vulnerable", value = VULNERABLE[quality], duration = DurationByQuality(quality), targetCount = targetCount }
    end
    return nil
end

local defs = {}
for _, spec in ipairs(TALISMANS) do
    for quality = 1, 9 do
        local effect = BuildEffect(spec.family, quality)
        local damage = effect and effect.type == "damage" and effect.value or 0
        table.insert(defs, {
            id = string.format("talisman_%s_q%d", spec.id, quality),
            baseId = spec.id,
            category = "talisman",
            quality = quality,
            name = spec.name,
            family = spec.family,
            power = effect and effect.value or 0,
            weight = 1,
            talismanEffect = effect,
            aoeDmg = damage,
            targetCount = effect and effect.targetCount or 1,
            aoeRange = 1,
            controlType = effect and effect.type == "root" and "root" or "none",
            controlDuration = effect and effect.turns or 0,
        })
    end
end

return defs
