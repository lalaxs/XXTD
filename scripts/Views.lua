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
        text = "波 1",
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
        backgroundColor = {40, 30, 30, 150},
        fillColor = "#E64640",
        borderRadius = 6,
        borderWidth = 2,
        borderColor = {60, 50, 50, 200},
        transition = "value 0.3s easeOut",
    }
    refs.expBar = UI.ProgressBar {
        value = 0,
        width = "100%",
        height = 8,
        backgroundColor = {40, 30, 50, 150},
        fillGradient = {direction = "to-right", from = "#9060DD", to = "#C080FF"},
        borderRadius = 4,
        borderWidth = 1.5,
        borderColor = {80, 60, 100, 180},
        transition = "value 0.3s easeOut",
    }

    local panel = UI.Panel {
        width = "100%",
        paddingHorizontal = 12,
        paddingTop = 8,
        paddingBottom = 6,
        gap = 5,
        children = {
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 6,
                        paddingHorizontal = 12,
                        paddingVertical = 5,
                        backgroundColor = STYLE.HUD_BG,
                        borderRadius = STYLE.HUD_RADIUS,
                        borderWidth = 2.5,
                        borderColor = {80, 75, 70, 200},
                        children = {
                            UI.Label { text = "☯", fontSize = 14, fontColor = STYLE.TEXT_GOLD },
                            refs.realmLabel,
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        paddingHorizontal = 10,
                        paddingVertical = 5,
                        backgroundColor = STYLE.HUD_BG,
                        borderRadius = STYLE.HUD_RADIUS,
                        borderWidth = 2.5,
                        borderColor = {80, 75, 70, 200},
                        children = { refs.turnLabel },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        alignItems = "center",
                        gap = 4,
                        paddingHorizontal = 10,
                        paddingVertical = 5,
                        backgroundColor = STYLE.HUD_BG,
                        borderRadius = STYLE.HUD_RADIUS,
                        borderWidth = 2.5,
                        borderColor = {80, 75, 70, 200},
                        children = {
                            UI.Label { text = "♥", fontSize = 14, fontColor = STYLE.HP_RED },
                            refs.hpLabel,
                        },
                    },
                },
            },
            refs.hpBar,
            refs.expBar,
        }
    }

    return panel, refs
end

function Views.CreateFieldPanel()
    return UI.Panel {
        id = "fieldPanel",
        width = "100%",
        flex = 1,
        flexBasis = 0,
        pointerEvents = "box-none",
        backgroundColor = {180, 215, 235, 180},
        borderRadius = 12,
        marginHorizontal = 8,
        marginVertical = 4,
    }
end

function Views.CreateDeployPanel(dragContext)
    local slots = {}
    local rows = {}

    for row = 1, Config.DEPLOY_ROWS do
        local rowCells = {}
        for col = 1, Config.GRID_COLS do
            local idx = (row - 1) * Config.GRID_COLS + col
            local slot = UI.ItemSlot {
                slotId = "deploy_" .. idx,
                slotCategory = "deploy",
                flex = 1,
                aspectRatio = 1,
                dragContext = dragContext,
                showTypeIcon = false,
                backgroundColor = STYLE.CARD_BG,
                borderRadius = STYLE.SLOT_RADIUS,
                borderWidth = 3,
                borderColor = STYLE.CARD_BORDER,
            }
            slots[idx] = slot
            table.insert(rowCells, slot)
        end
        table.insert(rows, UI.Panel {
            width = "100%",
            flexDirection = "row",
            gap = 8,
            children = rowCells,
        })
    end

    return UI.Panel {
        id = "deployPanel",
        width = "100%",
        paddingHorizontal = 12,
        paddingVertical = 10,
        gap = 8,
        backgroundColor = STYLE.GRASS_TOP,
        borderTopLeftRadius = 16,
        borderTopRightRadius = 16,
        borderWidth = 3,
        borderColor = {70, 130, 60, 200},
        children = rows,
    }, slots
end

function Views.CreateStoragePanel(dragContext)
    local slots = {}
    local slot = UI.ItemSlot {
        slotId = "storage_1",
        slotCategory = "storage",
        width = 56,
        height = 56,
        dragContext = dragContext,
        showTypeIcon = false,
        backgroundColor = STYLE.CARD_BG,
        borderRadius = STYLE.SLOT_RADIUS,
        borderWidth = 3,
        borderColor = STYLE.CARD_BORDER,
    }
    slots[1] = slot

    return UI.Panel {
        id = "storagePanel",
        width = "100%",
        paddingHorizontal = 12,
        paddingVertical = 10,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        gap = 12,
        backgroundColor = STYLE.EARTH,
        borderWidth = 3,
        borderColor = {120, 90, 55, 200},
        children = { slot },
    }, slots
end

function Views.CreateGameOverPanel(onRestart)
    return UI.Panel {
        id = "gameOverPanel",
        visible = false,
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = {0, 0, 0, 150},
        justifyContent = "center",
        alignItems = "center",
        children = {
            UI.Panel {
                width = "80%",
                maxWidth = 300,
                padding = 28,
                gap = 14,
                backgroundColor = {255, 255, 255, 245},
                borderRadius = 24,
                borderWidth = 4,
                borderColor = STYLE.CARD_BORDER,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "道陨身殒",
                        fontSize = 22,
                        fontColor = {200, 60, 50, 255},
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
                        width = 150,
                        height = 48,
                        fontSize = 16,
                        fontWeight = "bold",
                        marginTop = 8,
                        borderRadius = 16,
                        borderWidth = 3,
                        borderColor = {60, 150, 100, 230},
                        backgroundColor = {80, 190, 130, 255},
                        pressedBackgroundColor = {60, 150, 100, 255},
                        fontColor = STYLE.TEXT_WHITE,
                        onClick = onRestart,
                    },
                }
            }
        }
    }
end

return Views
