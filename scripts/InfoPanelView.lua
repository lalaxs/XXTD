-- InfoPanelView.lua
-- 信息浮窗视图（牛皮纸古卷风格）

local UI = require("urhox-libs/UI")
local Config = require("Config")
local ItemSystem = require("ItemSystem")
local SlotAdapter = require("SlotAdapter")
local ReincarnationSystem = require("ReincarnationSystem")
local RogueRewardSystem = require("rogue.RogueRewardSystem")
local STYLE = require("Theme")

local InfoPanelView = {}
InfoPanelView.__index = InfoPanelView

-- 类型标签文本映射
local TYPE_LABELS = {
    [Config.ITEM_TYPE.ATTACK] = "剑",
    [Config.ITEM_TYPE.DEFENSE] = "盾",
    [Config.ITEM_TYPE.PILL] = "丹",
    [Config.ITEM_TYPE.TALISMAN] = "符",
}

local function Percent(value)
    return math.floor((value or 0) * 100 + 0.5)
end

local function FormatDecimal(value)
    local text = string.format("%.2f", value or 0):gsub("0+$", "")
    if text:sub(-1) == "." then return text .. "0" end
    return text
end

local function PercentText(value)
    return FormatDecimal((value or 0) * 100)
end

local function AddLine(lines, text)
    if text and text ~= "" then
        table.insert(lines, text)
    end
end

local function JoinLines(lines)
    return table.concat(lines, "\n")
end

local function GetDecomposeExp(item)
    local quality = item and item.quality or 1
    return Config.DECOMPOSE_EXP[quality] or Config.DECOMPOSE_EXP[1] or 0
end

local function AddDecomposeLine(lines, item)
    AddLine(lines, string.format("分解获得修为：%d", GetDecomposeExp(item)))
end

local function GetExtraAttackPower(item)
    return item.extraAtk
        or item.extraAttack
        or item.extraAttackPower
        or item.atkBonus
        or item.attackBonus
        or 0
end

local function FormatCleanseCount(count)
    if (count or 0) >= 99 then
        return "全部"
    end
    return tostring(count or 1) .. "个"
end

local function Clamp01(value)
    return math.min(1.0, math.max(0.0, value or 0))
end

local function FormatExp(value)
    local n = tonumber(value) or 0
    return tostring(math.max(0, math.floor(n + 0.5)))
end

local function GetEffectiveCritChance(state, item)
    local chance = item.crit or 0
    if state then
        chance = chance + ReincarnationSystem.GetValue(state, "critChance") + RogueRewardSystem.GetModifierValue(state, "critChance") + RogueRewardSystem.GetModifierValue(state, "critChance:" .. tostring(item.baseId))
    end
    return Clamp01(chance)
end

local function GetEffectiveCritMultiplier(state, item)
    local multiplier = item.critMultiplier or 2.0
    if state then
        multiplier = multiplier + RogueRewardSystem.GetModifierValue(state, "critDamagePct") + RogueRewardSystem.GetModifierValue(state, "critDamagePct:" .. tostring(item.baseId))
    end
    return multiplier
end

local function HasWeaponSkill(state, skillId)
    return state
        and state.weaponUpgradeLevels
        and state.weaponUpgradeLevels["weaponSkill:" .. skillId] ~= nil
end

local function BuildWeaponSummary(item, state)
    local baseId = item.baseId
    local parts = {}

    if baseId == "qingfeng_sword" then
        local threshold = math.max(0, (item.highHpThreshold or 0.80) - (HasWeaponSkill(state, "qingfeng_huali") and 0.15 or 0))
        local bonus = (item.highHpBonusPct or 0.20) * (HasWeaponSkill(state, "sword_edge_exposed") and 1.20 or 1)
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("目标攻击前生命高于%d%%时，额外造成%d%%武器伤害", Percent(threshold), Percent(bonus)))
    elseif baseId == "chiyan_spear" then
        AddLine(parts, "攻击同列最近敌人，并施加1层灼烧")
        AddLine(parts, string.format("每层灼烧持续3回合，每回合造成%d%%武器伤害，最多5层", Percent(item.burnDamagePct or 0.05)))
        if (item.extraBurnChance or 0) > 0 then
            AddLine(parts, string.format("每次命中有%d%%概率额外施加1层灼烧", Percent(item.extraBurnChance)))
        end
    elseif baseId == "qingyu_fan" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("同时溅射%d个最近敌人，每个造成%d%%武器伤害", item.splashCount or 1, Percent(item.splashRatio or 0.20)))
    elseif baseId == "ziqi_gourd" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("每次攻击有%d%%概率回复相当于%d%%武器伤害的气血，最低回复1点", Percent(item.healChance or 0.08), Percent(item.healDamagePct or 0.01)))
        if (item.doubleDamageChance or 0) > 0 then
            AddLine(parts, string.format("触发回血时，另有%d%%概率使本次攻击造成双倍伤害", Percent(item.doubleDamageChance)))
        end
    elseif baseId == "jinguang_ring" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("每次攻击有%d%%概率将普通敌人击退2格；精英有50%%概率抵抗，头目免疫", Percent(item.knockbackChance or 0.10)))
        if (item.collisionDamagePct or 0) > 0 then
            AddLine(parts, string.format("击退路线被敌人阻挡时，对阻挡者额外造成%d%%武器伤害", Percent(item.collisionDamagePct)))
        end
    elseif baseId == "qingyin_qin" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("每次攻击有%d%%概率定身1回合，成功后目标进入%d回合定身免疫", Percent(item.rootChance or 0.20), item.rootCooldown or 4))
    elseif baseId == "baigu_staff" then
        local bonus = item.defenseDownBonus or 0
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("根据目标攻击前生命比例降低%d%%～%d%%防御，目标生命越高削防越强，持续2回合", Percent(0.10 + bonus), Percent(0.20 + bonus)))
        if (item.defenseDownDamagePct or 0) > 0 then
            AddLine(parts, string.format("攻击已被削防的目标时，武器伤害提高%d%%", Percent(item.defenseDownDamagePct)))
        end
    elseif baseId == "fuyao_chain" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("基础暴击率%d%%，暴击伤害×%.2f", Percent(item.crit or 0.25), item.critMultiplier or 2.0))
        if (item.chainCritStep or 0) > 0 then
            AddLine(parts, string.format("每次连续暴击使下一次暴击伤害提高%d个百分点，未暴击时重置", Percent(item.chainCritStep)))
        end
    elseif baseId == "zhenyao_tower" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("每次攻击还会对全场所有存活敌人造成%s%%武器伤害", PercentText(item.globalDamagePct or 0.025)))
        if (item.doubleCastChance or 0) > 0 then
            AddLine(parts, string.format("全场伤害有%d%%概率额外结算1次", Percent(item.doubleCastChance)))
        end
    elseif baseId == "double_blade_chain" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("每次攻击分为2段，每段造成%d%%武器伤害，并独立判定暴击", Percent(item.segmentDamagePct or 0.45)))
        if (item.tripleChance or 0) > 0 then
            AddLine(parts, string.format("每次攻击有%d%%概率追加第3段攻击", Percent(item.tripleChance)))
        end
    elseif baseId == "bishui_sword" then
        AddLine(parts, "攻击同列最近敌人，攻击必定暴击")
        AddLine(parts, string.format("当前基础暴击伤害×%.2f", item.critMultiplier or 1.15))
        if (item.weaponDamagePct or 0) > 0 then
            AddLine(parts, string.format("武器伤害额外提高%d%%", Percent(item.weaponDamagePct)))
        end
        if (item.maxHpDamagePct or 0) > 0 then
            AddLine(parts, string.format("额外造成目标最大生命%d%%的伤害，最多不超过70%%武器伤害", Percent(item.maxHpDamagePct)))
        end
    elseif baseId == "lingmo_brush" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("玩家生命不高于30%%时，武器伤害提高%d%%", Percent(item.lowPlayerDamagePct or 0.20)))
        if (item.lowPlayerLayerPct or 0) > 0 then
            AddLine(parts, string.format("生命低于30%%后，每再损失5%%最大生命，伤害再提高%d个百分点", Percent(item.lowPlayerLayerPct)))
        end
    elseif baseId == "pozhen_spear" then
        AddLine(parts, string.format("攻击同列最近敌人，并无视目标%d%%防御", Percent(item.defIgnore or 1.0)))
        if (item.baseDefenseDamagePct or 0) > 0 then
            AddLine(parts, string.format("额外造成相当于目标原始防御%d%%的伤害", Percent(item.baseDefenseDamagePct)))
        end
        if (item.weaponDamagePct or 0) > 0 then
            AddLine(parts, string.format("武器伤害额外提高%d%%", Percent(item.weaponDamagePct)))
        end
    elseif baseId == "taiji_sword" then
        local bonus = (item.lowHpBonusPct or 0.15) * (HasWeaponSkill(state, "sword_edge_exposed") and 1.20 or 1)
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("目标攻击前生命低于%d%%时，额外造成%d%%武器伤害", Percent(item.lowHpThreshold or 0.20), Percent(bonus)))
    elseif baseId == "huxin_pearl" then
        AddLine(parts, "攻击同列最近敌人")
        AddLine(parts, string.format("降低目标%d%%攻击力，持续2回合，并额外造成等同本次削减攻击力的伤害", Percent(item.attackDownPct or 0.10)))
        if (item.blindChance or 0) > 0 then
            AddLine(parts, string.format("每次攻击有%d%%概率致盲目标2回合；精英有50%%概率抵抗，头目免疫", Percent(item.blindChance)))
        end
    else
        AddLine(parts, "攻击同列最近敌人")
    end

    return table.concat(parts, "；") .. "。"
end

local function BuildWeaponDesc(item, state)
    local lines = {}
    local atk = item.atk or item.power or 0
    local crit = GetEffectiveCritChance(state, item)
    local critMultiplier = GetEffectiveCritMultiplier(state, item)
    local extraAttackPower = GetExtraAttackPower(item)
    AddLine(lines, string.format("攻击力：%d", atk))
    AddLine(lines, string.format("暴击率：%d%%", Percent(crit)))
    AddLine(lines, string.format("暴击伤害：×%.1f", critMultiplier))
    AddLine(lines, string.format("额外攻击力：%d", extraAttackPower))
    AddLine(lines, "详细效果：" .. BuildWeaponSummary(item, state))
    AddDecomposeLine(lines, item)
    return JoinLines(lines)
end

local function BuildArmorEffectDesc(effect)
    if not effect then return "" end
    if effect.type == "block" then
        local text = string.format("格挡：%d%%概率免伤", Percent(effect.blockChance))
        if (effect.reflectRatio or 0) > 0 then
            text = text .. string.format("，反伤%d%%", Percent(effect.reflectRatio))
        end
        return text
    elseif effect.type == "thorns" then
        local text = string.format("荆棘：反伤%d%%", Percent(effect.reflectRatio))
        if (effect.bleedRatio or 0) > 0 then
            text = text .. string.format("，吸收转伤%d%%", Percent(effect.bleedRatio))
        end
        return text
    elseif effect.type == "turnShield" then
        return string.format("回合护盾：每回合+%d，上限加成%d", effect.shield or 0, effect.carryBonus or 0)
    elseif effect.type == "regen" then
        return string.format("造化：每回合回血%d，受击回血%d", effect.perTurn or 0, effect.onHit or 0)
    elseif effect.type == "cleanse" then
        local cleanseText = effect.cleanseAll and "全净化" or "净化"
        return string.format("%s：免疫%d回合", cleanseText, effect.immunityTurns or 0)
    end
    return ""
end

local function BuildArmorDesc(item)
    local lines = {}
    AddLine(lines, string.format("防御力：%d", item.defense or item.power or 0))
    local effectDesc = BuildArmorEffectDesc(item.armorEffect)
    if effectDesc == "" then
        effectDesc = "占格生效，多件护甲加法叠加；单次伤害最多减算60%，无耐久。"
    end
    AddLine(lines, "特殊描述：" .. effectDesc)
    AddDecomposeLine(lines, item)
    return JoinLines(lines)
end

local function BuildPillEffectDesc(effect)
    if not effect then return nil end
    if effect.type == "heal" then
        local text = string.format("恢复%d气血", effect.value or 0)
        if (effect.reduction or 0) > 0 then
            text = text .. string.format("，并获得%d%%攻防强化%d回合", Percent(effect.reduction), effect.duration or 0)
        end
        if (effect.cleanseCount or 0) > 0 then
            text = text .. string.format("，清除%s负面状态", FormatCleanseCount(effect.cleanseCount))
        end
        return text .. "。"
    elseif effect.type == "shield" then
        return string.format("获得%d护盾，持续%d回合。", effect.value or 0, effect.duration or 0)
    elseif effect.type == "cleanse" then
        local text = string.format("清除%s负面状态", FormatCleanseCount(effect.cleanseCount))
        if (effect.immunityTurns or 0) > 0 then
            text = text .. string.format("，免疫负面状态%d回合", effect.immunityTurns or 0)
        end
        return text .. "。"
    elseif effect.type == "attackBuff" then
        return string.format("法宝伤害提升%d%%，持续%d回合。", Percent(effect.value), effect.duration or 0)
    elseif effect.type == "deathSave" then
        return string.format("获得一次免死护佑，触发时保留%d%%气血。", Percent(effect.value))
    end
    return nil
end

local function BuildPillDesc(item)
    local lines = {}
    AddLine(lines, BuildPillEffectDesc(item.pillEffect))
    if #lines == 0 then
        AddLine(lines, string.format("每秒恢复%d气血，持续%d秒。", item.healPerSec or item.value or 0, item.duration or 0))
    end
    AddDecomposeLine(lines, item)
    return JoinLines(lines)
end

local function FormatTargetCount(count)
    if (count or 0) >= 99 then
        return "全体"
    end
    return tostring(count or 1) .. "个"
end

local function BuildTalismanEffectDesc(effect)
    if not effect then return nil end
    local targetText = FormatTargetCount(effect.targetCount)
    if effect.type == "damage" then
        return string.format("随机对%s目标造成%d伤害。", targetText, effect.value or 0)
    elseif effect.type == "root" then
        return string.format("随机定身%s目标，持续%d回合。", targetText, effect.turns or 0)
    elseif effect.type == "armorBreak" then
        return string.format("随机破甲%s目标%d%%，持续%d回合。", targetText, Percent(effect.value), effect.duration or 0)
    elseif effect.type == "attackDown" then
        return string.format("随机削弱%s目标攻击%d%%，持续%d回合。", targetText, Percent(effect.value), effect.duration or 0)
    elseif effect.type == "vulnerable" then
        return string.format("随机使%s目标受到伤害提升%d%%，持续%d回合。", targetText, Percent(effect.value), effect.duration or 0)
    end
    return nil
end

local function BuildTalismanDesc(item)
    local lines = {}
    AddLine(lines, BuildTalismanEffectDesc(item.talismanEffect))
    if #lines == 0 then
        AddLine(lines, string.format("随机造成%d伤害。", item.aoeDmg or 0))
    end
    AddDecomposeLine(lines, item)
    return JoinLines(lines)
end

function InfoPanelView.Create()
    local self = setmetatable({
        root = nil,
        typeLabel = nil,
        iconPanel = nil,
        title = nil,
        desc = nil,
        useButton = nil,
        useButtonRow = nil,
        onUse = nil,
        activeItemContext = nil,
        timer = 0,
    }, InfoPanelView)

    self.typeLabel = UI.Label {
        text = "",
        fontSize = 20,
        fontWeight = "bold",
        textAlign = "center",
        fontColor = STYLE.TEXT_DARK,
        pointerEvents = "none",
    }
    self.iconPanel = UI.Panel {
        width = 72,
        height = 72,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = {232, 224, 202, 255},
        borderRadius = 10,
        borderWidth = 2,
        borderColor = {145, 106, 61, 255},
        backgroundFit = "contain",
        pointerEvents = "none",
        children = { self.typeLabel },
    }
    self.title = UI.Label {
        text = "",
        width = "100%",
        fontSize = 20,
        lineHeight = 1.25,
        fontColor = STYLE.TEXT_DARK,
        fontWeight = "bold",
        whiteSpace = "normal",
        wordBreak = "break-word",
        pointerEvents = "none",
    }
    self.desc = UI.Label {
        text = "",
        width = "100%",
        fontSize = 16,
        lineHeight = 1.35,
        fontColor = {58, 44, 30, 255},
        whiteSpace = "normal",
        wordBreak = "break-word",
        pointerEvents = "none",
    }
    self.useButton = UI.Button {
        text = "使用",
        visible = false,
        width = 96,
        height = 38,
        fontSize = 18,
        fontWeight = "bold",
        backgroundColor = {166, 60, 51, 255},
        textColor = {255, 245, 230, 255},
        borderRadius = 8,
        onClick = function()
            if self.onUse and self.activeItemContext then
                self.onUse(self.activeItemContext)
            end
        end,
    }
    self.useButtonRow = UI.Panel {
        visible = false,
        width = "100%",
        flexDirection = "row",
        justifyContent = "flex-end",
        alignItems = "center",
        children = {
            self.useButton,
        },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        bottom = 0,
        left = "8%",
        width = "84%",
        zIndex = 999,
        padding = 14,
        flexDirection = "column",
        gap = 10,
        backgroundColor = {244, 235, 212, 255},
        borderRadius = 12,
        borderWidth = 2,
        borderColor = {138, 96, 51, 255},
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 0, color = {0, 0, 0, 55} },
        },
        onClick = function()
            self:Hide()
        end,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = 12,
                alignItems = "center",
                children = {
                    self.iconPanel,
                    UI.Panel {
                        flexGrow = 1,
                        flexShrink = 1,
                        gap = 4,
                        children = {
                            self.title,
                        },
                    },
                },
            },
            self.desc,
            self.useButtonRow,
        },
    }

    return self
end

function InfoPanelView:GetRoot()
    return self.root
end

function InfoPanelView:SetBottom(bottom)
    if self.root then
        self.root:SetStyle({ bottom = math.max(0, bottom or 0) })
    end
end

function InfoPanelView:SetOnUse(callback)
    self.onUse = callback
end

function InfoPanelView:Update(dt)
    if self.timer > 0 then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self:Hide()
        end
    end
end

function InfoPanelView:Hide()
    self.timer = 0
    self.activeItemContext = nil
    if self.useButton then
        self.useButton:SetVisible(false)
    end
    if self.useButtonRow then
        self.useButtonRow:SetVisible(false)
    end
    self.root:SetVisible(false)
end

function InfoPanelView:ShowItem(item, context, state)
    if not item then return end

    local qName = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].name or "凡器"
    local title = string.format("%s [%s]", item.name, qName)
    local desc = ""
    if item.itemType == Config.ITEM_TYPE.ATTACK then
        desc = BuildWeaponDesc(item, state)
    elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
        desc = BuildArmorDesc(item)
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        desc = BuildPillDesc(item)
    elseif item.itemType == Config.ITEM_TYPE.TALISMAN then
        desc = BuildTalismanDesc(item)
    end

    local label = TYPE_LABELS[item.itemType] or "器"
    local qColor = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].color or {200, 200, 200, 255}
    local itemImage = SlotAdapter.GetItemImage(item)
    self.typeLabel:SetText(itemImage and "" or label)
    self.typeLabel:SetFontColor(STYLE.TEXT_DARK)
    if self.iconPanel then
        self.iconPanel:SetStyle({
            backgroundImage = itemImage or false,
            backgroundFit = "contain",
            backgroundColor = {232, 224, 202, 255},
            borderColor = qColor,
        })
    end
    self.title:SetText(title)
    self.desc:SetText(desc)
    self.activeItemContext = context
    local category = ItemSystem.GetCategory(item)
    local canUse = context and (category == "pill" or category == "talisman")
    if self.useButton then
        self.useButton:SetVisible(canUse == true)
    end
    if self.useButtonRow then
        self.useButtonRow:SetVisible(canUse == true)
    end
    self.timer = canUse and 6.0 or 4.0
    self.root:SetVisible(true)
end

function InfoPanelView:ShowFieldReward(quality)
    self.activeItemContext = nil
    if self.useButton then
        self.useButton:SetVisible(false)
    end
    if self.useButtonRow then
        self.useButtonRow:SetVisible(false)
    end
    quality = quality or 1
    local qName = Config.QUALITY[quality] and Config.QUALITY[quality].name or "凡器"
    local qColor = Config.QUALITY[quality] and Config.QUALITY[quality].color or {200, 200, 200, 255}
    self.typeLabel:SetText("奖")
    self.typeLabel:SetFontColor(qColor)
    if self.iconPanel then
        self.iconPanel:SetStyle({
            backgroundImage = false,
            backgroundColor = {232, 224, 202, 255},
            borderColor = qColor,
        })
    end
    self.title:SetText(string.format("场上奖励 [%s品质]", qName))
    self.desc:SetText("命中后可获得\n对应品质道具\n攻击法宝可拾取")
    self.timer = 3.0
    self.root:SetVisible(true)
end

function InfoPanelView:ShowRealm(state)
    if not state then return end
    self.activeItemContext = nil
    if self.useButton then
        self.useButton:SetVisible(false)
    end
    if self.useButtonRow then
        self.useButtonRow:SetVisible(false)
    end

    if state.ascensionMode == true then
        self.typeLabel:SetText("无尽")
        self.typeLabel:SetFontColor({171, 109, 46, 255})
        if self.iconPanel then
            self.iconPanel:SetStyle({
                backgroundImage = false,
                backgroundColor = {245, 219, 172, 255},
                borderColor = {171, 109, 46, 255},
            })
        end
        self.title:SetText("飞升状态")
        self.desc:SetText(JoinLines({
            "当前状态：飞升",
            "无尽波次：" .. tostring(state.endlessWaveIndex or 0),
            "累计击杀：" .. tostring(state.endlessKills or 0),
            "当前强度：" .. tostring(math.floor((state.endlessBudget or 0) + 0.5)),
            "气血归零后，本轮无尽挑战结束",
        }))
        self.timer = 6.0
        self.root:SetVisible(true)
        return
    end

    local realmIndex = math.min(#Config.REALMS, math.max(1, state.realmIndex or 1))
    local realm = Config.GetRealm(realmIndex)
    local requiredExp = realm.expRequired or 0
    local currentExp = state.exp or 0
    local progress = requiredExp > 0 and Clamp01(currentExp / requiredExp) or 1
    local remainingExp = math.max(0, requiredExp - currentExp)
    local nextRealm = realmIndex < #Config.REALMS and Config.GetRealm(realmIndex + 1) or nil
    local lines = {
        "当前境界：" .. tostring(realm.name),
    }

    if nextRealm then
        AddLine(lines, "下个境界：" .. tostring(nextRealm.name))
        AddLine(lines, string.format("当前修为：%s / %s", FormatExp(currentExp), FormatExp(requiredExp)))
        AddLine(lines, "还需修为：" .. FormatExp(remainingExp))
        AddLine(lines, "突破进度：" .. tostring(math.floor(progress * 100 + 0.5)) .. "%")
    else
        AddLine(lines, "下个境界：已至当前修行上限")
        AddLine(lines, "当前修为：" .. FormatExp(currentExp))
        AddLine(lines, "还需修为：0")
        AddLine(lines, "突破进度：100%")
    end

    self.typeLabel:SetText("境")
    self.typeLabel:SetFontColor({126, 78, 34, 255})
    if self.iconPanel then
        self.iconPanel:SetStyle({
            backgroundImage = false,
            backgroundColor = {245, 219, 172, 255},
            borderColor = {171, 109, 46, 255},
        })
    end
    self.title:SetText("境界修为")
    self.desc:SetText(JoinLines(lines))
    self.timer = 6.0
    self.root:SetVisible(true)
end

function InfoPanelView:ShowMonster(monster)
    if not monster then return end
    self.activeItemContext = nil
    if self.useButton then
        self.useButton:SetVisible(false)
    end
    if self.useButtonRow then
        self.useButtonRow:SetVisible(false)
    end
    local typeStr = monster.monsterType == Config.MONSTER_TYPE.MELEE and "近战" or "远程"
    local label = monster.monsterType == Config.MONSTER_TYPE.MELEE and "妖" or "修"
    local qColor = Config.QUALITY[monster.quality] and Config.QUALITY[monster.quality].color or {200, 80, 70, 255}
    local monsterImage = monster.asset
    local lines = {
        string.format("HP: %d/%d  ATK: %d  DEF: %d", monster.hp, monster.maxHp, monster.atk, monster.defense or 0),
        string.format("击杀获得: %d修为", monster.exp or 0),
    }

    if (monster.shieldAmount or 0) > 0 then
        AddLine(lines, string.format("护盾: %d", monster.shieldAmount))
    end
    if monster.skill then
        AddLine(lines, string.format("技能: %s", monster.skill.name or monster.skill.id or "未知"))
        AddLine(lines, monster.skill.desc)
    end

    local states = {}
    if monster.enraged then
        AddLine(states, "狂暴: 攻击+75% / 防御+60%")
    end
    if (monster.rootTurns or 0) > 0 then AddLine(states, string.format("定身%d回合", monster.rootTurns)) end
    if (monster.blindTurns or 0) > 0 then AddLine(states, string.format("致盲%d回合", monster.blindTurns)) end
    if (monster.qinImmuneTurns or 0) > 0 then AddLine(states, string.format("清音定身免疫%d回合", monster.qinImmuneTurns)) end
    if (monster.qinChanceBonus or 0) > 0 then AddLine(states, string.format("渐入清音+%d%%", Percent(monster.qinChanceBonus))) end
    if (monster.stealthTurns or 0) > 0 then AddLine(states, string.format("隐身%d", monster.stealthTurns)) end
    if (monster.defenseDownTurns or 0) > 0 then AddLine(states, string.format("破甲%d%%·%d回合", Percent(monster.defenseDown), monster.defenseDownTurns)) end
    if (monster.attackDownTurns or 0) > 0 then AddLine(states, string.format("削攻%d%%·%d回合", Percent(monster.attackDown), monster.attackDownTurns)) end
    if (monster.formationMarkTurns or 0) > 0 then AddLine(states, string.format("破阵印%d回合", monster.formationMarkTurns)) end
    if (monster.towerSealHits or 0) > 0 then AddLine(states, string.format("镇妖封印%d/5", monster.towerSealHits)) end
    if monster.burnInstances and #monster.burnInstances > 0 then
        local total = 0
        for index, burn in ipairs(monster.burnInstances) do
            local current = math.floor((burn.currentDamage or 0) + 0.5)
            total = total + current
            AddLine(states, string.format("灼烧%d: 初始%d/当前%d/%d回合", index, math.floor((burn.initialDamage or 0) + 0.5), current, burn.turns or 0))
        end
        AddLine(states, string.format("灼烧本次合计%d", total))
    end
    if monster.tier == Config.MONSTER_TIER.ELITE then AddLine(states, "控制抗性: 50%躲避硬控") end
    if monster.tier == Config.MONSTER_TIER.BOSS then AddLine(states, "控制抗性: 免疫硬控") end
    if (monster.critChanceDownTurns or 0) > 0 then AddLine(states, string.format("减暴%d%%", Percent(monster.critChanceDown))) end
    if (monster.vulnerableTurns or 0) > 0 then AddLine(states, string.format("易伤%d%%", Percent(monster.vulnerable))) end
    if (monster.dotTurns or 0) > 0 and (monster.dotDamage or 0) > 0 then AddLine(states, string.format("持续伤害%d×%d", monster.dotDamage, monster.dotTurns)) end
    if (monster.rootShockTurns or 0) > 0 and (monster.rootShockDamage or 0) > 0 then AddLine(states, string.format("镇魂震荡%d", monster.rootShockDamage)) end
    if (monster.poisonExplosionTurns or 0) > 0 and (monster.poisonExplosionDamage or 0) > 0 then AddLine(states, string.format("毒爆标记%d", monster.poisonExplosionDamage)) end
    if #states > 0 then
        AddLine(lines, "状态: " .. table.concat(states, " / "))
    end

    self.typeLabel:SetText(monsterImage and "" or label)
    self.typeLabel:SetFontColor(qColor)
    if self.iconPanel then
        self.iconPanel:SetStyle({
            backgroundImage = monsterImage or false,
            backgroundFit = "contain",
            backgroundColor = {232, 224, 202, 255},
            borderColor = qColor,
        })
    end
    self.title:SetText(string.format("%s [%s]", monster.name, typeStr))
    self.desc:SetText(JoinLines(lines))
    self.timer = 5.0
    self.root:SetVisible(true)
end

return InfoPanelView
