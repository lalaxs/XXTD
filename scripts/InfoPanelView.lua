-- InfoPanelView.lua
-- 信息浮窗视图（牛皮纸古卷风格）

local UI = require("urhox-libs/UI")
local Config = require("Config")
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

function InfoPanelView.Create()
    local self = setmetatable({
        root = nil,
        typeLabel = nil,
        title = nil,
        desc = nil,
        timer = 0,
    }, InfoPanelView)

    self.typeLabel = UI.Label {
        text = "",
        fontSize = 18,
        fontWeight = "bold",
        textAlign = "center",
        fontColor = STYLE.TEXT_GOLD,
        pointerEvents = "none",
    }
    self.title = UI.Label {
        text = "",
        fontSize = 14,
        fontColor = STYLE.TEXT_GOLD,
        fontWeight = "bold",
        pointerEvents = "none",
    }
    self.desc = UI.Label {
        text = "",
        fontSize = 11,
        lineHeight = 14,
        fontColor = STYLE.TEXT_WHITE,
        pointerEvents = "none",
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        bottom = "38%",
        left = "9%",
        width = "82%",
        zIndex = 999,
        paddingHorizontal = 12,
        paddingVertical = 6,
        flexDirection = "row",
        gap = 8,
        alignItems = "center",
        backgroundColor = {55, 40, 25, 240},
        borderRadius = 10,
        borderWidth = 2,
        borderColor = STYLE.HUD_BORDER,
        onClick = function()
            self:Hide()
        end,
        children = {
            UI.Panel {
                width = 38,
                height = 38,
                alignItems = "center",
                justifyContent = "center",
                backgroundColor = {80, 60, 40, 150},
                borderRadius = 8,
                borderWidth = 1.5,
                borderColor = STYLE.CARD_BORDER,
                pointerEvents = "none",
                children = { self.typeLabel },
            },
            UI.Panel {
                flex = 1,
                flexShrink = 1,
                gap = 2,
                pointerEvents = "none",
                children = {
                    self.title,
                    self.desc,
                },
            },
        },
    }

    return self
end

function InfoPanelView:GetRoot()
    return self.root
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
    self.root:SetVisible(false)
end

function InfoPanelView:ShowItem(item)
    if not item then return end

    local qName = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].name or "凡器"
    local title = string.format("%s [%s]", item.name, qName)
    local desc = ""
    if item.itemType == Config.ITEM_TYPE.ATTACK then
        desc = string.format("ATK: %d  攻速: %.1fs\n攻击同列最前排敌人", item.atk, item.atkSpeed or 1.0)
    elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
        local dur = item.durability or 0
        desc = string.format("护盾: %d  减伤: %d%%\n只生效五回合 (剩余%d)", item.shield, math.floor((item.damageReduction or 0) * 100), dur)
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        desc = string.format("回血: %d/秒  持续%d秒\n放置后持续生效", item.healPerSec or item.value or 0, item.duration)
    elseif item.itemType == Config.ITEM_TYPE.TALISMAN then
        desc = string.format("范围伤害: %d\n范围: %d格", item.aoeDmg or 0, item.aoeRange or 3)
    end

    local label = TYPE_LABELS[item.itemType] or "器"
    local qColor = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].color or {200, 200, 200, 255}
    self.typeLabel:SetText(label)
    self.typeLabel:SetFontColor(qColor)
    self.title:SetText(title)
    self.desc:SetText(desc)
    self.timer = 3.0
    self.root:SetVisible(true)
end

function InfoPanelView:ShowChest(quality)
    quality = quality or 1
    local qName = Config.QUALITY[quality] and Config.QUALITY[quality].name or "凡器"
    local qColor = Config.QUALITY[quality] and Config.QUALITY[quality].color or {200, 200, 200, 255}
    self.typeLabel:SetText("箱")
    self.typeLabel:SetFontColor(qColor)
    self.title:SetText(string.format("宝箱 [%s品质]", qName))
    self.desc:SetText("击碎后可获得\n对应品质道具\n攻击法宝可打破")
    self.timer = 3.0
    self.root:SetVisible(true)
end

function InfoPanelView:ShowMonster(monster)
    if not monster then return end
    local typeStr = monster.monsterType == Config.MONSTER_TYPE.MELEE and "近战" or "远程"
    local label = monster.monsterType == Config.MONSTER_TYPE.MELEE and "妖" or "修"
    local qColor = Config.QUALITY[monster.quality] and Config.QUALITY[monster.quality].color or {200, 80, 70, 255}
    self.typeLabel:SetText(label)
    self.typeLabel:SetFontColor(qColor)
    self.title:SetText(string.format("%s [%s]", monster.name, typeStr))
    self.desc:SetText(string.format("HP: %d/%d\nATK: %d\n击杀获得: %d修为", monster.hp, monster.maxHp, monster.atk, monster.exp or 0))
    self.timer = 3.0
    self.root:SetVisible(true)
end

return InfoPanelView
