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

local WEAPON_BASE_DESC = {
    qingfeng_sword = "攻击同列最近敌人",
    chiyan_spear = "穿透同列敌人",
    qingyu_fan = "横扫主目标及相邻列",
    ziqi_gourd = "攻击范围内敌人",
    jinguang_ring = "攻击范围内敌人",
    qingyin_qin = "横扫主目标及相邻列",
    baigu_staff = "攻击同列最近敌人",
    fuyao_chain = "攻击同列最近敌人",
    zhenyao_tower = "攻击范围内敌人",
    double_blade_chain = "横扫主目标及相邻列",
    bishui_sword = "攻击同列最近敌人",
    lingmo_brush = "攻击范围内敌人",
    pozhen_spear = "穿透同列敌人",
    taiji_sword = "攻击同列最近敌人",
    huxin_pearl = "攻击守护范围内敌人",
}

local function Percent(value)
    return math.floor((value or 0) * 100 + 0.5)
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

local function GetEffectTier(item)
    local effect = item.specialEffect
    if not effect then return item.quality or 1 end
    return effect.tier or item.quality or 1
end

local function TierValue(tier, q5, q6, q7, q8, q9)
    if tier >= 9 then return q9 end
    if tier >= 8 then return q8 end
    if tier >= 7 then return q7 end
    if tier >= 6 then return q6 end
    return q5
end

local function EffectDuration(tier)
    return TierValue(tier, 2, 3, 3, 4, 5)
end

local function BuildWeaponSummary(item, state)
    local tier = GetEffectTier(item)
    local baseId = item.baseId
    local parts = { WEAPON_BASE_DESC[baseId] or "攻击同列最近敌人" }
    local critChance = GetEffectiveCritChance(state, item)
    local critMultiplier = GetEffectiveCritMultiplier(state, item)

    if tier >= Config.SKILL_UNLOCK_TIER then
        local turns = EffectDuration(tier)
        if baseId == "qingfeng_sword" then
            if tier >= 7 then
                table.insert(parts, string.format("必定暴击×%.1f", critMultiplier))
                table.insert(parts, tier >= 9 and "击杀时溢出穿透整列" or "击杀时溢出穿透1个敌人")
            else
                table.insert(parts, string.format("暴击率%d%%、暴击伤害×%.1f", Percent(critChance), critMultiplier))
            end
        elseif baseId == "chiyan_spear" then
            table.insert(parts, string.format("灼烧%d%%伤害%d回合", TierValue(tier, 15, 18, 20, 25, 30), turns))
            if tier >= 9 then
                table.insert(parts, "命中时向全场扩散灼烧")
            elseif tier >= 7 then
                table.insert(parts, "命中时向相邻列同排扩散灼烧")
            end
        elseif baseId == "qingyu_fan" then
            table.insert(parts, string.format("施加受击+%d%%的风刃印记%d回合", TierValue(tier, 10, 15, 15, 20, 25), turns))
            if tier >= 7 then table.insert(parts, "溅射变为全额伤害") end
        elseif baseId == "ziqi_gourd" then
            table.insert(parts, string.format("中毒%d%%伤害%d回合", TierValue(tier, 15, 18, 30, 40, 50), turns))
            if tier >= 7 then
                table.insert(parts, string.format("中毒目标死亡时毒爆%d%%伤害", TierValue(tier, 50, 50, 50, 70, 100)))
            end
        elseif baseId == "jinguang_ring" then
            table.insert(parts, string.format("削攻%d%%持续%d回合", TierValue(tier, 15, 20, 25, 30, 35), turns))
            if tier >= 7 then table.insert(parts, string.format("扩至全场并减暴%d%%", TierValue(tier, 15, 15, 15, 20, 25))) end
        elseif baseId == "qingyin_qin" then
            table.insert(parts, string.format("定身%d阶段", TierValue(tier, 1, 2, 3, 4, 5)))
            if tier >= 7 then table.insert(parts, string.format("定身期间每回合首次受击震荡%d%%伤害", TierValue(tier, 20, 20, 20, 30, 40))) end
        elseif baseId == "baigu_staff" then
            table.insert(parts, string.format("目标防御-%d%%持续%d回合", TierValue(tier, 15, 20, 25, 30, 45), turns))
            if tier >= 7 then table.insert(parts, string.format("低血目标每回合损失最大生命%d%%", TierValue(tier, 5, 5, 5, 7, 10))) end
        elseif baseId == "fuyao_chain" then
            table.insert(parts, string.format("定身%d阶段", TierValue(tier, 1, 2, 3, 4, 5)))
            if tier >= 7 then table.insert(parts, string.format("定身期间每回合锁魂%d%%伤害", TierValue(tier, 30, 30, 30, 40, 50))) end
        elseif baseId == "zhenyao_tower" then
            table.insert(parts, string.format("削攻%d%%持续%d回合", TierValue(tier, 15, 20, 25, 30, 35), turns))
            if tier >= 7 then table.insert(parts, string.format("压制全场并造成塔威%d%%伤害", TierValue(tier, 20, 20, 20, 30, 40))) end
        elseif baseId == "double_blade_chain" then
            if tier == 5 then
                table.insert(parts, "拉拽最近敌人1格")
            else
                table.insert(parts, string.format("拉拽并绞杀%d%%伤害%d回合", TierValue(tier, 15, 15, 25, 35, 45), turns))
            end
            if tier >= 7 then table.insert(parts, "拉拽距离提升至2格") end
        elseif baseId == "bishui_sword" then
            table.insert(parts, string.format("目标攻击-%d%%持续%d回合", TierValue(tier, 15, 20, 25, 30, 35), turns))
            if tier >= 7 then table.insert(parts, string.format("对削攻目标伤害+%d%%", TierValue(tier, 20, 20, 20, 25, 30))) end
        elseif baseId == "lingmo_brush" then
            table.insert(parts, string.format("施加受击+%d%%的易伤标记%d回合", TierValue(tier, 10, 15, 20, 25, 30), turns))
            if tier >= 7 then table.insert(parts, string.format("全场易伤并造成墨蚀%d%%伤害", TierValue(tier, 15, 15, 15, 20, 25))) end
        elseif baseId == "pozhen_spear" then
            table.insert(parts, string.format("本武器命中无视%d%%防御", Percent(item.defIgnore or 0)))
            if tier >= 7 then table.insert(parts, string.format("穿透整列并施加受击+%d%%", TierValue(tier, 15, 15, 15, 20, 25))) end
        elseif baseId == "taiji_sword" then
            local damageBonus = TierValue(tier, 0, 10, 15, 20, 25)
            if damageBonus > 0 then
                table.insert(parts, string.format("击退目标1格并伤害+%d%%", damageBonus))
            else
                table.insert(parts, "击退目标1格")
            end
            if tier >= 7 then table.insert(parts, string.format("击退2格并落地定身%d阶段", tier >= 9 and 2 or 1)) end
        elseif baseId == "huxin_pearl" then
            table.insert(parts, string.format("削攻%d%%持续%d回合", TierValue(tier, 15, 20, 25, 30, 35), turns))
            if tier >= 7 then table.insert(parts, string.format("压制全场、减暴%d%%并造成莲华%d%%伤害", TierValue(tier, 15, 15, 15, 20, 25), TierValue(tier, 20, 20, 20, 30, 40))) end
        end
    end

    return table.concat(parts, "，") .. "。"
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
    local extraAttackChance = math.max(0, (item.atkSpeed or 1.0) - 1.0)
    if extraAttackChance > 0 then
        AddLine(lines, string.format("追加出手：%d%%", Percent(extraAttackChance)))
    end
    AddLine(lines, "描述：" .. BuildWeaponSummary(item, state))
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
        local text = string.format("法宝伤害提升%d%%", Percent(effect.value))
        if (effect.speedValue or 0) > 0 then
            text = text .. string.format("，追加出手提升%d%%", Percent(effect.speedValue))
        end
        return string.format("%s，持续%d回合。", text, effect.duration or 0)
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
    if (monster.rootTurns or 0) > 0 then AddLine(states, string.format("定身%d", monster.rootTurns)) end
    if (monster.stealthTurns or 0) > 0 then AddLine(states, string.format("隐身%d", monster.stealthTurns)) end
    if (monster.tauntTurns or 0) > 0 then AddLine(states, string.format("嘲讽%d", monster.tauntTurns)) end
    if (monster.defenseDownTurns or 0) > 0 then AddLine(states, string.format("破甲%d%%", Percent(monster.defenseDown))) end
    if (monster.attackDownTurns or 0) > 0 then AddLine(states, string.format("削攻%d%%", Percent(monster.attackDown))) end
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
