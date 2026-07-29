-- config/PillDefs.lua
-- 5 类丹药定义。按设计文档 P1-4 生成 Q1-Q9 消耗池。

local HEAL_VALUES = { 30, 60, 120, 240, 480, 960, 1920, 3840, 7680 }
local SHIELD_VALUES = { 30, 60, 120, 240, 480, 960, 1920, 3840, 7680 }
local ATK_BUFF = { 0.05, 0.08, 0.10, 0.12, 0.15, 0.18, 0.20, 0.25, 0.30 }
local SAVE_RATIO = { 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60 }

local PILLS = {
    { id = "juqi", name = "聚气丹", family = "heal" },
    { id = "hutai", name = "护体丹", family = "shield" },
    { id = "qingxin", name = "清心丹", family = "cleanse" },
    { id = "zengyuan", name = "增元丹", family = "attack_buff" },
    { id = "xuming", name = "续命丹", family = "death_save" },
}

local function DurationByQuality(quality)
    if quality >= 9 then return 5 end
    if quality >= 7 then return 4 end
    return 3
end

local function CleanseCount(quality)
    if quality >= 5 then return 99 end
    if quality >= 3 then return 2 end
    return 1
end

local function BuildEffect(family, quality)
    if family == "heal" then
        return { type = "heal", value = HEAL_VALUES[quality], reduction = quality >= 5 and (quality >= 9 and 0.30 or (quality >= 7 and 0.25 or 0.15)) or 0, duration = quality >= 5 and DurationByQuality(quality) or 0, cleanseCount = quality >= 7 and (quality >= 9 and 99 or 1) or 0 }
    elseif family == "shield" then
        return { type = "shield", value = SHIELD_VALUES[quality], duration = DurationByQuality(quality) }
    elseif family == "cleanse" then
        return { type = "cleanse", cleanseCount = CleanseCount(quality), immunityTurns = quality >= 7 and (quality >= 9 and 99 or 2) or 0 }
    elseif family == "attack_buff" then
        return { type = "attackBuff", value = ATK_BUFF[quality], duration = DurationByQuality(quality) }
    elseif family == "death_save" then
        return { type = "deathSave", value = SAVE_RATIO[quality], oncePerRun = true }
    end
    return nil
end

local defs = {}
for _, spec in ipairs(PILLS) do
    for quality = 1, 9 do
        local effect = BuildEffect(spec.family, quality)
        local healPerSec = effect and effect.type == "heal" and effect.value or 0
        table.insert(defs, {
            id = string.format("pill_%s_q%d", spec.id, quality),
            baseId = spec.id,
            category = "pill",
            quality = quality,
            name = spec.name,
            family = spec.family,
            power = effect and effect.value or 0,
            weight = 1,
            pillEffect = effect,
            healPerSec = healPerSec,
            duration = effect and effect.duration or 1,
            teamAtkBonus = effect and effect.type == "attackBuff" and effect.value or 0,
            globalHealAura = false,
        })
    end
end

return defs
