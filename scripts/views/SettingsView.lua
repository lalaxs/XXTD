local UI = require("urhox-libs/UI")

local SettingsView = {}
SettingsView.__index = SettingsView

local COLORS = {
    overlay = {0, 0, 0, 175},
    panel = {240, 225, 195, 252},
    card = {248, 235, 204, 245},
    border = {140, 105, 60, 230},
    title = {55, 40, 28, 255},
    text = {70, 52, 34, 255},
    muted = {120, 95, 68, 255},
    sliderTrack = {184, 207, 190, 255},
    sliderFill = {109, 159, 144, 255},
    sliderBorder = {55, 116, 95, 255},
    button = {109, 159, 144, 255},
    buttonPressed = {76, 144, 123, 255},
    danger = {165, 62, 50, 255},
    dangerPressed = {125, 42, 35, 255},
}

local function Percent(value)
    return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
end

local function MakeVolumeRow(title, onChange, onChangeEnd)
    local valueLabel = UI.Label {
        text = "100%",
        width = 54,
        fontSize = 15,
        fontWeight = "bold",
        fontColor = COLORS.title,
        textAlign = "right",
        flexShrink = 0,
    }

    local slider = UI.Slider {
        width = "100%",
        height = 34,
        min = 0,
        max = 100,
        step = 1,
        value = 100,
        trackHeight = 9,
        thumbSize = 24,
        trackBgColor = COLORS.sliderTrack,
        trackFillColor = COLORS.sliderFill,
        thumbColor = COLORS.panel,
        thumbBorderColor = COLORS.sliderBorder,
        thumbBorderWidth = 3,
        onChange = function(_, value)
            valueLabel:SetText(string.format("%d%%", math.floor(value + 0.5)))
            onChange(value / 100)
        end,
        onChangeEnd = function(_, value)
            onChangeEnd(value / 100)
        end,
    }

    return UI.Panel {
        width = "100%",
        padding = 14,
        gap = 10,
        backgroundColor = COLORS.card,
        borderRadius = 12,
        borderWidth = 2,
        borderColor = COLORS.border,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                alignItems = "center",
                justifyContent = "space-between",
                gap = 10,
                children = {
                    UI.Label {
                        text = title,
                        flexGrow = 1,
                        flexShrink = 1,
                        fontSize = 18,
                        fontWeight = "bold",
                        fontColor = COLORS.title,
                    },
                    valueLabel,
                },
            },
            slider,
        },
    }, slider, valueLabel
end

function SettingsView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        confirmPanel = nil,
        musicSlider = nil,
        musicValueLabel = nil,
        sfxSlider = nil,
        sfxValueLabel = nil,
    }, SettingsView)

    local musicRow
    musicRow, self.musicSlider, self.musicValueLabel = MakeVolumeRow(
        "音乐",
        function(value)
            if self.callbacks.onMusicVolumeChange then
                self.callbacks.onMusicVolumeChange(value, false)
            end
        end,
        function(value)
            if self.callbacks.onMusicVolumeChange then
                self.callbacks.onMusicVolumeChange(value, true)
            end
        end
    )

    local sfxRow
    sfxRow, self.sfxSlider, self.sfxValueLabel = MakeVolumeRow(
        "音效",
        function(value)
            if self.callbacks.onSfxVolumeChange then
                self.callbacks.onSfxVolumeChange(value, false)
            end
        end,
        function(value)
            if self.callbacks.onSfxVolumeChange then
                self.callbacks.onSfxVolumeChange(value, true)
            end
        end
    )

    self.confirmPanel = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        zIndex = 20,
        backgroundColor = {0, 0, 0, 185},
        alignItems = "center",
        justifyContent = "center",
        onClick = function() end,
        children = {
            UI.Panel {
                width = "82%",
                maxWidth = 410,
                padding = 20,
                gap = 14,
                backgroundColor = COLORS.panel,
                borderRadius = 16,
                borderWidth = 3,
                borderColor = COLORS.border,
                children = {
                    UI.Label {
                        text = "确认删除存档？",
                        width = "100%",
                        fontSize = 22,
                        fontWeight = "bold",
                        fontColor = COLORS.title,
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "当前轮回、永久成长和本地每日挑战进度将被清除。排行榜历史不会删除。此操作无法撤销。",
                        width = "100%",
                        fontSize = 14,
                        lineHeight = 1.5,
                        fontColor = COLORS.text,
                        whiteSpace = "normal",
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = 10,
                        children = {
                            UI.Button {
                                text = "取消",
                                width = "48%",
                                height = 48,
                                backgroundColor = COLORS.button,
                                pressedBackgroundColor = COLORS.buttonPressed,
                                textColor = {255, 245, 230, 255},
                                onClick = function()
                                    if self.callbacks.onUIClick then self.callbacks.onUIClick() end
                                    self.confirmPanel:SetVisible(false)
                                end,
                            },
                            UI.Button {
                                text = "确认删除",
                                width = "48%",
                                height = 48,
                                backgroundColor = COLORS.danger,
                                pressedBackgroundColor = COLORS.dangerPressed,
                                textColor = {255, 245, 230, 255},
                                onClick = function()
                                    if self.callbacks.onUIClick then self.callbacks.onUIClick() end
                                    self.confirmPanel:SetVisible(false)
                                    self:Hide()
                                    if self.callbacks.onDeleteSave then
                                        self.callbacks.onDeleteSave()
                                    end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        zIndex = 2400,
        backgroundColor = COLORS.overlay,
        alignItems = "center",
        justifyContent = "center",
        onClick = function()
            if self.callbacks.onUIClick then self.callbacks.onUIClick() end
            self:Hide()
        end,
        children = {
            UI.Panel {
                width = "88%",
                maxWidth = 500,
                padding = 20,
                gap = 14,
                backgroundColor = COLORS.panel,
                borderRadius = 20,
                borderWidth = 3,
                borderColor = COLORS.border,
                onClick = function() end,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        justifyContent = "space-between",
                        children = {
                            UI.Label {
                                text = "游戏设置",
                                fontSize = 26,
                                fontWeight = "bold",
                                fontColor = COLORS.title,
                            },
                            UI.Button {
                                text = "×",
                                width = 42,
                                height = 38,
                                fontSize = 22,
                                borderRadius = 10,
                                backgroundColor = COLORS.title,
                                pressedBackgroundColor = {35, 25, 18, 255},
                                textColor = {255, 245, 230, 255},
                                onClick = function()
                                    if self.callbacks.onUIClick then self.callbacks.onUIClick() end
                                    self:Hide()
                                end,
                            },
                        },
                    },
                    musicRow,
                    sfxRow,
                    UI.Panel {
                        width = "100%",
                        padding = 14,
                        gap = 8,
                        backgroundColor = {242, 218, 190, 245},
                        borderRadius = 12,
                        borderWidth = 2,
                        borderColor = {165, 62, 50, 220},
                        children = {
                            UI.Label {
                                text = "存档管理",
                                width = "100%",
                                fontSize = 18,
                                fontWeight = "bold",
                                fontColor = COLORS.title,
                            },
                            UI.Label {
                                text = "清除当前轮回、永久成长和本地每日挑战进度。音量设置会保留。",
                                width = "100%",
                                fontSize = 12,
                                fontColor = COLORS.muted,
                                whiteSpace = "normal",
                            },
                            UI.Button {
                                text = "删除存档",
                                width = "100%",
                                height = 48,
                                fontSize = 17,
                                fontWeight = "bold",
                                backgroundColor = COLORS.danger,
                                pressedBackgroundColor = COLORS.dangerPressed,
                                textColor = {255, 245, 230, 255},
                                onClick = function()
                                    if self.callbacks.onUIClick then self.callbacks.onUIClick() end
                                    self.confirmPanel:SetVisible(true)
                                end,
                            },
                        },
                    },
                },
            },
            self.confirmPanel,
        },
    }

    return self
end

function SettingsView:GetRoot()
    return self.root
end

function SettingsView:Show(settings)
    settings = settings or {}
    local musicVolume = math.min(1, math.max(0, settings.musicVolume or 1))
    local sfxVolume = math.min(1, math.max(0, settings.sfxVolume or 1))
    self.musicSlider:SetValue(musicVolume * 100)
    self.musicValueLabel:SetText(Percent(musicVolume))
    self.sfxSlider:SetValue(sfxVolume * 100)
    self.sfxValueLabel:SetText(Percent(sfxVolume))
    self.confirmPanel:SetVisible(false)
    self.root:SetVisible(true)
end

function SettingsView:Hide()
    self.confirmPanel:SetVisible(false)
    self.root:SetVisible(false)
end

return SettingsView
