local Config = require("Config")
local TurnEngine = require("combat.TurnEngine")
local VisualEventQueue = require("events.VisualEventQueue")

local TurnFlowController = {}
TurnFlowController.__index = TurnFlowController

local function CopyTable(value)
    if type(value) ~= "table" then return value end
    local copied = {}
    for k, v in pairs(value) do
        copied[k] = CopyTable(v)
    end
    return copied
end

local function CreateEmptyVisualEventQueue()
    return {
        statusEvents = {},
        dropMessages = {},
        pillConsumeMessages = {},
        damageDealt = {},
        playerDamage = 0,
        playerDamageCrit = false,
        reincarnationTriggered = false,
        breakthroughEvent = nil,
    }
end

local function CopyMonsterForVisual(monster)
    local copied = CopyTable(monster)
    if monster and (monster.hp or 0) <= 0 then
        copied.hp = math.max(1, monster.maxHp or 1)
    end
    return copied
end

local function CaptureTurnVisualState(state)
    if not state then return nil end
    local visual = CopyTable(state)
    visual.monsters = {}
    for _, monster in ipairs(state.monsters or {}) do
        if monster.row and monster.row >= 1 and monster.row <= Config.FIELD_ROWS then
            table.insert(visual.monsters, CopyMonsterForVisual(monster))
        end
    end
    visual.fieldRewards = CopyTable(state.fieldRewards or {})
    visual.lastDamageDealt = {}
    visual.lastPlayerDamage = 0
    visual.lastPlayerDamageCrit = false
    visual.pillConsumeMessages = {}
    visual.visualStatusEvents = {}
    visual.lastBreakthroughEvent = nil
    visual.dropMessages = {}
    visual.reincarnationTriggered = false
    visual.pendingRogueChoices = nil
    visual.pendingRogueEvent = nil
    visual.visualEventQueue = CreateEmptyVisualEventQueue()
    return visual
end

local function FindResolvedDamageForVisualMonster(resolvedState, monster)
    if not monster then return nil end
    local best = nil
    for _, current in ipairs(resolvedState and resolvedState.monsters or {}) do
        if current == monster or (current.id == monster.id and current.col == monster.col and current.row == monster.row) then
            best = current
            break
        end
    end
    if best then
        return best.hp
    end

    local damage = 0
    for _, ev in ipairs(resolvedState and resolvedState.lastDamageDealt or {}) do
        if ev.target == monster or (ev.col == monster.col and ev.row == monster.row) then
            damage = damage + (ev.dmg or 0)
        end
    end
    if damage > 0 then
        return math.max(0, (monster.hp or 0) - damage)
    end
    return nil
end

local function FindVisualMonster(visualState, event)
    if not visualState or not event then return nil end
    for _, monster in ipairs(visualState.monsters or {}) do
        if event.target and monster.id == event.target.id and monster.col == event.col and monster.row == event.row then
            return monster
        end
        if monster.col == event.col and monster.row == event.row then
            return monster
        end
    end
    return nil
end

local function CopyDamageEventForVisual(visualState, event)
    local copied = CopyTable(event)
    local visualMonster = FindVisualMonster(visualState, event)
    if visualMonster then
        copied.target = visualMonster
        copied.col = visualMonster.col
        copied.row = visualMonster.row
    end
    return copied
end

local function AttachHitDamageEvents(hitVisualState, resolvedState)
    if not hitVisualState or not resolvedState then return end
    local damageEvents = VisualEventQueue.DrainDamageDealtWhere(resolvedState, function(event)
        return event and event.visualPhase == "playerHit"
    end)
    if #damageEvents == 0 then return end

    local queue = VisualEventQueue.Ensure(hitVisualState)
    if not queue then return end
    for _, event in ipairs(damageEvents) do
        table.insert(queue.damageDealt, CopyDamageEventForVisual(hitVisualState, event))
    end
end

local function BuildHitVisualState(beforeState, resolvedState)
    if not beforeState then return nil end
    local visual = CopyTable(beforeState)
    visual.monsters = {}
    for _, monster in ipairs(beforeState.monsters or {}) do
        local copied = CopyMonsterForVisual(monster)
        local resolvedHp = FindResolvedDamageForVisualMonster(resolvedState, monster)
        if resolvedHp ~= nil then
            copied.hp = math.max(0, resolvedHp)
        end
        if copied.row and copied.row >= 1 and copied.row <= Config.FIELD_ROWS and copied.hp > 0 then
            table.insert(visual.monsters, copied)
        elseif copied.row and copied.row >= 1 and copied.row <= Config.FIELD_ROWS and resolvedHp ~= nil then
            copied.hp = 0
            copied.showDeadHit = true
            table.insert(visual.monsters, copied)
        end
    end
    visual.fieldRewards = CopyTable(beforeState.fieldRewards or {})
    visual.lastDamageDealt = {}
    visual.lastPlayerDamage = 0
    visual.lastPlayerDamageCrit = false
    visual.pillConsumeMessages = {}
    visual.visualStatusEvents = {}
    visual.lastBreakthroughEvent = nil
    visual.dropMessages = {}
    visual.reincarnationTriggered = false
    visual.pendingRogueChoices = nil
    visual.pendingRogueEvent = nil
    visual.visualEventQueue = CreateEmptyVisualEventQueue()
    return visual
end

function TurnFlowController.Create(callbacks)
    return setmetatable({
        callbacks = callbacks or {},
        resultRefreshDelay = 0,
        hitRefreshDelay = 0,
        resolvingTurnVisual = false,
        hitVisualState = nil,
        resolvedState = nil,
    }, TurnFlowController)
end

function TurnFlowController:IsResolving()
    return self.resolvingTurnVisual == true
end

function TurnFlowController:RefreshResolvedTurnNow()
    if self.hitVisualState then
        self:ShowHitVisualNow()
    end
    self.resultRefreshDelay = 0
    self.hitRefreshDelay = 0
    self.resolvingTurnVisual = false
    self.hitVisualState = nil
    self.resolvedState = nil
    if self.callbacks.onRefreshResolved then
        self.callbacks.onRefreshResolved()
    end
end

function TurnFlowController:ShowHitVisualNow()
    self.hitRefreshDelay = 0
    if self.hitVisualState and self.callbacks.onShowHitVisual then
        AttachHitDamageEvents(self.hitVisualState, self.resolvedState)
        self.callbacks.onShowHitVisual(self.hitVisualState)
    end
    self.hitVisualState = nil
end

function TurnFlowController:ScheduleResolvedTurnRefresh(hitDelay, finalDelay, hitVisualState, resolvedState)
    finalDelay = finalDelay or hitDelay
    if finalDelay and finalDelay > 0 then
        self.resultRefreshDelay = finalDelay
        self.hitRefreshDelay = math.max(0, hitDelay or 0)
        self.hitVisualState = hitVisualState
        self.resolvedState = resolvedState
        self.resolvingTurnVisual = true
    else
        self:RefreshResolvedTurnNow()
    end
end

function TurnFlowController:ExecutePlayerTurn(state)
    local turnVisualState = CaptureTurnVisualState(state)
    TurnEngine.ExecuteTurn(state)

    local attackDuration = 0
    local hitDelay = 0
    if self.callbacks.triggerAttack then
        attackDuration, hitDelay = self.callbacks.triggerAttack(state)
        attackDuration = attackDuration or 0
        hitDelay = hitDelay or 0
    end

    if turnVisualState and attackDuration > 0 and self.callbacks.onShowTurnVisual then
        local hitVisualState = BuildHitVisualState(turnVisualState, state)
        local shown = self.callbacks.onShowTurnVisual(turnVisualState)
        if shown then
            self:ScheduleResolvedTurnRefresh(hitDelay, attackDuration, hitVisualState, state)
            return
        end
    end

    if self.callbacks.onRefreshResolved then
        self.callbacks.onRefreshResolved()
    end
end

function TurnFlowController:Update(dt)
    if not self.resolvingTurnVisual then return end
    if self.hitVisualState then
        self.hitRefreshDelay = self.hitRefreshDelay - dt
        if self.hitRefreshDelay <= 0 then
            self:ShowHitVisualNow()
        end
    end
    self.resultRefreshDelay = self.resultRefreshDelay - dt
    if self.resultRefreshDelay <= 0 then
        self:RefreshResolvedTurnNow()
    end
end

return TurnFlowController
