local Config = require("Config")
local BoardLayout = require("BoardLayout")

local Effects = {}

local attackEffects_ = {}
local mergeEffects_ = {}
local coinEffects_ = {}
local pendingCoinCredit_ = 0
local coinTargetAmount_ = nil
local coinArrivalPulseCount_ = 0
local effectTime_ = 0

local Clamp01
local Lerp
local GetBoardMetrics
local FieldTargetPoint
local FillPolygon
local DrawFlatCircle

local vg_ = nil
local screenW_ = 0
local screenH_ = 0

local PLAYER_PROJECTILE_FLIGHT = 0.46
local MONSTER_PROJECTILE_FLIGHT = 0.5
local COIN_DROP_DURATION = 1.28
local COIN_DROP_STAGGER = 0.045
local HIT_HOLD_DURATION = 0.26

local PROJECTILE_OUTLINE = {83, 65, 58}

local PROJECTILE_STYLES = {
    qingfeng_sword = { shape = "blade", primary = {108, 205, 224}, secondary = {244, 250, 238}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.08, maxTrailPx = 56, impact = "slash" },
    bishui_sword = { shape = "blade", primary = {78, 174, 214}, secondary = {221, 245, 236}, outline = PROJECTILE_OUTLINE, curve = 5, trail = 0.32, impact = "slash" },
    taiji_sword = { shape = "taiji", primary = {246, 241, 220}, secondary = {78, 174, 185}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.34, impact = "ring" },
    chiyan_spear = { shape = "spear", primary = {226, 92, 54}, secondary = {255, 214, 112}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.36, impact = "burst" },
    pozhen_spear = { shape = "spear", primary = {232, 171, 62}, secondary = {255, 236, 151}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.38, impact = "pierce" },
    qingyu_fan = { shape = "wind", primary = {94, 198, 173}, secondary = {216, 244, 210}, outline = PROJECTILE_OUTLINE, curve = -16, wave = 5, trail = 0.42, impact = "wave" },
    ziqi_gourd = { shape = "poison", primary = {148, 93, 188}, secondary = {110, 198, 113}, outline = PROJECTILE_OUTLINE, curve = 12, wave = 3, trail = 0.40, impact = "poison" },
    jinguang_ring = { shape = "ring", primary = {236, 187, 67}, secondary = {255, 239, 155}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.34, impact = "ring" },
    zhenyao_tower = { shape = "ring", primary = {224, 133, 62}, secondary = {255, 220, 133}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.34, impact = "suppress" },
    huxin_pearl = { shape = "ring", primary = {94, 190, 145}, secondary = {242, 230, 151}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.34, impact = "ring" },
    qingyin_qin = { shape = "sound", primary = {109, 138, 211}, secondary = {234, 213, 237}, outline = PROJECTILE_OUTLINE, curve = -10, wave = 5, trail = 0.42, impact = "wave" },
    baigu_staff = { shape = "ink", primary = {172, 144, 207}, secondary = {93, 68, 132}, outline = PROJECTILE_OUTLINE, curve = 10, wave = 2, trail = 0.36, impact = "debuff" },
    lingmo_brush = { shape = "ink", primary = {110, 82, 153}, secondary = {221, 202, 235}, outline = PROJECTILE_OUTLINE, curve = -12, wave = 4, trail = 0.38, impact = "debuff" },
    fuyao_chain = { shape = "chain", primary = {129, 158, 206}, secondary = {91, 104, 143}, outline = PROJECTILE_OUTLINE, curve = 7, trail = 0.46, impact = "bind" },
    double_blade_chain = { shape = "chain", primary = {223, 98, 75}, secondary = {255, 200, 126}, outline = PROJECTILE_OUTLINE, curve = -7, trail = 0.46, impact = "slash" },
}

local MODE_FALLBACK_STYLES = {
    single = { shape = "blade", primary = {108, 205, 224}, secondary = {244, 250, 238}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.16, impact = "slash" },
    pierce = { shape = "spear", primary = {232, 171, 62}, secondary = {255, 236, 151}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.38, impact = "pierce" },
    sweep = { shape = "wind", primary = {94, 198, 173}, secondary = {216, 244, 210}, outline = PROJECTILE_OUTLINE, curve = -14, wave = 5, trail = 0.42, impact = "wave" },
    area = { shape = "ring", primary = {236, 187, 67}, secondary = {255, 239, 155}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.34, impact = "ring" },
    guardian = { shape = "ring", primary = {94, 190, 145}, secondary = {242, 230, 151}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.34, impact = "ring" },
    control = { shape = "chain", primary = {129, 158, 206}, secondary = {91, 104, 143}, outline = PROJECTILE_OUTLINE, curve = 7, trail = 0.44, impact = "bind" },
}

local DEFAULT_PROJECTILE_STYLE = { shape = "blade", primary = {108, 205, 224}, secondary = {244, 250, 238}, outline = PROJECTILE_OUTLINE, curve = 0, trail = 0.16, impact = "slash" }

local MONSTER_PROJECTILE_STYLES = {
    wild_boar = { shape = "tusk", primary = {179, 111, 72}, secondary = {247, 219, 166}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "slash" },
    gray_wolf = { shape = "claw", primary = {118, 125, 139}, secondary = {229, 231, 221}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "slash" },
    black_wolf = { shape = "claw", primary = {73, 79, 91}, secondary = {189, 202, 217}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "slash" },
    tree_demon = { shape = "leaf", primary = {92, 154, 91}, secondary = {184, 128, 80}, outline = PROJECTILE_OUTLINE, curve = 6, trail = 0.22, maxTrailPx = 82, impact = "wave" },
    shell_imp = { shape = "stone", primary = {142, 126, 104}, secondary = {224, 199, 139}, outline = PROJECTILE_OUTLINE, trail = 0.16, maxTrailPx = 64, impact = "burst" },
    green_snake = { shape = "venom", primary = {87, 174, 92}, secondary = {190, 230, 107}, outline = PROJECTILE_OUTLINE, curve = 10, wave = 3, trail = 0.24, maxTrailPx = 88, impact = "poison" },
    tiger_boss = { shape = "claw", primary = {220, 126, 54}, secondary = {255, 219, 118}, outline = PROJECTILE_OUTLINE, trail = 0.22, maxTrailPx = 90, impact = "slash" },
    white_fox = { shape = "foxfire", primary = {238, 229, 205}, secondary = {213, 134, 218}, outline = PROJECTILE_OUTLINE, curve = -8, wave = 3, trail = 0.24, maxTrailPx = 88, impact = "wave" },
    white_mage = { shape = "seal", primary = {222, 221, 212}, secondary = {116, 154, 210}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "suppress" },
    spear_guard = { shape = "spear", primary = {181, 134, 83}, secondary = {235, 209, 146}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 76, impact = "pierce" },
    gourd_cultivator = { shape = "gourd", primary = {196, 132, 57}, secondary = {112, 177, 93}, outline = PROJECTILE_OUTLINE, curve = 8, trail = 0.22, maxTrailPx = 82, impact = "poison" },
    fox_fire_witch = { shape = "foxfire", primary = {218, 91, 83}, secondary = {255, 185, 92}, outline = PROJECTILE_OUTLINE, curve = -8, wave = 4, trail = 0.25, maxTrailPx = 92, impact = "wave" },
    lantern_maiden = { shape = "lantern", primary = {226, 176, 79}, secondary = {255, 230, 139}, outline = PROJECTILE_OUTLINE, curve = -4, trail = 0.20, maxTrailPx = 78, impact = "suppress" },
    blade_cultivator = { shape = "blade", primary = {151, 137, 128}, secondary = {236, 229, 203}, outline = PROJECTILE_OUTLINE, trail = 0.16, maxTrailPx = 68, impact = "slash" },
    blue_swordsman = { shape = "blade", primary = {84, 139, 207}, secondary = {212, 234, 242}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "slash" },
    beast_tamer = { shape = "whip", primary = {166, 111, 77}, secondary = {237, 194, 123}, outline = PROJECTILE_OUTLINE, curve = 10, wave = 4, trail = 0.26, maxTrailPx = 96, impact = "bind" },
    black_assassin = { shape = "dart", primary = {71, 78, 93}, secondary = {180, 190, 204}, outline = PROJECTILE_OUTLINE, trail = 0.14, maxTrailPx = 60, impact = "pierce" },
    purple_cultivator = { shape = "seal", primary = {143, 94, 188}, secondary = {222, 194, 235}, outline = PROJECTILE_OUTLINE, curve = -6, wave = 3, trail = 0.22, maxTrailPx = 84, impact = "suppress" },
    flame_golem = { shape = "stone", primary = {198, 84, 54}, secondary = {239, 157, 75}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 76, impact = "burst" },
    poison_spider = { shape = "venom", primary = {93, 153, 80}, secondary = {151, 207, 87}, outline = PROJECTILE_OUTLINE, curve = 8, wave = 3, trail = 0.24, maxTrailPx = 88, impact = "poison" },
    purple_scorpion = { shape = "venom", primary = {143, 87, 178}, secondary = {213, 143, 217}, outline = PROJECTILE_OUTLINE, curve = 6, wave = 2, trail = 0.20, maxTrailPx = 78, impact = "poison" },
    three_headed_snake = { shape = "venom", primary = {88, 168, 105}, secondary = {226, 156, 86}, outline = PROJECTILE_OUTLINE, curve = 10, wave = 5, trail = 0.26, maxTrailPx = 96, impact = "poison" },
    ice_snake = { shape = "ice", primary = {105, 180, 215}, secondary = {222, 244, 238}, outline = PROJECTILE_OUTLINE, curve = 8, wave = 2, trail = 0.22, maxTrailPx = 82, impact = "pierce" },
    green_turtle = { shape = "stone", primary = {89, 147, 95}, secondary = {203, 185, 124}, outline = PROJECTILE_OUTLINE, trail = 0.16, maxTrailPx = 64, impact = "burst" },
    purple_spike_beast = { shape = "spike", primary = {131, 82, 158}, secondary = {218, 159, 208}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "pierce" },
    purple_fire_elder = { shape = "foxfire", primary = {159, 83, 187}, secondary = {240, 110, 74}, outline = PROJECTILE_OUTLINE, curve = -10, wave = 5, trail = 0.28, maxTrailPx = 104, impact = "wave" },
}

local MONSTER_TYPE_PROJECTILE_STYLES = {
    [Config.MONSTER_TYPE.MELEE] = { shape = "claw", primary = {188, 93, 72}, secondary = {247, 216, 152}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "slash" },
    [Config.MONSTER_TYPE.RANGED] = { shape = "seal", primary = {134, 106, 190}, secondary = {227, 205, 234}, outline = PROJECTILE_OUTLINE, trail = 0.22, maxTrailPx = 82, impact = "suppress" },
}

local DEFAULT_MONSTER_PROJECTILE_STYLE = { shape = "dart", primary = {190, 90, 120}, secondary = {248, 204, 214}, outline = PROJECTILE_OUTLINE, trail = 0.18, maxTrailPx = 72, impact = "pierce" }

function Effects.Reset()
    attackEffects_ = {}
    mergeEffects_ = {}
    coinEffects_ = {}
    pendingCoinCredit_ = 0
    coinTargetAmount_ = nil
    coinArrivalPulseCount_ = 0
    effectTime_ = 0
end

function Effects.Update(timeStep)
    effectTime_ = effectTime_ + timeStep
    for _, eff in ipairs(coinEffects_) do
        if not eff.arrived and effectTime_ >= eff.startTime + eff.duration then
            eff.arrived = true
            local amount = math.max(0, math.floor(eff.displayAmount or 0))
            pendingCoinCredit_ = math.max(0, pendingCoinCredit_ - amount)
            if amount > 0 then
                coinArrivalPulseCount_ = coinArrivalPulseCount_ + 1
            end
        end
    end
end

function Effects.GetCoinArrivalDelay(index, startDelay)
    local arrivalIndex = math.max(1, math.floor(tonumber(index) or 1))
    return math.max(0, tonumber(startDelay) or 0)
        + (arrivalIndex - 1) * COIN_DROP_STAGGER
        + COIN_DROP_DURATION
end

function Effects.GetCoinDisplayAmount(actualAmount)
    local amount = math.max(0, math.floor(tonumber(actualAmount) or 0))
    if pendingCoinCredit_ > 0 and coinTargetAmount_ ~= nil then
        return math.max(0, coinTargetAmount_ - pendingCoinCredit_)
    end
    coinTargetAmount_ = amount
    return amount
end

function Effects.HasPendingCoinCredit()
    return pendingCoinCredit_ > 0
end

function Effects.ConsumeCoinArrivalPulses()
    local count = coinArrivalPulseCount_
    coinArrivalPulseCount_ = 0
    return count
end

function Effects.TriggerMerge(category, idx, quality)
    table.insert(mergeEffects_, {
        category = category,
        idx = idx,
        quality = quality,
        startTime = effectTime_,
        duration = 0.8,
    })
end

function Effects.TriggerCoinDrops(state, startDelay)
    startDelay = math.max(0, startDelay or 0)
    local drops = state and state.lastCoinDropEvents or {}
    if #drops == 0 then return end

    coinTargetAmount_ = math.max(0, math.floor(tonumber(state.coins) or 0))
    local totalAmount = 0
    for _, drop in ipairs(drops) do
        totalAmount = totalAmount + math.max(1, math.floor(drop.amount or 1))
    end
    pendingCoinCredit_ = pendingCoinCredit_ + totalAmount

    for _, drop in ipairs(drops) do
        local amount = math.max(1, math.floor(drop.amount or 1))
        local coinCount = math.min(7, math.max(3, math.ceil(amount / 3)))
        local baseAmount = math.floor(amount / coinCount)
        local remainder = amount % coinCount
        for index = 1, coinCount do
            table.insert(coinEffects_, {
                col = drop.col,
                row = drop.row,
                index = index,
                count = coinCount,
                displayAmount = baseAmount + (index <= remainder and 1 or 0),
                arrived = false,
                startTime = effectTime_ + Effects.GetCoinArrivalDelay(index, startDelay) - COIN_DROP_DURATION,
                duration = COIN_DROP_DURATION,
            })
        end
    end
end

local function CoinTargetPoint(board)
    local rect = BoardLayout.ToScreenRect(board, board.coin)
    return rect.x + 47 * board.scale, rect.y + rect.h * 0.5
end

local function CoinDropStartPoint(board, eff)
    local x, y, cellW, cellH = FieldTargetPoint(board, eff.col, eff.row)
    if not x then return nil end
    local spread = cellW * 0.48
    local angle = (eff.index / math.max(1, eff.count)) * math.pi * 2 + eff.row * 0.7
    local distance = spread * (0.35 + (eff.index % 3) * 0.22)
    return x + math.cos(angle) * distance, y + cellH * 0.28 + math.sin(angle) * distance * 0.42
end

local function DrawCoinShape(cx, cy, radius, rotation, alpha)
    local width = radius * 0.72
    local height = radius * 1.18
    local cosR = math.cos(rotation)
    local sinR = math.sin(rotation)
    local function Point(x, y)
        return {
            x = cx + x * cosR - y * sinR,
            y = cy + x * sinR + y * cosR,
        }
    end

    local outline = {111, 78, 39}
    local vertices = {
        Point(-width, -height),
        Point(width, -height),
        Point(width, height),
        Point(-width, height),
    }
    FillPolygon(vertices, {232, 178, 65}, alpha, outline, math.max(1.0, radius * 0.16), alpha)
    local inner = Point(0, -height * 0.38)
    DrawFlatCircle(inner.x, inner.y, radius * 0.20, {255, 239, 157}, alpha * 0.9, nil, 0, 0)
end

local function DrawCoinDropEffects()
    local board = GetBoardMetrics()
    if not board then return end

    local targetX, targetY = CoinTargetPoint(board)
    local remaining = {}
    for _, eff in ipairs(coinEffects_) do
        local elapsed = effectTime_ - eff.startTime
        if elapsed < eff.duration then
            table.insert(remaining, eff)
            if elapsed >= 0 then
                local progress = Clamp01(elapsed / eff.duration)
                local startX, startY = CoinDropStartPoint(board, eff)
                if startX and startY then
                    local scatterEndX = startX + (startX - targetX) * 0.16
                    local scatterEndY = startY + 18 + (startY - targetY) * 0.05
                    local x
                    local y
                    if progress < 0.38 then
                        local t = progress / 0.38
                        x = Lerp(startX, scatterEndX, t)
                        y = Lerp(startY, scatterEndY, t) - math.sin(t * math.pi) * 28
                    else
                        local t = (progress - 0.38) / 0.62
                        local eased = t * t * (3 - 2 * t)
                        x = Lerp(scatterEndX, targetX, eased)
                        y = Lerp(scatterEndY, targetY, eased) - math.sin(t * math.pi) * 34 * (1 - t)
                    end

                    local radius = math.max(4, board.scale * 9)
                    local fade = progress > 0.88 and (1 - progress) / 0.12 or 1
                    DrawCoinShape(x, y, radius, eff.index * 0.7 + effectTime_ * 5, 235 * fade)
                end
            end
        end
    end
    coinEffects_ = remaining
end
local function IsValidFieldCoord(col, row)
    return col and row
        and col >= 1 and col <= Config.GRID_COLS
        and row >= 1 and row <= Config.FIELD_ROWS
end

function Effects.TriggerAttack(state)
    local maxDuration = 0
    local maxFlightDuration = 0
    for _, ev in ipairs(state.lastAttackEvents or {}) do
        local targetRow = ev.targetRow or (ev.target and ev.target.row)
        local targetCol = ev.targetCol or ev.col
        if ev.targetType ~= "none" and IsValidFieldCoord(targetCol, targetRow) and ev.slotIdx then
            local flightDuration = PLAYER_PROJECTILE_FLIGHT
            local duration = flightDuration + HIT_HOLD_DURATION
            table.insert(attackEffects_, {
                kind = "player",
                col = ev.col,
                slotIdx = ev.slotIdx,
                targetCol = targetCol,
                targetRow = targetRow,
                targetType = ev.targetType,
                baseId = ev.baseId,
                school = ev.school,
                attackMode = ev.attackMode,
                signature = ev.signature,
                quality = ev.quality,
                visualVariant = ev.visualVariant,
                skillId = ev.skillId,
                effectScale = ev.effectScale or 1,
                crit = ev.crit == true,
                startTime = effectTime_,
                duration = duration,
                flightDuration = flightDuration,
            })
            maxDuration = math.max(maxDuration, duration)
            maxFlightDuration = math.max(maxFlightDuration, flightDuration)
        end
    end

    for _, ev in ipairs(state.lastMonsterAttackEvents or {}) do
        if not ev.removedAfterAttack and IsValidFieldCoord(ev.col, ev.row) then
            local flightDuration = MONSTER_PROJECTILE_FLIGHT
            local duration = flightDuration + HIT_HOLD_DURATION
            table.insert(attackEffects_, {
                kind = "monster",
                col = ev.col,
                row = ev.row,
                monsterId = ev.monsterId,
                monsterType = ev.monsterType,
                tier = ev.tier,
                tags = ev.tags,
                skillId = ev.skillId,
                asset = ev.asset,
                name = ev.name,
                crit = ev.crit == true,
                startTime = effectTime_,
                duration = duration,
                flightDuration = flightDuration,
            })
            maxDuration = math.max(maxDuration, duration)
            maxFlightDuration = math.max(maxFlightDuration, flightDuration)
        end
    end
    return maxDuration, maxFlightDuration
end

Clamp01 = function(value)
    return math.min(1.0, math.max(0.0, value or 0))
end

local function ClampAlpha(value)
    return math.min(255, math.max(0, math.floor(value or 0)))
end

Lerp = function(a, b, t)
    return a + (b - a) * t
end

GetBoardMetrics = function()
    if screenW_ <= 0 or screenH_ <= 0 then return nil end
    return BoardLayout.CalcMetrics(screenW_, screenH_)
end

local function DesignRectPoint(board, rect)
    return board.originX + (rect.x + rect.w * 0.5) * board.scale,
        board.originY + (rect.y + rect.h * 0.5) * board.scale,
        rect.w * board.scale,
        rect.h * board.scale
end

local function DeployItemPoint(board, slotIdx)
    if not slotIdx or slotIdx < 1 or slotIdx > Config.TOTAL_SLOTS then return nil end
    local row = math.ceil(slotIdx / Config.GRID_COLS)
    local col = ((slotIdx - 1) % Config.GRID_COLS) + 1
    local cell = BoardLayout.CellRect(board, row, col, true)
    return cell.x + cell.w * 0.5,
        cell.y + cell.h * 0.5,
        cell.w,
        cell.h
end

local function StoragePoint(board)
    return DesignRectPoint(board, { x = 430, y = 2065, w = 220, h = 132 })
end

FieldTargetPoint = function(board, col, row)
    col = math.min(Config.GRID_COLS, math.max(1, col or 1))
    row = math.min(Config.FIELD_ROWS, math.max(1, row or 1))
    local cell = BoardLayout.CellRect(board, row, col, false)
    return cell.x + cell.w * 0.5,
        cell.y + cell.h * 0.55,
        cell.w,
        cell.h
end

local function DrawMergeEffects()
    local board = GetBoardMetrics()
    if not board then return end

    local remaining = {}
    local qColorR = {200, 100, 80, 180, 230, 255, 180, 200, 255}
    local qColorG = {200, 210, 160, 100, 70, 200, 140, 130, 160}
    local qColorB = {200, 120, 255, 255, 60, 50, 40, 255, 200}

    for _, eff in ipairs(mergeEffects_) do
        local elapsed = effectTime_ - eff.startTime
        local progress = elapsed / eff.duration

        if progress < 1.0 then
            table.insert(remaining, eff)
            progress = Clamp01(progress)

            local cx, cy, slotW
            if eff.category == "deploy" then
                cx, cy, slotW = DeployItemPoint(board, eff.idx)
            elseif eff.category == "storage" then
                cx, cy, slotW = StoragePoint(board)
            end

            if cx and cy and slotW then
                local q = math.min(9, math.max(1, eff.quality or 1))
                local cr = qColorR[q]
                local cg = qColorG[q]
                local cb = qColorB[q]

                local ringRadius = slotW * 0.3 + slotW * 0.8 * progress
                local ringAlpha = math.floor(220 * (1.0 - progress))
                nvgBeginPath(vg_)
                nvgCircle(vg_, cx, cy, ringRadius)
                nvgStrokeColor(vg_, nvgRGBA(cr, cg, cb, ringAlpha))
                nvgStrokeWidth(vg_, 3 * (1.0 - progress * 0.5))
                nvgStroke(vg_)

                local glowR = ringRadius * 1.3
                local glowPaint = nvgRadialGradient(vg_, cx, cy, ringRadius * 0.5, glowR,
                    nvgRGBA(cr, cg, cb, math.floor(60 * (1.0 - progress))),
                    nvgRGBA(cr, cg, cb, 0))
                nvgBeginPath(vg_)
                nvgCircle(vg_, cx, cy, glowR)
                nvgFillPaint(vg_, glowPaint)
                nvgFill(vg_)

                local particleCount = 4 + q * 2
                for particle = 1, particleCount do
                    local angle = (particle / particleCount) * math.pi * 2 + effectTime_ * 2
                    local dist = slotW * 0.2 + slotW * progress * 0.8
                    local px = cx + math.cos(angle) * dist
                    local py = cy + math.sin(angle) * dist
                    local pAlpha = math.floor(200 * (1.0 - progress * progress))
                    local pSize = (2 + q * 0.3) * (1.0 - progress * 0.7)
                    nvgBeginPath(vg_)
                    nvgCircle(vg_, px, py, pSize)
                    nvgFillColor(vg_, nvgRGBA(cr, cg, cb, pAlpha))
                    nvgFill(vg_)
                end
            end
        end
    end
    mergeEffects_ = remaining
end

local function ResolveStyle(eff)
    return PROJECTILE_STYLES[eff.baseId]
        or MODE_FALLBACK_STYLES[eff.attackMode or ""]
        or DEFAULT_PROJECTILE_STYLE
end

local function ResolveMonsterStyle(eff)
    return MONSTER_PROJECTILE_STYLES[eff.monsterId or ""]
        or MONSTER_TYPE_PROJECTILE_STYLES[eff.monsterType]
        or DEFAULT_MONSTER_PROJECTILE_STYLE
end

local function GetPathFrame(sx, sy, ex, ey)
    local dx = ex - sx
    local dy = ey - sy
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0.001 then return nil end
    return dx / len, dy / len, -dy / len, dx / len, len
end

local function PathPoint(sx, sy, ex, ey, ux, uy, nx, ny, t, style, phase)
    local baseX = Lerp(sx, ex, t)
    local baseY = Lerp(sy, ey, t)
    local envelope = math.sin(t * math.pi)
    local offset = (style.curve or 0) * envelope
    if (style.wave or 0) > 0 then
        offset = offset + math.sin(t * math.pi * 3.0 + (phase or 0)) * (style.wave or 0) * envelope
    end
    return baseX + nx * offset, baseY + ny * offset
end

local function BuildTrailPoints(sx, sy, ex, ey, ux, uy, nx, ny, progress, style, phase, trailOverride)
    local headT = Clamp01(progress)
    local trail = trailOverride or style.trail or 0.42
    if style.maxTrailPx then
        local dx = ex - sx
        local dy = ey - sy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.001 then
            trail = math.min(trail, style.maxTrailPx / len)
        end
    end
    local tailT = math.max(0, headT - trail)
    local points = {}
    local segmentCount = 12
    for i = 0, segmentCount do
        local stepT = i / segmentCount
        local t = Lerp(tailT, headT, stepT)
        local px, py = PathPoint(sx, sy, ex, ey, ux, uy, nx, ny, t, style, phase)
        table.insert(points, { x = px, y = py, t = t })
    end
    return points
end

local function StrokePolyline(points, color, width, alpha)
    if #points < 2 then return end
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, points[1].x, points[1].y)
    for i = 2, #points do
        nvgLineTo(vg_, points[i].x, points[i].y)
    end
    nvgStrokeColor(vg_, nvgRGBA(color[1], color[2], color[3], ClampAlpha(alpha)))
    nvgStrokeWidth(vg_, math.max(1.0, width or 1.0))
    nvgStroke(vg_)
end

local function GetOutline(style)
    return (style and style.outline) or PROJECTILE_OUTLINE
end

local function BeginPolygon(vertices)
    if #vertices < 3 then return end
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, vertices[1].x, vertices[1].y)
    for i = 2, #vertices do
        nvgLineTo(vg_, vertices[i].x, vertices[i].y)
    end
    nvgClosePath(vg_)
end

FillPolygon = function(vertices, fillColor, fillAlpha, outlineColor, outlineWidth, outlineAlpha)
    if #vertices < 3 then return end
    BeginPolygon(vertices)
    nvgFillColor(vg_, nvgRGBA(fillColor[1], fillColor[2], fillColor[3], ClampAlpha(fillAlpha)))
    nvgFill(vg_)
    if outlineColor and (outlineWidth or 0) > 0 then
        BeginPolygon(vertices)
        nvgStrokeColor(vg_, nvgRGBA(outlineColor[1], outlineColor[2], outlineColor[3], ClampAlpha(outlineAlpha or fillAlpha)))
        nvgStrokeWidth(vg_, outlineWidth)
        nvgStroke(vg_)
    end
end

DrawFlatCircle = function(cx, cy, radius, fillColor, fillAlpha, outlineColor, outlineWidth, outlineAlpha)
    if radius <= 0 then return end
    if fillColor then
        nvgBeginPath(vg_)
        nvgCircle(vg_, cx, cy, radius)
        nvgFillColor(vg_, nvgRGBA(fillColor[1], fillColor[2], fillColor[3], ClampAlpha(fillAlpha)))
        nvgFill(vg_)
    end
    if outlineColor and (outlineWidth or 0) > 0 then
        nvgBeginPath(vg_)
        nvgCircle(vg_, cx, cy, radius)
        nvgStrokeColor(vg_, nvgRGBA(outlineColor[1], outlineColor[2], outlineColor[3], ClampAlpha(outlineAlpha or fillAlpha)))
        nvgStrokeWidth(vg_, outlineWidth)
        nvgStroke(vg_)
    end
end

local function DrawFlatPolyline(points, fillColor, outlineColor, width, alpha)
    if #points < 2 then return end
    local w = math.max(1.0, width or 1.0)
    if outlineColor then
        StrokePolyline(points, outlineColor, w + math.max(2.0, w * 0.65), alpha * 0.74)
    end
    StrokePolyline(points, fillColor, w, alpha)
end

local function DrawFlatSegment(x1, y1, x2, y2, width, fillColor, alpha, outlineColor)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0.001 then return end
    local nx = -dy / len
    local ny = dx / len
    local half = math.max(0.6, width * 0.5)
    FillPolygon({
        { x = x1 + nx * half, y = y1 + ny * half },
        { x = x2 + nx * half, y = y2 + ny * half },
        { x = x2 - nx * half, y = y2 - ny * half },
        { x = x1 - nx * half, y = y1 - ny * half },
    }, fillColor, alpha, outlineColor, math.max(1.0, width * 0.22), alpha * 0.78)
end

local function DrawImpact(ex, ey, nx, ny, progress, style, thickness)
    local t = Clamp01((progress - 0.74) / 0.26)
    if t <= 0 then return end

    local primary = style.primary
    local secondary = style.secondary or primary
    local outline = GetOutline(style)
    local fade = 1.0 - t
    local alpha = 185 * fade
    local radius = thickness * (2.0 + t * 4.2)

    DrawFlatCircle(ex, ey, radius, nil, 0, outline, math.max(2.0, thickness * 0.42), alpha * 0.56)
    DrawFlatCircle(ex, ey, radius * 0.84, nil, 0, primary, math.max(1.5, thickness * 0.28), alpha)

    if style.impact == "slash" then
        local slashLen = thickness * (4.6 + t * 3.0)
        DrawFlatSegment(ex + nx * slashLen, ey + ny * slashLen, ex - nx * slashLen, ey - ny * slashLen,
            math.max(2.0, thickness * 0.62), secondary, alpha, outline)
    elseif style.impact == "bind" then
        for i = 1, 4 do
            local angle = i * math.pi * 0.5 + t * 0.7
            local px = ex + math.cos(angle) * radius * 0.72
            local py = ey + math.sin(angle) * radius * 0.72
            DrawFlatCircle(px, py, math.max(2.0, thickness * 0.48), primary, alpha, outline, math.max(1.0, thickness * 0.18), alpha * 0.78)
        end
    elseif style.impact == "poison" then
        for i = 1, 5 do
            local angle = i * 1.35 + t
            local px = ex + math.cos(angle) * radius * 0.66
            local py = ey + math.sin(angle) * radius * 0.66
            DrawFlatCircle(px, py, math.max(1.6, thickness * (0.32 + i * 0.03)), secondary, alpha * 0.82, outline,
                math.max(0.8, thickness * 0.12), alpha * 0.55)
        end
    elseif style.impact == "pierce" then
        local markLen = radius * 0.92
        DrawFlatSegment(ex - nx * markLen, ey - ny * markLen, ex + nx * markLen, ey + ny * markLen,
            math.max(1.8, thickness * 0.46), secondary, alpha, outline)
    elseif style.impact == "wave" then
        for i = 1, 3 do
            local markLen = thickness * (1.7 + i * 0.5)
            local ox = nx * (i - 2) * thickness * 1.8
            local oy = ny * (i - 2) * thickness * 1.8
            DrawFlatSegment(ex - nx * markLen + ox, ey - ny * markLen + oy, ex + nx * markLen + ox, ey + ny * markLen + oy,
                math.max(1.2, thickness * 0.28), secondary, alpha * (0.95 - i * 0.12), outline)
        end
    elseif style.impact == "suppress" then
        local r = radius * 0.72
        FillPolygon({
            { x = ex, y = ey - r },
            { x = ex + r, y = ey },
            { x = ex, y = ey + r },
            { x = ex - r, y = ey },
        }, secondary, alpha * 0.62, outline, math.max(1.2, thickness * 0.24), alpha * 0.8)
    end
end

local function DrawArrowHead(x, y, ux, uy, nx, ny, color, size, alpha, outline)
    local vertices = {
        { x = x + ux * size * 0.74, y = y + uy * size * 0.74 },
        { x = x - ux * size + nx * size * 0.52, y = y - uy * size + ny * size * 0.52 },
        { x = x - ux * size - nx * size * 0.52, y = y - uy * size - ny * size * 0.52 },
    }
    FillPolygon(vertices, color, alpha, outline, math.max(1.2, size * 0.12), alpha * 0.82)
end

local function DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness, phase, trailOverride)
    local ux, uy, nx, ny = GetPathFrame(sx, sy, ex, ey)
    if not ux then return nil end

    local lifeAlpha = progress > 0.9 and math.max(0.0, (1.0 - progress) / 0.1) or 1.0
    local points = BuildTrailPoints(sx, sy, ex, ey, ux, uy, nx, ny, progress, style, phase or effectTime_ * 2.0, trailOverride)
    local head = points[#points]
    local primary = style.primary
    local secondary = style.secondary or primary
    local outline = GetOutline(style)

    DrawFlatPolyline(points, outline, nil, thickness * 1.16, 88 * lifeAlpha)
    DrawFlatPolyline(points, primary, outline, thickness * 0.82, 210 * lifeAlpha)
    StrokePolyline(points, secondary, math.max(1.0, thickness * 0.18), 165 * lifeAlpha)

    return head.x, head.y, ux, uy, nx, ny, lifeAlpha
end

local function DrawBladeProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.86)
    if not headX then return end

    local outline = GetOutline(style)
    local bladeLen = thickness * 5.0
    local bladeW = thickness * 1.1
    FillPolygon({
        { x = headX + ux * bladeLen * 0.58, y = headY + uy * bladeLen * 0.58 },
        { x = headX - ux * bladeLen * 0.30 + nx * bladeW, y = headY - uy * bladeLen * 0.30 + ny * bladeW },
        { x = headX - ux * bladeLen * 0.58, y = headY - uy * bladeLen * 0.58 },
        { x = headX - ux * bladeLen * 0.30 - nx * bladeW, y = headY - uy * bladeLen * 0.30 - ny * bladeW },
    }, style.primary, 235 * lifeAlpha, outline, math.max(1.5, thickness * 0.25), 210 * lifeAlpha)
    DrawFlatSegment(headX - ux * bladeLen * 0.24, headY - uy * bladeLen * 0.24,
        headX + ux * bladeLen * 0.34, headY + uy * bladeLen * 0.34,
        math.max(1.2, thickness * 0.26), style.secondary or style.primary, 180 * lifeAlpha, nil)

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawSpearProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.62, 0, 0.40)
    if not headX then return end

    local outline = GetOutline(style)
    DrawFlatSegment(headX - ux * thickness * 4.6, headY - uy * thickness * 4.6,
        headX - ux * thickness * 0.5, headY - uy * thickness * 0.5,
        math.max(1.8, thickness * 0.36), style.secondary or style.primary, 205 * lifeAlpha, outline)
    DrawArrowHead(headX, headY, ux, uy, nx, ny, style.primary, thickness * 3.35, 240 * lifeAlpha, outline)

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawWindProjectile(sx, sy, ex, ey, progress, style, thickness)
    local ux, uy, nx, ny = GetPathFrame(sx, sy, ex, ey)
    if not ux then return end

    local lifeAlpha = progress > 0.9 and math.max(0.0, (1.0 - progress) / 0.1) or 1.0
    local outline = GetOutline(style)
    local headX, headY = PathPoint(sx, sy, ex, ey, ux, uy, nx, ny, Clamp01(progress), style, effectTime_ * 4.0)
    for i = -1, 1 do
        local offset = i * thickness * 1.35
        local waveStyle = {
            primary = style.primary,
            secondary = style.secondary,
            curve = (style.curve or 0) + offset,
            wave = (style.wave or 0) * 0.65,
            trail = style.trail,
        }
        local points = BuildTrailPoints(sx, sy, ex, ey, ux, uy, nx, ny, progress, waveStyle, effectTime_ * 4.0 + i, i == 0 and 0.34 or 0.28)
        DrawFlatPolyline(points, i == 0 and style.primary or style.secondary, outline, thickness * (i == 0 and 0.48 or 0.34), 180 * lifeAlpha)
    end
    DrawFlatCircle(headX, headY, thickness * 0.86, style.secondary or style.primary, 210 * lifeAlpha, outline,
        math.max(1.0, thickness * 0.18), 170 * lifeAlpha)

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawPoisonProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.52, effectTime_ * 2.5, 0.36)
    if not headX then return end

    local outline = GetOutline(style)
    DrawFlatCircle(headX, headY, thickness * 1.32, style.primary, 230 * lifeAlpha, outline, math.max(1.2, thickness * 0.22), 190 * lifeAlpha)
    DrawFlatCircle(headX + nx * thickness * 0.45 - ux * thickness * 0.12, headY + ny * thickness * 0.45 - uy * thickness * 0.12,
        thickness * 0.48, style.secondary, 220 * lifeAlpha, nil, 0, 0)

    for i = 1, 5 do
        local bubbleT = Clamp01(progress - i * 0.065)
        if bubbleT > 0 then
            local bx, by = PathPoint(sx, sy, ex, ey, ux, uy, nx, ny, bubbleT, style, effectTime_ * 2.5)
            local side = (i % 2 == 0) and 1 or -1
            local size = thickness * (0.28 + i * 0.055)
            DrawFlatCircle(bx + nx * side * thickness * 1.05, by + ny * side * thickness * 1.05,
                size, style.secondary, 135 * lifeAlpha, outline, math.max(0.7, thickness * 0.10), 80 * lifeAlpha)
        end
    end

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawRingProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.42, 0, 0.30)
    if not headX then return end

    local outline = GetOutline(style)
    local radius = thickness * 1.85
    DrawFlatCircle(headX, headY, radius, style.secondary or style.primary, 235 * lifeAlpha, outline,
        math.max(1.5, thickness * 0.26), 210 * lifeAlpha)
    DrawFlatCircle(headX, headY, radius * 0.50, style.primary, 230 * lifeAlpha, outline,
        math.max(1.0, thickness * 0.16), 150 * lifeAlpha)
    DrawFlatSegment(headX - nx * radius * 0.55, headY - ny * radius * 0.55, headX + nx * radius * 0.55, headY + ny * radius * 0.55,
        math.max(1.0, thickness * 0.18), style.secondary or style.primary, 175 * lifeAlpha, nil)

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function BuildSoundArc(cx, cy, ux, uy, nx, ny, radius, segmentCount)
    local points = {}
    for i = 0, segmentCount do
        local angle = -1.05 + 2.1 * (i / segmentCount)
        local px = cx - ux * math.cos(angle) * radius + nx * math.sin(angle) * radius
        local py = cy - uy * math.cos(angle) * radius + ny * math.sin(angle) * radius
        table.insert(points, { x = px, y = py })
    end
    return points
end

local function DrawSoundProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.48, effectTime_ * 4.0, 0.34)
    if not headX then return end

    local outline = GetOutline(style)
    for i = 1, 3 do
        local cx = headX - ux * i * thickness * 1.35
        local cy = headY - uy * i * thickness * 1.35
        local points = BuildSoundArc(cx, cy, ux, uy, nx, ny, thickness * (1.0 + i * 0.62), 8)
        DrawFlatPolyline(points, style.secondary or style.primary, outline, math.max(1.1, thickness * 0.22), (150 - i * 24) * lifeAlpha)
    end
    DrawFlatCircle(headX, headY, thickness * 0.72, style.primary, 210 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 150 * lifeAlpha)

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawChainProjectile(sx, sy, ex, ey, progress, style, thickness)
    local ux, uy, nx, ny = GetPathFrame(sx, sy, ex, ey)
    if not ux then return end

    local lifeAlpha = progress > 0.9 and math.max(0.0, (1.0 - progress) / 0.1) or 1.0
    local outline = GetOutline(style)
    local points = BuildTrailPoints(sx, sy, ex, ey, ux, uy, nx, ny, progress, style, effectTime_ * 2.0, 0.44)
    DrawFlatPolyline(points, style.secondary or style.primary, outline, thickness * 0.35, 175 * lifeAlpha)

    for i, point in ipairs(points) do
        if i % 2 == 0 then
            local radius = thickness * (0.58 + (i % 4) * 0.04)
            DrawFlatCircle(point.x, point.y, radius, style.primary, 210 * lifeAlpha, outline, math.max(1.0, thickness * 0.15), 160 * lifeAlpha)
            DrawFlatCircle(point.x, point.y, radius * 0.45, style.secondary or style.primary, 170 * lifeAlpha, nil, 0, 0)
        end
    end

    local head = points[#points]
    DrawFlatCircle(head.x, head.y, thickness * 0.92, style.primary, 230 * lifeAlpha, outline, math.max(1.2, thickness * 0.20), 190 * lifeAlpha)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawInkProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.72, effectTime_ * 3.0, 0.34)
    if not headX then return end

    local outline = GetOutline(style)
    DrawFlatCircle(headX, headY, thickness * 1.0, style.primary, 220 * lifeAlpha, outline, math.max(1.1, thickness * 0.18), 180 * lifeAlpha)
    FillPolygon({
        { x = headX + ux * thickness * 2.0, y = headY + uy * thickness * 2.0 },
        { x = headX - ux * thickness * 0.7 + nx * thickness * 0.8, y = headY - uy * thickness * 0.7 + ny * thickness * 0.8 },
        { x = headX - ux * thickness * 0.7 - nx * thickness * 0.8, y = headY - uy * thickness * 0.7 - ny * thickness * 0.8 },
    }, style.primary, 210 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 150 * lifeAlpha)

    for i = 1, 5 do
        local dropT = Clamp01(progress - i * 0.055)
        if dropT > 0 then
            local px, py = PathPoint(sx, sy, ex, ey, ux, uy, nx, ny, dropT, style, effectTime_ * 3.0)
            local side = (i % 2 == 0) and 1 or -1
            local size = thickness * (0.28 + i * 0.035)
            DrawFlatCircle(px + nx * side * size * 2.1, py + ny * side * size * 2.1,
                size, style.secondary or style.primary, 125 * lifeAlpha, outline, math.max(0.7, thickness * 0.10), 85 * lifeAlpha)
        end
    end

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawTaijiProjectile(sx, sy, ex, ey, progress, style, thickness)
    local ux, uy, nx, ny = GetPathFrame(sx, sy, ex, ey)
    if not ux then return end

    local outline = GetOutline(style)
    local styleA = { primary = style.primary, secondary = style.primary, outline = outline, curve = 8, wave = 4, trail = style.trail }
    local styleB = { primary = style.secondary, secondary = style.secondary, outline = outline, curve = -8, wave = 4, trail = style.trail }
    local headAX, headAY, _, _, _, _, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, styleA, thickness * 0.38, effectTime_ * 3.0, 0.28)
    local headBX, headBY = DrawGenericTrail(sx, sy, ex, ey, progress, styleB, thickness * 0.38, effectTime_ * 3.0 + math.pi, 0.28)
    if not headAX or not headBX then return end

    DrawFlatCircle(headAX, headAY, thickness * 0.78, style.primary, 225 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 170 * lifeAlpha)
    DrawFlatCircle(headBX, headBY, thickness * 0.78, style.secondary, 225 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 170 * lifeAlpha)
    DrawFlatCircle((headAX + headBX) * 0.5, (headAY + headBY) * 0.5, thickness * 0.38,
        style.secondary or style.primary, 180 * lifeAlpha, nil, 0, 0)

    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawPlayerProjectile(sx, sy, ex, ey, progress, eff, thickness)
    local style = ResolveStyle(eff)
    if eff.crit then
        thickness = thickness * 1.18
    end
    if eff.visualVariant == "extra_attack" or eff.visualVariant == "segment" then
        thickness = thickness * 0.88
    elseif eff.visualVariant == "global" or eff.visualVariant == "skill" then
        thickness = thickness * math.max(1.18, eff.effectScale or 1)
    end

    if style.shape == "blade" then
        DrawBladeProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "spear" then
        DrawSpearProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "wind" then
        DrawWindProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "poison" then
        DrawPoisonProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "ring" then
        DrawRingProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "sound" then
        DrawSoundProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "chain" then
        DrawChainProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "ink" then
        DrawInkProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "taiji" then
        DrawTaijiProjectile(sx, sy, ex, ey, progress, style, thickness)
    else
        DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness)
    end
end

local function DrawMonsterDartProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.42, 0, 0.22)
    if not headX then return end

    local outline = GetOutline(style)
    DrawArrowHead(headX, headY, ux, uy, nx, ny, style.primary, thickness * 2.75, 230 * lifeAlpha, outline)
    DrawFlatSegment(headX - ux * thickness * 3.0, headY - uy * thickness * 3.0,
        headX - ux * thickness * 0.8, headY - uy * thickness * 0.8,
        math.max(1.2, thickness * 0.24), style.secondary or style.primary, 170 * lifeAlpha, outline)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterClawProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.36, 0, 0.22)
    if not headX then return end

    local outline = GetOutline(style)
    for i = -1, 1 do
        local ox = nx * i * thickness * 0.92
        local oy = ny * i * thickness * 0.92
        DrawFlatSegment(headX - ux * thickness * 1.9 + ox - nx * thickness * 0.45,
            headY - uy * thickness * 1.9 + oy - ny * thickness * 0.45,
            headX + ux * thickness * 1.9 + ox + nx * thickness * 0.45,
            headY + uy * thickness * 1.9 + oy + ny * thickness * 0.45,
            math.max(1.6, thickness * 0.36), style.primary, 225 * lifeAlpha, outline)
    end
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterTuskProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.36, 0, 0.18)
    if not headX then return end

    local outline = GetOutline(style)
    for i = -1, 1, 2 do
        local side = i * thickness * 0.62
        FillPolygon({
            { x = headX + ux * thickness * 2.7 + nx * side * 0.5, y = headY + uy * thickness * 2.7 + ny * side * 0.5 },
            { x = headX - ux * thickness * 1.2 + nx * (side + thickness * 0.52), y = headY - uy * thickness * 1.2 + ny * (side + thickness * 0.52) },
            { x = headX - ux * thickness * 0.5 + nx * (side - thickness * 0.38), y = headY - uy * thickness * 0.5 + ny * (side - thickness * 0.38) },
        }, style.secondary or style.primary, 230 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 185 * lifeAlpha)
    end
    DrawFlatCircle(headX - ux * thickness * 0.5, headY - uy * thickness * 0.5, thickness * 0.52,
        style.primary, 190 * lifeAlpha, outline, math.max(0.8, thickness * 0.12), 150 * lifeAlpha)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterLeafProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.42, effectTime_ * 3.0, 0.24)
    if not headX then return end

    local outline = GetOutline(style)
    local len = thickness * 3.4
    local w = thickness * 1.25
    FillPolygon({
        { x = headX + ux * len * 0.62, y = headY + uy * len * 0.62 },
        { x = headX + nx * w, y = headY + ny * w },
        { x = headX - ux * len * 0.62, y = headY - uy * len * 0.62 },
        { x = headX - nx * w, y = headY - ny * w },
    }, style.primary, 220 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 170 * lifeAlpha)
    DrawFlatSegment(headX - ux * len * 0.45, headY - uy * len * 0.45,
        headX + ux * len * 0.42, headY + uy * len * 0.42,
        math.max(1.0, thickness * 0.16), style.secondary or style.primary, 150 * lifeAlpha, nil)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterStoneProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.30, 0, 0.16)
    if not headX then return end

    local outline = GetOutline(style)
    local r = thickness * 1.25
    FillPolygon({
        { x = headX + ux * r * 1.15, y = headY + uy * r * 1.15 },
        { x = headX + nx * r * 0.95, y = headY + ny * r * 0.95 },
        { x = headX - ux * r * 0.72 + nx * r * 0.35, y = headY - uy * r * 0.72 + ny * r * 0.35 },
        { x = headX - ux * r * 1.05 - nx * r * 0.45, y = headY - uy * r * 1.05 - ny * r * 0.45 },
        { x = headX - nx * r * 0.95, y = headY - ny * r * 0.95 },
    }, style.primary, 230 * lifeAlpha, outline, math.max(1.2, thickness * 0.18), 180 * lifeAlpha)
    DrawFlatCircle(headX + nx * r * 0.24 - ux * r * 0.10, headY + ny * r * 0.24 - uy * r * 0.10,
        r * 0.28, style.secondary or style.primary, 150 * lifeAlpha, nil, 0, 0)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterFoxfireProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.38, effectTime_ * 4.0, 0.24)
    if not headX then return end

    local outline = GetOutline(style)
    local r = thickness * 1.25
    FillPolygon({
        { x = headX + ux * r * 1.75, y = headY + uy * r * 1.75 },
        { x = headX + nx * r * 0.92, y = headY + ny * r * 0.92 },
        { x = headX - ux * r * 1.05, y = headY - uy * r * 1.05 },
        { x = headX - nx * r * 0.92, y = headY - ny * r * 0.92 },
    }, style.primary, 225 * lifeAlpha, outline, math.max(1.1, thickness * 0.17), 175 * lifeAlpha)
    DrawFlatCircle(headX - ux * r * 0.15, headY - uy * r * 0.15, r * 0.48,
        style.secondary or style.primary, 180 * lifeAlpha, nil, 0, 0)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterSealProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.34, effectTime_ * 2.0, 0.20)
    if not headX then return end

    local outline = GetOutline(style)
    local r = thickness * 1.55
    DrawFlatCircle(headX, headY, r, style.secondary or style.primary, 220 * lifeAlpha, outline,
        math.max(1.2, thickness * 0.18), 175 * lifeAlpha)
    FillPolygon({
        { x = headX, y = headY - r * 0.72 },
        { x = headX + r * 0.72, y = headY },
        { x = headX, y = headY + r * 0.72 },
        { x = headX - r * 0.72, y = headY },
    }, style.primary, 190 * lifeAlpha, outline, math.max(0.8, thickness * 0.12), 120 * lifeAlpha)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterGourdProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.35, effectTime_ * 2.5, 0.22)
    if not headX then return end

    local outline = GetOutline(style)
    DrawFlatCircle(headX - ux * thickness * 0.7, headY - uy * thickness * 0.7, thickness * 0.76,
        style.secondary or style.primary, 210 * lifeAlpha, outline, math.max(0.8, thickness * 0.12), 150 * lifeAlpha)
    DrawFlatCircle(headX + ux * thickness * 0.52, headY + uy * thickness * 0.52, thickness * 1.12,
        style.primary, 225 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 170 * lifeAlpha)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterLanternProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.34, effectTime_ * 2.0, 0.20)
    if not headX then return end

    local outline = GetOutline(style)
    local w = thickness * 1.65
    local h = thickness * 2.4
    FillPolygon({
        { x = headX + ux * h * 0.52, y = headY + uy * h * 0.52 },
        { x = headX + nx * w * 0.60, y = headY + ny * w * 0.60 },
        { x = headX - ux * h * 0.52, y = headY - uy * h * 0.52 },
        { x = headX - nx * w * 0.60, y = headY - ny * w * 0.60 },
    }, style.primary, 215 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 160 * lifeAlpha)
    DrawFlatCircle(headX, headY, thickness * 0.48, style.secondary or style.primary, 180 * lifeAlpha, nil, 0, 0)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterWhipProjectile(sx, sy, ex, ey, progress, style, thickness)
    local ux, uy, nx, ny = GetPathFrame(sx, sy, ex, ey)
    if not ux then return end

    local lifeAlpha = progress > 0.9 and math.max(0.0, (1.0 - progress) / 0.1) or 1.0
    local outline = GetOutline(style)
    local points = BuildTrailPoints(sx, sy, ex, ey, ux, uy, nx, ny, progress, style, effectTime_ * 4.0, 0.34)
    DrawFlatPolyline(points, style.primary, outline, thickness * 0.42, 210 * lifeAlpha)
    local head = points[#points]
    DrawFlatCircle(head.x, head.y, thickness * 0.76, style.secondary or style.primary, 210 * lifeAlpha, outline,
        math.max(0.9, thickness * 0.14), 160 * lifeAlpha)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterIceProjectile(sx, sy, ex, ey, progress, style, thickness)
    local headX, headY, ux, uy, nx, ny, lifeAlpha = DrawGenericTrail(sx, sy, ex, ey, progress, style, thickness * 0.36, effectTime_ * 2.0, 0.20)
    if not headX then return end

    local outline = GetOutline(style)
    local r = thickness * 1.45
    FillPolygon({
        { x = headX + ux * r * 1.25, y = headY + uy * r * 1.25 },
        { x = headX + nx * r * 0.70, y = headY + ny * r * 0.70 },
        { x = headX - ux * r * 1.25, y = headY - uy * r * 1.25 },
        { x = headX - nx * r * 0.70, y = headY - ny * r * 0.70 },
    }, style.secondary or style.primary, 225 * lifeAlpha, outline, math.max(1.0, thickness * 0.16), 160 * lifeAlpha)
    DrawFlatSegment(headX - ux * r * 0.75, headY - uy * r * 0.75,
        headX + ux * r * 0.75, headY + uy * r * 0.75,
        math.max(0.9, thickness * 0.14), style.primary, 150 * lifeAlpha, nil)
    DrawImpact(ex, ey, nx, ny, progress, style, thickness)
end

local function DrawMonsterProjectile(sx, sy, ex, ey, progress, eff, thickness)
    local style = ResolveMonsterStyle(eff)
    if eff.crit then
        thickness = thickness * 1.18
    end

    if style.shape == "claw" then
        DrawMonsterClawProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "tusk" then
        DrawMonsterTuskProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "leaf" then
        DrawMonsterLeafProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "stone" then
        DrawMonsterStoneProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "venom" then
        DrawPoisonProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "foxfire" then
        DrawMonsterFoxfireProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "seal" then
        DrawMonsterSealProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "gourd" then
        DrawMonsterGourdProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "lantern" then
        DrawMonsterLanternProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "whip" then
        DrawMonsterWhipProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "ice" then
        DrawMonsterIceProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "spike" or style.shape == "dart" then
        DrawMonsterDartProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "spear" then
        DrawSpearProjectile(sx, sy, ex, ey, progress, style, thickness)
    elseif style.shape == "blade" then
        DrawBladeProjectile(sx, sy, ex, ey, progress, style, thickness)
    else
        DrawMonsterDartProjectile(sx, sy, ex, ey, progress, style, thickness)
    end
end

local function DrawVectorProjectile(sx, sy, ex, ey, progress, color, thickness)
    local t = Clamp01(progress)
    local dx = ex - sx
    local dy = ey - sy
    local len = math.sqrt(dx * dx + dy * dy)
    if len <= 0.001 then return end

    local ux = dx / len
    local uy = dy / len
    local nx = -uy
    local ny = ux
    local headX = Lerp(sx, ex, t)
    local headY = Lerp(sy, ey, t)
    local tailT = math.max(0, t - 0.32)
    local tailX = Lerp(sx, ex, tailT)
    local tailY = Lerp(sy, ey, tailT)
    local alpha = math.floor(220 * (1.0 - t * 0.08))
    local outline = PROJECTILE_OUTLINE

    DrawFlatPolyline({ { x = tailX, y = tailY }, { x = headX, y = headY } }, color, outline, thickness * 0.70, alpha)
    DrawArrowHead(headX, headY, ux, uy, nx, ny, color, math.max(16, thickness * 2.75), alpha, outline)
end

local function DrawCastPulse(cx, cy, radius, progress, color)
    local t = Clamp01(progress)
    local r, g, b = color[1], color[2], color[3]
    local alpha = math.floor(135 * (1.0 - t))
    if alpha <= 0 then return end

    nvgBeginPath(vg_)
    nvgCircle(vg_, cx, cy, radius * (0.22 + t * 0.32))
    nvgStrokeColor(vg_, nvgRGBA(PROJECTILE_OUTLINE[1], PROJECTILE_OUTLINE[2], PROJECTILE_OUTLINE[3], ClampAlpha(alpha * 0.55)))
    nvgStrokeWidth(vg_, math.max(2.0, radius * 0.036))
    nvgStroke(vg_)
    nvgBeginPath(vg_)
    nvgCircle(vg_, cx, cy, radius * (0.22 + t * 0.32))
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, alpha))
    nvgStrokeWidth(vg_, math.max(1.2, radius * 0.022))
    nvgStroke(vg_)
end

local function DrawHitHoldEffect(cx, cy, cellW, cellH, progress, style, crit)
    local t = Clamp01(progress)
    local color = style and style.primary or {255, 230, 120}
    local secondary = style and style.secondary or {255, 255, 255}
    local outline = GetOutline(style)
    local baseSize = math.min(cellW or 48, cellH or 48)
    local pulse = math.sin(t * math.pi)
    local fade = 1.0 - t
    local alpha = ClampAlpha(195 * fade)
    local radius = baseSize * (0.12 + 0.22 * t + 0.04 * pulse)
    if style and style.visualVariant == "global" then radius = radius * 1.45 end

    DrawFlatCircle(cx, cy, radius, nil, 0, outline, math.max(2.0, baseSize * 0.028), alpha * 0.65)
    DrawFlatCircle(cx, cy, radius * 0.82, nil, 0, color, math.max(1.5, baseSize * 0.020), alpha)

    if crit then
        local r = baseSize * (0.12 + 0.03 * pulse)
        FillPolygon({
            { x = cx, y = cy - r },
            { x = cx + r, y = cy },
            { x = cx, y = cy + r },
            { x = cx - r, y = cy },
        }, secondary, ClampAlpha(150 * fade), outline, math.max(1.0, baseSize * 0.012), ClampAlpha(120 * fade))
    else
        DrawFlatCircle(cx, cy, baseSize * (0.065 + 0.02 * pulse), secondary, ClampAlpha(105 * fade), nil, 0, 0)
    end

    local rayCount = crit and 8 or 6
    for i = 1, rayCount do
        local angle = (i / rayCount) * math.pi * 2 + t * 0.5
        local inner = baseSize * (0.13 + 0.03 * pulse)
        local outer = baseSize * (0.23 + 0.14 * t)
        local x1 = cx + math.cos(angle) * inner
        local y1 = cy + math.sin(angle) * inner
        local x2 = cx + math.cos(angle) * outer
        local y2 = cy + math.sin(angle) * outer
        DrawFlatSegment(x1, y1, x2, y2, math.max(1.4, baseSize * 0.016), secondary, ClampAlpha(130 * fade), outline)
    end
end

local function DrawAttackWaveEffects()
    local remaining = {}
    local board = GetBoardMetrics()
    if not board then return end

    local firstCell = BoardLayout.CellRect(board, 1, 1, false)
    local lastCell = BoardLayout.CellRect(board, Config.FIELD_ROWS, Config.GRID_COLS, false)
    local fieldBottom = lastCell.y + lastCell.h

    for _, eff in ipairs(attackEffects_) do
        local elapsed = effectTime_ - eff.startTime
        local flightDuration = eff.flightDuration or eff.duration
        local flightProgress = Clamp01(elapsed / math.max(0.001, flightDuration))
        local hitProgress = Clamp01((elapsed - flightDuration) / HIT_HOLD_DURATION)

        if elapsed < eff.duration then
            table.insert(remaining, eff)

            if eff.kind == "monster" then
                local sx, sy, cellW, cellH = FieldTargetPoint(board, eff.col, eff.row)
                local style = ResolveMonsterStyle(eff)
                local thickness = math.max(4, firstCell.w * (eff.crit and 0.068 or 0.054))
                local targetY = fieldBottom + firstCell.h * 0.12
                if elapsed <= flightDuration then
                    DrawMonsterProjectile(sx, sy, sx, targetY, flightProgress, eff, thickness)
                end
                if hitProgress > 0 then
                    DrawHitHoldEffect(sx, targetY, cellW, cellH, hitProgress, style, eff.crit)
                end
            else
                local sx, sy, slotW = DeployItemPoint(board, eff.slotIdx)
                if sx and sy then
                    local ex, ey, targetW, targetH = FieldTargetPoint(board, eff.targetCol or eff.col, eff.targetRow)
                    local thickness = math.max(4, slotW * 0.055)
                    local style = ResolveStyle(eff)
                    if elapsed <= flightDuration then
                        DrawCastPulse(sx, sy, slotW * 0.48, flightProgress, style.primary)
                        DrawPlayerProjectile(sx, sy, ex, ey, flightProgress, eff, thickness)
                    end
                    if hitProgress > 0 then
                        DrawHitHoldEffect(ex, ey, targetW, targetH, hitProgress, { primary = style.primary, secondary = style.secondary, outline = style.outline, visualVariant = eff.visualVariant }, eff.crit)
                    end
                end
            end
        end
    end
    attackEffects_ = remaining
end

function Effects.Render(vg, state, screenW, screenH)
    vg_ = vg
    screenW_ = screenW
    screenH_ = screenH

    DrawMergeEffects()
    DrawAttackWaveEffects()
    DrawCoinDropEffects()
end

return Effects
