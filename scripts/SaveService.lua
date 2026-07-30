-- SaveService.lua
-- 普通局与每日挑战的本地缓存 + TapTap 云存档后端。逻辑云 Key 不依赖开发账号或发布 App ID。

local SaveService = {}

SaveService.StorageIds = {
    normalLocalPath = "saves/normal_run_v1.json",
    dailyLocalPath = "saves/daily_run_v1.json",
    cloudNormalKey = "xxtd_normal_run_v1",
    cloudDailyKey = "xxtd_daily_run_v1",
}

local SAVE_VERSION = 1
local TRANSIENT_FIELDS = {
    visual = true,
    visualEventQueue = true,
    lastDamageDealt = true,
    lastAttackEvents = true,
    lastMonsterAttackEvents = true,
    lastCoinDropEvents = true,
    lastPlayerDamage = true,
    lastPlayerDamageCrit = true,
    pillConsumeMessages = true,
    visualStatusEvents = true,
    lastBreakthroughEvent = true,
    dropMessages = true,
    reincarnationTriggered = true,
    turnLog = true,
}

local function IsFiniteNumber(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

local function PackValue(value, stack, fieldName)
    local valueType = type(value)
    if valueType == "nil" then return nil end
    if valueType == "boolean" or valueType == "string" then return value end
    if valueType == "number" then
        return IsFiniteNumber(value) and value or nil
    end
    if valueType ~= "table" or TRANSIENT_FIELDS[fieldName] then
        return nil
    end
    if stack[value] then
        return nil
    end

    stack[value] = true
    local entries = {}
    for key, child in pairs(value) do
        local keyType = type(key)
        if keyType == "string" or keyType == "number" or keyType == "boolean" then
            local packedChild = PackValue(child, stack, keyType == "string" and key or nil)
            if packedChild ~= nil then
                table.insert(entries, {
                    keyType = keyType,
                    key = key,
                    value = packedChild,
                })
            end
        end
    end
    stack[value] = nil
    return { entries = entries }
end

local function UnpackValue(value)
    if type(value) ~= "table" or type(value.entries) ~= "table" then
        return value
    end

    local unpacked = {}
    for _, entry in ipairs(value.entries) do
        if type(entry) == "table" then
            local key = entry.key
            if entry.keyType == "number" then
                key = tonumber(key)
            elseif entry.keyType == "boolean" then
                key = key == true
            end
            if key ~= nil then
                unpacked[key] = UnpackValue(entry.value)
            end
        end
    end
    return unpacked
end

local function EnsureSaveDirectory()
    if not fileSystem then return false end
    if fileSystem:DirExists("saves") then return true end
    return fileSystem:CreateDir("saves")
end

local function WritePayload(path, payload)
    if not EnsureSaveDirectory() then
        print("[Save] 无法创建存档目录")
        return false
    end

    local ok, encoded = pcall(cjson.encode, payload)
    if not ok then
        print("[Save] 存档序列化失败: " .. tostring(encoded))
        return false
    end

    local file = File(path, FILE_WRITE)
    if not file or not file:IsOpen() then
        print("[Save] 无法打开存档文件: " .. path)
        return false
    end
    file:WriteString(encoded)
    file:Close()
    return true
end

local function ReadPayload(path, expectedKind)
    if not fileSystem or not fileSystem:FileExists(path) then
        return nil
    end

    local file = File(path, FILE_READ)
    if not file or not file:IsOpen() then
        print("[Save] 无法读取存档文件: " .. path)
        return nil
    end
    local content = file:ReadString()
    file:Close()

    local ok, payload = pcall(cjson.decode, content or "")
    if not ok or type(payload) ~= "table" then
        print("[Save] 存档文件损坏: " .. path)
        return nil
    end
    if payload.version ~= SAVE_VERSION or payload.kind ~= expectedKind or type(payload.state) ~= "table" then
        print("[Save] 存档版本或类型不匹配: " .. path)
        return nil
    end
    return payload
end

local function DeletePath(path)
    if not fileSystem or not fileSystem:FileExists(path) then
        return true
    end
    return fileSystem:Delete(path)
end

local function DecodePayload(payload, expectedKind)
    if type(payload) == "string" then
        local ok, decoded = pcall(cjson.decode, payload)
        if not ok then return nil end
        payload = decoded
    end
    if type(payload) ~= "table" or payload.version ~= SAVE_VERSION
        or payload.kind ~= expectedKind or type(payload.state) ~= "table" then
        return nil
    end
    return payload
end

local function DecodeState(payload)
    if not payload then return nil end
    local state = UnpackValue(payload.state)
    return type(state) == "table" and state or nil
end

local CLOUD_QUEUES = {}

local function HasClientCloud()
    return clientCloud ~= nil and clientCloud.Get ~= nil and clientCloud.Set ~= nil
end

local function GetCloudQueue(key)
    local queue = CLOUD_QUEUES[key]
    if not queue then
        queue = { busy = false, pending = nil, lastFingerprint = nil }
        CLOUD_QUEUES[key] = queue
    end
    return queue
end

local function ProcessCloudQueue(key)
    local queue = GetCloudQueue(key)
    if queue.busy or not queue.pending or not HasClientCloud() then return end

    local operation = queue.pending
    queue.pending = nil
    queue.busy = true

    local function Finish(success, reason)
        queue.busy = false
        if success then
            queue.lastFingerprint = operation.kind == "set" and operation.fingerprint or nil
        end
        if operation.callback then operation.callback(success, reason) end
        ProcessCloudQueue(key)
    end

    local events = {
        ok = function()
            print(operation.kind == "set" and "[Save] 云存档写入成功: " .. key or "[Save] 云存档已删除: " .. key)
            Finish(true)
        end,
        error = function(code, reason)
            print("[Save] 云存档操作失败: " .. tostring(code) .. " " .. tostring(reason))
            Finish(false, reason)
        end,
        timeout = function()
            print("[Save] 云存档操作超时: " .. key)
            Finish(false, "timeout")
        end,
    }

    if operation.kind == "delete" then
        clientCloud:BatchSet():Delete(key):Save("删除游戏存档", events)
    else
        clientCloud:Set(key, operation.payload, events)
    end
end

local function SaveCloud(key, payload, callback)
    if not HasClientCloud() then
        if callback then callback(false, "clientCloud 不可用") end
        return false
    end

    local ok, fingerprint = pcall(cjson.encode, {
        kind = payload.kind,
        hasActiveRun = payload.hasActiveRun,
        challengeId = payload.challengeId,
        state = payload.state,
    })
    if not ok then
        if callback then callback(false, "云存档指纹生成失败") end
        return false
    end

    local queue = GetCloudQueue(key)
    if queue.lastFingerprint == fingerprint and not queue.pending then
        if callback then callback(true) end
        return true
    end
    if queue.pending and queue.pending.kind == "set" and queue.pending.fingerprint == fingerprint then
        return true
    end

    queue.pending = {
        kind = "set",
        payload = payload,
        fingerprint = fingerprint,
        callback = callback,
    }
    ProcessCloudQueue(key)
    return true
end

local function LoadCloud(key, expectedKind, callback)
    if not HasClientCloud() then
        callback(nil, "clientCloud 不可用")
        return true
    end
    clientCloud:Get(key, {
        ok = function(values)
            callback(DecodePayload(values and values[key], expectedKind), nil)
        end,
        error = function(code, reason)
            print("[Save] 云存档读取失败: " .. tostring(code) .. " " .. tostring(reason))
            callback(nil, reason)
        end,
        timeout = function()
            print("[Save] 云存档读取超时: " .. key)
            callback(nil, "timeout")
        end,
    })
    return true
end

local function DeleteCloud(key, callback)
    if not HasClientCloud() or not clientCloud.BatchSet then
        if callback then callback(false, "clientCloud 不可用") end
        return false
    end
    local queue = GetCloudQueue(key)
    queue.pending = {
        kind = "delete",
        callback = callback,
    }
    ProcessCloudQueue(key)
    return true
end

local function BuildPayload(kind, state, extra, previousPayload)
    local savedAt = os.time()
    local previousRevision = previousPayload and tonumber(previousPayload.revision) or 0
    local revision = math.max(savedAt, previousRevision + 1)
    local payload = {
        version = SAVE_VERSION,
        kind = kind,
        savedAt = savedAt,
        revision = revision,
        state = PackValue(state, {}, nil),
    }
    for key, value in pairs(extra or {}) do
        payload[key] = value
    end
    return payload
end

local function SelectNewerPayload(localPayload, cloudPayload)
    if not localPayload then return cloudPayload end
    if not cloudPayload then return localPayload end

    local localRevision = tonumber(localPayload.revision)
    local cloudRevision = tonumber(cloudPayload.revision)
    if localRevision and cloudRevision and localRevision ~= cloudRevision then
        return cloudRevision > localRevision and cloudPayload or localPayload
    end

    local localSavedAt = tonumber(localPayload.savedAt) or 0
    local cloudSavedAt = tonumber(cloudPayload.savedAt) or 0
    if cloudSavedAt > localSavedAt then
        return cloudPayload
    end
    return localPayload
end

function SaveService.SaveNormal(state, hasActiveRun, callback)
    if not state then return false end
    local previousPayload = ReadPayload(SaveService.StorageIds.normalLocalPath, "normal")
    local payload = BuildPayload("normal", state, {
        storageId = SaveService.StorageIds.cloudNormalKey,
        hasActiveRun = hasActiveRun == true,
    }, previousPayload)
    local localSaved = WritePayload(SaveService.StorageIds.normalLocalPath, payload)
    if localSaved then
        print("[Save] 普通本地缓存已保存，active=" .. tostring(hasActiveRun == true))
    end
    local cloudStarted = SaveCloud(SaveService.StorageIds.cloudNormalKey, payload, callback)
    return localSaved or cloudStarted
end

function SaveService.LoadNormal()
    local payload = ReadPayload(SaveService.StorageIds.normalLocalPath, "normal")
    local state = DecodeState(payload)
    if not state then return nil, false end
    print("[Save] 普通本地缓存已加载，active=" .. tostring(payload.hasActiveRun == true))
    return state, payload.hasActiveRun == true
end

function SaveService.LoadNormalAsync(callback)
    local localPayload = ReadPayload(SaveService.StorageIds.normalLocalPath, "normal")
    return LoadCloud(SaveService.StorageIds.cloudNormalKey, "normal", function(cloudPayload, errorMessage)
        local payload = SelectNewerPayload(localPayload, cloudPayload)
        if cloudPayload and payload == cloudPayload then
            WritePayload(SaveService.StorageIds.normalLocalPath, cloudPayload)
        end
        callback(DecodeState(payload), payload and payload.hasActiveRun == true or false, errorMessage)
    end)
end

function SaveService.SaveDaily(state, challengeId, callback)
    if not state or not challengeId then return false end
    local previousPayload = ReadPayload(SaveService.StorageIds.dailyLocalPath, "daily")
    if previousPayload and previousPayload.challengeId ~= challengeId then
        previousPayload = nil
    end
    local payload = BuildPayload("daily", state, {
        storageId = SaveService.StorageIds.cloudDailyKey,
        challengeId = challengeId,
    }, previousPayload)
    local localSaved = WritePayload(SaveService.StorageIds.dailyLocalPath, payload)
    if localSaved then
        print("[Save] 每日挑战本地缓存已保存: " .. tostring(challengeId))
    end
    local cloudStarted = SaveCloud(SaveService.StorageIds.cloudDailyKey, payload, callback)
    return localSaved or cloudStarted
end

function SaveService.LoadDaily(challengeId)
    local payload = ReadPayload(SaveService.StorageIds.dailyLocalPath, "daily")
    if not payload then return nil end
    if payload.challengeId ~= challengeId then
        DeletePath(SaveService.StorageIds.dailyLocalPath)
        print("[Save] 已清理过期的每日挑战本地缓存")
        return nil
    end
    local state = DecodeState(payload)
    if state then print("[Save] 每日挑战本地缓存已加载: " .. tostring(challengeId)) end
    return state
end

function SaveService.LoadDailyAsync(challengeId, callback)
    local localPayload = ReadPayload(SaveService.StorageIds.dailyLocalPath, "daily")
    if localPayload and localPayload.challengeId ~= challengeId then
        localPayload = nil
        DeletePath(SaveService.StorageIds.dailyLocalPath)
    end
    return LoadCloud(SaveService.StorageIds.cloudDailyKey, "daily", function(cloudPayload, errorMessage)
        if cloudPayload and cloudPayload.challengeId ~= challengeId then
            cloudPayload = nil
        end
        local payload = SelectNewerPayload(localPayload, cloudPayload)
        if cloudPayload and payload == cloudPayload then
            WritePayload(SaveService.StorageIds.dailyLocalPath, cloudPayload)
        end
        callback(DecodeState(payload), errorMessage)
    end)
end

function SaveService.DeleteNormalLocalCache()
    local deleted = DeletePath(SaveService.StorageIds.normalLocalPath)
    print(deleted and "[Save] 普通本地缓存已清理" or "[Save] 普通本地缓存清理失败")
    return deleted
end

function SaveService.DeleteDailyLocalCache()
    local deleted = DeletePath(SaveService.StorageIds.dailyLocalPath)
    print(deleted and "[Save] 每日挑战本地缓存已清理" or "[Save] 每日挑战本地缓存清理失败")
    return deleted
end

function SaveService.DeleteNormal(callback)
    local deleted = SaveService.DeleteNormalLocalCache()
    DeleteCloud(SaveService.StorageIds.cloudNormalKey, callback)
    return deleted
end

function SaveService.DeleteDaily(callback)
    local deleted = SaveService.DeleteDailyLocalCache()
    DeleteCloud(SaveService.StorageIds.cloudDailyKey, callback)
    return deleted
end

function SaveService.DeleteAll()
    local normalDeleted = SaveService.DeleteNormal()
    local dailyDeleted = SaveService.DeleteDaily()
    return normalDeleted and dailyDeleted
end

return SaveService
