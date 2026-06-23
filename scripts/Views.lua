-- Views.lua
-- 仙侠合成塔防 - UI 视图组件（牛皮纸古卷风格）

local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")

local Views = {}

function Views.CreateTopHUD()
    local refs = {}

    refs.realmLabel = UI.Label {
        text = "练气",
        fontSize = 16,
        fontColor = STYLE.TEXT_GOLD,
        fontWeight = "bold",
    }
    refs.turnLabel = UI.Label {
        text = "第1波",
        fontSize = 13,
        fontColor = STYLE.TEXT_WHITE,
    }
    refs.hpLabel = UI.Label {
        text = "100",
        fontSize = 13,
        fontColor = STYLE.TEXT_WHITE,
        fontWeight = "bold",
    }
    refs.hpBar = UI.ProgressBar {
        value = 1.0,
        width = "100%",
        height = 12,
        backgroundColor = {40, 30, 20, 180},
        fillColor = "#C83728",
        borderRadius = 6,
        borderWidth = 2,
        borderColor = STYLE.HUD_BORDER,
        transition = "value 0.3s easeOut",
    }
    refs.expBar = UI.ProgressBar {
        value = 0,
        width = "100%",
        height = 8,
        backgroundColor = {40, 28, 50, 180},
        fillGradient = {direction = "to-right", from = "#7040B0", to = "#A060E0"},
        borderRadius = 4,
        borderWidth = 1.5,
        borderColor = {100, 70, 45, 180},
        transition = "value 0.3s easeOut",
    }

    local panel = UI.Panel {
        width = "100%",
        paddingHorizontal = 10,
        paddingTop = 8,
        paddingBottom = 10,
        gap = 6,
        backgroundColor = STYLE.HUD_BG,
        borderBottomWidth = 5,
        borderBottomColor = STYLE.HUD_BORDER,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    -- 境界标签
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 5,
                        paddingHorizontal = 10,
                        paddingVertical = 4,
                        backgroundColor = {80, 58, 35, 200},
                        borderRadius = STYLE.HUD_RADIUS,
                        borderWidth = 2,
                        borderColor = STYLE.HUD_BORDER,
                        children = {
                            UI.Label { text = "☯", fontSize = 13, fontColor = STYLE.TEXT_GOLD },
                            refs.realmLabel,
                        },
                    },
                    -- 波次标签
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        paddingHorizontal = 10,
                        paddingVertical = 4,
                        backgroundColor = {80, 58, 35, 200},
                        borderRadius = STYLE.HUD_RADIUS,
                        borderWidth = 2,
                        borderColor = STYLE.HUD_BORDER,
                        children = { refs.turnLabel },
                    },
                    -- 血量标签
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        paddingHorizontal = 10,
                        paddingVertical = 4,
                        backgroundColor = {80, 58, 35, 200},
                        borderRadius = STYLE.HUD_RADIUS,
                        borderWidth = 2,
                        borderColor = STYLE.HUD_BORDER,
                        children = {
                            UI.Label { text = "♥", fontSize = 13, fontColor = STYLE.HP_RED },
                            refs.hpLabel,
                        },
                    },
                },
            },
            refs.hpBar,
            refs.expBar,
        },
    }

    return panel, refs
end

function Views.CreateFieldPanel()
    -- 现在作为统一游戏面板（战场+部署+暂存）
    return UI.Panel {
        id = "fieldPanel",
        width = "100%",
        flex = 1,
        flexBasis = 0,
        pointerEvents = "box-none",
    }
end

function Views.CreateDeployPanel(dragContext)
    local slots = {}

    -- 创建透明 ItemSlot（后续由 DeployView.Update 定位）
    for i = 1, Config.TOTAL_SLOTS do
        slots[i] = UI.ItemSlot {
            slotId = "deploy_" .. i,
            slotCategory = "deploy",
            position = "absolute",
            dragContext = dragContext,
            showTypeIcon = false,
            backgroundColor = {0, 0, 0, 0},
            borderWidth = 0,
            borderColor = {0, 0, 0, 0},
            borderRadius = 0,
        }
    end

    -- 面板：用 aspectRatio=2.5 保持正确高度（2行正方形）
    local panelChildren = {}
    for i = 1, Config.TOTAL_SLOTS do
        table.insert(panelChildren, slots[i])
    end

    return UI.Panel {
        id = "deployPanel",
        width = "100%",
        aspectRatio = 2.5,
        flexShrink = 0,
        backgroundColor = {0, 0, 0, 0},
        pointerEvents = "box-none",
    }, slots
end

function Views.CreateStoragePanel(dragContext)
    local slots = {}
    local slot = UI.ItemSlot {
        slotId = "storage_1",
        slotCategory = "storage",
        flex = 1,
        aspectRatio = 1,
        dragContext = dragContext,
        showTypeIcon = false,
        backgroundColor = {0, 0, 0, 0},
        borderWidth = 0,
        borderColor = {0, 0, 0, 0},
        borderRadius = 0,
    }
    slots[1] = slot

    return UI.Panel {
        id = "storagePanel",
        width = "100%",
        flexShrink = 0,
        paddingVertical = 8,
        alignItems = "center",
        children = {
            UI.Panel {
                width = "20%",
                aspectRatio = 1,
                backgroundColor = STYLE.DEPLOY_CELL_A,
                borderWidth = 3,
                borderColor = {120, 115, 105, 200},
                borderRadius = 4,
                children = { slot },
            },
        },
    }, slots
end

function Views.CreateGameOverPanel(onRestart)
    return UI.Panel {
        id = "gameOverPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = STYLE.GAMEOVER_OVERLAY,
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = "78%",
                maxWidth = 300,
                padding = 24,
                gap = 12,
                backgroundColor = STYLE.GAMEOVER_BG,
                borderRadius = 20,
                borderWidth = 3,
                borderColor = STYLE.GAMEOVER_BORDER,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "道陨身殒",
                        fontSize = 22,
                        fontColor = STYLE.GAMEOVER_TITLE,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        id = "goScore",
                        text = "积分: 0",
                        fontSize = 15,
                        fontColor = STYLE.TEXT_DARK,
                    },
                    UI.Label {
                        id = "goRealm",
                        text = "最终境界: 练气",
                        fontSize = 13,
                        fontColor = STYLE.TEXT_SOFT,
                    },
                    UI.Button {
                        text = "再修一世",
                        width = 140,
                        height = 44,
                        fontSize = 16,
                        fontWeight = "bold",
                        marginTop = 6,
                        borderRadius = 12,
                        borderWidth = 2.5,
                        borderColor = STYLE.GAMEOVER_BTN_BORDER,
                        backgroundColor = STYLE.GAMEOVER_BTN_BG,
                        pressedBackgroundColor = STYLE.GAMEOVER_BTN_PRESS,
                        fontColor = STYLE.TEXT_WHITE,
                        onClick = onRestart,
                    },
                },
            },
        },
    }
end

return Views
