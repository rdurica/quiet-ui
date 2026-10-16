-- Modern minimap: a square skin that leaves Blizzard's minimap-related controls usable and visible.
local h = ...
local L = h.lib("modern")
local F = h.lib("modern-map-tip")

h.test("Minimap applies a square mask, hides its art, and restores every original input", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = F.minimap(t.mock)
    local oldWheel = map:GetScript("OnMouseWheel")
    local oldMask = map:GetMaskTexture()
    local oldShape = function() return "ROUND" end
    GetMinimapShape = oldShape
    local before = L.snapshot({ map, p.ring, p.north, p.zoomIn, p.zoomOut })

    F.enable(ns)
    A.ne(map:GetMaskTexture(), oldMask, "square mask replaces Blizzard's round mask")
    A.eq(GetMinimapShape(), "SQUARE")
    A.alpha(p.ring, 0, "ring art is held hidden")
    A.alpha(p.north, 0, "decoration is held hidden")
    A.alpha(p.zoomIn, 0, "zoom in is faded")
    A.alpha(p.zoomOut, 0, "zoom out is faded")
    A.eq(p.zoomIn:IsMouseEnabled(), false, "zoom in cannot be clicked")
    A.eq(p.zoomOut:IsMouseEnabled(), false, "zoom out cannot be clicked")
    A.eq(map:IsMouseWheelEnabled(), true, "mouse wheel zoom is enabled")
    A.type(map:GetScript("OnMouseWheel"), "function", "wheel zoom handler")

    ns.Modern.Restore()
    A.eq(map:GetMaskTexture(), oldMask)
    A.eq(GetMinimapShape, oldShape, "another addon's shape function is restored")
    A.eq(map:GetScript("OnMouseWheel"), oldWheel, "previous wheel script is restored")
    A.eq(map:IsMouseWheelEnabled(), false, "previous wheel setting is restored")
    A.eq(p.zoomIn:IsMouseEnabled(), true)
    A.eq(p.zoomOut:IsMouseEnabled(), true)
    A.deep(L.diff(before), {}, "mask-area visuals are exact after restore")
end)

h.test("Minimap restores an absent GetMinimapShape and keeps minimap, queue, eye, mail and tracking visible", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = F.minimap(t.mock)
    GetMinimapShape = nil
    local protected = { map, p.queue, p.eye, p.mail, p.tracking }
    for _, frame in ipairs(protected) do
        local oldAlpha, oldHide = frame.SetAlpha, frame.Hide
        frame.SetAlpha = function(self, value) error((self:GetName() or "Minimap") .. " alpha changed to " .. tostring(value), 0) end
        frame.Hide = function(self) error((self:GetName() or "Minimap") .. " was hidden", 0) end
        frame._oldAlpha, frame._oldHide = oldAlpha, oldHide
    end
    F.enable(ns)
    A.eq(GetMinimapShape(), "SQUARE")
    for _, frame in ipairs(protected) do A.ok(frame:IsShown(), (frame:GetName() or "Minimap") .. " stays visible") end
    ns.Modern.Restore()
    A.eq(GetMinimapShape, nil, "nil global is restored exactly")
end)

h.test("QuietUI's minimap setup button moves onto the square edge and back onto the round edge", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map = F.minimap(t.mock)
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
    A.eq(restoredX, roundX, "round x restored")
    A.eq(restoredY, roundY, "round y restored")
end)

h.test("Minimap safely skips missing optional art and forbidden controls", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = F.minimap(t.mock)
    MinimapBorder = nil
    p.zoomIn._forbidden = true
    A.noThrow(function() F.enable(ns) end)
    A.eq(map:GetMaskTexture() ~= "Textures\\MinimapMask", true, "other minimap work still applies")
    ns.Modern.Restore()
end)

h.test("Minimap finds its parts by name and never scans its children", function(t)
    local A, ns = t.assert, t.ns
    F.area(ns, "minimap")
    local map, p = F.minimap(t.mock)
    map.GetChildren = function() error("the minimap children were scanned", 0) end
    A.noThrow(function() F.enable(ns) end)
    A.eq(#t.mock.printed, 0, "nothing reported")
    A.eq(p.ring:GetAlpha(), 0, "the named border art is still held")
    ns.Modern.Restore()
end)
