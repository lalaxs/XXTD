-- GameState.lua
-- 仙侠合成塔防 - 游戏状态管理 + 回合系统

local Config = require("Config")
local ItemSystem = require("ItemSystem")
local PlayerItemResolver = require("combat.PlayerItemResolver")
local KillResolver = require("combat.KillResolver")
local VisualState = require("VisualState")
local ReincarnationSystem = require("ReincarnationSystem")

local GameState = {}

-- ============================================================================
-- 初始化
-- ============================================================================
function GameState.New()
    local state = {
        -- 玩家状态
        hp = Config.REALMS[1].maxHp,
        maxHp = Config.REALMS[1].maxHp,
        exp = Config.PLAYER.BASE_EXP,
        coins = 10,
        realmIndex = 1,  -- 当前境界索引
        lastPillHp = Config.REALMS[1].maxHp,  -- 丹药触发HP基准点
        
        -- 局外轮回强化（跨重开保留）
        reincarnationPoints = 0,
        reincarnationUpgrades = {},
        reincarnationCount = 0,

        -- 本轮肉鸽构筑
        runWeapons = { qingfeng_sword = true },
        runArmors = { dark_iron_shield = true },
        weaponUpgradeLevels = {},
        weaponCombatState = {},
        nextWeaponCombatInstanceId = 0,
        towerRefineBonusPct = 0,
        modifiers = {},
        selectedRogueRewards = {},
        rogueRewardHistory = {},
        pendingRogueChoices = nil,
        pendingRogueStage = nil,
        pendingRogueStages = nil,
        pendingRogueStageIndex = nil,
        pendingRogueEvent = nil,
        lastBreakthroughEvent = nil,
        
        -- 回合计数
        turn = 0,
        waveCount = 0,
        waveTurnProgress = 0,  -- 独立的波次进度（领取场上奖励不计入）
        waveTurnsSinceSpawn = 0,
        realmWaveIndex = 0,
        endlessWaveIndex = 0,
        endlessBudget = 0,
        endlessKills = 0,
        totalKills = 0,
        endlessWaveActive = false,
        forceSpawnNextTurn = false,
        difficulty = 1,
        maxUnlockedDifficulty = 1,
        runSeed = os.time(),
        deathSaveRatio = 0,
        deathSaveUsed = false,
        adReviveUsed = false,
        fieldRewardTurnsSinceSpawn = 0,
        fieldRewardRecentCols = {},
        recentSpawnColumns = {},
        
        -- 布政区格子 (1D数组，大小 = GRID_COLS * GRID_ROWS)
        -- 每个格子: nil（空）或 item 对象
        slots = {},
        
        -- 怪物列表
        -- 每个怪物: {type, name, hp, maxHp, atk, exp, dropChance, col, row, charging, attackRange}
        monsters = {},
        
        -- 场上奖励列表
        -- 每个场上实体: {entityType="reward"|"shop", col, row, hp, quality, rewardItem/shopItems}
        fieldRewards = {},
        shopInventory = nil,
        pendingShop = nil,
        
        -- 掉落队列（缓冲区，最多存 BUFFER_MAX 个道具）
        dropQueue = {},
        -- 掉落飘字队列（UI读取后清空）
        dropMessages = {},
        
        -- 当前激活的丹药Buff
        -- {type, value, remainTurns}
        buffs = {},

        -- 主动消耗品使用次数（每回合重置）
        consumableUsesThisTurn = 0,
        consumableUseLimit = Config.CONSUMABLE_USE_LIMIT or 2,
        
        -- 游戏状态
        isGameOver = false,
        isVictory = false,
        victoryReason = nil,
        canReincarnate = false,
        reincarnationClaimed = false,
        canContinueRun = false,
        ascensionAchieved = false,
        ascensionMode = false,
        settlementType = nil,
        shouldSpawnBreakthroughWave = false,
        breakthroughSpawnAllowance = 0,
        score = 0,
        leaderboardSubmitted = false,
        
        -- 动画/UI状态
        visual = VisualState.Create(),
        lastDamageDealt = {},   -- 上回合造成的伤害（用于显示伤害数字）
        lastCoinDropEvents = {}, -- 上回合敌人金币掉落动画事件
        lastPlayerDamage = 0,   -- 上回合玩家受到的伤害
        lastPlayerDamageCrit = false, -- 上回合玩家受到的伤害是否包含暴击
        turnLog = {},           -- 回合日志
    }
    
    ReincarnationSystem.EnsureState(state)

    -- 初始化空格子
    for i = 1, Config.TOTAL_SLOTS do
        state.slots[i] = nil
    end
    
    return state
end

-- ============================================================================
-- 回合执行（核心逻辑）
-- ============================================================================
-- 标准单回合执行流程：
-- 1. 布政区所有道具执行效果
-- 2. 命中灵材光球、击杀怪物，生成道具存入布政区空位
-- 3. 所有存活怪物统一下移1格
-- 4. 远程怪物施法攻击玩家、近战怪物蓄力判定
-- 5. 全额伤害结算，更新玩家气血值
-- 6. 判定玩家是否死亡
-- 7. 刷新场上浮空资源、刷新下一波怪物

function GameState.ExecuteTurn(state)
    require("combat.TurnEngine").ExecuteTurn(state)
end

-- ============================================================================
-- Step 1: 道具生效
-- ============================================================================
function GameState.ExecuteItems(state)
    PlayerItemResolver.Resolve(state)
end

-- ============================================================================
-- Step 2: 处理击杀和掉落
-- ============================================================================
function GameState.ProcessKillsAndDrops(state)
    KillResolver.Resolve(state)
end

-- ============================================================================
-- 道具创建对外接口
-- ============================================================================
function GameState.CreateItem(state, itemType, quality)
    return ItemSystem.CreateItem(state, itemType, quality)
end

function GameState.CreateItemByBaseId(state, category, baseId, quality)
    return ItemSystem.CreateItemByBaseId(state, category, baseId, quality)
end

return GameState
