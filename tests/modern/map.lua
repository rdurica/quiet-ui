-- Modern Map: dark chrome and the shared public movable-window contract.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")

h.test("Map skins WorldMapFrame dark, saves a title drag point and restores Blizzard state", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "map")
    local map = W.window("WorldMapFrame")
    WorldMapFrame = map
    local before = L.snapshot({ map, map.chrome, map.TitleContainer.TitleText })
    W.enable(ns)
    A.ok(W.isDark(map), "map gets a dark panel")
    A.alpha(map.chrome, 0, "Blizzard map chrome is held")
    A.ok(L.handle(map), "map title has a drag handle")
    L.drag(map, "CENTER", "CENTER", 141, -52)
    A.deep(QuietUICharDB.windowPoints.WorldMapFrame, { "CENTER", "CENTER", 141, -52 })
    map:Hide(); map:Show()
    A.deep(W.point(map), { "CENTER", "CENTER", 141, -52 }, "saved map point reapplies on show")
    QuietUICharDB.modernize.map = false
    ns.Modern.Apply()
    A.deep(W.point(map), { "TOPLEFT", "TOPLEFT", 31, -71 }, "area off returns Blizzard point")
    A.deep(QuietUICharDB.windowPoints.WorldMapFrame, { "CENTER", "CENTER", 141, -52 }, "saved point stays")
    QuietUICharDB.modernize.map = nil
    ns.Modern.Apply(); ns.Modern.Restore()
    A.deep(L.diff(before), {}, "map visuals restore exactly")
end)

h.test("Map skips a missing WorldMapFrame without blocking another registered area", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "map")
    WorldMapFrame = nil
    local neighbour = L.area(t, "zz_map_neighbour")
    W.enable(ns)
    A.eq(neighbour.apply, 1, "another area applies")
end)
