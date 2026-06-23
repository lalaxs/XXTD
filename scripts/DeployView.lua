-- DeployView.lua
-- 部署区视图 - 使用与 FieldView 完全相同的绝对定位逻辑
-- 格子不会被压缩，图片不会被拉伸

local UI = require("urhox-libs/UI")
local Config = require("Config")
local STYLE = require("Theme")
local SlotAdapter = require("SlotAdapter")

local DeployView = {}

--- 创建道具视觉面板（与怪物面板同逻辑）
local function CreateItemVisual(item, cellSize)
    if not item then return nil end
    local img = SlotAdapter.GetItemImage(item)
    local qColor = Config.QUALITY[item.quality] and Config.QUALITY[item.quality].color
        or {200, 200, 200, 255}

    return UI.Panel {
        width = "100%",
        height = "100%",
        alignItems = "center",
        justifyContent = "center",
        pointerEvents = "none",
        overflow = "visible",
        children = {
            -- 道具图片（保持比例，可向上破格）
            UI.Panel {
                position = "absolute",
                bottom = 2,
                width = cellSize * 0.85,
                aspectRatio = 5/6,
                backgroundImage = img,
                backgroundSize = "contain",
                pointerEvents = "none",
            },
        },
    }
end

function DeployView.Update(deployPanel, state, slots)
    -- 清除旧的视觉子元素（保留 slots）
    deployPanel:ClearChildren()

    local layout = deployPanel:GetAbsoluteLayout()
    if not layout or layout.w == 0 or layout.h == 0 then return end

    local cellSize = layout.w / Config.GRID_COLS

    -- 绘制格子背景 + 道具图片 + 放置 ItemSlot 交互层
    for row = 0, Config.DEPLOY_ROWS - 1 do
        for col = 0, Config.GRID_COLS - 1 do
            local idx = row * Config.GRID_COLS + col + 1
            local x = col * cellSize
            local y = row * cellSize
            local isA = (row + col) % 2 == 0

            -- 格子背景
            deployPanel:AddChild(UI.Panel {
                position = "absolute",
                left = x, top = y,
                width = cellSize, height = cellSize,
                backgroundColor = isA and STYLE.DEPLOY_CELL_A or STYLE.DEPLOY_CELL_B,
                borderWidth = 0.5,
                borderColor = STYLE.FIELD_GRID_LINE,
                pointerEvents = "none",
            })

            -- 道具图片
            local item = state.slots[idx]
            if item then
                deployPanel:AddChild(UI.Panel {
                    position = "absolute",
                    left = x, top = y,
                    width = cellSize, height = cellSize,
                    pointerEvents = "none",
                    overflow = "visible",
                    children = {
                        CreateItemVisual(item, cellSize),
                    },
                })
            end

            -- ItemSlot 交互层（透明，覆盖在最上面）
            local slot = slots[idx]
            if slot then
                slot:SetStyle({
                    left = x, top = y,
                    width = cellSize, height = cellSize,
                })
                deployPanel:AddChild(slot)
            end
        end
    end
end

return DeployView
