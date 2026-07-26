-- combat/KillResolver.lua
-- 怪物死亡、修为、击杀回血与场上奖励移除结算。

local RealmSystem = require("RealmSystem")
local Config = require("Config")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local Stats = require("combat.Stats")
local VisualEventQueue = require("events.VisualEventQueue")
local DailyChallenge = require("DailyChallenge")

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

local function GetMonsterCoinReward(monster)
    local rules = Config.SHOP or {}
    local tierMultiplier = (rules.TIER_MULTIPLIER and rules.TIER_MULTIPLIER[monster.tier]) or 1.0
    local realm = math.max(1, math.floor(monster.realm or monster.quality or 1))
    local base = (rules.KILL_COIN_BASE or 2) + (realm - 1) * (rules.KILL_COIN_PER_REALM or 2)
    return math.max(1, math.floor(base * tierMultiplier + 0.5))
end

local function RollMonsterCoinReward(state, monster)
    local rules = Config.SHOP or {}
    local dropChance = math.min(1.0, math.max(0.0, rules.KILL_COIN_DROP_CHANCE or 0))
    if DailyChallenge.RandomFloat(state) >= dropChance then
        return 0
    end

    return GetMonsterCoinReward(monster)
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
            local coinGain = RollMonsterCoinReward(state, monster)
            state.score = state.score + expGain
            if state.ascensionMode == true then
                state.endlessKills = (state.endlessKills or 0) + 1
            end
            state.coins = (state.coins or 0) + coinGain
            if killHealPct > 0 then
                totalHeal = totalHeal + math.max(1, math.floor((state.maxHp or 0) * killHealPct))
            end
            if coinGain > 0 then
                table.insert(state.lastCoinDropEvents, {
                    col = monster.col,
                    row = monster.row,
                    amount = coinGain,
                    monsterId = monster.id,
                    startDelay = 0,
                })
                VisualEventQueue.PushDropMessage(state, string.format("击杀%s：+%d金币", monster.name, coinGain))
            end
            print(string.format("  [Kill] %s 被击杀! +%d修为%s", monster.name, expGain, coinGain > 0 and string.format(" +%d金币", coinGain) or ""))
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
