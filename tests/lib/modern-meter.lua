-- Blizzard_DamageMeter fixtures shaped after a frame dump of the client: a session window with the Header
-- texture, the SessionTimer text, the type / session / settings dropdowns and the minimize button on the
-- header, and MinimizeContainer (Background, ScrollBox of pooled rows). A row is a Button with an Icon frame
-- (Icon texture) and a StatusBar with a coloured fill and its Background / BackgroundEdge art.
local D = {}

local CLASS = { 0.78, 0.61, 0.43, 1 }
local GOLD = { 1, 0.82, 0, 1 }

local function art(parent, name, alpha, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture("Interface\\DamageMeter\\" .. name)
    texture:SetAlpha(alpha)
    return texture
end

local function text(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    font:SetTextColor(unpack(GOLD))
    return font
end

local function button(parent)
    local b = CreateFrame("Button", nil, parent)
    local normal = art(b, "Button", 1, "ARTWORK")
    b.GetNormalTexture = function() return normal end
    b.normal = normal
    return b
end

function D.row(window)
    local entry = CreateFrame("Button", nil, window.MinimizeContainer.ScrollBox.ScrollTarget)
    entry.Icon = CreateFrame("Frame", nil, entry)
    entry.Icon.Icon = art(entry.Icon, "SpecIcon", 1, "ARTWORK")
    local bar = CreateFrame("StatusBar", nil, entry)
    local fill = art(bar, "Bar", 1, "ARTWORK")
    bar._barColor = { unpack(CLASS) }
    bar.SetStatusBarTexture = function(_, value) fill:SetTexture(value) end
    bar.GetStatusBarTexture = function() return fill end
    bar.SetStatusBarColor = function(self, ...) self._barColor = { ... } end
    bar.GetStatusBarColor = function(self) return unpack(self._barColor) end
    bar.Background = art(bar, "BarBackground", 0.8)
    bar.BackgroundEdge = art(bar, "BarEdge", 0.7, "OVERLAY")
    bar.Name = bar:CreateFontString(nil, "OVERLAY")
    entry.StatusBar = bar
    return bar
end

function D.window(index)
    local window = CreateFrame("Frame", "DamageMeterSessionWindow" .. index, UIParent)
    window:SetSize(326, 137)
    window.Header = art(window, "Header", 0.9)
    window.SessionTimer = text(window, "[00:02]")
    window.MinimizeButton = button(window)
    window.SettingsDropdown = CreateFrame("Button", nil, window)
    window.SettingsDropdown.Icon = art(window.SettingsDropdown, "Settings", 1, "ARTWORK")
    local session = CreateFrame("Button", nil, window)
    session.Background = art(session, "SessionButton", 1)
    session.Arrow = art(session, "SessionArrow", 1, "OVERLAY")
    session.SessionName = text(session, "C")
    window.SessionDropdown = session
    window.DamageMeterTypeDropdown = CreateFrame("Button", nil, window)
    window.DamageMeterTypeDropdown.Arrow = art(window.DamageMeterTypeDropdown, "TypeArrow", 1, "OVERLAY")
    local container = CreateFrame("Frame", nil, window)
    container.Background = art(container, "Background", 0.5)
    local box = CreateFrame("Frame", nil, container)
    box.Update = function() end
    box.ScrollTarget = CreateFrame("Frame", nil, box)
    container.ScrollBox = box
    window.MinimizeContainer = container
    window.row = D.row(window)
    return window
end

D.CLASS, D.GOLD = CLASS, GOLD
return D
