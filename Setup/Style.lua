local _, ns = ...

-- The setup look: the same chrome Modernize draws on Blizzard's windows, whether Modernize is on or not.
-- Edges and fills are textures, so they draw without BackdropTemplate too.

local Setup = ns.Setup

-- Modernize's window header height.
Setup.HEADER = 24
-- Modernize's hover: a faint white wash inside the edge.
local HOVER = { 1, 1, 1, 0.07 }
local MUTED = { 0.65, 0.65, 0.65 }

function Setup.Colors()
    return ns.Modern.Theme()
end

-- A theme colour at full opacity: the setup keeps its fills opaque whatever the panel background alpha.
function Setup.Solid(color)
    return { color[1], color[2], color[3], 1 }
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

function Setup.Hover(frame)
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", 1, -1)
    highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    highlight:SetColorTexture(unpack(HOVER))
    return highlight
end

-- A button (panel fill) or a field and checkbox (`fill` = the theme track): thin grey edge, light label; dimmed while
-- disabled.
function Setup.Control(button, fill)
    Setup.Fill(button, Setup.Solid(fill or Setup.Colors().bg))
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

-- A window like Modernize's: opaque fill lit towards the top, quiet outline, a header band with the accent hairline,
-- the title and an optional close cross.
function Setup.Window(frame, title, onClose)
    local theme = Setup.Colors()
    ns.Modern.Lit(Setup.Fill(frame, Setup.Solid(theme.bg), "BACKGROUND", -8), Setup.Solid(theme.bg), 0.03)
    Setup.Edge(frame, theme.outline)
    local band = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", -1, -1)
    band:SetHeight(Setup.HEADER - 1)
    ns.Modern.Band(band)
    local rule = frame:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.6)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", 0, -(Setup.HEADER - 12) / 2)
    frame.title:SetText(title)
    if onClose then frame.close = Setup.CloseCross(frame, onClose) end
end

-- A strip a step above the panel with a 2 px accent edge on the left: Modernize's section header and selected row.
function Setup.Strip(frame)
    frame.fill = Setup.Fill(frame, Setup.Colors().strip)
    frame.mark = frame:CreateTexture(nil, "ARTWORK")
    frame.mark:SetPoint("TOPLEFT", 0, 0)
    frame.mark:SetPoint("BOTTOMLEFT", 0, 0)
    frame.mark:SetWidth(2)
    frame.mark:SetColorTexture(unpack(Setup.Colors().accent))
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
