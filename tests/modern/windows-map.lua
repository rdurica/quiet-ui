-- Map on the 12.0 client: the chrome lives on WorldMapFrame.BorderFrame; canvas and quest log stay.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

h.test("Map holds the BorderFrame chrome and keeps the canvas, quest log and title", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "map")
    local map = R.worldMap()
    local border = map.BorderFrame
    local kept = L.snapshot({ map.ScrollContainer, map.ScrollContainer.canvas, map.BlackoutFrame,
        map.BlackoutFrame.Blackout, unpack(R.all(map.QuestMapFrame)) })
    local before = L.snapshot(R.all(map))
    W.enable(ns, { windows = false })
    A.eq(R.visibleChrome(border, map), "", "BorderFrame NineSlice, Bg, streaks, portrait, Inset and InsetBorderTop are hidden")
    A.ok(R.dark(map), "the map gets a dark panel")
    A.alpha(border.TitleContainer.TitleText, 1, "the map title stays")
    A.deep(L.diff(kept), {}, "map canvas, blackout and quest log content stay")
    border.Bg:SetAlpha(1); border.Inset.NineSlice.Center:SetAlpha(1); border.PortraitContainer.portrait:SetAlpha(1)
    A.eq(R.visibleChrome(border, map), "", "chrome stays hidden against Blizzard's SetAlpha")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Restore returns every map texture")
end)

h.test("Map area off restores the BorderFrame chrome and the Blizzard point; title drag saves windowPoints", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "map")
    local map = R.worldMap()
    local before = L.snapshot(R.all(map))
    W.enable(ns, { windows = false })
    A.ok(L.handle(map), "title drag handle")
    L.drag(map, "CENTER", "CENTER", 141, -52)
    A.deep(QuietUICharDB.windowPoints.WorldMapFrame, { "CENTER", "CENTER", 141, -52 })
    map:Hide(); map:Show()
    A.deep(W.point(map), { "CENTER", "CENTER", 141, -52 }, "saved point reapplies on show")
    QuietUICharDB.modernize.map = false
    ns.Modern.Apply()
    A.deep(W.point(map), { "TOPLEFT", "TOPLEFT", 31, -71 }, "Blizzard point returns")
    A.deep(QuietUICharDB.windowPoints.WorldMapFrame, { "CENTER", "CENTER", 141, -52 }, "saved point stays")
    A.eq(table.concat(L.diff(before), ","), "", "all map chrome is Blizzards again")
end)
