-- config/WeaponDefs.lua
-- 15 把具名攻击法宝定义。按设计文档 P1-2 生成 Q1-Q9 道具池。

local BASE_DAMAGE = { 12, 24, 48, 96, 192, 384, 768, 1536, 3072 }

local WEAPONS = {
    { id = "qingfeng_sword", name = "青锋剑", school = "sword", mode = "single", coefficient = 1.00, tendency = "burst", signature = "crit" },
    { id = "chiyan_spear", name = "赤焰枪", school = "spear", mode = "pierce", coefficient = 0.90, tendency = "dot", signature = "burn" },
    { id = "qingyu_fan", name = "青羽扇", school = "magic", mode = "sweep", coefficient = 0.85, tendency = "area", signature = "wind_mark" },
    { id = "ziqi_gourd", name = "紫气葫芦", school = "magic", mode = "area", coefficient = 0.75, tendency = "dot_area", signature = "poison" },
    { id = "jinguang_ring", name = "金光环", school = "magic", mode = "area", coefficient = 0.80, tendency = "debuff", signature = "attack_down_aura" },
    { id = "qingyin_qin", name = "清音琴", school = "magic", mode = "sweep", coefficient = 0.85, tendency = "control", signature = "root" },
    { id = "baigu_staff", name = "白骨杖", school = "magic", mode = "single", coefficient = 0.90, tendency = "debuff", signature = "defense_down" },
    { id = "fuyao_chain", name = "缚妖链", school = "chain", mode = "control", coefficient = 0.90, tendency = "control", signature = "root_lock" },
    { id = "zhenyao_tower", name = "镇妖塔", school = "tower", mode = "area", coefficient = 0.80, tendency = "suppress", signature = "attack_down_area" },
    { id = "double_blade_chain", name = "双刃锁链", school = "chain", mode = "sweep", coefficient = 0.85, tendency = "displace", signature = "pull" },
    { id = "bishui_sword", name = "碧水剑", school = "sword", mode = "single", coefficient = 0.95, tendency = "debuff", signature = "attack_down" },
    { id = "lingmo_brush", name = "灵墨笔", school = "magic", mode = "area", coefficient = 0.80, tendency = "vulnerable", signature = "vulnerability" },
    { id = "pozhen_spear", name = "破阵枪", school = "spear", mode = "pierce", coefficient = 0.90, tendency = "pierce_debuff", signature = "armor_break" },
    { id = "taiji_sword", name = "太极剑", school = "sword", mode = "single", coefficient = 0.95, tendency = "displace", signature = "knockback" },
    { id = "huxin_pearl", name = "护心珠", school = "guardian", mode = "guardian", coefficient = 0.80, tendency = "guardian", signature = "guardian_attack_down" },
}

local function BuildWeaponDescription(spec)
    local modeNames = {
        single = "单体攻击",
        pierce = "穿透攻击",
        sweep = "扇形攻击",
        area = "范围攻击",
        control = "控制攻击",
        guardian = "守护攻击",
    }
    local tendencyNames = {
        burst = "擅长暴击",
        dot = "擅长持续伤害",
        area = "擅长范围压制",
        dot_area = "擅长范围持续伤害",
        debuff = "擅长施加减益",
        control = "擅长定身控制",
        displace = "擅长位移控场",
        vulnerable = "擅长施加易伤",
        pierce_debuff = "擅长破甲穿透",
        guardian = "擅长守护削弱",
    }
    return string.format("%s，%s。", modeNames[spec.mode] or "法宝攻击", tendencyNames[spec.tendency] or "拥有独特效果")
end

local function Round(value)
    return math.floor(value + 0.5)
end

local function PierceCount(quality)
    if quality < 5 then return 0 end
    if quality == 5 then return 1 end
    if quality == 6 then return 2 end
    return 99
end

local function SplashRatio(quality)
    if quality <= 2 then return 0.30 end
    if quality <= 4 then return 0.40 end
    if quality <= 6 then return 0.50 end
    if quality <= 8 then return 0.60 end
    return 0.80
end

local function AreaPattern(quality)
    if quality < 5 then return "same_col_adjacent" end
    if quality < 7 then return "adjacent_col_same_row" end
    if quality < 9 then return "square_3x3" end
    return "global"
end

local function HighTierEffect(signature, quality)
    if quality < 5 then return nil end
    local tier = quality >= 9 and 9 or (quality >= 8 and 8 or (quality >= 7 and 7 or (quality >= 6 and 6 or 5)))
    return { signature = signature, tier = tier }
end

local defs = {}
for _, spec in ipairs(WEAPONS) do
    for quality = 1, 9 do
        local atk = Round(BASE_DAMAGE[quality] * spec.coefficient)
        local def = {
            id = string.format("weapon_%s_q%d", spec.id, quality),
            baseId = spec.id,
            category = "weapon",
            quality = quality,
            name = spec.name,
            school = spec.school,
            attackMode = spec.mode,
            coefficient = spec.coefficient,
            tendency = spec.tendency,
            signature = spec.signature,
            description = BuildWeaponDescription(spec),
            power = atk,
            weight = 1,
            atk = atk,
            atkSpeed = 1.0,
            crit = 0.0,
            defIgnore = 0.0,
            pierceCount = spec.mode == "pierce" and PierceCount(quality) or 0,
            splashRatio = spec.mode == "sweep" and SplashRatio(quality) or 0,
            areaPattern = (spec.mode == "area" or spec.mode == "guardian") and AreaPattern(quality) or nil,
            specialEffect = HighTierEffect(spec.signature, quality),
        }
        if spec.signature == "crit" and quality >= 5 then
            def.crit = quality == 5 and 0.15 or (quality == 6 and 0.20 or 1.0)
            def.critMultiplier = quality >= 8 and 2.5 or 2.0
        end
        if spec.signature == "armor_break" and quality >= 5 then
            def.defIgnore = quality == 5 and 0.20 or (quality == 6 and 0.30 or (quality == 7 and 0.50 or (quality == 8 and 0.70 or 1.0)))
        end
        table.insert(defs, def)
    end
end

return defs
