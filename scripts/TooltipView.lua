local UI = require("urhox-libs/UI")
local Config = require("Config")

local TooltipView = {}

function TooltipView.ShowItemInfo(item)
    if not item then return end

    local qName = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].name or "凡器"
    local info = ""
    if item.itemType == Config.ITEM_TYPE.ATTACK then
        info = string.format("剑 %s [%s]\nATK: %d  暴击: %d%%\n攻击同列最前排敌人", item.name, qName, item.atk, math.floor(item.crit * 100))
    elseif item.itemType == Config.ITEM_TYPE.DEFENSE then
        info = string.format("符 %s [%s]\n护盾: %d  减速: %d%%\n减速同列敌人并回复气血", item.name, qName, item.shield, math.floor(item.slow * 100))
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        info = string.format("丹 %s [%s]\n效果: %s  持续: %d回合\n放置后持续生效", item.name, qName, item.buff, item.duration)
    end

    if info ~= "" then
        TooltipView.ShowTooltip(info)
    end
end

function TooltipView.ShowMonsterInfo(monster)
    if not monster then return end

    local typeStr = monster.monsterType == Config.MONSTER_TYPE.MELEE and "近战" or "远程"
    TooltipView.ShowTooltip(string.format("%s [%s]\nHP: %d/%d  ATK: %d", monster.name, typeStr, monster.hp, monster.maxHp, monster.atk))
end

function TooltipView.ShowChestInfo(quality)
    local qName = Config.QUALITY[quality] and Config.QUALITY[quality].name or "凡器"
    TooltipView.ShowTooltip(string.format("宝箱 [%s品质]\n击碎可获得对应品质道具", qName))
end

function TooltipView.ShowTooltipAt(item, x, y)
    if not item then return end
    TooltipView.ShowItemInfo(item)
end

function TooltipView.ShowTooltip(text)
    UI.Toast.Show(text, { duration = 2.5, position = "center" })
end

function TooltipView.HideTooltip()
end

return TooltipView
