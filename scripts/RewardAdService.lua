-- RewardAdService.lua
-- 统一激励视频广告入口与每日次数限制。不包含任何广告位 ID。

local RewardAdService = {}
RewardAdService.__index = RewardAdService

local SAVE_PATH = "reward_ad_limits.json"
local REVIVE_DAILY_LIMIT = 3
local WATCHDOG_SECONDS = 20

local function TodayKey()
    return os.date("!%Y-%m-%d", os.time())
end

local function NewState()
    return {
        date = TodayKey(),
        reviveCount = 0,
    }
end

local function ReadState()
    if not fileSystem or not fileSystem:FileExists(SAVE_PATH) then
        return NewState()
    end

    local file = File(SAVE_PATH, FILE_READ)
    if not file or not file:IsOpen() then
        return NewState()
    end

    local content = file:ReadString()
    file:Close()
    local ok, decoded = pcall(cjson.decode, content or "")
    if not ok or type(decoded) ~= "table" or decoded.date ~= TodayKey() then
        return NewState()
    end

    decoded.reviveCount = math.max(0, math.floor(decoded.reviveCount or 0))
    return decoded
end

local function WriteState(state)
    if not fileSystem then return false end
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file or not file:IsOpen() then
        print("[Ad] 无法保存激励广告次数")
        return false
    end
    file:WriteString(cjson.encode(state))
    file:Close()
    return true
end

local function IsBusy(self)
    return self.inFlight == true
end

function RewardAdService.Create()
    return setmetatable({
        dailyState = ReadState(),
        inFlight = false,
        elapsed = 0,
        finish = nil,
    }, RewardAdService)
end

function RewardAdService:GetReviveCount()
    self.dailyState = self.dailyState or ReadState()
    if self.dailyState.date ~= TodayKey() then
        self.dailyState = NewState()
    end
    return self.dailyState.reviveCount or 0
end

function RewardAdService:GetReviveRemaining()
    return math.max(0, REVIVE_DAILY_LIMIT - self:GetReviveCount())
end

function RewardAdService:CanRevive()
    return self:GetReviveRemaining() > 0 and not IsBusy(self)
end

function RewardAdService:_Finish(result)
    if not self.inFlight then return end
    self.inFlight = false
    self.elapsed = 0
    local finish = self.finish
    self.finish = nil
    if finish then
        finish(result or { success = false, msg = "广告暂不可用，请稍后重试" })
    end
end

function RewardAdService:Show(kind, options)
    options = options or {}
    if IsBusy(self) then
        if options.onFailure then options.onFailure("广告正在处理中") end
        return false
    end
    if kind == "revive" and not self:CanRevive() then
        if options.onFailure then options.onFailure("今日复活次数已用尽") end
        return false
    end
    local adSdk = _G["sdk"]
    if not adSdk then
        if options.onFailure then options.onFailure("广告暂不可用，请稍后重试") end
        return false
    end

    self.inFlight = true
    self.elapsed = 0
    local callbackFired = false
    self.finish = function(result)
        if result and result.success == true then
            if kind == "revive" then
                self.dailyState.reviveCount = self:GetReviveCount() + 1
                WriteState(self.dailyState)
            end
            if options.onSuccess then options.onSuccess() end
        else
            if options.onFailure then
                options.onFailure(result and result.msg or "广告未完整播放")
            end
        end
    end

    local accepted = adSdk:ShowRewardVideoAd(function(result)
        callbackFired = true
        self:_Finish(result)
    end)

    if accepted == false and not callbackFired then
        self:_Finish({ success = false, msg = "广告暂不可用，请稍后重试" })
    end
    return accepted ~= false
end

function RewardAdService:Update(dt)
    if not self.inFlight then return end
    self.elapsed = self.elapsed + (dt or 0)
    if self.elapsed >= WATCHDOG_SECONDS then
        self:_Finish({ success = false, msg = "广告响应超时，请稍后重试" })
    end
end

return RewardAdService
