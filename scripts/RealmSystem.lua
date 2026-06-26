local Config = require("Config")

local RealmSystem = {}

-- 获取天赋加成后的最大血量
function RealmSystem.GetMaxHp(state)
    local realm = Config.REALMS[state.realmIndex]
    local baseHp = realm.maxHp
    local talentPoints = state.talentPoints or 0
    local hpBonus = 1.0 + talentPoints * Config.TALENT.PER_POINT_HP
    return math.floor(baseHp * hpBonus)
end

-- 获取天赋加成后的经验倍率
function RealmSystem.GetExpMultiplier(state)
    local talentPoints = state.talentPoints or 0
    return 1.0 + talentPoints * Config.TALENT.PER_POINT_EXP
end

-- 添加经验（含天赋加成和轮回检测）
function RealmSystem.AddExp(state, amount)
    -- 天赋点经验加成
    local expMul = RealmSystem.GetExpMultiplier(state)
    local finalAmount = math.floor(amount * expMul)
    state.exp = state.exp + finalAmount

    -- 检查升级
    RealmSystem.CheckRealmUp(state)

    -- 检查轮回触发：渡劫满级后溢出经验触发
    if state.realmIndex >= #Config.REALMS and state.exp > Config.REINCARNATION_EXP_THRESHOLD then
        RealmSystem.TriggerReincarnation(state)
    end
end

-- 检查境界提升
function RealmSystem.CheckRealmUp(state)
    while state.realmIndex < #Config.REALMS do
        local nextRealm = Config.REALMS[state.realmIndex + 1]
        if state.exp >= nextRealm.expRequired then
            local oldHp = state.hp
            state.realmIndex = state.realmIndex + 1
            local realm = Config.REALMS[state.realmIndex]
            state.maxHp = RealmSystem.GetMaxHp(state)
            state.hp = math.max(oldHp, state.maxHp)
            state.lastPillHp = state.hp
            print(string.format("[Realm Up] 境界突破: %s! 气血=%d/%d", realm.name, state.hp, state.maxHp))
        else
            break
        end
    end
end

-- 死亡处理：练气期真正死亡；练气以上修为倒退一级并按掉阶后的默认气血复活
-- 返回 true = 复活成功，false = 真正死亡
function RealmSystem.HandleDeath(state)
    if state.realmIndex <= 1 then
        -- 已是最低境界（练气期），真正死亡
        state.hp = 0
        return false
    end

    -- 修为倒退至上一等级
    state.realmIndex = state.realmIndex - 1
    local realm = Config.REALMS[state.realmIndex]

    -- 修为回到复活后境界的起始修为
    state.exp = realm.expRequired

    -- 按复活后境界的默认最大气血恢复
    state.maxHp = RealmSystem.GetMaxHp(state)
    state.hp = state.maxHp
    state.lastPillHp = state.maxHp

    print(string.format("[Death Save] 气血归零，修为跌落至: %s，复活 HP=%d", realm.name, state.hp))
    return true
end

-- 轮回系统
function RealmSystem.TriggerReincarnation(state)
    -- 获得1天赋点（上限100）
    state.talentPoints = state.talentPoints or 0
    if state.talentPoints < Config.TALENT.MAX_POINTS then
        state.talentPoints = state.talentPoints + 1
        print(string.format("[Reincarnation] 获得天赋点! 当前: %d/%d",
            state.talentPoints, Config.TALENT.MAX_POINTS))
    else
        print("[Reincarnation] 天赋点已满100，不再增加")
    end

    -- 重置修为到1阶练气期，清空累计经验
    state.realmIndex = 1
    state.exp = 0

    -- 重置波次、场上怪物、已放置道具
    state.waveCount = 0
    state.waveTurnProgress = 0
    state.monsters = {}
    state.chests = {}

    -- 清空布政区已放置道具
    for i = 1, Config.TOTAL_SLOTS do
        state.slots[i] = nil
    end

    -- 保留仓库内未放置道具（dropQueue）和已绑定词条
    -- dropQueue 不清空

    -- 重置血量为新境界满血（含天赋加成）
    state.maxHp = RealmSystem.GetMaxHp(state)
    state.hp = state.maxHp

    -- 重置辅助计数器
    state.lastPillHp = state.maxHp
    state.buffs = {}
    state.turn = 0

    -- 标记轮回事件（UI可读取显示）
    state.reincarnationTriggered = true
    state.reincarnationCount = (state.reincarnationCount or 0) + 1

    print(string.format("[Reincarnation] 返璞归真！第%d次轮回，天赋点=%d",
        state.reincarnationCount, state.talentPoints))
end

return RealmSystem
