-- Map on the 12.0 client: the chrome lives on WorldMapFrame.BorderFrame; the top bar, corner buttons and the quest
-- log inside the map are restyled; the canvas and quest text stay.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

local function hidden(list)
    local visible = {}
    for index, texture in ipairs(list) do
        if texture._alpha ~= 0 then visible[#visible + 1] = (tostring(texture._texture or index):gsub("^.*\\", "")) end
    end
    return table.concat(visible, ",")
end

local function light(font)
    local r, g, b = font:GetTextColor()
    return 0.3 * r + 0.59 * g + 0.11 * b > 0.5
end

h.test("Map holds the BorderFrame chrome and keeps the canvas, quest text and title", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "map")
    local map = R.worldMap()
    local border = map.BorderFrame
    local kept = L.snapshot({ map.ScrollContainer, map.ScrollContainer.canvas, map.BlackoutFrame,
        map.BlackoutFrame.Blackout, unpack(map.QuestMapFrame.content) })
    local before = L.snapshot(R.all(map))
    W.enable(ns, { windows = false })
    A.eq(R.visibleChrome(border, map), "",
        "BorderFrame NineSlice, Bg, streaks, portrait, Inset, InsetBorderTop and the title buttons' art are hidden")
    A.ok(R.dark(map), "the map gets a dark panel")
    A.alpha(border.TitleContainer.TitleText, 1, "the map title stays")
    A.deep(L.diff(kept), {}, "map canvas, blackout and quest titles stay")
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

h.test("Map flattens the breadcrumb, tracking buttons and title buttons and restores them", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "map")
    local map = R.worldMap()
    local bar, pin, sizing = map.navBar, map.WorldMapTrackingPinButton, map.BorderFrame.MaximizeMinimizeFrame
    local before = L.snapshot(R.all(map))
    W.enable(ns, { windows = false })
    A.alpha(map.BorderFrame.CloseButton.normal, 0, "the close button on BorderFrame gets the flat cross")
    A.alpha(sizing.MaximizeButton.normal, 0, "maximize art is held")
    A.alpha(sizing.MinimizeButton.normal, 0, "minimize art is held")
    A.eq(hidden(bar.crumbArt), "", "navBar and breadcrumb art is held")
    A.ok(R.dark(bar), "the breadcrumb is a dark field")
    A.alpha(bar.homeButton.text, 1, "breadcrumb text stays")
    A.alpha(bar.homeButton.MenuArrowButton.art, 0.9, "the breadcrumb dropdown arrow stays")
    NavBar_AddButton(bar, { name = "Teldrassil" })
    A.eq(hidden(bar.crumbArt), "", "a breadcrumb added while browsing is flattened too")
    A.eq(hidden(pin.trackingArt), "", "the pin button loses its round border, background, shadow and highlight")
    A.alpha(pin.Icon, 0.9, "the pin icon stays")
    A.ok(R.dark(pin), "the pin button is a dark square")
    A.ok(R.dark(map.WorldMapTrackingOptionsButton), "the filter button is a dark square")
    A.alpha(map.WorldMapTrackingOptionsButton.Icon, 0.9, "the filter icon stays")
    QuietUICharDB.modernize.map = false
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "area off restores the bar and buttons")
    NavBar_AddButton(bar, { name = "Darnassus" })
    A.alpha(R.all(bar)[#R.all(bar)], 0.9, "a breadcrumb added while the area is off keeps Blizzard art")
end)

h.test("Map restyles the quest log and details, lightens their ink, follows pooled parts and restores it", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "map")
    local map = R.worldMap()
    local quest = map.QuestMapFrame
    local scroll = quest.QuestsFrame.ScrollFrame
    local before = L.snapshot(R.all(quest))
    local questPoint = W.point(quest)
    W.enable(ns, { windows = false })
    A.eq(hidden(quest.art), "", "parchment, gold frames, field, header, scroll bar and details art are held")
    A.ok(R.dark(scroll.SearchBox), "the search box is a dark field")
    A.ok(R.dark(QuestLogCount), "the quest count is a dark field")
    A.ok(R.dark(quest.QuestsFrame.DetailsFrame.AbandonButton), "detail buttons are flat fields")
    A.ok(light(quest.description), "quest detail ink becomes light")
    local r, g, b = quest.heading:GetTextColor()
    A.ok(light(quest.heading) and r > b + 0.3, "the quest title heading keeps gold ink")
    local title = quest.content[2]
    A.deep({ title:GetTextColor() }, { 1, 0.82, 0, 1 }, "gold quest titles stay")
    local strip = ns.Modern.Theme().strip
    local function striped(header)
        for _, region in ipairs(header._regions) do
            if region._color and region._color[1] == strip[1] and region._shown ~= false then return true end
        end
        return false
    end
    local contents = scroll.Contents
    A.ok(striped(contents._children[1]), "a zone header is a solid strip")
    local edge = ns.Modern.Theme().border
    for _, region in ipairs(scroll._regions) do
        A.falsy(region._color and region._color[1] == edge[1], "no border around the quest list")
    end
    QuestLogQuests_Update()
    A.eq(hidden(quest.art), "", "a header Blizzard adds to the list is flattened")
    A.ok(striped(contents._children[#contents._children]), "the added header is a strip too")
    QuestMapFrame_ShowQuestDetails()
    local regions = quest.QuestsFrame.DetailsFrame.ScrollFrame.Contents._regions
    A.ok(light(regions[#regions]), "text shown with new quest details is lightened")
    A.eq(L.handle(quest), nil, "the embedded quest log has no drag handle")
    A.deep(W.point(quest), questPoint, "the quest log keeps its place")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Restore returns the quest log art, ink and fonts")
end)
