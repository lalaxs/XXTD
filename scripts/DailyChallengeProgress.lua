-- DailyChallengeProgress.lua
-- 每日挑战的本地进度：免费次数、完成状态与今日个人最佳。

local DailyChallengeProgress = {}

local SAVE_PATH = "daily_challenge_progress.json"

local function NewProgress(challengeId)
    return {
        challengeId = challengeId,
        freeAttemptUsed = false,
        completed = false,
        attemptsUsed = 0,
        lastScore = 0,
        bestScore = 0,
    }
end

local function ReadSave()
    if not fileSystem or not fileSystem:FileExists(SAVE_PATH) then
        return nil
    end

    local file = File(SAVE_PATH, FILE_READ)
    if not file or not file:IsOpen() then
        return nil
    end

    local content = file:ReadString()
    file:Close()
    if not content or content == "" then
        return nil
    end

    local ok, data = pcall(cjson.decode, content)
    if not ok or type(data) ~= "table" then
        return nil
    end
    return data
end

local function WriteSave(progress)
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file or not file:IsOpen() then
        print("[Daily] 无法打开每日挑战进度文件")
        return false
    end

    file:WriteString(cjson.encode(progress))
    file:Close()
    return true
end

function DailyChallengeProgress.Load(challengeId)
    local saved = ReadSave()
    if not saved or saved.challengeId ~= challengeId then
        local fresh = NewProgress(challengeId)
        WriteSave(fresh)
        return fresh
    end

    saved.freeAttemptUsed = saved.freeAttemptUsed == true
    saved.completed = saved.completed == true
    saved.attemptsUsed = math.max(0, math.floor(saved.attemptsUsed or 0))
    saved.lastScore = math.max(0, math.floor(saved.lastScore or 0))
    saved.bestScore = math.max(0, math.floor(saved.bestScore or 0))
    return saved
end

function DailyChallengeProgress.Save(progress)
    if not progress then return false end
    return WriteSave(progress)
end

function DailyChallengeProgress.CanStart(progress)
    return progress and progress.freeAttemptUsed ~= true
end

function DailyChallengeProgress.BeginAttempt(progress)
    if not DailyChallengeProgress.CanStart(progress) then
        return false
    end

    progress.freeAttemptUsed = true
    progress.attemptsUsed = (progress.attemptsUsed or 0) + 1
    DailyChallengeProgress.Save(progress)
    return true
end

function DailyChallengeProgress.Complete(progress, score)
    if not progress then return false, false end

    local finalScore = math.max(0, math.floor(score or 0))
    local previousBest = progress.bestScore or 0
    progress.completed = true
    progress.lastScore = finalScore
    progress.bestScore = math.max(previousBest, finalScore)
    DailyChallengeProgress.Save(progress)
    return true, finalScore > previousBest
end

function DailyChallengeProgress.Reset(progress)
    if not progress then return nil end
    local reset = NewProgress(progress.challengeId)
    WriteSave(reset)
    print("[Daily] 今日挑战进度已重置")
    return reset
end

function DailyChallengeProgress.DeleteSave()
    if not fileSystem or not fileSystem:FileExists(SAVE_PATH) then
        return true
    end

    local deleted = fileSystem:Delete(SAVE_PATH)
    if deleted then
        print("[Daily] 每日挑战进度已删除")
    else
        print("[Daily] 每日挑战进度删除失败")
    end
    return deleted
end

function DailyChallengeProgress.GetDisplayState(progress)
    if not progress then
        return {
            completed = false,
            attemptsUsed = 0,
            bestScore = 0,
            lastScore = 0,
        }
    end

    return {
        completed = progress.completed == true,
        attemptsUsed = progress.attemptsUsed or 0,
        bestScore = progress.bestScore or 0,
        lastScore = progress.lastScore or 0,
    }
end

return DailyChallengeProgress
