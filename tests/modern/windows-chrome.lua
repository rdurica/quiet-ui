-- Windows on the 12.0 client: nested PortraitFrameTemplate chrome, panel tabs, load-on-demand spellbook and
-- talents, the quest log inside the map, and content art that stays.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

local function character()
    local frame = R.window("CharacterFrame")
    CharacterFrame = frame
    R.content(frame, "ModelScene", 0.71)
    local tabs = {}
    for index = 1, 3 do tabs[index] = R.tab(frame, "CharacterFrameTab" .. index) end
    return frame, tabs
end

local function everything(frame, tabs)
    local list = R.all(frame)
    for _, tab in ipairs(tabs or {}) do list[#list + 1] = tab end
    return list
end

h.test("Windows holds all 12.0 window chrome, nested Inset and portrait included, and keeps title and content", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local frame = character()
    local content = L.snapshot(R.all(frame.ModelScene))
    local before = L.snapshot(R.all(frame))
    W.enable(ns)
    A.eq(R.visibleChrome(frame), "", "NineSlice, Bg, TopTileStreaks, portrait and Inset chrome are all hidden")
    A.ok(R.dark(frame), "dark panel replaces the chrome")
    A.alpha(frame.TitleContainer.TitleText, 1, "the title text stays visible")
    A.alpha(frame.CloseButton, 1, "the close button stays")
    A.deep(L.diff(content), {}, "character model scene art is untouched")
    -- Blizzard repaints chrome (templates reapply alpha on update): it must stay hidden.
    frame.Bg:SetAlpha(1); frame.Inset.Bg:SetAlpha(1); frame.PortraitContainer.portrait:SetAlpha(1)
    frame.Inset.NineSlice.TopEdge:SetAlpha(1)
    A.eq(R.visibleChrome(frame), "", "chrome stays hidden against Blizzard's SetAlpha")
    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "area off restores every chrome texture exactly")
    W.enable(ns)
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Restore restores every chrome texture exactly")
end)

h.test("Windows holds the gold panel tab art, keeps the tab text and restores it", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local frame, tabs = character()
    local before = L.snapshot(everything(frame, tabs))
    W.enable(ns)
    for index, tab in ipairs(tabs) do
        A.eq(R.visibleChrome(tab, tab), "", "tab " .. index .. " art (Left/Middle/Right and Active) is hidden")
        A.ok(R.dark(tab), "tab " .. index .. " has the dark fill")
        A.alpha(tab.Text, 1, "tab " .. index .. " text stays")
    end
    -- Selecting a tab makes Blizzard switch Active and normal art.
    tabs[1].LeftActive:SetAlpha(1); tabs[1].Left:SetAlpha(1)
    A.eq(R.visibleChrome(tabs[1], tabs[1]), "", "tab art stays hidden when Blizzard swaps the active art")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "tab art restores")
end)

h.test("Windows skins PlayerSpellsFrame after Blizzard_PlayerSpells loads, makes it movable and keeps its content", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    W.enable(ns)
    A.eq(PlayerSpellsFrame, nil, "load-on-demand frame does not exist yet")
    local frame = R.window("PlayerSpellsFrame")
    PlayerSpellsFrame = frame
    for _, key in ipairs({ "SpecFrame", "TalentsFrame", "SpellBookFrame" }) do R.content(frame, key, 0.74) end
    local content = {}
    for _, key in ipairs({ "SpecFrame", "TalentsFrame", "SpellBookFrame" }) do
        for _, object in ipairs(R.all(frame[key])) do content[#content + 1] = object end
    end
    local contentBefore = L.snapshot(content)
    local before = L.snapshot(R.all(frame))
    ns.Modern.AddonLoaded("Blizzard_PlayerSpells")
    A.ok(R.dark(frame), "spellbook and talents window is skinned")
    A.eq(R.visibleChrome(frame), "", "its 12.0 chrome is hidden")
    A.deep(L.diff(contentBefore), {}, "spellbook page, talent tree and spec art are untouched")
    A.ok(L.handle(frame), "it has a title drag handle")
    L.drag(frame, "CENTER", "CENTER", 12, -34)
    A.deep(QuietUICharDB.windowPoints.PlayerSpellsFrame, { "CENTER", "CENTER", 12, -34 })
    A.eq(#mock.printed, 0, "absent ClassTalentFrame / PlayerTalentFrame are skipped silently")
    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(W.point(frame), { "TOPLEFT", "TOPLEFT", 31, -71 }, "area off returns the Blizzard point")
    A.deep(L.diff(before), {}, "area off restores the window")
end)

h.test("Windows never makes or panels QuestMapFrame inside WorldMapFrame", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows"); W.area(ns, "map")
    local map = R.worldMap()
    local quest = map.QuestMapFrame
    local questBefore = L.snapshot(R.all(quest))
    W.enable(ns, { windows = true, map = true })
    A.eq(quest:GetParent(), map, "the quest log sits inside the map")
    A.ok(R.dark(map), "the map around the quest log has the dark panel")
    A.eq(L.handle(quest), nil, "no drag handle on the embedded quest log")
    A.falsy(R.dark(quest), "no panel on the embedded quest log")
    A.deep(L.diff(questBefore), {}, "its art and points are untouched")
    A.ok(L.handle(map), "the map itself is movable")
    L.drag(map, "CENTER", "CENTER", 1, 1)
    A.eq(QuietUICharDB.windowPoints.QuestMapFrame, nil, "no saved point for the embedded quest log")
    A.deep(QuietUICharDB.windowPoints.WorldMapFrame, { "CENTER", "CENTER", 1, 1 }, "the map saves its own point")
end)

h.test("Windows skins and moves a standalone QuestLogFrame when the client has one", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local quest = R.window("QuestLogFrame")
    QuestLogFrame = quest
    local before = L.snapshot(R.all(quest))
    W.enable(ns)
    A.ok(R.dark(quest), "quest log window is a dark panel")
    A.eq(R.visibleChrome(quest), "", "its chrome is hidden")
    A.ok(L.handle(quest), "it is movable")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "restore returns Blizzard's look")
end)

h.test("Reset positions returns character, spellbook and map windows to Blizzard's points", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows"); W.area(ns, "map")
    local frame = character()
    PlayerSpellsFrame = R.window("PlayerSpellsFrame")
    local map = R.worldMap()
    W.enable(ns, { windows = true, map = true })
    for _, window in ipairs({ frame, PlayerSpellsFrame, map }) do L.drag(window, "CENTER", "CENTER", 5, 6) end
    ns.Modern.ResetPositions()
    A.eq(QuietUICharDB.windowPoints, nil, "saved points are cleared")
    for _, window in ipairs({ frame, PlayerSpellsFrame, map }) do
        A.deep(W.point(window), { "TOPLEFT", "TOPLEFT", 31, -71 }, (window:GetName() or "window") .. " is back")
    end
    A.eq(R.visibleChrome(frame), "", "the skin stays applied")
end)

h.test("Windows turns the close button into a dark square with a thin cross, red under the mouse, and restores it", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local frame = character()
    local close = frame.CloseButton
    close:SetSize(24, 24)
    close.normal = close:CreateTexture(nil, "ARTWORK")
    close.normal:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close.normal:SetAlpha(1)
    close.GetNormalTexture = function() return close.normal end
    local before = L.snapshot({ close.normal })
    local theme = ns.Modern.Theme()
    W.enable(ns)
    A.alpha(close.normal, 0, "Blizzard's red and gold art is held")
    A.alpha(close, 1, "the button itself stays, with its place and click")
    local own = {}
    for _, region in ipairs({ close:GetRegions() }) do
        if region ~= close.normal and region:IsShown() and region._color then own[#own + 1] = region end
    end
    A.ok(#own >= 6, "a box, its border and two cross lines are drawn")
    local function crossColor()
        for _, region in ipairs(own) do
            if region._layer == "OVERLAY" and region:GetWidth() == 10 then return region._color end
        end
    end
    A.deep(crossColor(), theme.glyph, "the cross is grey")
    close.normal:SetAlpha(1)
    A.alpha(close.normal, 0, "the art stays held when Blizzard repaints it")
    close:GetScript("OnEnter")(close)
    A.deep(crossColor(), theme.danger, "the cross turns red under the mouse")
    close:GetScript("OnLeave")(close)
    A.deep(crossColor(), theme.glyph, "and grey again when the mouse leaves")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "restore returns Blizzard's art")
    for _, region in ipairs(own) do A.falsy(region:IsShown(), "own regions are hidden on restore") end
    close:GetScript("OnEnter")(close)
    A.deep(crossColor(), theme.glyph, "the hover hook does nothing while the area is off")
end)
