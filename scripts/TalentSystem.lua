-- TalentSystem.lua
-- 局内天赋购买与生效逻辑。

local TalentDefs = require("config.TalentDefs")
local TalentUnlockSystem = require("TalentUnlockSystem")

local TalentSystem = {}

local NODE_BY_ID = {}
for _, node in ipairs(TalentDefs.nodes) do
    NODE_BY_ID[node.id] = node
end

function TalentSystem.GetBranches()
    return TalentDefs.branches
end

function TalentSystem.GetNodes(branch)
    local nodes = {}
    for _, node in ipairs(TalentDefs.nodes) do
        if node.branch == branch then
            table.insert(nodes, node)
        end
    end
    return nodes
end

function TalentSystem.GetEdges(branch)
    local nodeById = {}
    for _, node in ipairs(TalentDefs.nodes) do
        if node.branch == branch then
            nodeById[node.id] = true
        end
    end

    local edges = {}
    for _, edge in ipairs(TalentDefs.edges or {}) do
        if nodeById[edge.from] and nodeById[edge.to] then
            table.insert(edges, edge)
        end
    end
    return edges
end

function TalentSystem.GetNode(id)
    return NODE_BY_ID[id]
end

function TalentSystem.EnsureState(state)
    state.purchasedTalents = state.purchasedTalents or {}
    state.talentModifiers = state.talentModifiers or {}
    state.talentVariants = state.talentVariants or {}
    TalentUnlockSystem.EnsureDefaults(state)

    for _, node in ipairs(TalentDefs.nodes) do
        if node.default then
            state.purchasedTalents[node.id] = true
        end
    end
end

function TalentSystem.IsPurchased(state, nodeId)
    TalentSystem.EnsureState(state)
    return state.purchasedTalents[nodeId] == true
end

local function HasRequirement(state, requirementId)
    local node = NODE_BY_ID[requirementId]
    return (node and node.default) or TalentSystem.IsPurchased(state, requirementId)
end

local function HasExclusiveConflict(state, node)
    if not node.exclusiveGroup then return false end
    for _, other in ipairs(TalentDefs.nodes) do
        if other.id ~= node.id
            and other.exclusiveGroup == node.exclusiveGroup
            and TalentSystem.IsPurchased(state, other.id) then
            return true
        end
    end
    return false
end

function TalentSystem.CanPurchase(state, nodeId)
    TalentSystem.EnsureState(state)
    local node = NODE_BY_ID[nodeId]
    if not node then return false, "天赋不存在" end
    if node.default then return false, "默认已解锁" end
    if state.purchasedTalents[nodeId] then return false, "已解锁" end
    if (state.talentPoints or 0) < (node.cost or 0) then return false, "天赋点不足" end

    for _, requirementId in ipairs(node.requires or {}) do
        if not HasRequirement(state, requirementId) then
            return false, "前置未满足"
        end
    end

    if HasExclusiveConflict(state, node) then
        return false, "同系变种只能选择一个"
    end

    return true, "可解锁"
end

local function ApplyUnlock(state, unlock)
    if not unlock then return end
    if unlock.type == "item" then
        TalentUnlockSystem.UnlockItem(state, unlock.category, unlock.baseId)
    end
end

local function ApplyModifier(state, modifier)
    if not modifier then return end
    table.insert(state.talentModifiers, {
        stat = modifier.stat,
        value = modifier.value or 0,
    })
end

function TalentSystem.Purchase(state, nodeId)
    TalentSystem.EnsureState(state)
    local ok, reason = TalentSystem.CanPurchase(state, nodeId)
    if not ok then
        return { ok = false, message = reason }
    end

    local node = NODE_BY_ID[nodeId]
    state.talentPoints = (state.talentPoints or 0) - (node.cost or 0)
    state.spentTalentPoints = (state.spentTalentPoints or 0) + (node.cost or 0)
    state.purchasedTalents[nodeId] = true

    ApplyUnlock(state, node.unlock)
    ApplyModifier(state, node.modifier)

    if node.variant then
        state.talentVariants[node.variant.school] = node.variant.value
    end

    return { ok = true, message = "已解锁：" .. node.name, node = node }
end

function TalentSystem.GetModifierValue(state, stat)
    local total = 0
    for _, modifier in ipairs(state.talentModifiers or {}) do
        if modifier.stat == stat then
            total = total + (modifier.value or 0)
        end
    end
    return total
end

return TalentSystem
