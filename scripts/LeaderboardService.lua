-- LeaderboardService.lua
-- 游戏结算分数上传与玩家排行榜读取。

local LeaderboardService = {}

local SCORE_KEY = "run_high_score"
local DIFFICULTY_KEY = "run_high_difficulty"
local TURN_KEY = "run_high_turns"
local WAVE_KEY = "run_high_waves"
local REALM_KEY = "run_high_realm"
local RESULT_KEY = "run_high_result"
local RUN_COUNT_KEY = "run_completed_count"
local DAILY_SCORE_PREFIX = "daily_challenge_score:"

local function GetWaveCount(state)
    if state.ascensionMode then
        return state.endlessWaveIndex or state.waveCount or 0
    end
    return state.waveCount or 0
end

function LeaderboardService.CalculateFinalScore(state)
    local baseScore = math.max(0, math.floor(state.score or 0))
    local turnCount = math.max(0, math.floor(state.turn or 0))
    local waveCount = math.max(0, math.floor(GetWaveCount(state)))
    local difficulty = math.max(1, math.floor(state.difficulty or 1))
    local difficultyMultiplier = 1 + (difficulty - 1) * 0.25
    local rawScore = baseScore + turnCount * 10 + waveCount * 50

    return math.max(0, math.floor(rawScore * difficultyMultiplier)), {
        difficulty = difficulty,
        turns = turnCount,
        waves = waveCount,
        realm = math.max(1, math.floor(state.realmIndex or 1)),
        result = state.isVictory and 1 or 0,
    }
end

function LeaderboardService.SubmitFinalResult(state)
    if not state or state.leaderboardSubmitted then return end
    state.leaderboardSubmitted = true

    if not clientCloud then
        print("[Leaderboard] 云端排行榜不可用，跳过本局成绩上传")
        return
    end

    local finalScore, summary = LeaderboardService.CalculateFinalScore(state)
    print(string.format("[Leaderboard] 结算分数=%d（难度%d，%d回合，%d波）",
        finalScore, summary.difficulty, summary.turns, summary.waves))

    if state.dailyChallenge and state.dailyChallenge.id then
        local challengeKey = DAILY_SCORE_PREFIX .. state.dailyChallenge.id
        clientCloud:Get(challengeKey, {
            ok = function(_, scores)
                local highScore = (scores and scores[challengeKey]) or 0
                if finalScore <= highScore then
                    print("[Leaderboard] 每日挑战成绩未超过个人最佳")
                    return
                end
                clientCloud:BatchSet():SetInt(challengeKey, finalScore):Save("上传每日挑战成绩", {
                    ok = function()
                        print("[Leaderboard] 每日挑战个人最佳已上传")
                    end,
                    error = function(_, reason)
                        print("[Leaderboard] 每日挑战成绩上传失败: " .. tostring(reason))
                    end,
                    timeout = function()
                        print("[Leaderboard] 每日挑战成绩上传超时")
                    end,
                })
            end,
            error = function(_, reason)
                print("[Leaderboard] 读取每日挑战记录失败: " .. tostring(reason))
            end,
            timeout = function()
                print("[Leaderboard] 读取每日挑战记录超时")
            end,
        })
        return
    end

    clientCloud:Get(SCORE_KEY, {
        ok = function(_, iscores)
            local highScore = (iscores and iscores[SCORE_KEY]) or 0
            local changes = clientCloud:BatchSet():Add(RUN_COUNT_KEY, 1)
            if finalScore > highScore then
                changes:SetInt(SCORE_KEY, finalScore)
                    :SetInt(DIFFICULTY_KEY, summary.difficulty)
                    :SetInt(TURN_KEY, summary.turns)
                    :SetInt(WAVE_KEY, summary.waves)
                    :SetInt(REALM_KEY, summary.realm)
                    :SetInt(RESULT_KEY, summary.result)
            end
            changes:Save("上传游戏结算", {
                ok = function()
                    print(finalScore > highScore and "[Leaderboard] 新纪录已上传" or "[Leaderboard] 本局成绩已记录")
                end,
                error = function(_, reason)
                    print("[Leaderboard] 成绩上传失败: " .. tostring(reason))
                end,
                timeout = function()
                    print("[Leaderboard] 成绩上传超时")
                end,
            })
        end,
        error = function(_, reason)
            print("[Leaderboard] 读取历史成绩失败: " .. tostring(reason))
        end,
        timeout = function()
            print("[Leaderboard] 读取历史成绩超时")
        end,
    })
end

local function BuildEntry(rank, userId, scores)
    scores = scores or {}
    return {
        rank = rank,
        userId = userId,
        nickname = "未知玩家",
        score = scores[SCORE_KEY] or 0,
        difficulty = scores[DIFFICULTY_KEY] or 1,
        turns = scores[TURN_KEY] or 0,
        waves = scores[WAVE_KEY] or 0,
        realm = scores[REALM_KEY] or 1,
        victory = scores[RESULT_KEY] == 1,
    }
end

local function ResolveNicknames(entries, callback)
    if #entries == 0 or not GetUserNickname then
        callback()
        return
    end

    local userIds = {}
    for _, entry in ipairs(entries) do
        table.insert(userIds, entry.userId)
    end

    GetUserNickname({
        userIds = userIds,
        onSuccess = function(nicknames)
            local namesById = {}
            for _, info in ipairs(nicknames or {}) do
                namesById[info.userId] = info.nickname or "未知玩家"
            end
            for _, entry in ipairs(entries) do
                entry.nickname = namesById[entry.userId] or "未知玩家"
            end
            callback()
        end,
        onError = function()
            callback()
        end,
    })
end

local function ResolveNickname(entry, callback)
    if not entry or not GetUserNickname then
        callback()
        return
    end

    GetUserNickname({
        userIds = {entry.userId},
        onSuccess = function(nicknames)
            local info = nicknames and nicknames[1]
            entry.nickname = (info and info.nickname) or "未知玩家"
            callback()
        end,
        onError = function()
            callback()
        end,
    })
end

function LeaderboardService.LoadTop(limit, callback)
    if not clientCloud then
        callback(nil, nil, "云端排行榜暂不可用")
        return
    end

    clientCloud:GetRankList(SCORE_KEY, 0, limit or 20, {
        ok = function(rankList)
            local entries = {}
            for rank, item in ipairs(rankList or {}) do
                table.insert(entries, BuildEntry(rank, item.userId, item.iscore))
            end

            if not clientCloud.userId then
                ResolveNicknames(entries, function()
                    callback(entries, nil)
                end)
                return
            end

            clientCloud:GetUserRank(clientCloud.userId, SCORE_KEY, {
                ok = function(myRank, myScore)
                    if not myRank or not myScore then
                        ResolveNicknames(entries, function()
                            callback(entries, nil)
                        end)
                        return
                    end

                    clientCloud:BatchGet()
                        :Key(SCORE_KEY)
                        :Key(DIFFICULTY_KEY)
                        :Key(TURN_KEY)
                        :Key(WAVE_KEY)
                        :Key(REALM_KEY)
                        :Key(RESULT_KEY)
                        :Fetch({
                            ok = function(_, myScores)
                                local myEntry = BuildEntry(myRank, clientCloud.userId, myScores)
                                ResolveNicknames(entries, function()
                                    ResolveNickname(myEntry, function()
                                        callback(entries, myEntry)
                                    end)
                                end)
                            end,
                            error = function()
                                ResolveNicknames(entries, function()
                                    local fallbackEntry = BuildEntry(myRank, clientCloud.userId, {
                                        [SCORE_KEY] = myScore,
                                    })
                                    ResolveNickname(fallbackEntry, function()
                                        callback(entries, fallbackEntry)
                                    end)
                                end)
                            end,
                        })
                end,
                error = function()
                    ResolveNicknames(entries, function()
                        callback(entries, nil)
                    end)
                end,
            })
        end,
        error = function(_, reason)
            callback(nil, nil, "排行榜读取失败: " .. tostring(reason))
        end,
        timeout = function()
            callback(nil, nil, "排行榜读取超时")
        end,
    }, DIFFICULTY_KEY, TURN_KEY, WAVE_KEY, REALM_KEY, RESULT_KEY)
end

local function BuildDailyEntry(rank, userId, scores, scoreKey)
    scores = scores or {}
    return {
        rank = rank,
        userId = userId,
        nickname = "未知玩家",
        score = scores[scoreKey] or 0,
    }
end

local function ResolveDailyNicknames(entries, callback)
    if #entries == 0 or not GetUserNickname then
        callback()
        return
    end

    local userIds = {}
    for _, entry in ipairs(entries) do
        table.insert(userIds, entry.userId)
    end

    GetUserNickname({
        userIds = userIds,
        onSuccess = function(nicknames)
            local namesById = {}
            for _, info in ipairs(nicknames or {}) do
                namesById[info.userId] = info.nickname or "未知玩家"
            end
            for _, entry in ipairs(entries) do
                entry.nickname = namesById[entry.userId] or "未知玩家"
            end
            callback()
        end,
        onError = function()
            callback()
        end,
    })
end

local function ResolveDailyNickname(entry, callback)
    if not entry or not GetUserNickname then
        callback()
        return
    end

    GetUserNickname({
        userIds = {entry.userId},
        onSuccess = function(nicknames)
            local info = nicknames and nicknames[1]
            entry.nickname = (info and info.nickname) or "未知玩家"
            callback()
        end,
        onError = function()
            callback()
        end,
    })
end

function LeaderboardService.LoadDailyTop(challengeId, limit, callback)
    if not challengeId or challengeId == "" then
        callback(nil, nil, "每日挑战信息不可用")
        return
    end
    if not clientCloud then
        callback(nil, nil, "云端排行榜暂不可用")
        return
    end

    local scoreKey = DAILY_SCORE_PREFIX .. challengeId
    clientCloud:GetRankList(scoreKey, 0, limit or 20, {
        ok = function(rankList)
            local entries = {}
            for rank, item in ipairs(rankList or {}) do
                table.insert(entries, BuildDailyEntry(rank, item.userId, item.iscore, scoreKey))
            end

            if not clientCloud.userId then
                ResolveDailyNicknames(entries, function()
                    callback(entries, nil)
                end)
                return
            end

            clientCloud:GetUserRank(clientCloud.userId, scoreKey, {
                ok = function(myRank, myScore)
                    if not myRank or not myScore then
                        ResolveDailyNicknames(entries, function()
                            callback(entries, nil)
                        end)
                        return
                    end

                    clientCloud:BatchGet()
                        :Key(scoreKey)
                        :Fetch({
                            ok = function(_, myScores)
                                local myEntry = BuildDailyEntry(myRank, clientCloud.userId, myScores, scoreKey)
                                ResolveDailyNicknames(entries, function()
                                    ResolveDailyNickname(myEntry, function()
                                        callback(entries, myEntry)
                                    end)
                                end)
                            end,
                            error = function()
                                ResolveDailyNicknames(entries, function()
                                    local fallbackEntry = BuildDailyEntry(myRank, clientCloud.userId, {
                                        [scoreKey] = myScore,
                                    }, scoreKey)
                                    ResolveDailyNickname(fallbackEntry, function()
                                        callback(entries, fallbackEntry)
                                    end)
                                end)
                            end,
                        })
                end,
                error = function()
                    ResolveDailyNicknames(entries, function()
                        callback(entries, nil)
                    end)
                end,
            })
        end,
        error = function(_, reason)
            callback(nil, nil, "每日排行榜读取失败: " .. tostring(reason))
        end,
        timeout = function()
            callback(nil, nil, "每日排行榜读取超时")
        end,
    })
end

return LeaderboardService
