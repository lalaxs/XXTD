-- combat/KillResolver.lua
-- 怪物死亡、修为、击杀回血与场上奖励移除结算。

local RealmSystem = require("RealmSystem")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local Stats = require("combat.Stats")
local VisualEventQueue = require("events.VisualEventQueue")

local KillResolver = {}

local function IsLiveMonster(monster)
    return monster and monster.hp and monster.hp > 0
end

local function AddDamageEvent(state, monster, damage)
    if not monster or damage <= 0 then return end
    local event = {
        col = monster.col,
        row = monster.row,
        dmg = damage,
        target = monster,
    }
    table.insert(state.lastDamageDealt, event)
    VisualEventQueue.PushDamageDealt(state, event)
end

local function IsInPattern(monster, center, pattern)
    if pattern == "global" then return true end
    if pattern == "square_3x3" then
        return math.abs(monster.col - center.col) <= 1 and math.abs(monster.row - center.row) <= 1
    elseif pattern == "adjacent_col_same_row" then
        return math.abs(monster.col - center.col) <= 1 and monster.row == center.row
    end
    return monster.col == center.col and math.abs(monster.row - center.row) <= 1
end

local function TriggerPoisonExplosion(state, source)
    if source.poisonExplosionTriggered or (source.poisonExplosionDamage or 0) <= 0 then return 0 end

    source.poisonExplosionTriggered = true
    local damage = math.floor(source.poisonExplosionDamage or 0)
    local pattern = source.poisonExplosionPattern or "same_col_adjacent"
    local label = source.poisonExplosionLabel or "毒爆"
    local total = 0

    for _, monster in ipairs(state.monsters or {}) do
        if monster ~= source and IsLiveMonster(monster) and IsInPattern(monster, source, pattern) then
            monster.hp = monster.hp - damage
            AddDamageEvent(state, monster, damage)
            total = total + damage
        end
    end

    if total > 0 then
        print(string.format("  [%s] %s 死亡引爆，追加%d范围伤害", label, source.name, total))
    end
    return total
end

local function ResolveMonsterDeaths(state)
    local toRemove = {}
    local killHealPct = RogueRewardSystem.GetModifierValue(state, "killHealPct")
    local totalHeal = 0

    for i, monster in ipairs(state.monsters) do
        if monster.hp <= 0 then
            TriggerPoisonExplosion(state, monster)
            table.insert(toRemove, i)
            local expReward = math.max(1, math.floor(monster.exp or 0))
            local expGain = RealmSystem.AddExp(state, expReward, { deferCheck = true })
            state.score = state.score + expGain
            if killHealPct > 0 then
                totalHeal = totalHeal + math.max(1, math.floor((state.maxHp or 0) * killHealPct))
            end
            print(string.format("  [Kill] %s 被击杀! +%d修为", monster.name, expGain))
        end
    end

    if totalHeal > 0 then
        Stats.Heal(state, totalHeal)
        print(string.format("  [Rogue] 噬魂回复%d气血", totalHeal))
    end

    for i = #toRemove, 1, -1 do
        table.remove(state.monsters, toRemove[i])
    end
end

local function RemoveClaimedFieldRewards(state)
    local fieldRewardRemove = {}

    for i, fieldReward in ipairs(state.fieldRewards) do
        if fieldReward.hp <= 0 then
            table.insert(fieldRewardRemove, i)
        end
    end

    for i = #fieldRewardRemove, 1, -1 do
        table.remove(state.fieldRewards, fieldRewardRemove[i])
    end
end

function KillResolver.Resolve(state)
    ResolveMonsterDeaths(state)
    RemoveClaimedFieldRewards(state)
end

return KillResolver
