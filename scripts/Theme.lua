-- Theme.lua
-- 仙侠合成塔防 - 牛皮纸古卷风格主题

local Theme = {}

-- === 背景底色 ===
Theme.BG_TOP = {62, 48, 35, 255}       -- 深褐色（古旧卷轴顶部）
Theme.BG_BOTTOM = {85, 65, 45, 255}    -- 偏暖深褐色

-- === 战场格子（灰白色系，半透明让背景透出）===
Theme.FIELD_BG = {0, 0, 0, 0}                -- 透明底
Theme.FIELD_CELL_A = {250, 248, 244, 120}    -- 暖白格（半透明）
Theme.FIELD_CELL_B = {238, 235, 230, 120}    -- 浅灰格（半透明）
Theme.FIELD_GRID_LINE = {200, 195, 185, 80}  -- 淡灰格线
Theme.FIELD_BORDER = {180, 175, 165, 120}    -- 灰外框

-- === 部署区（下方放置区域）===
Theme.DEPLOY_BG = {0, 0, 0, 0}              -- 透明
Theme.DEPLOY_BORDER = {0, 0, 0, 0}          -- 无边框
Theme.DEPLOY_CELL_A = {230, 226, 218, 130}  -- 部署浅格（半透明）
Theme.DEPLOY_CELL_B = {215, 210, 202, 130}  -- 部署深格（半透明）
Theme.DEPLOY_ACCENT = {180, 145, 95, 180}   -- 点缀色

-- === 缓冲区/储存区 ===
Theme.STORAGE_BG = {0, 0, 0, 0}             -- 透明
Theme.STORAGE_BORDER = {0, 0, 0, 0}         -- 无边框

-- === 卡槽格子 ===
Theme.CARD_BG = {248, 246, 242, 200}        -- 灰白卡底
Theme.CARD_BORDER = {185, 180, 170, 180}    -- 淡灰边框
Theme.CARD_EMPTY_MARK = {200, 195, 188, 100} -- 空格标记
Theme.SLOT_RADIUS = 8

-- === HUD 顶栏 ===
Theme.HUD_BG = {55, 40, 28, 220}            -- 深棕HUD背景
Theme.HUD_BORDER = {120, 90, 50, 200}       -- 金边
Theme.HUD_RADIUS = 16

-- === 血条/经验条 ===
Theme.HP_RED = {200, 55, 40, 255}            -- 朱砂红
Theme.EXP_PURPLE = {140, 80, 200, 255}      -- 灵气紫

-- === 文字颜色 ===
Theme.TEXT_WHITE = {255, 245, 230, 255}      -- 暖白
Theme.TEXT_DARK = {50, 38, 25, 255}          -- 墨色
Theme.TEXT_GOLD = {255, 200, 60, 255}        -- 金色
Theme.TEXT_SOFT = {160, 130, 90, 200}        -- 柔和棕

-- === 品质色（保持原有便于识别）===
Theme.Q_WHITE = {200, 200, 200, 255}
Theme.Q_GREEN = {100, 210, 120, 255}
Theme.Q_BLUE = {80, 160, 255, 255}
Theme.Q_PURPLE = {180, 100, 255, 255}
Theme.Q_GOLD = {255, 200, 50, 255}
Theme.Q_ORANGE = {255, 140, 50, 255}

-- === 怪物相关 ===
Theme.MONSTER_HP_BG = {50, 35, 25, 180}
Theme.MONSTER_CHARGE_DOT = {255, 180, 40, 240}
Theme.MONSTER_CHARGE_BORDER = {200, 140, 20, 255}

-- === 草地分割线（部署区顶部装饰）===
Theme.DIVIDER_COLOR = {120, 85, 50, 200}

-- === GameOver弹窗 ===
Theme.GAMEOVER_OVERLAY = {20, 15, 10, 170}
Theme.GAMEOVER_BG = {240, 225, 195, 250}
Theme.GAMEOVER_BORDER = {140, 105, 60, 220}
Theme.GAMEOVER_TITLE = {180, 50, 35, 255}
Theme.GAMEOVER_BTN_BG = {160, 120, 60, 255}
Theme.GAMEOVER_BTN_PRESS = {130, 95, 45, 255}
Theme.GAMEOVER_BTN_BORDER = {110, 80, 35, 230}

return Theme
