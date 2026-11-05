local _, ns = ...

-- Square minimap chrome.  Controls owned by Blizzard (tracking, mail, the queue button and the
-- landing page button) keep their place, click and visibility; only the header row's art is restyled
-- (MinimapHeader.lua). Retail 12.0 names are resolved first
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

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function Points(frame)
    local points = {}
    for i = 1, frame:GetNumPoints() do points[i] = Pack(frame:GetPoint(i)) end
    return points
end

local function Put(frame, points)
    frame:ClearAllPoints()
    for _, p in ipairs(points) do frame:SetPoint(unpack(p, 1, p.n)) end
end

-- Gap between the zone header and the top edge of the square map; the header band fills it.
local GAP = 1
-- Room left between the map's right edge and the cluster's; the round buttons sit inside the map instead.
local EDGE = 4
-- While docked: the cluster parts and Blizzard's latest container points; the SetPoint hook re-docks.
local dock
local docking
local hooked = setmetatable({}, { __mode = "k" })

local function Anchored(frame, cluster)
    if frame:GetNumPoints() ~= 1 then return nil end
    local point, relative, relativePoint, _, y = frame:GetPoint(1)
    if point ~= "TOP" or relative ~= cluster or relativePoint ~= "TOP" or type(y) ~= "number" then return nil end
    return y
end

-- 12.0 hangs the map container well below the zone header; the container (map, its buttons and the
-- coordinates) moves up so the map sits right under the header. A header Edit Mode put underneath
-- is not anchored to the cluster top, so the container stays where Blizzard put it.
-- Blizzard keeps room right of the map for its round buttons; the map moves right into it, never left.
local function Shift(d, x)
    local right, mapRight = d.cluster:GetRight(), d.map:GetRight()
    if type(right) ~= "number" or type(mapRight) ~= "number" or type(x) ~= "number" then return x end
    local clusterScale = d.cluster:GetEffectiveScale() or 1
    local delta = (right - EDGE) * clusterScale - mapRight * (d.map:GetEffectiveScale() or 1)
    if delta <= 0 then return x end
    return x + delta / (d.container:GetEffectiveScale() or 1)
end

local function Dock()
    local d = dock
    if not d or docking then return end
    local headerY, containerY = Anchored(d.header, d.cluster), Anchored(d.container, d.cluster)
    if not headerY or not containerY then return end
    local _, _, _, x = d.container:GetPoint(1)
    x = Shift(d, x)
    local scale = d.container:GetScale() or 1
    local mapHeight = d.map:GetHeight() * (d.map:GetScale() or 1)
    local inset = (d.container:GetHeight() - mapHeight) / 2
    local y = (headerY - d.header:GetHeight() - GAP) / scale + inset
    docking = true
    d.container:ClearAllPoints()
    d.container:SetPoint("TOP", d.cluster, "TOP", x, y)
    docking = false
end

local function Docked(skin, cluster, map)
    local container, header = cluster.MinimapContainer, cluster.ZoneTextButton
    if not ns.Usable(container) or not ns.Usable(header) or type(container.ClearAllPoints) ~= "function" then return false end
    if not Anchored(header, cluster) or not Anchored(container, cluster) then return false end
    dock = { cluster = cluster, container = container, header = header, map = map, points = Points(container) }
    skin:Remember(container, "dock", function()
        local d = dock
        dock = nil
        if d then Put(container, d.points) end
    end)
    if not hooked[container] then
        hooked[container] = true
        -- Blizzard re-anchors the container when Edit Mode applies a layout; that point becomes the one to restore.
        pcall(hooksecurefunc, container, "SetPoint", function()
            if not dock or docking or dock.container ~= container then return end
            dock.points = Points(container)
            ns.Profiler.Run("modern minimap", Dock)
        end)
    end
    Dock()
    return true
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
        -- 12.0 keeps the zone text in its own header; only an older minimap gets our strip.
        if ns.Usable(cluster) and Docked(skin, cluster, map) then
            Modern.MinimapHeader(skin, cluster, map)
        else
            Strip(skin, map)
        end
        Modern.MinimapButtons(skin, map, ns.Usable(cluster) and dock and cluster.MinimapContainer or nil)
        Wheel(skin, map)
        Shape(skin, map)
    end,
}
