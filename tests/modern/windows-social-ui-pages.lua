-- The friends window of the Forever client (SocialUIFrame) under the Windows area, second half (fixture:
-- tests/lib/modern-social.lua; the first half is windows-social-ui.lua): the Battle.net bar, search and Filter on
-- every list page, flat red and gold buttons, the icon side tabs, the raid, raid info and ignore pages and the
-- movable key `SocialUIFrame`.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")
local F = h.lib("modern-finder")
local S = h.lib("modern-social")
local Q = h.lib("modern-social-read")
local Rows = h.lib("modern-social-rows")
Rows.use(P)
S.use(P, Rows)

local function setup(t)
    local ns = t.ns
    W.area(ns, "windows")
    local c = P.new()
    local f = S.build(c)
    return ns, c, f
end

------------------------------------------------------------------------------
-- Battle.net bar, search and Filter
------------------------------------------------------------------------------
h.test("Windows holds the Battle.net plate and keeps tag, copy and status; the dropdown is dark with a bare chevron", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    local watch = L.watchScripts(f.copy)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.alpha(f.bar.Background, 0, "the infoBG plate is held")
    A.alpha(f.bar.ControlsContainer.BattleNetBackground, 0, "the tag pill behind the controls is held")
    A.ok(f.bar.Background._shown ~= false, "by alpha, not hidden")
    A.ok(not R.invisible(f.bar.ControlsContainer.PersonalBattleTagDisplay.DisplayText, f.frame), "the tag stays")
    A.alpha(f.copy.Icon, 0.9, "the copy icon stays")
    A.ok(not W.isDark(f.copy), "the copy icon gets no box")
    f.copy:Click()
    A.eq(f.copy.clicks, 1, "the copy click still works")
    A.eq(watch.n, 0, "no script of the copy button was replaced")
    A.ok(W.isDark(f.status), "the status dropdown is a dark field")
    A.alpha(f.status.Arrow, 0, "its gold arrow box is held")
    A.eq(P.glyphs(f.status, theme.glyph), 2, "a bare chevron of two strokes stands in its place")
    A.ok(not R.invisible(f.status.Text, f.frame), "the status text stays")
end)

h.test("Windows turns the Battle.net menu button into a bare glyph without its square plate", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        A.alpha(f.menu[getter](f.menu), 0, "the tertiary plate (" .. getter .. ") is held")
    end
    A.alpha(f.menu.Icon, 0.9, "the menu glyph stays")
    A.ok(not W.isDark(f.menu), "no dark box")
    A.eq(Q.edges(f.menu, theme), 0, "no border")
    f.menu:Click()
    A.eq(f.menu.clicks, 1, "the click still works")
    local party = f.pool.friend[1].PartyButton
    A.alpha(party:GetNormalTexture(), 0, "a row's party button plate is held too")
    A.alpha(party.ActionIcon, 0.9, "and its action icon stays")
end)

h.test("Windows gives the broadcast box and the unavailable notice the dark popout look with flat buttons", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    A.ok(W.isDark(f.broadcast), "the broadcast box has a dark panel of its own")
    A.ok(W.isDark(f.edit), "its input is a dark field")
    A.eq(Q.unheld(c.art), "", "the DiamondMetal borders and the input pieces are held")
    A.ok(W.isDark(f.broadcast.UpdateButton) and W.isDark(f.broadcast.CancelButton), "Update and Cancel are flat buttons")
    A.ok(not R.invisible(f.edit.PromptText, f.frame), "the prompt text stays")
    A.ok(not R.invisible(f.notice.Text, f.frame), "the notice text stays")
end)

for _, key in ipairs({ "FriendsList", "RecentAlliesList", "FriendRequestsList" }) do
    h.test("Windows gives the " .. key .. " search bar and Filter dark fields with bare glyphs and a working reset", function(t)
        local A = t.assert
        local ns, c, f = setup(t)
        local bar = f.frame[key].FilterBar
        local search, filter = bar.SearchBar, bar.SearchFilterDropdown
        local watch = L.watchScripts(filter.ResetButton)
        W.enable(ns)
        local theme = ns.Modern.Theme()
        A.ok(W.isDark(search), "the search bar is a dark field")
        A.alpha(search.Background, 0, "its common-searchbar plate is held")
        A.alpha(search.searchIcon, 0.9, "the search icon stays as a bare glyph")
        A.alpha(search.clearButton.Icon, 0.9, "the clear cross stays")
        A.ok(W.isDark(filter), "Filter is a dark field")
        A.alpha(filter.Background, 0, "its dropdown plate is held")
        A.eq(P.glyphs(filter, theme.glyph), 2, "Filter shows a bare chevron")
        A.alpha(filter.ResetButton.Icon, 0.9, "the reset cross stays")
        filter.ResetButton:Show()
        filter.ResetButton:Click()
        A.eq(filter.ResetButton.clicks, 1, "the reset still works")
        A.eq(watch.n, 0, "no script of the reset button was replaced")
        local list = f.frame[key]
        for _, divider in ipairs({ list.TopDivider, list.BottomDivider }) do
            A.ok(Q.quiet(divider), "a divider is held or a quiet rule")
        end
    end)
end

------------------------------------------------------------------------------
-- Buttons, tabs, pages
------------------------------------------------------------------------------
h.test("Windows flattens every red and gold button of the window and their clicks still work", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    local watches = {}
    for index, button in ipairs(f.buttons) do watches[index] = L.watchScripts(button) end
    W.enable(ns)
    A.eq(#f.buttons, 11, "the fixture has every button of the window")
    for index, button in ipairs(f.buttons) do
        local name = button.Text and button.Text:GetText() or ("button " .. index)
        A.ok(W.isDark(button), name .. " is a flat Modern button")
        A.ok(P.hasHover(button), name .. " lights up under the mouse")
        A.ok(not R.invisible(button.Text, f.frame), name .. " keeps its label")
        button:Click()
        A.eq(button.clicks, 1, name .. " still clicks")
        A.eq(watches[index].n, 0, name .. " keeps its script")
    end
    A.eq(Q.unheld(c.art), "", "no red or gold plate shows")
end)

h.test("Windows turns the four side tabs into small icon tabs marked by the accent line, the count badge stays", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    local before = L.snapshot(R.all(f.frame))
    W.enable(ns)
    for index, tab in ipairs(f.tabs) do
        local width, height = tab:GetSize()
        A.ok(width < 55 and width == height, "side tab " .. index .. " is a small square")
        A.ok(L.zoomed(tab.Icon), "side tab " .. index .. " icon is cropped square")
        A.alpha(tab.Background, 0, "side tab " .. index .. " stone plate is held")
        A.alpha(tab.HighlightTexture, 0, "side tab " .. index .. " gold hover art is held")
        A.alpha(tab.Count, 1, "side tab " .. index .. " count badge stays")
    end
    A.ok(W.marked(ns, f.tabs[1]), "the selected tab gets the accent line")
    A.ok(not W.marked(ns, f.tabs[2]) and not W.marked(ns, f.tabs[3]), "the others have none")
    f.tabs[1].SelectedTexture:Hide()
    f.tabs[3].SelectedTexture:Show()
    A.ok(not W.marked(ns, f.tabs[1]) and W.marked(ns, f.tabs[3]), "the line follows Blizzard's selection")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    f.tabs[3].SelectedTexture:Hide()
    f.tabs[1].SelectedTexture:Show()
    A.deep(L.diff(before), {}, "the side tabs restore exactly")
end)

h.test("Windows gives the raid page a flat All Assist checkbox and keeps its role icons and counts", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    f.assist:SetChecked(true)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.alpha(f.assist:GetNormalTexture(), 0, "Blizzard's checkbox art is held")
    A.alpha(f.assist:GetCheckedTexture(), 0, "the gold checkmark is held")
    A.ok(F.flat(f.assist, theme), "the checkbox is a flat Modern checkbox")
    A.ok(F.mark(f.assist, theme), "a checked box shows the accent mark")
    f.assist:SetChecked(false)
    A.ok(not F.mark(f.assist, theme), "the mark follows Blizzard's state")
    for index, role in ipairs(f.roles) do
        A.alpha(role.Icon, 0.9, "role icon " .. index .. " stays")
        A.ok(not R.invisible(role.Count, f.frame), "role count " .. index .. " stays")
    end
end)

h.test("Windows gives raid info a dark sub-window with a thin close cross and holds its rock and metal edges", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.ok(W.isDark(f.info), "the raid info frame is a dark sub-window")
    for _, key in ipairs({ "TopInset", "BottomInset", "TopInsetEdge" }) do
        A.alpha(f.info[key], 0, key .. " is held")
    end
    for _, texture in ipairs({ f.info.Border.Bg, f.info.Border.TopLeftCorner, f.info.Border.LeftEdge }) do
        A.alpha(texture, 0, "the metal border piece " .. tostring(texture._label) .. " is held")
    end
    A.eq(P.glyphs(f.info.CloseButton, theme.glyph), 2, "its close button is a thin cross")
    A.alpha(f.info.CloseButton:GetNormalTexture(), 0, "the red close art is held")
end)

h.test("Windows gives the ignore list a dark window with its own band and a thin close cross", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    local ignore = f.ignore
    A.ok(W.isDark(ignore), "the ignore list is a dark window")
    A.ok(Q.band(ignore), "with a header band")
    A.eq(P.glyphs(ignore.CloseButton, theme.glyph), 2, "its close button is a thin cross")
    A.ok(W.isDark(ignore.BlockButton) and W.isDark(ignore.UnblockButton), "Ignore Player and Remove are flat buttons")
end)

------------------------------------------------------------------------------
-- The movable window
------------------------------------------------------------------------------
h.test("dragging the friends window by its title saves its point under SocialUIFrame and reopening restores it", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local frame = f.frame
    A.ok(L.handle(frame), "the window has a title drag handle")
    L.drag(frame, "CENTER", "CENTER", 12, -34)
    A.deep(QuietUICharDB.windowPoints.SocialUIFrame, { "CENTER", "CENTER", 12, -34 }, "the point is saved")
    frame:Hide()
    L.blizzardPoint(frame, "TOPLEFT", 31, -71)
    frame:Show()
    A.deep(W.point(frame), { "CENTER", "CENTER", 12, -34 }, "it reopens at the dragged point")
end)

h.test("the friends window comes back at its saved point after a reload", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    QuietUICharDB = { modernize = { enabled = true }, windowPoints = { SocialUIFrame = { "CENTER", "CENTER", 7, 8 } } }
    ns.Modern.Apply()
    A.deep(W.point(f.frame), { "CENTER", "CENTER", 7, 8 }, "the saved point is applied")
end)

h.test("dragging the friends window in combat does nothing", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    W.enable(ns)
    local frame = f.frame
    local handle = L.handle(frame)
    A.ok(handle, "the window has a title drag handle")
    mock.state.combat = true
    local start, stop = handle._scripts.OnDragStart or handle._scripts.OnMouseDown,
        handle._scripts.OnDragStop or handle._scripts.OnMouseUp
    start(handle)
    A.eq(frame:IsMoving(), false, "the drag does not start")
    stop(handle)
    A.eq(QuietUICharDB.windowPoints, nil, "nothing is saved")
    A.deep(W.point(frame), { "TOPLEFT", "TOPLEFT", 31, -71 }, "the window stays at Blizzard's point")
end)

h.test("Reset positions returns the friends window to Blizzard's point and keeps the skin", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    L.drag(f.frame, "CENTER", "CENTER", 5, 6)
    ns.Modern.ResetPositions()
    A.eq(QuietUICharDB.windowPoints, nil, "the saved point is cleared")
    A.deep(W.point(f.frame), { "TOPLEFT", "TOPLEFT", 31, -71 }, "the window is back at Blizzard's point")
    A.ok(W.isDark(f.frame), "the skin stays applied")
end)
