-- config/ArmorDefs.lua
-- 5 类护甲道具定义。按设计文档 §6 / P1-3 生成 Q1-Q9 固定防御值模型。

local BASE_DEFENSE = { 6, 12, 24, 48, 96, 192, 384, 768, 1536 }

local ARMORS = {
    { id = "dark_iron_shield", name = "玄铁宝盾", family = "block", weightMod = 0.85 },
    { id = "thorn_armor", name = "荆棘战甲", family = "thorns", weightMod = 1.00 },
    { id = "yuqing_robe", name = "玉清道衣", family = "shield", weightMod = 1.00 },
    { id = "creation_robe", name = "生生造化袍", family = "regen", weightMod = 1.00 },
    { id = "purity_orb", name = "净秽宝珠", family = "cleanse", weightMod = 0.70 },
}

local function Round(value)
    return math.floor(value + 0.5)
end

local function ArmorEffect(family, quality)
    if quality < 5 then return nil end
    if family == "block" then
        local chances = { [5] = 0.15, [6] = 0.25, [7] = 0.40, [8] = 0.50, [9] = 0.60 }
        local reflect = { [7] = 0.10, [8] = 0.15, [9] = 0.20 }
        return { type = "block", blockChance = chances[quality], reflectRatio = reflect[quality] or 0 }
    elseif family == "thorns" then
        local ratios = { [5] = 0.15, [6] = 0.20, [7] = 0.30, [8] = 0.35, [9] = 0.40 }
        return { type = "thorns", reflectRatio = ratios[quality], bleedRatio = quality >= 7 and (quality == 7 and 0.50 or (quality == 8 and 0.75 or 1.00)) or 0 }
    elseif family == "shield" then
        local values = { [5] = 20, [6] = 30, [7] = 50, [8] = 70, [9] = 100 }
        return { type = "turnShield", shield = values[quality], carryBonus = quality >= 7 and 20 or 0 }
    elseif family == "regen" then
        local regen = { [5] = 15, [6] = 25, [7] = 40, [8] = 60, [9] = 80 }
        local hitHeal = { [7] = 10, [8] = 15, [9] = 20 }
        return { type = "regen", perTurn = regen[quality], onHit = hitHeal[quality] or 0 }
    elseif family == "cleanse" then
        return { type = "cleanse", cleanseCount = quality >= 7 and 99 or 1, cleanseAll = quality >= 7, immunityTurns = quality == 6 and 1 or (quality == 7 and 2 or (quality == 8 and 3 or (quality == 9 and 99 or 0))) }
    end
    return nil
end

local defs = {}
for _, spec in ipairs(ARMORS) do
    for quality = 1, 9 do
        local defense = Round(BASE_DEFENSE[quality] * spec.weightMod)
        table.insert(defs, {
            id = string.format("armor_%s_q%d", spec.id, quality),
            baseId = spec.id,
            category = "armor",
            quality = quality,
            name = spec.name,
            family = spec.family,
            power = defense,
            weight = 1,
            defense = defense,
            armorEffect = ArmorEffect(spec.family, quality),
        })
    end
end

return defs
