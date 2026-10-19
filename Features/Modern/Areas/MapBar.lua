local _, ns = ...

-- The world map's top bar and corner buttons, shaped after a frame dump of the Forever 12.0 client. The zone
-- breadcrumb (navBar) becomes a dark field whose buttons are bare text split by thin rules; their dropdown arrows
-- stay. The tracking filter and pin buttons become small dark squares that keep their icons, and the maximize /
-- minimize buttons take flat glyphs like the close button. Breadcrumb buttons are created as the player browses,
-- so the bar is scanned again for every new button.

local Modern = ns.Modern
local MapBar = {}
Modern.MapBar = MapBar

local GLYPH = 10

local function Hold(skin, texture)
    if ns.Usable(texture) then skin:Hold(texture) end
end

local function Is(obj, kind)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == kind
end

local function Children(frame)
    if not ns.Usable(frame) or type(frame.GetChildren) ~= "function" then return {} end
    return { frame:GetChildren() }
end

-- Maximize: an outlined square; minimize: one bar.
local function BoxParts(button)
    local half = GLYPH / 2 - 1
    return { Modern.GlyphLine(button, GLYPH, 2, 0, half), Modern.GlyphLine(button, GLYPH, 2, 0, -half),
        Modern.GlyphLine(button, 2, GLYPH, -half, 0), Modern.GlyphLine(button, 2, GLYPH, half, 0) }
end

local function BarParts(button)
    return { Modern.GlyphLine(button, GLYPH, 2, 0, 0) }
end

-- A thin rule at the right edge splits one breadcrumb from the next.
local function Rule(skin, button)
    local rule = skin:Own(button, "crumb rule", function()
        local texture = button:CreateTexture(nil, "OVERLAY")
        texture:SetWidth(1)
        texture:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, -7)
        texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 7)
        return texture
    end)
    if not rule then return end
    rule:SetColorTexture(unpack(Modern.Theme().border))
    rule:Show()
end

-- Home, overflow and zone buttons: all their art goes (the dropdown arrow is a child button and stays).
function MapBar.Breadcrumbs(skin, map)
    local bar = ns.Usable(map) and map.navBar
    if not ns.Usable(bar) then return end
    Modern.Character.HoldArt(skin, bar)
    Modern.Character.HoldArt(skin, bar.overlay)
    skin:Panel(bar)
    skin:Border(bar)
    for _, button in ipairs(Children(bar)) do
        if Is(button, "Button") then
            Modern.Character.HoldArt(skin, button)
            if button ~= bar.overflowButton then Rule(skin, button) end
        end
    end
end

-- The filter keeps its arrow icon; the pin keeps its icon and active ring but loses its round border,
-- background, corner shadow and round highlight.
local function Tracking(skin, map)
    local filter = map.WorldMapTrackingOptionsButton
    if ns.Usable(filter) then
        skin:Panel(filter)
        skin:Border(filter)
    end
    local pin = map.WorldMapTrackingPinButton
    if not ns.Usable(pin) or type(pin.GetRegions) ~= "function" then return end
    Hold(skin, pin.Border)
    for _, region in ipairs({ pin:GetRegions() }) do
        local ok, layer = pcall(region.GetDrawLayer, region)
        if ok and (layer == "BACKGROUND" or layer == "HIGHLIGHT") then Hold(skin, region) end
    end
    skin:Panel(pin)
    skin:Border(pin)
end

function MapBar.Apply(skin, map)
    if not ns.Usable(map) then return end
    MapBar.Breadcrumbs(skin, map)
    Tracking(skin, map)
    local border = map.BorderFrame
    local sizing = ns.Usable(border) and border.MaximizeMinimizeFrame
    if ns.Usable(sizing) then
        Modern.GlyphButton(skin, sizing.MaximizeButton, "maximize", BoxParts, "text")
        Modern.GlyphButton(skin, sizing.MinimizeButton, "minimize", BarParts, "text")
    end
end
