-- debug/DebugWeaponSystem.lua
-- 武器特效与专属肉鸽技能的战斗调试数据准备。

local Config = require("Config")
local ItemSystem = require("ItemSystem")
local WaveSystem = require("WaveSystem")
local WeaponDefs = require("config.WeaponDefs")
local RogueRewardDefs = require("config.RogueRewardDefs")
local RogueRewardSystem = require("rogue.RogueRewardSystem")

local DebugWeaponSystem = {}

local weapons = {}
local weaponById = {}
local skillsByWeapon = {}

for _, def in ipairs(WeaponDefs) do
    if not weaponById[def.baseId] then
        local weapon = { id = def.baseId, name = def.name }
        weaponById[def.baseId] = weapon
        table.insert(weapons, weapon)
    end
end

for _, reward in ipairs(RogueRewardDefs) do
    if reward.kind == "weaponSkill" then
        local linked = reward.weaponIds or { reward.weaponId }
        for _, weaponId in ipairs(linked) do
            skillsByWeapon[weaponId] = skillsByWeapon[weaponId] or {}
            table.insert(skillsByWeapon[weaponId], {
                id = reward.skillId,
                rewardId = reward.id,
                name = reward.name,
                desc = reward.desc,
            })
        end
    end
end

local function CopyArray(source)
    local copy = {}
    for index, value in ipairs(source or {}) do copy[index] = value end
    return copy
end

local function CopyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function EnsureSession(state)
    if state.debugWeaponSession then return state.debugWeaponSession end
    local session = {
        originalSlots = CopyMap(state.slots),
        originalMonsters = CopyArray(state.monsters),
        originalFieldRewards = CopyArray(state.fieldRewards),
        originalDropQueue = CopyArray(state.dropQueue),
        originalHp = state.hp,
        originalMaxHp = state.maxHp,
        originalRunWeapons = CopyMap(state.runWeapons),
        originalRunArmors = CopyMap(state.runArmors),
        originalWeaponUpgradeLevels = CopyMap(state.weaponUpgradeLevels),
        originalArmorUpgradeLevels = CopyMap(state.armorUpgradeLevels),
        originalSelectedRogueRewards = CopyMap(state.selectedRogueRewards),
        originalModifiers = CopyArray(state.modifiers),
        originalRogueRewardHistory = CopyArray(state.rogueRewardHistory),
        originalPendingRogueChoices = state.pendingRogueChoices,
        originalPendingRogueStage = state.pendingRogueStage,
        originalPendingRogueEvent = state.pendingRogueEvent,
        originalShouldSpawnBreakthroughWave = state.shouldSpawnBreakthroughWave,
        originalForceSpawnNextTurn = state.forceSpawnNextTurn,
    }
    state.debugWeaponSession = session
    return session
end

local function CreateMonster(state, id, col, row, hpRatio)
    local def = Config.MONSTER_BY_ID[id]
    if not def then return nil end
    local monster = WaveSystem.CreateMonsterFromDef(def, col, row, state)
    local item = state.slots[1]
    local weaponPower = item and (item.atk or item.power or 1) or 1
    monster.maxHp = math.max(monster.maxHp or 1, weaponPower * 30)
    monster.hp = math.max(1, math.floor(monster.maxHp * (hpRatio or 1.0)))
    return monster
end

function DebugWeaponSystem.GetWeapons()
    return weapons
end

function DebugWeaponSystem.GetSkills(weaponId)
    return skillsByWeapon[weaponId] or {}
end

function DebugWeaponSystem.GetSelectedWeaponId(state)
    return state.debugSelectedWeaponId or weapons[1].id
end

function DebugWeaponSystem.EquipWeapon(state, weaponId, quality)
    if not weaponById[weaponId] then return false end
    EnsureSession(state)
    state.runWeapons = state.runWeapons or {}
    state.runWeapons[weaponId] = true
    state.slots[1] = ItemSystem.CreateItemByBaseId(
        state,
        Config.ITEM_CATEGORY.WEAPON,
        weaponId,
        math.min(Config.MAX_QUALITY, math.max(1, quality or Config.MAX_QUALITY))
    )
    state.debugSelectedWeaponId = weaponId
    state.debugSelectedQuality = state.slots[1].quality
    print(string.format("[Debug Weapon] 已装配%s Q%d到第一列", weaponById[weaponId].name, state.slots[1].quality))
    return true
end

function DebugWeaponSystem.IsSkillEnabled(state, skillId)
    return ((state.weaponUpgradeLevels or {})["weaponSkill:" .. skillId] or 0) > 0
end

function DebugWeaponSystem.SetSkillEnabled(state, skill, enabled)
    if not skill then return false end
    EnsureSession(state)
    state.weaponUpgradeLevels = state.weaponUpgradeLevels or {}
    state.selectedRogueRewards = state.selectedRogueRewards or {}
    local key = "weaponSkill:" .. skill.id
    state.weaponUpgradeLevels[key] = enabled and 1 or nil
    state.selectedRogueRewards[skill.rewardId] = enabled and 1 or nil
    print(string.format("[Debug Weapon] %s技能：%s", enabled and "开启" or "关闭", skill.name))
    return true
end

function DebugWeaponSystem.SetAllSkills(state, weaponId, enabled)
    for _, skill in ipairs(DebugWeaponSystem.GetSkills(weaponId)) do
        DebugWeaponSystem.SetSkillEnabled(state, skill, enabled)
    end
end

function DebugWeaponSystem.CreateSkillChoices(state)
    EnsureSession(state)

    local choices = RogueRewardSystem.CreateBreakthroughChoices(state)
    if #choices == 0 then
        state.pendingRogueChoices = nil
        state.pendingRogueStage = nil
        state.pendingRogueEvent = nil
        return false, "当前没有可用于修炼提升的肉鸽选项"
    end

    local realm = Config.GetRealm(state.realmIndex or 1)
    state.pendingRogueEvent = {
        realmIndex = state.realmIndex,
        realmName = realm.name,
        isMajorBreakthrough = true,
        isDebugTraining = true,
    }
    state.shouldSpawnBreakthroughWave = false
    print(string.format("[Debug Weapon] 打开修炼提升三选一，共%d个攻击法宝机缘", #choices))
    return true
end

function DebugWeaponSystem.PrepareScenario(state, scenarioId)
    EnsureSession(state)
    state.monsters = {}
    state.fieldRewards = {}

    local function add(id, col, row, hpRatio)
        local monster = CreateMonster(state, id, col, row, hpRatio)
        if monster then table.insert(state.monsters, monster) end
    end

    if scenarioId == "low_hp" then
        add("wild_boar", 1, 5, 0.15)
    elseif scenarioId == "group" then
        add("wild_boar", 1, 5, 1.0)
        add("gray_wolf", 1, 3, 1.0)
        add("shell_imp", 2, 5, 1.0)
        add("green_snake", 2, 3, 1.0)
        add("poison_spider", 3, 4, 1.0)
    elseif scenarioId == "elite" then
        add("tree_demon", 1, 5, 1.0)
    elseif scenarioId == "boss" then
        add("tiger_boss", 1, 5, 1.0)
    else
        add("wild_boar", 1, 5, 1.0)
    end

    state.isGameOver = false
    state.isVictory = false
    print(string.format("[Debug Weapon] 已准备测试场景：%s（%d个目标）", scenarioId, #state.monsters))
    return #state.monsters > 0
end

function DebugWeaponSystem.PrepareFieldRewardScenario(state, rewardCategory)
    EnsureSession(state)
    local itemCategory = rewardCategory == "armor" and Config.ITEM_CATEGORY.ARMOR or Config.ITEM_CATEGORY.WEAPON
    local baseId = rewardCategory == "armor" and "dark_iron_shield" or "qingfeng_sword"
    local rewardItem = ItemSystem.CreateItemByBaseId(state, itemCategory, baseId, 1)
    if not rewardItem then return false end
    state.monsters = {}
    state.fieldRewards = {
        {
            id = "debug_field_reward",
            entityType = "reward",
            col = 1,
            row = 7,
            hp = 1,
            quality = 1,
            rewardItem = rewardItem,
        },
    }
    state.dropQueue = {}
    state.isGameOver = false
    state.isVictory = false
    print(string.format("[Debug Weapon] 已准备同列掉落%s测试", rewardCategory == "armor" and "防具" or "武器"))
    return true
end

function DebugWeaponSystem.SetPlayerHpRatio(state, ratio)
    EnsureSession(state)
    ratio = math.min(1, math.max(0.01, ratio or 1))
    state.hp = math.max(1, math.floor((state.maxHp or 1) * ratio))
    print(string.format("[Debug Weapon] 玩家气血设为%d%%", math.floor(ratio * 100 + 0.5)))
end

function DebugWeaponSystem.Clear(state)
    local session = state.debugWeaponSession
    if not session then return false end

    state.slots = CopyMap(session.originalSlots)
    state.monsters = session.originalMonsters
    state.fieldRewards = session.originalFieldRewards
    state.dropQueue = session.originalDropQueue
    state.hp = session.originalHp
    state.maxHp = session.originalMaxHp
    state.pendingRogueChoices = session.originalPendingRogueChoices
    state.pendingRogueStage = session.originalPendingRogueStage
    state.pendingRogueEvent = session.originalPendingRogueEvent
    state.shouldSpawnBreakthroughWave = session.originalShouldSpawnBreakthroughWave
    state.forceSpawnNextTurn = session.originalForceSpawnNextTurn

    state.runWeapons = CopyMap(session.originalRunWeapons)
    state.runArmors = CopyMap(session.originalRunArmors)
    state.weaponUpgradeLevels = CopyMap(session.originalWeaponUpgradeLevels)
    state.armorUpgradeLevels = CopyMap(session.originalArmorUpgradeLevels)
    state.selectedRogueRewards = CopyMap(session.originalSelectedRogueRewards)
    state.modifiers = CopyArray(session.originalModifiers)
    state.rogueRewardHistory = CopyArray(session.originalRogueRewardHistory)

    state.weaponCombatState = {}
    state.debugSelectedWeaponId = nil
    state.debugSelectedQuality = nil
    state.debugWeaponSession = nil
    print("[Debug Weapon] 已还原调试前的武器、技能、气血与战场")
    return true
end

return DebugWeaponSystem
