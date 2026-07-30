-- views/StatusPresenter.lua
-- 汇总当前战斗中的玩家增益/减益状态，用于 HUD 与状态列表展示。

local StatusPresenter = {}

local function Percent(value)
    return math.floor((value or 0) * 100 + 0.5)
end

local function AddStatus(list, kind, name, desc, turns, valueText)
    table.insert(list, {
        kind = kind,
        name = name,
        desc = desc,
        turns = turns,
        valueText = valueText,
    })
end

local function SumShieldBuffs(state)
    local total = 0
    for _, buff in ipairs(state.buffs or {}) do
        if buff.type == "shield" and (buff.value or 0) > 0 then
            total = total + buff.value
        end
    end
    return math.floor(total + 0.5)
end

local function CountTableEntries(t)
    local count = 0
    if not t then return 0 end
    for _, _ in pairs(t) do
        count = count + 1
    end
    return count
end

function StatusPresenter.GetShieldValue(state)
    if not state then return 0 end
    return SumShieldBuffs(state) + math.floor((state.armorShield or 0) + 0.5)
end

function StatusPresenter.BuildStatuses(state)
    local list = {}
    if not state then return list end

    local shieldValue = StatusPresenter.GetShieldValue(state)
    if shieldValue > 0 then
        AddStatus(list, "buff", "护盾", "优先吸收即将受到的伤害", nil, tostring(shieldValue))
    end

    for _, buff in ipairs(state.buffs or {}) do
        local turns = buff.remainTurns or 0
        if buff.type == "shield" then
            -- 护盾类增益只计入总护盾值，不单独显示来源和回合数。
        elseif buff.type == "atkUp" then
            AddStatus(list, "buff", "法宝增伤", "提升法宝造成的伤害", turns, "+" .. Percent(buff.value) .. "%")
        elseif buff.type == "allUp" then
            AddStatus(list, "buff", "攻防强化", "提升法宝伤害，并降低受到的伤害", turns, "±" .. Percent(buff.value) .. "%")
        else
            AddStatus(list, "buff", tostring(buff.type or "增益"), "临时增益效果", turns, tostring(buff.value or ""))
        end
    end

    if (state.debuffImmunityTurns or 0) > 0 then
        AddStatus(list, "buff", "负面免疫", "免疫怪物施加的负面状态", state.debuffImmunityTurns, nil)
    end

    if (state.deathSaveRatio or 0) > 0 then
        AddStatus(list, "buff", "免死护佑", "气血归零时触发并消耗", nil, Percent(state.deathSaveRatio) .. "%")
    end

    local playerDebuffs = state.playerDebuffs or {}
    if playerDebuffs.attackDown and (playerDebuffs.attackDown.turns or 0) > 0 then
        AddStatus(list, "debuff", "减攻", "法宝造成的伤害降低", playerDebuffs.attackDown.turns, "-" .. Percent(playerDebuffs.attackDown.value) .. "%")
    end
    if playerDebuffs.vulnerable and (playerDebuffs.vulnerable.turns or 0) > 0 then
        AddStatus(list, "debuff", "易伤", "受到的怪物伤害提高", playerDebuffs.vulnerable.turns, "+" .. Percent(playerDebuffs.vulnerable.value) .. "%")
    end

    local sealedCount = CountTableEntries(state.sealedSlots)
    if sealedCount > 0 then
        AddStatus(list, "debuff", "法宝封印", string.format("%d 个攻击法宝暂时无法行动", sealedCount), nil, tostring(sealedCount))
    end

    if (state.poisonStacks or 0) > 0 then
        AddStatus(list, "debuff", "腐毒", "每回合按最大气血受到伤害", nil, tostring(state.poisonStacks) .. "层")
    end

    if (state.itemSilenceTurns or 0) > 0 then
        AddStatus(list, "debuff", "灾厄压制", "攻击法宝暂时无法行动", state.itemSilenceTurns, nil)
    end

    return list
end

function StatusPresenter.BuildPreviewStatuses()
    local list = {}
    AddStatus(list, "buff", "护盾", "优先吸收即将受到的伤害", nil, "208")
    AddStatus(list, "buff", "法宝增伤", "提升法宝造成的伤害", 2, "+25%")
    AddStatus(list, "buff", "攻防强化", "提升法宝伤害，并降低受到的伤害", 2, "±20%")
    AddStatus(list, "buff", "负面免疫", "免疫怪物施加的负面状态", 2, nil)
    AddStatus(list, "buff", "免死护佑", "气血归零时触发并消耗", nil, "1次")
    AddStatus(list, "debuff", "减攻", "法宝造成的伤害降低", 2, "-25%")
    AddStatus(list, "debuff", "易伤", "受到的怪物伤害提高", 3, "+20%")
    AddStatus(list, "debuff", "法宝封印", "2 个攻击法宝暂时无法行动", nil, "2")
    AddStatus(list, "debuff", "腐毒", "每回合按最大气血受到伤害", nil, "3层")
    AddStatus(list, "debuff", "灾厄压制", "攻击法宝暂时无法行动", 1, nil)
    return list
end

return StatusPresenter
