-- TalentUnlockSystem.lua
-- 天赋解锁池：控制合成 / 掉落 / 初始默认池能抽到哪些道具类型。

local Config = require("Config")

local TalentUnlockSystem = {}

local DEFAULT_UNLOCKS = {
    [Config.ITEM_CATEGORY.WEAPON] = { "qingfeng_sword" },
    [Config.ITEM_CATEGORY.ARMOR] = { "dark_iron_shield" },
    [Config.ITEM_CATEGORY.PILL] = { "juqi" },
    [Config.ITEM_CATEGORY.TALISMAN] = { "thunder" },
}

local WEAPON_SCHOOL_BY_BASE_ID = {
    qingfeng_sword = "sword",
    bishui_sword = "sword",
    taiji_sword = "sword",
    chiyan_spear = "spear",
    pozhen_spear = "spear",
    qingyu_fan = "magic",
    qingyin_qin = "magic",
    lingmo_brush = "magic",
    baigu_staff = "magic",
    ziqi_gourd = "magic",
    jinguang_ring = "magic",
    fuyao_chain = "chain",
    double_blade_chain = "chain",
    zhenyao_tower = "tower",
    huxin_pearl = "guardian",
}

local function AddDefaultUnlocks(unlocked, category)
    unlocked[category] = unlocked[category] or {}
    for _, id in ipairs(DEFAULT_UNLOCKS[category] or {}) do
        unlocked[category][id] = true
    end
end

local function RefreshUnlockedWeaponSchools(state)
    local schools = {}
    local unlockedWeapons = state.unlockedPools and state.unlockedPools[Config.ITEM_CATEGORY.WEAPON]
    for baseId, enabled in pairs(unlockedWeapons or {}) do
        local school = WEAPON_SCHOOL_BY_BASE_ID[baseId]
        if enabled and school then
            schools[school] = true
        end
    end
    state.unlockedWeaponSchools = schools
end

function TalentUnlockSystem.EnsureDefaults(state)
    if not state then return end

    state.unlockedPools = state.unlockedPools or {}
    AddDefaultUnlocks(state.unlockedPools, Config.ITEM_CATEGORY.WEAPON)
    AddDefaultUnlocks(state.unlockedPools, Config.ITEM_CATEGORY.ARMOR)
    AddDefaultUnlocks(state.unlockedPools, Config.ITEM_CATEGORY.PILL)
    AddDefaultUnlocks(state.unlockedPools, Config.ITEM_CATEGORY.TALISMAN)

    RefreshUnlockedWeaponSchools(state)
end

function TalentUnlockSystem.GetDefinitionBaseId(def)
    if not def then return nil end
    local data = def.data or def
    if data.baseId then return data.baseId end
    if data.unlockId then return data.unlockId end

    local id = data.id or def.id
    local category = data.category or def.category
    if not id or not category then return nil end

    return id:match("^" .. category .. "_(.+)_q%d+$") or id
end

function TalentUnlockSystem.IsDefinitionUnlocked(state, category, def)
    if not state then return true end
    TalentUnlockSystem.EnsureDefaults(state)

    local baseId = TalentUnlockSystem.GetDefinitionBaseId(def)
    local unlocked = state.unlockedPools and state.unlockedPools[category]
    if unlocked and baseId and unlocked[baseId] then
        return true
    end

    return false
end

function TalentUnlockSystem.FilterPool(state, category, pool)
    if not state then return pool end
    TalentUnlockSystem.EnsureDefaults(state)

    local filtered = {}
    for _, def in ipairs(pool or {}) do
        if TalentUnlockSystem.IsDefinitionUnlocked(state, category, def) then
            table.insert(filtered, def)
        end
    end

    if #filtered > 0 then
        return filtered
    end

    for _, def in ipairs(pool or {}) do
        local baseId = TalentUnlockSystem.GetDefinitionBaseId(def)
        for _, defaultId in ipairs(DEFAULT_UNLOCKS[category] or {}) do
            if baseId == defaultId then
                table.insert(filtered, def)
                break
            end
        end
    end

    return filtered
end

function TalentUnlockSystem.UnlockItem(state, category, baseId)
    TalentUnlockSystem.EnsureDefaults(state)
    state.unlockedPools[category] = state.unlockedPools[category] or {}
    state.unlockedPools[category][baseId] = true
    if category == Config.ITEM_CATEGORY.WEAPON then
        RefreshUnlockedWeaponSchools(state)
    end
end

return TalentUnlockSystem
