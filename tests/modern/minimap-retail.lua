-- Modern minimap against the retail 12.0 frame shapes: MinimapCluster.BorderTop, MinimapCompassTexture,
-- Minimap.ZoomIn / ZoomOut (parentKeys that Blizzard shows from OnEnter), MinimapZoneText in the
-- cluster's ZoneTextButton header, MinimapContainer and AddonCompartmentFrame. The classic-named fallback stays covered by minimap.lua.
local h = ...
local L = h.lib("modern")
local F = h.lib("modern-map-tip")
local R = h.lib("modern-retail")

-- The shown flat plate a button draws behind its icon, if any.
local function plate(button)
    for _, region in ipairs(button._regions) do
        if region._layer == "BACKGROUND" and region._w == 22 and region._h == 22 and region._shown then return region end
    end
end

local function snapshot(map, p)
    local list = { map, p.border, p.compass, p.zoomIn, p.zoomOut, p.zone, p.zoneButton, p.backdrop, p.container,
        p.compartment, p.dial }
    for _, piece in ipairs(p.borderPieces) do list[#list + 1] = piece end
    return L.snapshot(list)
end

h.test("12.0 minimap holds BorderTop and the compass ring hidden and switches to a square shape", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    F.enable(ns)
    A.alpha(p.compass, 0, "MinimapCompassTexture is held hidden")
    A.ok(R.heldHidden(p.border), "MinimapCluster.BorderTop art is held hidden")
    A.eq(GetMinimapShape(), "SQUARE")
    A.ne(map._mask, "Textures\\MinimapMask", "square mask replaces the round mask")
    A.eq(L.errors(t.mock), 0, "no Report for the retail shapes")
end)

h.test("12.0 minimap fades Minimap.ZoomIn / ZoomOut and keeps them unclickable when Blizzard shows them", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local _, p = R.minimap()
    F.enable(ns)
    A.alpha(p.zoomIn, 0, "Minimap.ZoomIn is faded")
    A.alpha(p.zoomOut, 0, "Minimap.ZoomOut is faded")
    A.eq(p.zoomIn:IsMouseEnabled(), false, "Minimap.ZoomIn cannot be clicked")
    A.eq(p.zoomOut:IsMouseEnabled(), false, "Minimap.ZoomOut cannot be clicked")
    p.zoomIn:Show(); p.zoomOut:Show() -- MinimapMixin:OnEnter
    A.alpha(p.zoomIn, 0, "shown by Blizzard, ZoomIn stays invisible")
    A.alpha(p.zoomOut, 0, "shown by Blizzard, ZoomOut stays invisible")
    A.eq(p.zoomIn:IsMouseEnabled(), false, "shown by Blizzard, ZoomIn stays unclickable")
    ns.Modern.Restore()
    A.eq(p.zoomIn:IsMouseEnabled(), true, "restore makes ZoomIn clickable again")
    A.alpha(p.zoomIn, 0.8, "restore returns ZoomIn's alpha")
end)

h.test("12.0 minimap keeps the mouse wheel zoom working", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map = R.minimap()
    F.enable(ns)
    A.eq(map:IsMouseWheelEnabled(), true, "mouse wheel stays enabled")
    local wheel = map:GetScript("OnMouseWheel")
    A.type(wheel, "function", "wheel handler")
    wheel(map, 1)
    A.eq(map:GetZoom(), 1, "wheel up zooms in")
    wheel(map, -1)
    A.eq(map:GetZoom(), 0, "wheel down zooms out")
end)

h.test("12.0 minimap moves the map up right under the zone header and keeps the zone text in the header", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    F.enable(ns)
    A.eq(p.container:GetNumPoints(), 1, "the container has one anchor")
    local point, relative, relativePoint, x, y = p.container:GetPoint(1)
    A.eq(point, "TOP"); A.eq(relative, p.cluster); A.eq(relativePoint, "TOP")
    A.eq(x, 11.1, "the map keeps its horizontal place")
    -- header bottom -23, 1 px gap, map inset (253 - 198) / 2 inside the container: map top at -24
    A.ok(math.abs(y - 3.5) < 0.001, "map top sits 1 px under the header, got container y " .. tostring(y))
    local _, mapRelative = map:GetPoint(1)
    A.eq(mapRelative, p.container, "the map itself stays in its container")
    local _, zoneRelative = p.zone:GetPoint(p.zone:GetNumPoints())
    A.eq(zoneRelative and zoneRelative._parent, p.cluster, "zone text stays in the header band on the cluster")
    A.alpha(p.zone, 1, "zone text stays visible")
    for _, child in ipairs(map._children) do
        local _, anchor, anchorPoint = child:GetPoint(1)
        A.ok(not (anchor == map and anchorPoint == "TOPLEFT" and child:GetHeight() == 16), "no empty zone strip above the map")
    end
end)

h.test("12.0 minimap keeps the map docked when Blizzard re-anchors the container and restores Blizzard's latest point", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local _, p = R.minimap()
    F.enable(ns)
    p.container:ClearAllPoints()
    p.container:SetPoint("TOP", p.cluster, "TOP", 11.1, -40) -- Edit Mode applies a layout
    local _, _, _, _, y = p.container:GetPoint(1)
    A.ok(math.abs(y - 3.5) < 0.001, "docked again after Blizzard's SetPoint")
    ns.Modern.Restore()
    local _, _, _, _, back = p.container:GetPoint(1)
    A.eq(back, -40, "restore returns Blizzard's latest point")
    p.container:ClearAllPoints()
    p.container:SetPoint("TOP", p.cluster, "TOP", 11.1, -33.3)
    _, _, _, _, back = p.container:GetPoint(1)
    A.eq(back, -33.3, "once restored, Blizzard's points are left alone")
end)

h.test("12.0 minimap leaves the container alone when the header sits underneath the map", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local _, p = R.minimap()
    p.zoneButton:ClearAllPoints()
    p.zoneButton:SetPoint("TOP", p.container, "BOTTOM", 0, 0)
    F.enable(ns)
    local _, _, _, _, y = p.container:GetPoint(1)
    A.eq(y, -33.3, "container keeps Blizzard's point")
end)

h.test("12.0 minimap moves the addon compartment and the clock under the map and back", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    TimeManagerClockButton = CreateFrame("Button", "TimeManagerClockButton", p.cluster)
    TimeManagerClockButton:SetPoint("RIGHT", p.zoneButton, "RIGHT", -3, -1)
    F.enable(ns)
    local point, relative, relativePoint = p.compartment:GetPoint(1)
    A.eq(p.compartment:GetNumPoints(), 1)
    A.eq(point, "LEFT"); A.eq(relative, map, "at the map"); A.eq(relativePoint, "BOTTOMLEFT", "left corner under it")
    A.ok(p.compartment:IsShown(), "the compartment stays visible")
    point, relative, relativePoint = TimeManagerClockButton:GetPoint(1)
    A.eq(point, "RIGHT"); A.eq(relative, map); A.eq(relativePoint, "BOTTOMRIGHT", "the clock sits under the right corner")
    ns.Modern.Restore()
    local _, back = p.compartment:GetPoint(1)
    A.eq(back, p.calendar, "back under the calendar")
    _, back = TimeManagerClockButton:GetPoint(1)
    A.eq(back, p.zoneButton, "the clock is back in the header")
end)

h.test("12.0 minimap turns the day dial into a flat plate in the map's top-right corner and back", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local _, p = R.minimap()
    F.enable(ns)
    local point, relative, _, x, y = p.dial:GetPoint(1)
    A.eq(point, "CENTER"); A.eq(relative, p.container)
    A.eq(x, 85, "14 px inside the right edge")
    A.eq(y, 85, "14 px inside the top edge")
    A.alpha(p.dialRing, 0, "the gold ring is held")
    A.alpha(p.dial.Background, 1, "the sky with the sun stays")
    A.eq(p.dial.Background:GetWidth(), 16, "the sky shrinks to an icon")
    A.eq(p.dial:GetWidth(), 22, "the dial shrinks to its plate")
    A.ok(plate(p.dial), "a flat plate sits behind the dial")
    ns.Modern.Restore()
    _, _, _, x, y = p.dial:GetPoint(1)
    A.eq(x, 49.5, "restored")
    A.eq(y, 77.4, "restored")
    A.alpha(p.dialRing, 1, "the ring is back")
    A.eq(p.dial.Background:GetWidth(), 33, "the sky is back to its size")
    A.eq(p.dial:GetWidth(), 42, "the dial is back to its size")
    A.ok(not plate(p.dial), "the plate is hidden")
end)

h.test("12.0 minimap moves the map right into the room Blizzard keeps for round buttons", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    p.cluster.GetRight = function() return 300 end
    map.GetRight = function() return 280 end
    F.enable(ns)
    local _, _, _, x = p.container:GetPoint(1)
    A.ok(math.abs(x - 27.1) < 0.001, "the map's right edge sits 4 px inside the cluster's, got x " .. tostring(x))
    ns.Modern.Restore()
    _, _, _, x = p.container:GetPoint(1)
    A.eq(x, 11.1, "Blizzard's place is restored")
end)

-- LibDBIcon-1.0 as other addons embed it: objects by name, a shared radius and a created callback.
local function libDBIcon()
    local lib = { objects = {}, radius = 5, callbacks = {} }
    function lib:SetButtonRadius(radius) self.radius = radius end
    function lib.RegisterCallback(_, event, fn) lib.callbacks[event] = fn end
    function lib.button(name)
        local button = CreateFrame("Button", "LibDBIcon10_" .. name, Minimap)
        button:SetSize(31, 31)
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.border = button:CreateTexture(nil, "OVERLAY")
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(18, 18)
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
        for _, region in ipairs({ button.background, button.border }) do region:SetAlpha(1) end
        lib.objects[name] = button
        return button
    end
    LibStub = { GetLibrary = function(_, major) if major == "LibDBIcon-1.0" then return lib end end }
    return lib
end

h.test("12.0 minimap flattens LibDBIcon buttons, pulls them inside the map and restores both", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    R.minimap()
    local lib = libDBIcon()
    local hammer = lib.button("GnomeLevelUp")
    F.enable(ns)
    A.eq(lib.radius, -14, "buttons sit 14 px inside the map's edge")
    A.alpha(hammer.border, 0, "the gold ring is held")
    A.alpha(hammer.background, 0, "the round background is held")
    A.ok(plate(hammer), "a flat plate sits behind the icon")
    local point, relative = hammer.icon:GetPoint(1)
    A.eq(point, "CENTER"); A.eq(relative, hammer, "the icon is centred on the plate")
    local later = lib.button("Later")
    lib.callbacks.LibDBIcon_IconCreated("LibDBIcon_IconCreated", later, "Later")
    A.ok(plate(later), "a button created later is flattened too")
    ns.Modern.Restore()
    A.eq(lib.radius, 5, "the shared radius is back")
    A.alpha(hammer.border, 1, "the ring is back")
    A.ok(not plate(hammer), "the plate is hidden")
    point = hammer.icon:GetPoint(1)
    A.eq(point, "TOPLEFT", "the icon is back in its place")
    local after = lib.button("After")
    lib.callbacks.LibDBIcon_IconCreated("LibDBIcon_IconCreated", after, "After")
    A.ok(not plate(after), "after restore new buttons stay Blizzard round")
    LibStub = nil
end)

h.test("12.0 minimap never hides or fades the minimap, queue button, mail, tracking or the landing page button", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    local protected = { map, p.queue, p.mail, p.tracking, p.landing, p.backdrop, p.zoneButton, p.cluster }
    for _, frame in ipairs(protected) do
        frame.SetAlpha = function(self, value) error((self:GetName() or "frame") .. " alpha changed to " .. tostring(value), 0) end
        frame.Hide = function(self) error((self:GetName() or "frame") .. " was hidden", 0) end
    end
    F.enable(ns)
    A.eq(L.errors(t.mock), 0, "the area did not touch a protected control")
    for _, frame in ipairs(protected) do A.ok(frame:IsShown(), (frame:GetName() or "frame") .. " stays visible") end
    ns.Modern.Restore()
    A.eq(L.errors(t.mock), 0, "restore did not touch a protected control")
end)

h.test("12.0 minimap restore returns mask, shape, wheel, art and zoom buttons exactly", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    local oldShape = function() return "ROUND" end
    GetMinimapShape = oldShape
    local before = snapshot(map, p)
    F.enable(ns)
    ns.Modern.Restore()

    A.eq(GetMinimapShape, oldShape, "another addon's shape function is back")
    A.eq(map:GetScript("OnMouseWheel"), p.nativeWheel, "Blizzard's wheel handler is back")
    A.eq(map:IsMouseWheelEnabled(), true)
    A.eq(p.zoomIn:IsMouseEnabled(), true, "zoom in is clickable again")
    A.eq(p.zoomOut:IsMouseEnabled(), true, "zoom out is clickable again")
    A.ne(map._mask, "Interface\\Buttons\\WHITE8X8", "the square mask is gone")
    A.type(map._mask, "string", "a mask is set again")
    local diff = L.diff(before); A.deep(diff, {}, table.concat(diff, ",") .. " every touched alpha, mouse, point and shown flag is as before")
end)

h.test("12.0 minimap restores an absent GetMinimapShape", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    R.minimap()
    GetMinimapShape = nil
    F.enable(ns)
    A.eq(GetMinimapShape(), "SQUARE")
    ns.Modern.Restore()
    A.eq(GetMinimapShape, nil, "nil global is restored exactly")
end)

h.test("12.0 minimap skips a forbidden zoom button and a missing compass and still skins the rest", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    p.zoomIn._forbidden = true
    MinimapCompassTexture = nil
    A.noThrow(function() F.enable(ns) end)
    A.ok(R.heldHidden(p.border), "BorderTop is still held")
    A.alpha(p.zoomOut, 0, "the usable zoom button is still faded")
    A.eq(GetMinimapShape(), "SQUARE")
    ns.Modern.Restore()
end)

h.test("12.0 minimap moves QuietUI's minimap button inside the square edge as a flat plate and back", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map = R.minimap()
    map:SetSize(140, 140)
    QuietUIDB.minimap = 225
    ns.Setup.EnsureMinimap()
    local button = map._children[#map._children]
    local _, _, _, roundX, roundY = F.point(button)
    F.enable(ns)
    local _, _, _, squareX, squareY = F.point(button)
    A.ok(math.abs(math.abs(squareX) - 56) < 0.001 and math.abs(math.abs(squareY) - 56) < 0.001,
        "button sits 14 px inside the square edge")
    A.alpha(button.border, 0, "its gold ring is held")
    A.ok(plate(button), "a flat plate sits behind the gear")
    ns.Modern.Restore()
    local _, _, _, restoredX, restoredY = F.point(button)
    A.eq(restoredX, roundX)
    A.eq(restoredY, roundY)
end)

h.test("12.0 minimap header becomes a band as wide as the map with the magnifier, centred zone and a calendar page", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    local function art(owner, key)
        owner[key] = owner:CreateTexture(nil, "BACKGROUND")
        owner[key]:SetAlpha(1)
        return owner[key]
    end
    local zoneArt = art(p.zoneButton, "StateTexture")
    local trackingBg = art(p.tracking, "Background")
    local lens = art(p.tracking.Button, "StateTexture")
    local calendar = art(p.calendar, "StateTexture")
    local count = art(p.compartment, "StateTexture")
    local before = L.snapshot({ zoneArt, trackingBg, lens, calendar, count, p.zone, p.tracking, p.calendar })
    F.enable(ns)
    for _, texture in ipairs({ zoneArt, trackingBg, lens, calendar, count }) do
        A.alpha(texture, 0, "Blizzard's boxed header art is held")
    end
    local band
    for _, region in ipairs(p.cluster._regions) do
        if region._layer == "BACKGROUND" and region._shown and region._color then band = region end
    end
    A.ok(band, "the cluster draws one header band")
    A.eq(band._points[1][2], map, "it starts at the map's left edge")
    A.eq(band._points[2][2], map, "and ends at its right edge")
    local _, trackAt = p.tracking:GetPoint(1)
    local _, calendarAt = p.calendar:GetPoint(1)
    A.eq(trackAt, band, "the magnifier sits at the band's left end")
    A.eq(calendarAt, band, "the calendar at its right end")
    local day
    for _, child in ipairs(p.calendar._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" and region._shown then day = region._text end
        end
    end
    A.eq(day, tostring(tonumber(os.date("%d"))), "the calendar page shows today's day")
    for i = 1, p.zone:GetNumPoints() do
        local _, relative = p.zone:GetPoint(i)
        A.eq(relative, band, "the zone text spans the band")
    end
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Restore returns the header art and points")
    A.ok(not band._shown, "the band is hidden")
end)

h.test("12.0 minimap flattens QuietUI's minimap button created after the area was applied", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map = R.minimap()
    F.enable(ns)
    ns.Setup.EnsureMinimap()
    local button = map._children[#map._children]
    A.alpha(button.border, 0, "its gold ring is held")
    A.ok(plate(button), "a flat plate sits behind the gear")
    ns.Modern.Restore()
    A.ok(not plate(button), "the plate is hidden on restore")
end)
