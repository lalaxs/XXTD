local Config = require("Config")
local ItemSystem = require("ItemSystem")

local SlotAdapter = {}

local RARITY_MAP = {"common", "uncommon", "rare", "epic", "legendary", "mythic", "mythic", "mythic", "mythic"}

local ITEM_IMAGE_BY_BASE_ID = {
    qingfeng_sword = "image/weapon/weapon  (1).png",
    chiyan_spear = "image/weapon/weapon  (2).png",
    qingyu_fan = "image/weapon/weapon  (3).png",
    ziqi_gourd = "image/weapon/weapon  (4).png",
    jinguang_ring = "image/weapon/weapon  (5).png",
    qingyin_qin = "image/weapon/weapon  (6).png",
    baigu_staff = "image/weapon/weapon  (7).png",
    fuyao_chain = "image/weapon/weapon  (8).png",
    zhenyao_tower = "image/weapon/weapon  (9).png",
    double_blade_chain = "image/weapon/weapon  (10).png",
    bishui_sword = "image/weapon/weapon  (11).png",
    lingmo_brush = "image/weapon/weapon  (12).png",
    pozhen_spear = "image/weapon/weapon  (13).png",
    taiji_sword = "image/weapon/weapon  (14).png",
    huxin_pearl = "image/weapon/weapon  (15).png",

    dark_iron_shield = "image/armor/dark_iron_shield.png",
    thorn_armor = "image/armor/thorn_armor.png",
    yuqing_robe = "image/armor/yuqing_robe.png",
    creation_robe = "image/armor/creation_robe.png",
    purity_orb = "image/armor/purity_orb.png",

    hutai = "image/item/hutai.png",
    qingxin = "image/item/qingxin.png",
    zengyuan = "image/item/zengyuan.png",
    xuming = "image/item/xuming.png",
    juqi = "image/item/juqi.png",

    thunder = "image/item/thunder.png",
    root = "image/item/root.png",
    armor_break = "image/item/armor_break.png",
    attack_down = "image/item/attack_down.png",
    vulnerable = "image/item/vulnerable.png",
}

local ITEM_IMAGE_BY_NAME = {
    ["青锋剑"] = ITEM_IMAGE_BY_BASE_ID.qingfeng_sword,
    ["赤焰枪"] = ITEM_IMAGE_BY_BASE_ID.chiyan_spear,
    ["青羽扇"] = ITEM_IMAGE_BY_BASE_ID.qingyu_fan,
    ["紫气葫芦"] = ITEM_IMAGE_BY_BASE_ID.ziqi_gourd,
    ["金光环"] = ITEM_IMAGE_BY_BASE_ID.jinguang_ring,
    ["清音琴"] = ITEM_IMAGE_BY_BASE_ID.qingyin_qin,
    ["白骨杖"] = ITEM_IMAGE_BY_BASE_ID.baigu_staff,
    ["缚妖链"] = ITEM_IMAGE_BY_BASE_ID.fuyao_chain,
    ["镇妖塔"] = ITEM_IMAGE_BY_BASE_ID.zhenyao_tower,
    ["双刃锁链"] = ITEM_IMAGE_BY_BASE_ID.double_blade_chain,
    ["碧水剑"] = ITEM_IMAGE_BY_BASE_ID.bishui_sword,
    ["灵墨笔"] = ITEM_IMAGE_BY_BASE_ID.lingmo_brush,
    ["破阵枪"] = ITEM_IMAGE_BY_BASE_ID.pozhen_spear,
    ["太极剑"] = ITEM_IMAGE_BY_BASE_ID.taiji_sword,
    ["护心珠"] = ITEM_IMAGE_BY_BASE_ID.huxin_pearl,
}

local function NormalizeBaseId(item)
    if not item then return nil end
    local baseId = item.baseId
    if baseId and ITEM_IMAGE_BY_BASE_ID[baseId] then
        return baseId
    end

    local id = item.id
    if type(id) == "string" then
        local parsed = id:match("^weapon_(.+)_q%d+$")
            or id:match("^armor_(.+)_q%d+$")
            or id:match("^pill_(.+)_q%d+$")
            or id:match("^talisman_(.+)_q%d+$")
        if parsed and ITEM_IMAGE_BY_BASE_ID[parsed] then
            return parsed
        end
    end

    return baseId
end

local FALLBACK_IMAGES = {
    [Config.ITEM_TYPE.ATTACK] = "image/weapon/weapon  (1).png",
    [Config.ITEM_TYPE.DEFENSE] = "image/armor/dark_iron_shield.png",
    [Config.ITEM_TYPE.PILL] = "image/item/juqi.png",
    [Config.ITEM_TYPE.TALISMAN] = "image/item/thunder.png",
}

function SlotAdapter.GetItemImageByBaseId(baseId)
    return ITEM_IMAGE_BY_BASE_ID[baseId]
end

function SlotAdapter.GetItemImage(item)
    if not item then return nil end
    local baseId = NormalizeBaseId(item)
    return ITEM_IMAGE_BY_BASE_ID[baseId]
        or ITEM_IMAGE_BY_NAME[item.name]
        or FALLBACK_IMAGES[item.itemType]
end

function SlotAdapter.ItemToSlotData(item)
    if not item then return nil end

    local img = SlotAdapter.GetItemImage(item)

    return {
        name = item.name,
        icon = "",
        image = img,
        type = "any",
        category = ItemSystem.GetCategory(item),
        rarity = RARITY_MAP[item.quality] or "common",
        _raw = item,
    }
end

return SlotAdapter
