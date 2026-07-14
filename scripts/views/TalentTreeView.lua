-- views/TalentTreeView.lua
-- 传统 MMO 风格天赋树：分支 Tab + 节点画布 + 连线 + 节点详情购买。

local UI = require("urhox-libs/UI")
local TalentSystem = require("TalentSystem")
local SlotAdapter = require("SlotAdapter")

local TalentTreeView = {}
TalentTreeView.__index = TalentTreeView

local NODE_SIZE = 92
local CANVAS_W = 760
local CANVAS_H = 1920

local COLORS = {
    overlay = {0, 0, 0, 150},
    panel = {236, 218, 184, 252},
    panelInner = {250, 238, 210, 255},
    canvas = {118, 98, 72, 210},
    pointBg = {111, 78, 39, 235},
    nodeBg = {107, 78, 45, 255},
    nodeLocked = {92, 82, 68, 232},
    nodeReady = {151, 108, 48, 255},
    nodeDone = {88, 132, 85, 255},
    border = {132, 95, 52, 235},
    borderDark = {80, 56, 34, 255},
    title = {55, 38, 25, 255},
    text = {72, 52, 32, 255},
    muted = {116, 88, 56, 255},
    tabText = {58, 41, 26, 255},
    tabTextActive = {72, 44, 20, 255},
    gold = {228, 166, 42, 255},
    green = {88, 142, 88, 255},
    red = {165, 62, 50, 255},
    lineOff = {83, 70, 55, 220},
    lineReady = {176, 126, 53, 245},
    lineDone = {228, 166, 42, 255},
    tab = {153, 116, 70, 255},
    tabActive = {217, 166, 70, 255},
}

local COMMON_TALENT_ICONS = {
    common_hp = "image/talent/common_hp.png",
    common_armor = "image/talent/common_armor.png",
    common_reduce = "image/talent/common_reduce.png",
    common_crit = "image/talent/common_crit.png",
    common_regen = "image/talent/common_regen.png",
    common_attack = "image/talent/common_attack.png",
}

local DEFAULT_NODE_ICON_BASE_IDS = {
    weapon_sword_a = "qingfeng_sword",
    weapon_sword_b = "taiji_sword",
    weapon_spear_a = "chiyan_spear",
    weapon_spear_b = "pozhen_spear",
    weapon_magic_a = "ziqi_gourd",
    weapon_magic_b = "jinguang_ring",
    weapon_chain_a = "fuyao_chain",
    weapon_chain_b = "double_blade_chain",
    weapon_tower_a = "zhenyao_tower",
    weapon_tower_b = "zhenyao_tower",
    weapon_guardian_a = "huxin_pearl",
    weapon_guardian_b = "huxin_pearl",
    armor_dark_iron = "dark_iron_shield",
    pill_juqi = "juqi",
    talisman_thunder = "thunder",
}

local function GetTalentNodeIcon(node)
    if not node then return nil end

    local commonIcon = COMMON_TALENT_ICONS[node.id]
    if commonIcon then return commonIcon end

    local unlock = node.unlock
    if unlock and unlock.type == "item" then
        return SlotAdapter.GetItemImageByBaseId(unlock.baseId)
    end

    local baseId = DEFAULT_NODE_ICON_BASE_IDS[node.id]
    if baseId then
        return SlotAdapter.GetItemImageByBaseId(baseId)
    end
    return nil
end

local function NodeCenter(node)
    return (node.x or 0) + NODE_SIZE * 0.5, (node.y or 0) + NODE_SIZE * 0.5
end

local function StatusInfo(state, node)
    if TalentSystem.IsPurchased(state, node.id) then
        return "已解锁", COLORS.nodeDone, COLORS.green, true
    end
    local ok, reason = TalentSystem.CanPurchase(state, node.id)
    if ok then
        return "可解锁", COLORS.nodeReady, COLORS.gold, false
    end
    return reason or "不可解锁", COLORS.nodeLocked, COLORS.lineOff, false
end

local function RequirementText(node)
    local names = {}
    for _, requirementId in ipairs(node.requires or {}) do
        local requirement = TalentSystem.GetNode(requirementId)
        table.insert(names, requirement and requirement.name or requirementId)
    end
    if #names == 0 then
        return "前置节点：无"
    end
    return "前置节点：" .. table.concat(names, "、")
end

local function MakeTab(text, active, onClick)
    return UI.Button {
        text = text,
        flexGrow = 1,
        height = 46,
        fontSize = 15,
        borderRadius = 10,
        borderWidth = 2,
        borderColor = active and COLORS.gold or COLORS.borderDark,
        backgroundColor = active and COLORS.tabActive or COLORS.tab,
        textColor = active and COLORS.tabTextActive or COLORS.tabText,
        fontWeight = "bold",
        onClick = onClick,
    }
end

local function Line(parent, x1, y1, x2, y2, color)
    local thickness = 6
    if math.abs(x1 - x2) < 1 then
        parent:AddChild(UI.Panel {
            position = "absolute",
            left = x1 - thickness * 0.5,
            top = math.min(y1, y2),
            width = thickness,
            height = math.abs(y2 - y1),
            borderRadius = thickness * 0.5,
            backgroundColor = color,
            pointerEvents = "none",
        })
    else
        parent:AddChild(UI.Panel {
            position = "absolute",
            left = math.min(x1, x2),
            top = y1 - thickness * 0.5,
            width = math.abs(x2 - x1),
            height = thickness,
            borderRadius = thickness * 0.5,
            backgroundColor = color,
            pointerEvents = "none",
        })
    end
end

function TalentTreeView.Create(callbacks)
    local self = setmetatable({
        callbacks = callbacks or {},
        root = nil,
        titleLabel = nil,
        pointsPanel = nil,
        availablePointsLabel = nil,
        spentPointsLabel = nil,
        tabsPanel = nil,
        scrollView = nil,
        canvas = nil,
        detailPanel = nil,
        detailTitle = nil,
        detailPrereq = nil,
        detailDesc = nil,
        detailStatus = nil,
        detailButton = nil,
        selectedBranch = "weapon",
        selectedNode = nil,
        state = nil,
    }, TalentTreeView)

    self.titleLabel = UI.Label {
        text = "天赋",
        fontSize = 24,
        fontWeight = "bold",
        fontColor = COLORS.title,
    }
    self.availablePointsLabel = UI.Label {
        text = "可用点: 0",
        fontSize = 15,
        fontColor = COLORS.gold,
        fontWeight = "bold",
    }
    self.spentPointsLabel = UI.Label {
        text = "已花费: 0",
        fontSize = 15,
        fontColor = {203, 128, 38, 255},
        fontWeight = "bold",
    }
    self.pointsPanel = UI.Panel {
        width = "100%",
        height = 44,
        flexDirection = "row",
        gap = 10,
        children = {
            UI.Panel {
                flexGrow = 1,
                height = "100%",
                borderRadius = 12,
                borderWidth = 2,
                borderColor = {178, 128, 62, 210},
                backgroundColor = COLORS.pointBg,
                alignItems = "center",
                justifyContent = "center",
                children = { self.availablePointsLabel },
            },
            UI.Panel {
                flexGrow = 1,
                height = "100%",
                borderRadius = 12,
                borderWidth = 2,
                borderColor = {148, 104, 52, 210},
                backgroundColor = {247, 232, 198, 255},
                alignItems = "center",
                justifyContent = "center",
                children = { self.spentPointsLabel },
            },
        },
    }
    self.tabsPanel = UI.Panel {
        width = "100%",
        flexDirection = "row",
        gap = 6,
    }
    self.canvas = UI.Panel {
        width = CANVAS_W,
        height = CANVAS_H,
        backgroundColor = COLORS.canvas,
        borderRadius = 16,
        borderWidth = 2,
        borderColor = COLORS.border,
        overflow = "visible",
    }
    self.scrollView = UI.ScrollView {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        scrollX = true,
        scrollY = true,
        showScrollbar = false,
        children = { self.canvas },
    }
    self.scrollView.OnPanStart = function(view, event)
        if not view.props.scrollX and not view.props.scrollY then
            return false
        end
        view.state.isDragging = true
        view.dragStartScrollX_ = view.state.scrollX
        view.dragStartScrollY_ = view.state.scrollY
        view.state.velocityX = 0
        view.state.velocityY = 0
        if event.StopPropagation then
            event:StopPropagation()
        end
        return true
    end
    self.scrollView.OnPanMove = function(view, event)
        if not view.state.isDragging then return end
        local dx = view.props.scrollX and -event.totalDeltaX or 0
        local dy = view.props.scrollY and -event.totalDeltaY or 0
        view:SetScroll(view.dragStartScrollX_ + dx, view.dragStartScrollY_ + dy)
        view.state.velocityX = -event.deltaX
        view.state.velocityY = -event.deltaY
        if event.StopPropagation then
            event:StopPropagation()
        end
    end
    self.scrollView.OnPanEnd = function(view, event)
        view.state.isDragging = false
        if event.StopPropagation then
            event:StopPropagation()
        end
    end

    self.detailTitle = UI.Label { text = "", fontSize = 18, fontWeight = "bold", fontColor = COLORS.title, height = 24 }
    self.detailPrereq = UI.Label {
        text = "",
        width = "100%",
        height = 20,
        fontSize = 12,
        fontColor = COLORS.muted,
        whiteSpace = "normal",
        flexShrink = 0,
    }
    self.detailDesc = UI.Label {
        text = "",
        width = "100%",
        height = 88,
        fontSize = 13,
        lineHeight = 1.25,
        fontColor = COLORS.text,
        whiteSpace = "normal",
        flexShrink = 0,
    }
    self.detailStatus = UI.Label { text = "", width = "100%", height = 22, fontSize = 13, fontColor = COLORS.gold, whiteSpace = "normal" }
    self.detailButton = UI.Button {
        text = "解锁",
        width = "100%",
        height = 36,
        fontSize = 16,
        borderRadius = 10,
        borderWidth = 2,
        borderColor = COLORS.gold,
        backgroundColor = COLORS.tabActive,
        textColor = COLORS.tabTextActive,
        onClick = function()
            if self.selectedNode and self.callbacks.onPurchase then
                self.callbacks.onPurchase(self.selectedNode.id)
            end
        end,
    }
    self.detailPanel = UI.Panel {
        visible = false,
        width = "100%",
        height = 260,
        padding = 10,
        gap = 6,
        backgroundColor = COLORS.panelInner,
        borderRadius = 14,
        borderWidth = 2,
        borderColor = COLORS.borderDark,
        children = {
            self.detailTitle,
            self.detailPrereq,
            self.detailDesc,
            self.detailStatus,
            self.detailButton,
        },
    }

    self.root = UI.Panel {
        visible = false,
        position = "absolute",
        left = 0, top = 0, right = 0, bottom = 0,
        backgroundColor = COLORS.overlay,
        alignItems = "center",
        justifyContent = "center",
        children = {
            UI.Panel {
                width = "94%",
                maxWidth = 620,
                height = "94%",
                padding = 16,
                gap = 10,
                backgroundColor = COLORS.panel,
                borderRadius = 20,
                borderWidth = 3,
                borderColor = COLORS.borderDark,
                children = {
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "space-between",
                        alignItems = "center",
                        children = {
                            self.titleLabel,
                            UI.Button {
                                text = "×",
                                width = 42,
                                height = 38,
                                fontSize = 22,
                                borderRadius = 10,
                                borderWidth = 2,
                                borderColor = COLORS.borderDark,
                                backgroundColor = {92, 63, 36, 255},
                                textColor = {235, 218, 185, 255},
                                onClick = function()
                                    self:Hide()
                                end,
                            },
                        },
                    },
                    self.pointsPanel,
                    self.tabsPanel,
                    self.scrollView,
                    self.detailPanel,
                },
            },
        },
    }

    return self
end

function TalentTreeView:GetRoot()
    return self.root
end

function TalentTreeView:BuildTabs()
    self.tabsPanel:ClearChildren()
    for _, branch in ipairs(TalentSystem.GetBranches()) do
        local branchId = branch.id
        self.tabsPanel:AddChild(MakeTab(branch.name, self.selectedBranch == branchId, function()
            if self.selectedBranch == branchId then return end
            self.selectedBranch = branchId
            self.selectedNode = nil
            self:Refresh()
            self.scrollView:SetScroll(0, 0)
        end))
    end
end

function TalentTreeView:BuildEdge(edge, nodeById)
    local from = nodeById[edge.from]
    local to = nodeById[edge.to]
    if not from or not to then return end

    local _, _, fromLineColor, fromDone = StatusInfo(self.state, from)
    local _, _, toLineColor, toDone = StatusInfo(self.state, to)
    local color = (fromDone and toDone) and COLORS.lineDone or (fromDone and toLineColor or fromLineColor)

    local x1, y1 = NodeCenter(from)
    local x2, y2 = NodeCenter(to)
    local midY = (y1 + y2) * 0.5
    Line(self.canvas, x1, y1, x1, midY, color)
    Line(self.canvas, x1, midY, x2, midY, color)
    Line(self.canvas, x2, midY, x2, y2, color)
end

function TalentTreeView:BuildNode(node)
    local status, bgColor, borderColor = StatusInfo(self.state, node)
    local icon = GetTalentNodeIcon(node)
    local iconTint = status == "已解锁" and {255, 255, 255, 255}
        or status == "可解锁" and {255, 244, 210, 255}
        or {128, 120, 105, 205}

    self.canvas:AddChild(UI.Panel {
        position = "absolute",
        left = node.x or 0,
        top = node.y or 0,
        width = NODE_SIZE,
        height = NODE_SIZE,
        borderRadius = 18,
        borderWidth = 4,
        borderColor = borderColor,
        backgroundColor = bgColor,
        overflow = "hidden",
        onTap = function()
            self:SelectNode(node)
        end,
        children = {
            UI.Panel {
                position = "absolute",
                left = 14,
                top = 7,
                width = NODE_SIZE - 28,
                height = 52,
                borderRadius = 12,
                backgroundColor = {42, 29, 17, 78},
                backgroundImage = icon or nil,
                backgroundFit = "contain",
                imageTint = icon and iconTint or nil,
                pointerEvents = "none",
            },
            UI.Label {
                position = "absolute",
                left = 5,
                top = 58,
                width = NODE_SIZE - 10,
                height = 19,
                text = node.name,
                fontSize = 10,
                lineHeight = 10,
                fontWeight = "bold",
                fontColor = {255, 245, 230, 255},
                textAlign = "center",
                maxLines = 2,
            },
            UI.Panel {
                position = "absolute",
                left = 22,
                bottom = 5,
                width = NODE_SIZE - 44,
                height = 18,
                borderRadius = 9,
                backgroundColor = {55, 38, 22, 180},
                alignItems = "center",
                justifyContent = "center",
                children = {
                    UI.Label {
                        text = tostring(node.cost or 0) .. "点",
                        fontSize = 10,
                        fontColor = COLORS.gold,
                        textAlign = "center",
                    },
                },
            },
        },
    })
end

function TalentTreeView:SelectNode(node)
    self.selectedNode = node
    local status, _, statusColor = StatusInfo(self.state, node)
    local canBuy = TalentSystem.CanPurchase(self.state, node.id)
    self.detailTitle:SetText(node.name)
    self.detailPrereq:SetText(RequirementText(node))
    self.detailDesc:SetText(node.desc or "")
    self.detailStatus:SetText(string.format("状态：%s  消耗：%d点", status, node.cost or 0))
    self.detailStatus:SetStyle({ fontColor = statusColor })
    self.detailButton:SetText(TalentSystem.IsPurchased(self.state, node.id) and "已解锁" or "解锁")
    self.detailButton:SetStyle({
        borderColor = canBuy and COLORS.gold or COLORS.border,
        backgroundColor = canBuy and COLORS.tabActive or COLORS.nodeLocked,
    })
    self.detailPanel:SetVisible(true)
end

function TalentTreeView:Refresh()
    if not self.state then return end
    TalentSystem.EnsureState(self.state)
    if self.availablePointsLabel then
        self.availablePointsLabel:SetText(string.format("可用点: %d", self.state.talentPoints or 0))
    end
    if self.spentPointsLabel then
        self.spentPointsLabel:SetText(string.format("已花费: %d", self.state.spentTalentPoints or 0))
    end
    self:BuildTabs()
    self.canvas:ClearChildren()

    local nodes = TalentSystem.GetNodes(self.selectedBranch)
    local nodeById = {}
    for _, node in ipairs(nodes) do
        nodeById[node.id] = node
    end
    for _, edge in ipairs(TalentSystem.GetEdges(self.selectedBranch)) do
        self:BuildEdge(edge, nodeById)
    end
    for _, node in ipairs(nodes) do
        self:BuildNode(node)
    end

    if self.selectedNode and self.selectedNode.branch == self.selectedBranch then
        self:SelectNode(self.selectedNode)
    else
        self.detailPanel:SetVisible(false)
    end
end

function TalentTreeView:Show(state)
    self.state = state
    self:Refresh()
    self.root:SetVisible(true)
end

function TalentTreeView:Hide()
    self.root:SetVisible(false)
end

return TalentTreeView
