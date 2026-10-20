local _, ns = ...

-- The setup look: Modernize's dark theme on the addon's own frames, whether Modernize is on or not.
-- Edges and fills are textures, so they draw without BackdropTemplate too.

local Setup = ns.Setup

Setup.HEADER = 30
-- Control fill: a step above the window, like an empty bag slot.
local CONTROL = { 0.1, 0.1, 0.1, 1 }
local MUTED = { 0.65, 0.65, 0.65 }

function Setup.Colors()
    return ns.Modern.Theme()
end

function Setup.Fill(frame, color, layer, sublevel)
    local fill = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
    fill:SetAllPoints(frame)
    fill:SetColorTexture(unpack(color))
    return fill
end

-- Four 1 px lines inside the frame's bounds.
function Setup.Edge(frame, color)
    frame._quietEdge = {}
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = frame:CreateTexture(nil, "BORDER")
        if edge == "TOP" or edge == "BOTTOM" then
            line:SetHeight(1)
            line:SetPoint(edge .. "LEFT", 0, 0)
            line:SetPoint(edge .. "RIGHT", 0, 0)
        else
            line:SetWidth(1)
            line:SetPoint("TOP" .. edge, 0, 0)
            line:SetPoint("BOTTOM" .. edge, 0, 0)
        end
        frame._quietEdge[#frame._quietEdge + 1] = line
    end
    Setup.EdgeColor(frame, color or Setup.Colors().border)
end

function Setup.EdgeColor(frame, color)
    for _, line in ipairs(frame._quietEdge or {}) do line:SetColorTexture(unpack(color)) end
end

function Setup.Hover(frame, alpha)
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    local accent = Setup.Colors().accent
    highlight:SetColorTexture(accent[1], accent[2], accent[3], alpha or 0.12)
    return highlight
end

-- A button or field: dark fill, thin grey edge, light label; dimmed while disabled.
function Setup.Control(button)
    Setup.Fill(button, CONTROL)
    Setup.Edge(button)
    if button.label and button.label.SetTextColor then button.label:SetTextColor(unpack(Setup.Colors().text)) end
    if type(button.HookScript) == "function" then
        button:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
        button:HookScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    end
end

function Setup.Muted(label)
    label:SetTextColor(unpack(MUTED))
    return label
end

-- A bare cross that turns red under the mouse.
function Setup.CloseCross(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(Setup.HEADER - 6, Setup.HEADER - 6)
    button:SetPoint("TOPRIGHT", -3, -3)
    button:SetFrameLevel(parent:GetFrameLevel() + 20)
    local lines = { ns.Modern.GlyphLine(button, 12, 2, 0, 0, 45), ns.Modern.GlyphLine(button, 12, 2, 0, 0, -45) }
    local function Paint(color)
        for _, line in ipairs(lines) do line:SetColorTexture(unpack(color)) end
    end
    Paint(Setup.Colors().glyph)
    button:SetScript("OnEnter", function() Paint(Setup.Colors().danger) end)
    button:SetScript("OnLeave", function() Paint(Setup.Colors().glyph) end)
    button:SetScript("OnClick", onClick)
    return button
end

-- A window of the setup look: opaque fill, thin edge, a header band with the title and an optional close cross.
function Setup.Window(frame, title, onClose)
    ns.DialogBackground(frame)
    Setup.Edge(frame)
    local band = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", -1, -1)
    band:SetHeight(Setup.HEADER - 1)
    ns.Modern.Band(band)
    local rule = frame:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetColorTexture(unpack(Setup.Colors().border))
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -(Setup.HEADER - 12) / 2)
    frame.title:SetText(title)
    if onClose then frame.close = Setup.CloseCross(frame, onClose) end
end

-- A 1 px line from `from` to `to` (both { point, x, y }).
function Setup.Rule(frame, from, to)
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetPoint(from[1], frame, from[1], from[2], from[3])
    line:SetPoint(to[1], frame, to[1], to[2], to[3])
    if from[3] == to[3] then line:SetHeight(1) else line:SetWidth(1) end
    line:SetColorTexture(unpack(Setup.Colors().border))
    return line
end

-- Stacks rows down one column of a page. Rows take the column width unless `width` is given.
Setup.ROW = 30
Setup.GAP = 18

function Setup.Column(page, x, width)
    local column = { y = 0 }
    function column.Add(_, widget, height, indent, ownWidth)
        indent = indent or 0
        widget:SetPoint("TOPLEFT", page, "TOPLEFT", x + indent, -column.y)
        if ownWidth ~= false then widget:SetWidth(ownWidth or width - indent) end
        column.y = column.y + (height or Setup.ROW)
        return widget
    end
    function column.Gap(_, height) column.y = column.y + (height or Setup.GAP) end
    return column
end

-- Every other row of a table gets a faint band, so a label finds its controls across a wide page.
function Setup.Stripe(row, index)
    if index % 2 == 1 then return end
    local band = row:CreateTexture(nil, "BACKGROUND")
    band:SetAllPoints(row)
    band:SetColorTexture(1, 1, 1, 0.03)
end
