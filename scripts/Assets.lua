-- Assets.lua
-- 仙侠合成塔防 - 纯矢量资源（使用 emoji + 颜色代替外部图片）

local Config = require("Config")

local Assets = {}

-- ============================================================================
-- 道具矢量图标（emoji + 品质颜色边框）
-- ============================================================================
local ITEM_ICONS = {
    [Config.ITEM_TYPE.ATTACK] = {
        emoji = "⚔️",
        names = {"飞剑","灵剑","仙剑","神剑","天剑","圣剑","太古剑","混沌剑","鸿蒙剑"},
    },
    [Config.ITEM_TYPE.DEFENSE] = {
        emoji = "🛡️",
        names = {"铁甲","玄铁甲","星辰甲","紫霄甲","天罡甲","圣光甲","太古甲","紫金甲","鸿蒙甲"},
    },
    [Config.ITEM_TYPE.PILL] = {
        emoji = "💊",
        names = {"回灵丹","聚气丹","护体丹","破魔丹","天元丹","太乙丹","太古丹","混沌丹","鸿蒙丹"},
    },
    [Config.ITEM_TYPE.TALISMAN] = {
        emoji = "📜",
        names = {"镇灵符","青木符","星辰符","紫霄符","烈焰符","鎏金符","太古符","紫金符","鸿蒙符"},
    },
}

-- ============================================================================
-- 怪物矢量图标
-- ============================================================================
local MELEE_ICONS = {
    { emoji = "👹", color = {200, 80, 70, 255} },    -- 小妖
    { emoji = "👺", color = {180, 60, 50, 255} },    -- 妖兵/妖将
    { emoji = "🦇", color = {160, 50, 80, 255} },    -- 妖王
    { emoji = "😈", color = {140, 30, 60, 255} },    -- 魔尊+
}

local RANGED_ICONS = {
    { emoji = "🧙", color = {100, 70, 180, 255} },   -- 邪修
    { emoji = "🧿", color = {80, 60, 160, 255} },    -- 妖道/魔修
    { emoji = "👁️", color = {120, 50, 200, 255} },   -- 邪仙
    { emoji = "💀", color = {100, 40, 180, 255} },    -- 高阶
}

-- ============================================================================
-- 场上奖励矢量图标
-- ============================================================================
local FIELD_REWARD_ICONS = {
    { emoji = "📦", color = {180, 150, 100, 255} },  -- 1阶
    { emoji = "🎁", color = {100, 200, 120, 255} },  -- 2阶
    { emoji = "💰", color = {80, 150, 255, 255} },   -- 3阶
    { emoji = "👑", color = {180, 100, 255, 255} },  -- 4阶
    { emoji = "✨", color = {255, 160, 50, 255} },   -- 5阶
    { emoji = "🌟", color = {230, 70, 60, 255} },    -- 6阶
    { emoji = "💎", color = {255, 160, 200, 255} },  -- 7阶
    { emoji = "🔮", color = {255, 200, 50, 255} },   -- 8阶
    { emoji = "⭐", color = {180, 140, 40, 255} },   -- 9阶
}

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 获取道具图标数据（返回 {emoji, color} 用于 UI.Label 渲染）
function Assets.GetItemIcon(item)
    if not item then return nil end
    local quality = item.quality or 1
    local info = ITEM_ICONS[item.itemType]
    if not info then
        info = ITEM_ICONS[Config.ITEM_TYPE.ATTACK]
    end
    local qualityColor = Config.QUALITY[quality] and Config.QUALITY[quality].color or {200, 200, 200, 255}
    return {
        emoji = info.emoji,
        color = qualityColor,
        name = info.names[quality] or info.names[1],
    }
end

--- 获取怪物图标数据
function Assets.GetMonsterIcon(monster)
    if monster.monsterType == Config.MONSTER_TYPE.MELEE then
        local q = monster.quality or 1
        if q <= 2 then return MELEE_ICONS[1]
        elseif q <= 4 then return MELEE_ICONS[2]
        elseif q <= 6 then return MELEE_ICONS[3]
        else return MELEE_ICONS[4] end
    else
        local q = monster.quality or 1
        if q <= 2 then return RANGED_ICONS[1]
        elseif q <= 4 then return RANGED_ICONS[2]
        elseif q <= 6 then return RANGED_ICONS[3]
        else return RANGED_ICONS[4] end
    end
end

--- 获取场上奖励图标数据
function Assets.GetFieldRewardIcon(quality)
    return FIELD_REWARD_ICONS[quality] or FIELD_REWARD_ICONS[1]
end

return Assets
