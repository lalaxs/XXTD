-- ReincarnationSystem.lua
-- 局外轮回点与永久强化管理。

local ReincarnationUpgradeDefs = require("config.ReincarnationUpgradeDefs")

local ReincarnationSystem = {}

local DEF_BY_ID = {}
for _, def in ipairs(ReincarnationUpgradeDefs) do
    DEF_BY_ID[def.id] = def
end

function ReincarnationSystem.EnsureState(state)
    state.reincarnationPoints = state.reincarnationPoints or 0
    state.reincarnationUpgrades = state.reincarnationUpgrades or {}
    state.reincarnationCount = state.reincarnationCount or 0
end

function ReincarnationSystem.GetDefinitions()
    return ReincarnationUpgradeDefs
end

function ReincarnationSystem.GetDefinition(upgradeId)
    return DEF_BY_ID[upgradeId]
end

function ReincarnationSystem.GetLevel(state, upgradeId)
    ReincarnationSystem.EnsureState(state)
    return state.reincarnationUpgrades[upgradeId] or 0
end

function ReincarnationSystem.GetValue(state, upgradeId)
    local def = DEF_BY_ID[upgradeId]
    if not def then return 0 end
    return ReincarnationSystem.GetLevel(state, upgradeId) * (def.valuePerLevel or 0)
end

function ReincarnationSystem.CanUpgrade(state, upgradeId)
    ReincarnationSystem.EnsureState(state)
    local def = DEF_BY_ID[upgradeId]
    if not def then return false, "强化不存在" end
    local level = ReincarnationSystem.GetLevel(state, upgradeId)
    if level >= (def.maxLevel or 1) then return false, "已达满级" end
    if (state.reincarnationPoints or 0) < 1 then return false, "轮回点不足" end
    return true, "可强化"
end

function ReincarnationSystem.Upgrade(state, upgradeId)
    local ok, reason = ReincarnationSystem.CanUpgrade(state, upgradeId)
    if not ok then return { ok = false, message = reason } end

    local level = ReincarnationSystem.GetLevel(state, upgradeId) + 1
    state.reincarnationPoints = state.reincarnationPoints - 1
    state.reincarnationUpgrades[upgradeId] = level
    local def = DEF_BY_ID[upgradeId]
    print(string.format("[Reincarnation Upgrade] %s 升至 %d/%d，剩余轮回点%d", def.name, level, def.maxLevel, state.reincarnationPoints))
    return { ok = true, message = "强化成功：" .. def.name, definition = def, level = level }
end

function ReincarnationSystem.GrantReincarnationPoint(state)
    ReincarnationSystem.EnsureState(state)
    state.reincarnationPoints = state.reincarnationPoints + 1
    state.reincarnationCount = state.reincarnationCount + 1
    print(string.format("[Reincarnation] 第%d次轮回，获得1轮回点，当前%d", state.reincarnationCount, state.reincarnationPoints))
end

return ReincarnationSystem
