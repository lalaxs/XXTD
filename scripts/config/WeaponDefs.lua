-- config/WeaponDefs.lua
-- 15 把攻击法宝的 Q1-Q9 累计成长配置；战斗逻辑读取这些字段而非旧 signature 简化效果。

local BASE_DAMAGE = { 12, 24, 48, 96, 192, 384, 768, 1536, 3072 }

local WEAPONS = {
    { id = "qingfeng_sword", name = "青锋剑", school = "sword", mode = "single", coefficient = 1.00 },
    { id = "chiyan_spear", name = "赤焰枪", school = "spear", mode = "pierce", coefficient = 0.90 },
    { id = "qingyu_fan", name = "青羽扇", school = "magic", mode = "sweep", coefficient = 0.85 },
    { id = "ziqi_gourd", name = "紫气葫芦", school = "magic", mode = "single", coefficient = 0.75 },
    { id = "jinguang_ring", name = "金光环", school = "magic", mode = "single", coefficient = 0.80 },
    { id = "qingyin_qin", name = "清音琴", school = "magic", mode = "single", coefficient = 0.85 },
    { id = "baigu_staff", name = "白骨杖", school = "magic", mode = "single", coefficient = 0.90 },
    { id = "fuyao_chain", name = "缚妖链", school = "chain", mode = "single", coefficient = 0.90 },
    { id = "zhenyao_tower", name = "镇妖塔", school = "tower", mode = "area", coefficient = 0.80 },
    { id = "double_blade_chain", name = "双刃锁链", school = "chain", mode = "single", coefficient = 0.85 },
    { id = "bishui_sword", name = "碧水剑", school = "sword", mode = "single", coefficient = 0.95 },
    { id = "lingmo_brush", name = "灵墨笔", school = "magic", mode = "single", coefficient = 0.80 },
    { id = "pozhen_spear", name = "破阵枪", school = "spear", mode = "pierce", coefficient = 0.90 },
    { id = "taiji_sword", name = "太极剑", school = "sword", mode = "single", coefficient = 0.95 },
    { id = "huxin_pearl", name = "护心珠", school = "guardian", mode = "single", coefficient = 0.80 },
}

local function Round(value) return math.floor(value + 0.5) end
local function LowCrit(q) return math.min(3, q) * 0.05 end
local function BonusAt(q, start, step, cap)
    if q < start then return 0 end
    return math.min(cap or 99, q - start + 1) * step
end

local function ApplyGrowth(def)
    local q = def.quality
    local id = def.baseId
    def.crit = LowCrit(q)
    if id == "bishui_sword" then
        def.crit = 1.0
        def.critMultiplier = 1.10 + math.min(3, q) * 0.05
        def.weaponDamagePct = BonusAt(q, 4, 0.05, 3)
        def.maxHpDamagePct = q >= 9 and 0.05 or (q >= 8 and 0.03 or (q >= 7 and 0.01 or 0))
    elseif id == "qingfeng_sword" then
        def.highHpThreshold = 0.80 - BonusAt(q, 7, 0.05, 3)
        def.highHpBonusPct = 0.20 + BonusAt(q, 4, 0.10, 3)
    elseif id == "taiji_sword" then
        def.lowHpThreshold = 0.20 + BonusAt(q, 7, 0.05, 3)
        def.lowHpBonusPct = 0.15 + BonusAt(q, 4, 0.10, 3)
    elseif id == "qingyu_fan" then
        def.splashRatio = 0.20 + (q >= 8 and 0.30 or (q >= 7 and 0.20 or BonusAt(q, 4, 0.05, 3)))
        def.splashCount = q >= 9 and 3 or 1
    elseif id == "fuyao_chain" then
        def.crit = 0.20 + LowCrit(q)
        def.critMultiplier = 2.0 + BonusAt(q, 4, 0.05, 3)
        def.chainCritStep = q >= 9 and 0.05 or (q >= 8 and 0.03 or (q >= 7 and 0.01 or 0))
    elseif id == "lingmo_brush" then
        def.lowPlayerDamagePct = q >= 6 and 0.35 or (q >= 5 and 0.30 or (q >= 4 and 0.25 or 0.20))
        def.lowPlayerLayerPct = q >= 9 and 0.10 or (q >= 8 and 0.06 or (q >= 7 and 0.03 or 0))
    elseif id == "huxin_pearl" then
        def.attackDownPct = 0.10 + BonusAt(q, 4, 0.10, 3)
        def.blindChance = q >= 9 and 0.25 or (q >= 8 and 0.15 or (q >= 7 and 0.10 or 0))
    elseif id == "baigu_staff" then
        def.defenseDownBonus = BonusAt(q, 4, 0.10, 3)
        def.defenseDownDamagePct = BonusAt(q, 7, 0.05, 3)
    elseif id == "qingyin_qin" then
        def.rootChance = 0.20 + BonusAt(q, 4, 0.05, 3)
        def.rootCooldown = 4 - BonusAt(q, 7, 1, 3)
    elseif id == "zhenyao_tower" then
        def.globalDamagePct = 0.025 + BonusAt(q, 4, 0.025, 3)
        def.doubleCastChance = q >= 9 and 0.15 or (q >= 8 and 0.10 or (q >= 7 and 0.05 or 0))
    elseif id == "ziqi_gourd" then
        def.healChance = 0.08 + BonusAt(q, 4, 0.02, 3)
        def.healDamagePct = 0.01
        def.doubleDamageChance = q >= 9 and 0.15 or (q >= 8 and 0.10 or (q >= 7 and 0.05 or 0))
    elseif id == "pozhen_spear" then
        def.defIgnore = 1.0
        def.baseDefenseDamagePct = q >= 6 and 1.00 or (q >= 5 and 0.60 or (q >= 4 and 0.30 or 0))
        def.weaponDamagePct = BonusAt(q, 7, 0.05, 3)
    elseif id == "jinguang_ring" then
        def.knockbackChance = 0.10 + BonusAt(q, 4, 0.05, 3)
        def.collisionDamagePct = q >= 9 and 1.50 or (q >= 8 and 1.10 or (q >= 7 and 0.70 or 0))
    elseif id == "chiyan_spear" then
        def.burnDamagePct = q >= 6 and 0.20 or (q >= 5 and 0.15 or (q >= 4 and 0.10 or 0.05))
        def.extraBurnChance = q >= 9 and 0.60 or (q >= 8 and 0.40 or (q >= 7 and 0.20 or 0))
    elseif id == "double_blade_chain" then
        def.segmentDamagePct = q >= 6 and 0.55 or (q >= 5 and 0.51 or (q >= 4 and 0.48 or 0.45))
        def.tripleChance = q >= 9 and 0.15 or (q >= 8 and 0.10 or (q >= 7 and 0.05 or 0))
    end
end

local defs = {}
for _, spec in ipairs(WEAPONS) do
    for quality = 1, 9 do
        local atk = Round(BASE_DAMAGE[quality] * spec.coefficient)
        local def = {
            id = string.format("weapon_%s_q%d", spec.id, quality), baseId = spec.id,
            category = "weapon", quality = quality, name = spec.name, school = spec.school,
            attackMode = spec.mode, coefficient = spec.coefficient, description = spec.name .. "攻击法宝。",
            power = atk, atk = atk, crit = 0, defIgnore = 0,
        }
        ApplyGrowth(def)
        table.insert(defs, def)
    end
end
return defs
