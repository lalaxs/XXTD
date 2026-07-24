-- views/VectorIcons.lua
-- UI 层共享矢量图标。

local Widget = require("urhox-libs/UI/Core/Widget")

local CoinIcon = setmetatable({}, { __index = Widget })
CoinIcon.__index = CoinIcon

function CoinIcon:new(props)
    return Widget.new(self, props or {})
end

setmetatable(CoinIcon, {
    __index = Widget,
    __call = function(cls, props)
        return cls:new(props)
    end,
})

function CoinIcon:Render(nvg)
    local l = self:GetAbsoluteLayout()
    local cx = l.x + l.w * 0.5
    local cy = l.y + l.h * 0.5
    local radius = math.min(l.w, l.h) * 0.36

    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius)
    nvgFillColor(nvg, nvgRGBA(232, 178, 65, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(111, 78, 39, 255))
    nvgStrokeWidth(nvg, math.max(1.5, radius * 0.09))
    nvgStroke(nvg)

    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, radius * 0.68)
    nvgStrokeColor(nvg, nvgRGBA(255, 236, 156, 220))
    nvgStrokeWidth(nvg, math.max(1, radius * 0.06))
    nvgStroke(nvg)

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx - radius * 0.22, cy - radius * 0.28, radius * 0.44, radius * 0.56, radius * 0.04)
    nvgFillColor(nvg, nvgRGBA(255, 239, 157, 255))
    nvgFill(nvg)
end

return {
    CoinIcon = CoinIcon,
}
