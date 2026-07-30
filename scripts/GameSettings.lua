local cjson = require("cjson")

local GameSettings = {}

local SETTINGS_PATH = "game_settings.json"
local DEFAULTS = {
    musicVolume = 1.0,
    sfxVolume = 1.0,
}

local function Clamp01(value)
    return math.min(1.0, math.max(0.0, tonumber(value) or 1.0))
end

local function Normalize(settings)
    settings = settings or {}
    local musicVolume = settings.musicVolume
    if musicVolume == nil then
        musicVolume = settings.masterVolume
    end
    return {
        musicVolume = Clamp01(musicVolume),
        sfxVolume = Clamp01(settings.sfxVolume),
    }
end

function GameSettings.Load()
    if not fileSystem or not fileSystem:FileExists(SETTINGS_PATH) then
        return Normalize(DEFAULTS)
    end

    local file = File(SETTINGS_PATH, FILE_READ)
    if not file:IsOpen() then
        print("[Settings] 无法打开设置文件，使用默认设置")
        return Normalize(DEFAULTS)
    end

    local content = file:ReadString()
    file:Close()
    local ok, decoded = pcall(cjson.decode, content)
    if not ok or type(decoded) ~= "table" then
        print("[Settings] 设置文件损坏，使用默认设置")
        return Normalize(DEFAULTS)
    end

    local settings = Normalize(decoded)
    print(string.format("[Settings] 已加载：音乐音量=%d%%，音效音量=%d%%",
        math.floor(settings.musicVolume * 100 + 0.5),
        math.floor(settings.sfxVolume * 100 + 0.5)))
    return settings
end

function GameSettings.Save(settings)
    local normalized = Normalize(settings)
    local ok, encoded = pcall(cjson.encode, normalized)
    if not ok then
        print("[Settings] 设置序列化失败")
        return false
    end

    local file = File(SETTINGS_PATH, FILE_WRITE)
    if not file:IsOpen() then
        print("[Settings] 无法写入设置文件")
        return false
    end

    file:WriteString(encoded)
    file:Close()
    print(string.format("[Settings] 已保存：音乐音量=%d%%，音效音量=%d%%",
        math.floor(normalized.musicVolume * 100 + 0.5),
        math.floor(normalized.sfxVolume * 100 + 0.5)))
    return true
end

function GameSettings.Normalize(settings)
    return Normalize(settings)
end

return GameSettings
