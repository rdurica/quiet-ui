local _, ns = ...

-- Square minimap chrome.  Controls owned by Blizzard (tracking, mail, the queue button and the
-- landing page button) deliberately stay out of this area. Retail 12.0 names are resolved first
-- (MinimapCluster.BorderTop, MinimapCompassTexture, Minimap.ZoomIn / ZoomOut / ZoomHitArea), the
-- older flat names are the fallback.
local Modern = ns.Modern

-- Named parts only: a named child is also a global, so no scan of the minimap's children is needed.
local function Part(name)
    local frame = _G[name]
    if ns.Usable(frame) then return frame end
end

local function Art(skin, frame)
    if ns.Usable(frame) then skin:Hold(frame) end
end

-- Blizzard shows the zoom buttons from the minimap's OnEnter; the held alpha keeps them invisible.
local function Zoom(skin, button)
    if not ns.Usable(button) or type(button.EnableMouse) ~= "function" then return end
    skin:Hold(button)
    local mouse = button.IsMouseEnabled and button:IsMouseEnabled()
    skin:Remember(button, "mouse", function() button:EnableMouse(mouse) end)
    button:EnableMouse(false)
end

-- The retail minimap zooms with the wheel by itself; only an older minimap gets our handler.
local function Wheel(skin, map)
    if type(map.EnableMouseWheel) ~= "function" or type(map.SetScript) ~= "function" then return end
    local enabled = map.IsMouseWheelEnabled and map:IsMouseWheelEnabled()
    local previous = map.GetScript and map:GetScript("OnMouseWheel")
    if enabled and previous then return end
    skin:Remember(map, "wheel", function()
        map:EnableMouseWheel(enabled)
        map:SetScript("OnMouseWheel", previous)
    end)
    map:EnableMouseWheel(true)
    map:SetScript("OnMouseWheel", function(_, delta)
        local zoom = map.GetZoom and map:GetZoom() or 0
        if delta > 0 and zoom < 5 and map.SetZoom then map:SetZoom(zoom + 1) end
        if delta < 0 and zoom > 0 and map.SetZoom then map:SetZoom(zoom - 1) end
    end)
end

local function Compass()
    local compass = _G.MinimapCompassTexture
    if compass == nil and ns.Usable(_G.MinimapBackdrop) then compass = _G.MinimapBackdrop.MinimapCompassTexture end
    return compass
end

local function Mask(skin, map)
    if not map.SetMaskTexture then return end
    local old = map.GetMaskTexture and map:GetMaskTexture() or "Textures\\MinimapMask"
    skin:Remember(map, "mask", function() map:SetMaskTexture(old) end)
    map:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
end

-- Flat strip above the minimap that carries the zone text.
local function Strip(skin, map)
    local strip = skin:Own(map, "zone strip", function()
        local frame = CreateFrame("Frame", nil, map)
        frame:SetHeight(16)
        frame:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 2)
        frame:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 0, 2)
        return frame
    end)
    if not ns.Usable(strip) then return end
    skin:Panel(strip)
    skin:Border(strip)
    strip:Show()
    local zone = _G.MinimapZoneText
    if ns.Usable(zone) and zone.SetPoint then skin:Set(zone, "SetPoint", "CENTER", strip, "CENTER", 0, 0) end
end

-- The global only exists while the area is applied; restore puts back whatever was there.
local function Shape(skin, map)
    local shape = GetMinimapShape
    skin:Remember(map, "shape", function()
        GetMinimapShape = shape
        if ns.Setup and ns.Setup.PlaceMinimap then ns.Setup.PlaceMinimap() end
    end)
    GetMinimapShape = function() return "SQUARE" end
    if ns.Setup and ns.Setup.PlaceMinimap then ns.Setup.PlaceMinimap() end
end

Modern.Register{
    key = "minimap",
    label = "Minimap",
    apply = function(skin)
        local map = Minimap
        if not ns.Usable(map) then return end
        Mask(skin, map)
        local cluster = _G.MinimapCluster
        Art(skin, ns.Usable(cluster) and cluster.BorderTop or nil)
        Art(skin, Compass())
        Art(skin, Part("MinimapBorder"))
        Art(skin, Part("MinimapNorthTag"))
        for _, key in ipairs({ "ZoomIn", "ZoomOut", "ZoomHitArea" }) do Zoom(skin, map[key]) end
        Zoom(skin, Part("MinimapZoomIn"))
        Zoom(skin, Part("MinimapZoomOut"))
        skin:Border(map)
        Strip(skin, map)
        Wheel(skin, map)
        Shape(skin, map)
    end,
}
