local Config = require("Config")

local Assets = {}

Assets.JIAN_ICONS = {
    "image/jian_1_20260622134510.png",
    "image/jian_2_20260622134516.png",
    "image/jian_3_20260622134525.png",
    "image/jian_4_20260622134544.png",
    "image/jian_5_20260622134523.png",
    "image/jian_6_20260622134515.png",
    "image/jian_7_20260622134526.png",
    "image/jian_8_20260622134511.png",
    "image/jian_9_20260622134518.png",
}

Assets.FULU_ICONS = {
    "image/fulu_1.png", "image/fulu_2.png", "image/fulu_3.png",
    "image/fulu_4.png", "image/fulu_5.png", "image/fulu_6.png",
    "image/fulu_7.png", "image/fulu_8.png", "image/fulu_9.png",
}

Assets.JINNANG_ICONS = {
    "image/jinnang_1.png", "image/jinnang_2.png", "image/jinnang_3.png",
    "image/jinnang_4.png", "image/jinnang_5.png", "image/jinnang_6.png",
    "image/jinnang_7.png", "image/jinnang_8.png", "image/jinnang_9.png",
}

Assets.DANYAO_ICONS = {
    "image/danyao_1.png", "image/danyao_2.png", "image/danyao_3.png",
    "image/danyao_4.png", "image/danyao_5.png", "image/danyao_6.png",
    "image/danyao_7.png", "image/danyao_8.png", "image/danyao_9.png",
}

Assets.BAOXIANG_ICONS = {
    "image/baoxiang_1.png", "image/baoxiang_2.png", "image/baoxiang_3.png",
    "image/baoxiang_4.png", "image/baoxiang_5.png", "image/baoxiang_6.png",
    "image/baoxiang_7.png", "image/baoxiang_8.png", "image/baoxiang_9.png",
}

Assets.MELEE_ICONS = {
    "image/m_xiaoyao_20260621145055.png",
    "image/m_yaojiang_20260621145054.png",
    "image/m_yaowang_20260621145057.png",
    "image/m_mozun_20260621145056.png",
}

Assets.RANGED_ICONS = {
    "image/m_xiexiu_20260621145059.png",
    "image/m_yaodao_20260621145058.png",
    "image/m_moxiu_20260621145101.png",
    "image/m_xiexian_20260621145103.png",
}

function Assets.GetItemIcon(item)
    if not item then return nil end
    local quality = item.quality or 1
    if item.itemType == Config.ITEM_TYPE.DEFENSE then
        return Assets.JINNANG_ICONS[quality] or Assets.JINNANG_ICONS[1]
    elseif item.itemType == Config.ITEM_TYPE.PILL then
        return Assets.DANYAO_ICONS[quality] or Assets.DANYAO_ICONS[1]
    elseif item.itemType == Config.ITEM_TYPE.TALISMAN then
        return Assets.FULU_ICONS[quality] or Assets.FULU_ICONS[1]
    end
    return Assets.JIAN_ICONS[quality] or Assets.JIAN_ICONS[1]
end

function Assets.GetChestIcon(quality)
    return Assets.BAOXIANG_ICONS[quality] or Assets.BAOXIANG_ICONS[1]
end

function Assets.GetMonsterIcon(monster)
    if monster.monsterType == Config.MONSTER_TYPE.MELEE then
        local idx = 1
        if monster.name == "妖将" then idx = 2
        elseif monster.name == "妖王" then idx = 3
        elseif monster.name == "魔尊" then idx = 4 end
        return Assets.MELEE_ICONS[idx]
    end

    local idx = 1
    if monster.name == "妖道" then idx = 2
    elseif monster.name == "魔修" then idx = 3
    elseif monster.name == "邪仙" then idx = 4 end
    return Assets.RANGED_ICONS[idx]
end

return Assets
