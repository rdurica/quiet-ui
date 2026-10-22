local _, ns = ...

-- The world map's top bar and corner buttons, shaped after a frame dump of the Forever 12.0 client. The zone
-- breadcrumb (navBar) becomes bare text on the window, split by quiet thin rules; their dropdown arrows stay. The
-- tracking filter and pin buttons become bare icons. Breadcrumb buttons are created as the player browses, so the bar
-- is scanned again for every new button.

local Modern = ns.Modern
local MapBar = {}
Modern.MapBar = MapBar

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
    rule:SetColorTexture(unpack(Modern.Theme().wellEdge))
    rule:Show()
end

-- Home, overflow and zone buttons: all their art goes (the dropdown arrow is a child button and stays).
function MapBar.Breadcrumbs(skin, map)
    local bar = ns.Usable(map) and map.navBar
    if not ns.Usable(bar) then return end
    Modern.Character.HoldArt(skin, bar)
    Modern.Character.HoldArt(skin, bar.overlay)
    for _, button in ipairs(Children(bar)) do
        if Is(button, "Button") then
            Modern.Character.HoldArt(skin, button)
            if button ~= bar.overflowButton then Rule(skin, button) end
        end
    end
end

-- The filter keeps its arrow icon as it is; the pin keeps its icon and active ring but loses its round border,
-- background, corner shadow and round highlight.
local function Tracking(skin, map)
    local pin = map.WorldMapTrackingPinButton
    if not ns.Usable(pin) or type(pin.GetRegions) ~= "function" then return end
    Hold(skin, pin.Border)
    for _, region in ipairs({ pin:GetRegions() }) do
        local ok, layer = pcall(region.GetDrawLayer, region)
        if ok and (layer == "BACKGROUND" or layer == "HIGHLIGHT") then Hold(skin, region) end
    end
end

function MapBar.Apply(skin, map)
    if not ns.Usable(map) then return end
    MapBar.Breadcrumbs(skin, map)
    Tracking(skin, map)
end
