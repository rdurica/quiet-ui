local _, ns = ...

-- Window chrome shared by the Windows and Map areas: holds the art that Blizzard's
-- PortraitFrameTemplate / ButtonFrameTemplate, NineSlicePanelTemplate, InsetFrameTemplate and
-- PanelTabButtonTemplate put on a frame. Everything is held through the area journal (alpha),
-- never hidden, so titles and window content stay. The close button keeps its place and click area; only its art
-- becomes a bare thin cross.

local Modern = ns.Modern

local TEXTURE_KEYS = { "chrome", "Bg", "Background", "Border", "Portrait", "portrait", "PortraitFrame", "TitleBg",
    "TopTileStreaks", "InsetBorderTop", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder",
    -- BasicFrameTemplate(WithInset): the taxi window. Its InsetBg is the taxi map and stays.
    "TopLeftCorner", "TopRightCorner", "TopBorder", "BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder",
    "RightBorder", "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft",
    "InsetBorderBottomRight", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight" }
-- DialogHeaderTemplate (game menu, colour picker, raid info) and the two halves behind a static popup.
local HEADER_KEYS = { "LeftBG", "RightBG", "CenterBG" }
local POPUP_KEYS = { "Top", "Bottom" }
local NINE_KEYS = { "art", "Center", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "TopLeftCorner",
    "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
-- Panel tabs (PanelTabButtonTemplate), the character window's side tabs (common-sidetab art) and the
-- spellbook's icon tabs (spellbook-Tab-Frame art).
local TAB_KEYS = { "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive", "LeftDisabled",
    "MiddleDisabled", "RightDisabled", "Background", "SelectedTexture", "TabGlow", "HighlightTexture",
    "SquareBackground", "SquareBackgroundActive", "SquareBackgroundActiveGlow", "LeftHighlight", "MiddleHighlight",
    "RightHighlight" }
-- The art Blizzard shows on the selected tab, first match wins.
local SELECTED_KEYS = { "SquareBackgroundActive", "LeftActive", "SelectedTexture" }

local GLYPH_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }
local CROSS_LENGTH = 12

local tabs = setmetatable({}, { __mode = "k" })    -- tab -> true while its area is applied
local glyphs = setmetatable({}, { __mode = "k" })  -- glyph button -> { skin, key, build, hover } while applied
local hovered = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function HoldKeys(skin, owner, keys)
    if not ns.Usable(owner) then return end
    for _, key in ipairs(keys) do
        local texture = owner[key]
        if IsTexture(texture) then skin:Hold(texture) end
    end
end

-- FlatPanelBackgroundTemplate (the loot window's Bg): a frame of flat pieces.
local FLAT_KEYS = { "TopSection", "BottomEdge", "BottomLeft", "BottomRight" }

-- A frame of nine pieces (or the old single `art`) is chrome only.
local function Slice(skin, slice)
    if IsTexture(slice) then skin:Hold(slice) else HoldKeys(skin, slice, NINE_KEYS) end
end

-- InsetFrameTemplate: a frame with its own Bg and NineSlice. An old single texture is held as is.
local function Inset(skin, inset)
    if IsTexture(inset) then
        skin:Hold(inset)
    elseif ns.Usable(inset) then
        HoldKeys(skin, inset, { "Bg" })
        Slice(skin, inset.NineSlice)
    end
end

function Modern.WindowChrome(skin, frame)
    if not ns.Usable(frame) then return end
    HoldKeys(skin, frame, TEXTURE_KEYS)
    if not IsTexture(frame.Bg) then HoldKeys(skin, frame.Bg, FLAT_KEYS) end
    Slice(skin, frame.NineSlice)
    -- DialogBorderTemplate: a nine-piece border frame with its own Bg.
    if ns.Usable(frame.Border) and not IsTexture(frame.Border) then
        Slice(skin, frame.Border)
        HoldKeys(skin, frame.Border, { "Bg" })
    end
    HoldKeys(skin, frame.Header, HEADER_KEYS)
    if ns.Usable(frame.BG) and not IsTexture(frame.BG) then HoldKeys(skin, frame.BG, POPUP_KEYS) end
    Inset(skin, frame.Inset)
    Inset(skin, frame.InsetRight)    -- the character window's stats pane
    local container = frame.PortraitContainer
    if ns.Usable(container) then HoldKeys(skin, container, { "portrait", "Portrait" }) end
end

-- The accent border marks the selected tab: Blizzard shows the Active (side tab: Selected) art for it.
local function Selected(tab)
    for _, key in ipairs(SELECTED_KEYS) do
        local active = tab[key]
        if ns.Usable(active) and type(active.IsShown) == "function" then return active:IsShown() and true or false end
    end
    return false
end

local function TabBorder(skin, tab)
    local theme = Modern.Theme()
    skin:Border(tab, Selected(tab) and theme.accent or theme.border)
end

-- A bare tab keeps only its fill and hover, with no border and no selected accent.
function Modern.TabChrome(skin, tab, bare)
    if not ns.Usable(tab) then return end
    HoldKeys(skin, tab, TAB_KEYS)
    skin:Panel(tab)
    Modern.Shapes.Hover(skin, tab)
    if bare then return end
    TabBorder(skin, tab)
    tabs[tab] = skin
    skin:Remember(tab, "modern tab", function() tabs[tab] = nil end)
    if hooked[tab] then return end
    hooked[tab] = true
    for _, key in ipairs({ "SquareBackgroundActive", "LeftActive", "Left", "SelectedTexture" }) do
        local piece = tab[key]
        for _, method in ipairs({ "Show", "Hide", "SetShown" }) do
            if ns.Usable(piece) and type(piece[method]) == "function" then
                pcall(hooksecurefunc, piece, method, function()
                    local owner = tabs[tab]
                    if owner then ns.Profiler.Run("modern tab", TabBorder, owner, tab) end
                end)
            end
        end
    end
end

-- Tab buttons of the 12.0 TabSystem (spellbook / talents window) are children of TabSystem
-- (PlayerSpellsFrame and its spellbook name it tabSystem).
function Modern.TabSystemChrome(skin, frame, bare)
    local system = ns.Usable(frame) and (frame.TabSystem or frame.tabSystem)
    if not ns.Usable(system) or type(system.GetChildren) ~= "function" then return end
    for _, tab in ipairs({ system:GetChildren() }) do
        if ns.Usable(tab) and (tab.Left or tab.LeftActive) then Modern.TabChrome(skin, tab, bare) end
    end
end

-- One 2 px line of a glyph, `x`, `y` from the button centre, optionally rotated by `angle` degrees.
function Modern.GlyphLine(button, width, height, x, y, angle)
    local line = button:CreateTexture(nil, "OVERLAY")
    line:SetSize(width, height)
    line:SetPoint("CENTER", button, "CENTER", x or 0, y or 0)
    if angle and type(line.SetRotation) == "function" then pcall(line.SetRotation, line, math.rad(angle)) end
    return line
end

function Modern.CrossParts(button)
    return { Modern.GlyphLine(button, CROSS_LENGTH, 2, 0, 0, 45), Modern.GlyphLine(button, CROSS_LENGTH, 2, 0, 0, -45) }
end

local function PaintGlyph(button)
    local state = glyphs[button]
    if not state then return end
    local theme = Modern.Theme()
    local parts = state.skin:Own(button, state.key, function() return state.build(button) end)
    local color = hovered[button] and theme[state.hover] or theme.glyph
    for _, line in ipairs(parts) do line:SetColorTexture(unpack(color)) end
end

-- A title-bar button keeps its place, size and click; its art is held and `build(button)` draws a bare glyph of
-- thin lines in its centre, grey and `theme[hover]` under the mouse.
function Modern.GlyphButton(skin, button, key, build, hover)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    for _, getter in ipairs(GLYPH_ART) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok and IsTexture(texture) then skin:Hold(texture) end
        end
    end
    glyphs[button] = { skin = skin, key = key, build = build, hover = hover }
    for _, part in ipairs(skin:Own(button, key, function() return build(button) end)) do part:Show() end
    skin:Remember(button, "modern glyph", function()
        glyphs[button] = nil
        hovered[button] = nil
    end)
    PaintGlyph(button)
    if hooked[button] or type(button.HookScript) ~= "function" then return end
    hooked[button] = true
    for script, on in pairs({ OnEnter = true, OnLeave = false }) do
        pcall(button.HookScript, button, script, function()
            if not glyphs[button] then return end
            hovered[button] = on
            ns.Profiler.Run("modern glyph", PaintGlyph, button)
        end)
    end
end

-- PortraitFrameTemplate / ButtonFrameTemplate name it CloseButton, ScrollingFlatPanelTemplate ClosePanelButton; the world map keeps it on BorderFrame only,
-- so a missing candidate must not end the search. A labelled one is a text button (the settings panel's Close).
local function Labelled(button)
    local text = type(button.GetText) == "function" and button:GetText()
    return type(text) == "string" and text ~= ""
end

local function FindClose(frame)
    local name = type(frame.GetName) == "function" and frame:GetName()
    local border = ns.Usable(frame.BorderFrame) and frame.BorderFrame or nil
    local candidates = { frame.CloseButton or false, frame.ClosePanelButton or false, border and border.CloseButton or false,
        type(name) == "string" and _G[name .. "CloseButton"] or false }
    for index = 1, #candidates do
        local close = candidates[index]
        if close and ns.Usable(close) and type(close.CreateTexture) == "function" and not Labelled(close) then
            return close
        end
    end
end

function Modern.CloseButton(skin, frame)
    local button = ns.Usable(frame) and FindClose(frame)
    if button then Modern.GlyphButton(skin, button, "close", Modern.CrossParts, "danger") end
end

local SIZE_GLYPH = 10

-- Maximize: an outlined square; minimize: one bar.
local function BoxParts(button)
    local half = SIZE_GLYPH / 2 - 1
    return { Modern.GlyphLine(button, SIZE_GLYPH, 2, 0, half), Modern.GlyphLine(button, SIZE_GLYPH, 2, 0, -half),
        Modern.GlyphLine(button, 2, SIZE_GLYPH, -half, 0), Modern.GlyphLine(button, 2, SIZE_GLYPH, half, 0) }
end

local function BarParts(button)
    return { Modern.GlyphLine(button, SIZE_GLYPH, 2, 0, 0) }
end

-- MaximizeMinimizeButtonFrameTemplate: the spellbook keeps it as MaximizeMinimizeButton, the map on BorderFrame.
function Modern.SizeButtons(skin, frame)
    local border = ns.Usable(frame.BorderFrame) and frame.BorderFrame or nil
    for _, sizing in ipairs({ frame.MaximizeMinimizeButton or false, frame.MaximizeMinimizeFrame or false,
        border and border.MaximizeMinimizeFrame or false }) do
        if sizing and ns.Usable(sizing) then
            Modern.GlyphButton(skin, sizing.MaximizeButton, "maximize", BoxParts, "text")
            Modern.GlyphButton(skin, sizing.MinimizeButton, "minimize", BarParts, "text")
            return
        end
    end
end

-- The title row of a top-level window becomes a header band a step above the panel, lit from the top, with an accent
-- hairline under it. Nested panels have no title row, so they never get one.
local HEADER = 24

local function Gradient(texture, orientation, from, to)
    return type(texture.SetGradient) == "function" and type(CreateColor) == "function"
        and pcall(texture.SetGradient, texture, orientation, CreateColor(unpack(from)), CreateColor(unpack(to)))
end

-- `color` at the bottom, `lift` lighter at the top; flat where gradients are missing.
function Modern.Lit(texture, color, lift)
    local lit = { color[1] + lift, color[2] + lift, color[3] + lift, color[4] }
    texture:SetColorTexture(1, 1, 1, 1)
    if not Gradient(texture, "VERTICAL", color, lit) then texture:SetColorTexture(unpack(color)) end
end

-- A header band's fill: theme `strip`, lit towards the top.
function Modern.Band(texture)
    Modern.Lit(texture, Modern.Theme().strip, 0.06)
end

-- A section header: a solid strip a step lighter than the panel, with a 2 px accent edge on the left. With `height`
-- the strip is that tall, centred on the header, for headers Blizzard makes much taller than their title.
function Modern.Strip(skin, header, height)
    if not ns.Usable(header) or type(header.CreateTexture) ~= "function" then return end
    local parts = skin:Own(header, "strip", function()
        local fill = header:CreateTexture(nil, "BACKGROUND", nil, -8)
        if height then
            fill:SetPoint("LEFT", header, "LEFT", 0, 0)
            fill:SetPoint("RIGHT", header, "RIGHT", 0, 0)
            fill:SetHeight(height)
        else
            fill:SetAllPoints(header)
        end
        local edge = header:CreateTexture(nil, "BORDER")
        edge:SetWidth(2)
        edge:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
        edge:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
        return { fill, edge }
    end)
    local theme = Modern.Theme()
    parts[1]:SetColorTexture(unpack(theme.strip))
    parts[2]:SetColorTexture(unpack(theme.accent))
    for _, part in ipairs(parts) do part:Show() end
end

function Modern.Header(skin, frame)
    if not ns.Usable(frame) or type(frame.CreateTexture) ~= "function" then return end
    local theme = Modern.Theme()
    local band, rule = unpack(skin:Own(frame, "window header", function()
        local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        fill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        fill:SetHeight(HEADER - 1)
        local line = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        line:SetPoint("TOPLEFT", fill, "BOTTOMLEFT", 0, 0)
        line:SetPoint("TOPRIGHT", fill, "BOTTOMRIGHT", 0, 0)
        line:SetHeight(1)
        return { fill, line }
    end))
    Modern.Band(band)
    -- The accent hairline under the title is the one gold mark every QuietUI window carries.
    rule:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0.6)
    band:Show()
    rule:Show()
end

-- DialogHeaderTemplate floats its title over the top edge; the title moves down into the header band.
local function DialogTitle(skin, frame)
    local header = ns.Usable(frame) and frame.Header
    local title = ns.Usable(header) and (header.Text or header.TitleText)
    if not ns.Usable(title) or type(title.ClearAllPoints) ~= "function" then return end
    -- The journal remembers Blizzard's points on the first call; the title is then anchored afresh.
    skin:Set(title, "SetPoint", "TOP", frame, "TOP", 0, -6)
    title:ClearAllPoints()
    title:SetPoint("TOP", frame, "TOP", 0, -6)
end

-- A dialog window (DialogBorderTemplate, DialogHeaderTemplate): the dark window with its title in the header band.
function Modern.Dialog(skin, frame)
    if not ns.Usable(frame) then return end
    Modern.Window(skin, frame)
    Modern.Header(skin, frame)
    DialogTitle(skin, frame)
end

-- A window: dark fill lit towards the top and a quiet outline, Blizzard chrome held, optionally a title drag
-- handle (above `over`). A `flat` window keeps its text on the panel: its insets get no sunken box.
function Modern.Window(skin, frame, key, over, flat)
    if not ns.Usable(frame) then return end
    local theme = Modern.Theme()
    local fill = skin:Panel(frame)
    if fill then Modern.Lit(fill, theme.bg, 0.03) end
    skin:Border(frame, theme.outline)
    Modern.WindowChrome(skin, frame)
    -- A window's own insets sink a step below the panel. Not the map's: its BorderFrame inset lies over the canvas.
    for _, inset in ipairs(flat and {} or { frame.Inset or false, frame.InsetRight or false }) do
        if inset and not IsTexture(inset) and ns.Usable(inset) and type(inset.CreateTexture) == "function" then
            skin:Panel(inset, theme.sunk)
        end
    end
    Modern.TabSystemChrome(skin, frame)
    Modern.Checkboxes(skin, frame)
    Modern.CloseButton(skin, frame)
    Modern.SizeButtons(skin, frame)
    if key then
        skin:Remember(frame, "modern movable", function() Modern.ReleaseMovable(frame) end)
        Modern.MakeMovable(frame, key, over)
    end
end
