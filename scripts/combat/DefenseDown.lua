local DefenseDown = {}

local MAX_DEFENSE_DOWN = 0.70

local function IsActive(effect)
    return effect and (effect.value or 0) > 0 and (effect.turns or 0) > 0
end

local function UpsertEffect(monster, key, kind, value, turns, direct)
    monster.defenseDownEffects = monster.defenseDownEffects or {}
    local effect = monster.defenseDownEffects[key] or {}
    effect.kind = kind
    effect.value = math.max(effect.value or 0, value or 0)
    effect.turns = math.max(effect.turns or 0, turns or 0)
    effect.direct = direct == true
    monster.defenseDownEffects[key] = effect
    return effect
end

function DefenseDown.Recalculate(monster)
    local whiteBase = 0
    local whiteMarrow = 0
    local external = 0
    local maxTurns = 0

    for key, effect in pairs(monster.defenseDownEffects or {}) do
        if IsActive(effect) then
            maxTurns = math.max(maxTurns, effect.turns)
            if effect.kind == "white_base" then
                whiteBase = math.max(whiteBase, effect.value)
            elseif effect.kind == "white_marrow" then
                whiteMarrow = math.max(whiteMarrow, effect.value)
            elseif effect.kind == "external" then
                external = math.max(external, effect.value)
            end
        else
            monster.defenseDownEffects[key] = nil
        end
    end

    local whiteTotal = math.min(MAX_DEFENSE_DOWN, whiteBase + whiteMarrow)
    local finalValue = math.min(MAX_DEFENSE_DOWN, math.max(whiteTotal, external))
    monster.baseDefenseDown = whiteBase > 0 and whiteBase or nil
    monster.marrowDefenseDown = whiteMarrow > 0 and whiteMarrow or nil
    monster.talismanDefenseDown = external > 0 and external or nil
    monster.whiteBoneDefenseDown = whiteTotal > 0 and whiteTotal or nil
    monster.defenseDown = finalValue > 0 and finalValue or nil
    monster.defenseDownTurns = maxTurns > 0 and maxTurns or nil
    return finalValue
end

function DefenseDown.ApplyWhiteBase(monster, sourceKey, value, turns, direct)
    UpsertEffect(monster, "white_base:" .. tostring(sourceKey), "white_base", value, turns, direct)
    return DefenseDown.Recalculate(monster)
end

function DefenseDown.ApplyWhiteMarrow(monster, sourceKey, value, turns)
    monster.defenseDownEffects = monster.defenseDownEffects or {}
    monster.defenseDownEffects["white_marrow:" .. tostring(sourceKey)] = {
        kind = "white_marrow",
        value = math.max(0, value or 0),
        turns = math.max(0, turns or 0),
        direct = true,
    }
    return DefenseDown.Recalculate(monster)
end

function DefenseDown.ApplyExternal(monster, sourceKey, value, turns)
    UpsertEffect(monster, "external:" .. tostring(sourceKey), "external", value, turns, false)
    return DefenseDown.Recalculate(monster)
end

function DefenseDown.GetWhiteBoneValue(monster)
    DefenseDown.Recalculate(monster)
    return monster.whiteBoneDefenseDown or 0
end

function DefenseDown.GetWhiteBoneTurns(monster)
    local maxTurns = 0
    for _, effect in pairs(monster.defenseDownEffects or {}) do
        if IsActive(effect) and (effect.kind == "white_base" or effect.kind == "white_marrow") then
            maxTurns = math.max(maxTurns, effect.turns)
        end
    end
    return maxTurns
end

function DefenseDown.GetSpreadableWhiteBone(monster)
    local directBase = 0
    local marrow = 0
    local maxTurns = 0
    for _, effect in pairs(monster.defenseDownEffects or {}) do
        if IsActive(effect) then
            if effect.kind == "white_base" and effect.direct then
                directBase = math.max(directBase, effect.value)
                maxTurns = math.max(maxTurns, effect.turns)
            elseif effect.kind == "white_marrow" then
                marrow = math.max(marrow, effect.value)
                maxTurns = math.max(maxTurns, effect.turns)
            end
        end
    end
    return math.min(MAX_DEFENSE_DOWN, directBase + marrow), maxTurns
end

function DefenseDown.HasDirectWhiteBone(monster)
    for _, effect in pairs(monster.defenseDownEffects or {}) do
        if IsActive(effect) and effect.kind == "white_base" and effect.direct then
            return true
        end
    end
    return false
end

function DefenseDown.ExtendWhiteBone(monster, turns)
    local extended = false
    for _, effect in pairs(monster.defenseDownEffects or {}) do
        if IsActive(effect) and (effect.kind == "white_base" or effect.kind == "white_marrow") then
            effect.turns = effect.turns + (turns or 0)
            extended = true
        end
    end
    if extended then DefenseDown.Recalculate(monster) end
    return extended
end

function DefenseDown.Tick(monster)
    for _, effect in pairs(monster.defenseDownEffects or {}) do
        if (effect.turns or 0) > 0 then
            effect.turns = effect.turns - 1
        end
    end
    return DefenseDown.Recalculate(monster)
end

return DefenseDown
