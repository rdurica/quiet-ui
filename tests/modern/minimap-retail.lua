-- Modern minimap against the retail 12.0 frame shapes: MinimapCluster.BorderTop, MinimapCompassTexture,
-- Minimap.ZoomIn / ZoomOut (parentKeys that Blizzard shows from OnEnter), MinimapZoneText in the
-- cluster's ZoneTextButton. The classic-named fallback stays covered by minimap.lua.
local h = ...
local L = h.lib("modern")
local F = h.lib("modern-map-tip")
local R = h.lib("modern-retail")

local function snapshot(map, p)
    local list = { map, p.border, p.compass, p.zoomIn, p.zoomOut, p.zone, p.zoneButton, p.backdrop }
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

h.test("12.0 minimap puts the zone text into the flat strip and keeps it visible", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = R.minimap()
    F.enable(ns)
    local _, relative = p.zone:GetPoint(p.zone:GetNumPoints()) -- the latest anchor wins
    A.ok(relative and relative ~= p.zoneButton and relative ~= p.border, "zone text leaves Blizzard's anchors")
    A.ok(F.borderColor(relative), "the strip has a themed border")
    A.ok(R.hasColor(relative, ns.Modern.Theme().bg), "the strip has the theme background")
    A.alpha(p.zone, 1, "zone text stays visible")
    A.alpha(p.zoneButton, 1, "the zone button is not faded")
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

h.test("12.0 minimap moves QuietUI's minimap button onto the square edge and back", function(t)
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
    A.ok(math.abs(squareX) >= 70 and math.abs(squareY) >= 70, "button reaches the square edge")
    ns.Modern.Restore()
    local _, _, _, restoredX, restoredY = F.point(button)
    A.eq(restoredX, roundX)
    A.eq(restoredY, roundY)
end)
