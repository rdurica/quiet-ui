-- The friends window of the Forever client (SocialUIFrame, fixture tests/lib/modern-social.lua, whose key block lists
-- what is assumed from the dump) under the Windows area: the dark window with its title band, metal chrome held at
-- alpha 0, bare friend rows with a rule, hover wash and an accent edge for the selected one, the group header as a
-- section strip with an accent sign, the Battle.net bar, search and Filter, flat buttons, icon tabs, the raid and
-- ignore pages, the movable key `SocialUIFrame` and an exact restore. FriendsFrame stays skinned as a fallback.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")
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
-- The window
------------------------------------------------------------------------------
h.test("Windows makes SocialUIFrame a dark window with a title band, a gold hairline and a thin close cross", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.ok(W.isDark(f.frame), "graphite panel")
    A.ok(Q.band(f.frame), "header band")
    A.ok(Q.hairline(f.frame, theme), "gold hairline under the title")
    local close = f.frame.CloseButton
    A.eq(P.glyphs(close, theme.glyph), 2, "the close button is a thin grey cross")
    A.ok(not W.isDark(close), "no plate behind the cross")
    A.ok(not R.invisible(f.frame.TitleContainer.TitleText, f.frame), "the title stays")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Windows holds the metal frame, portrait, fades and gamepad glow at alpha 0 without hiding them", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    for index, texture in ipairs(f.chrome) do
        A.alpha(texture, 0, "chrome piece " .. index .. " (" .. tostring(texture._label) .. ") is held")
        A.ok(texture._shown ~= false, "chrome piece " .. index .. " is held by alpha, never hidden")
    end
    A.eq(Q.unheld(c.art), "", "every piece of art of the window and its pages is held")
    A.eq(Q.unheld(c.arrows), "", "the dropdown arrows are held")
    A.eq(Q.heldKeep(c.keep), "", "texts and icons stay")
    f.topFade:SetAlpha(1)
    f.portrait:SetAlpha(1)
    f.frame.NineSlice.TopEdge:SetAlpha(1)
    A.alpha(f.topFade, 0, "the top fade stays held when Blizzard repaints it")
    A.alpha(f.portrait, 0, "the portrait too")
    A.alpha(f.frame.NineSlice.TopEdge, 0, "and the metal edge")
end)

h.test("Windows restores SocialUIFrame and the old FriendsFrame exactly, on Restore and with the area off", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    local legacy = S.legacy(c)
    -- Only the two friends windows: other areas stay applied and hook their own frames.
    local before = L.snapshot(R.all(legacy, R.all(f.frame)))
    W.enable(ns)
    A.ok(W.isDark(legacy), "the old FriendsFrame is still skinned")
    A.ok(W.isDark(f.frame), "and so is SocialUIFrame")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "Restore returns both windows exactly")
    W.enable(ns)
    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "unchecking Windows returns both windows exactly")
end)

h.test("a client without SocialUIFrame skins FriendsFrame as before and reports nothing", function(t)
    local A, mock = t.assert, t.mock
    local ns = t.ns
    W.area(ns, "windows")
    local legacy = S.legacy(P.new())
    A.eq(rawget(_G, "SocialUIFrame"), nil, "there is no SocialUIFrame")
    W.enable(ns)
    A.ok(W.isDark(legacy), "FriendsFrame is skinned")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Windows adds no own texture when it applies twice or is turned off and on", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    local base = Q.count(f.frame)
    W.enable(ns)
    local skinned = Q.count(f.frame)
    A.ok(skinned > base, "the skin adds its own textures")
    ns.Modern.Apply()
    A.eq(Q.count(f.frame), skinned, "applying again adds nothing")
    ns.Modern.Restore()
    W.enable(ns)
    A.eq(Q.count(f.frame), skinned, "off and on again adds nothing")
    Rows.refill(f, Rows.data)
    local refilled = Q.count(f.frame)
    ns.Modern.Apply()
    A.eq(Q.count(f.frame), refilled, "nor does applying again after a refill")
end)

------------------------------------------------------------------------------
-- Friend rows
------------------------------------------------------------------------------
h.test("Windows lets friend rows stand bare: card backgrounds and the gold highlight held, text untouched", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    local texts = {}
    for _, row in ipairs(f.pool.friend) do
        for _, key in ipairs(Rows.texts) do texts[#texts + 1] = row[key] end
    end
    local before = L.snapshot(texts)
    W.enable(ns)
    for index, row in ipairs(f.pool.friend) do
        A.eq(Q.unheld(row.lists.art), "", "row " .. index .. " card background, highlight and button plates are held")
        A.eq(Q.heldKeep(row.lists.keep), "", "row " .. index .. " presence, game and favourite icons and texts stay")
        A.ok(not W.isDark(row), "row " .. index .. " has no dark card")
        A.ok(row.highlight._shown ~= false, "the gold highlight is held by alpha, never hidden")
    end
    A.deep(L.diff(before), {}, "no name, level, class or location text or colour is touched")
    local row = f.pool.friend[1]
    row.Background:SetAlpha(1)
    row.highlight:SetAlpha(1)
    A.alpha(row.Background, 0, "the card stays held when Blizzard repaints it")
    A.alpha(row.highlight, 0, "and so does the gold highlight")
    ns.Modern.Restore()
    A.alpha(row.Background, 0.9, "the card is back on restore")
end)

h.test("Windows puts a quiet rule under each friend row and a faint wash under the mouse", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    for index, row in ipairs(f.pool.friend) do
        A.eq(Q.rules(row), 1, "row " .. index .. " has one quiet rule along its bottom")
        A.eq(Q.washes(row), 1, "row " .. index .. " has one faint wash in its HIGHLIGHT layer, drawn only under the mouse")
        A.ok(P.hasHover(row), "row " .. index .. " lights up under the mouse")
    end
    ns.Modern.Restore()
    for index, row in ipairs(f.pool.friend) do
        A.eq(Q.rules(row), 0, "row " .. index .. " loses the rule on Restore")
        A.eq(Q.washes(row), 0, "and the wash")
    end
end)

h.test("Windows marks the selected friend with an accent edge on the left that follows the selection", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    local list = f.pool.friend
    for index, row in ipairs(list) do A.ok(not Q.edge(row, theme), "row " .. index .. " has no edge before a selection") end
    Rows.select(f, list[1])
    A.ok(Q.edge(list[1], theme), "the selected friend shows the accent edge")
    A.ok(not Q.edge(list[2], theme) and not Q.edge(list[3], theme), "the others do not")
    A.alpha(list[1].highlight, 0, "and no gold card shows")
    Rows.select(f, list[3])
    A.ok(Q.edge(list[3], theme) and not Q.edge(list[1], theme), "selecting another friend moves the edge")
    Rows.select(f, nil)
    A.ok(not Q.edge(list[3], theme), "clearing the selection removes it")
    Rows.select(f, list[2])
    ns.Modern.Restore()
    A.ok(not Q.edge(list[2], theme), "Restore removes the edge")
    Rows.select(f, list[1])
    A.ok(not Q.edge(list[1], theme), "the selection hook does nothing while the area is off")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("Windows gives new and reused pooled rows the same bare look when the list refills", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    local data = { Rows.data[1], Rows.data[2], Rows.data[3], Rows.data[4],
        { kind = "friend", FriendName = "Ks9", Name = "Corvin", Level = "Lvl 33", Class = "Rogue", Location = "Duskwood",
            online = true },
        { kind = "friend", FriendName = "Ks8", Name = "Dessa", Level = "Lvl 44", Class = "Druid", Location = "Ashenvale",
            online = false } }
    local fresh = Rows.refill(f, data)
    A.eq(#fresh.rows, 2, "two rows were created")
    A.eq(Q.unheld(fresh.art), "", "the new rows' card backgrounds, highlights and plates are held")
    A.eq(Q.heldKeep(fresh.keep), "", "their icons and texts stay")
    for index, row in ipairs(fresh.rows) do
        A.eq(Q.rules(row), 1, "new row " .. index .. " has its quiet rule")
        A.ok(P.hasHover(row), "and its wash")
        Rows.select(f, row)
        A.ok(Q.edge(row, theme), "and takes the selection edge")
    end
    for index, row in ipairs(f.pool.friend) do
        A.eq(Q.unheld(row.lists.art), "", "row " .. index .. " is bare after the refill")
        A.eq(Q.rules(row), 1, "row " .. index .. " has exactly one rule")
        A.eq(Q.washes(row), 1, "and exactly one wash")
    end
    local reused = f.pool.friend[2]
    A.alpha(reused.Background, 0, "a reused row whose card Blizzard re-pointed stays held")
    Rows.refill(f, { Rows.data[1], Rows.data[3] })
    A.eq(Q.unheld(f.pool.friend[1].lists.art), "", "fewer rows later change nothing")
end)

------------------------------------------------------------------------------
-- The group header
------------------------------------------------------------------------------
h.test("Windows turns the Friends List header into a section strip with an accent minus, a plus when collapsed", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    local head = f.pool.header[1]
    local watch = L.watchScripts(head)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.eq(Q.unheld(head.lists.art), "", "the card strip art, its highlight and Blizzard's minus are held")
    A.eq(Q.heldKeep(head.lists.keep), "", "the label stays")
    A.ok(Q.striped(head, theme), "the header is a section strip")
    A.eq(Q.sign(head, theme), 1, "an expanded header shows an accent minus")
    head:Click()
    A.eq(head.clicks, 1, "the click still collapses the list")
    A.ok(head.collapsed, "Blizzard's state flipped")
    A.eq(Q.sign(head, theme), 2, "a collapsed header shows an accent plus")
    A.eq(Q.unheld(head.lists.art), "", "Blizzard's plus stays held")
    head.CollapseButton:Click()
    A.ok(not head.collapsed and Q.sign(head, theme) == 1, "the sign button expands it again with its minus")
    A.eq(watch.n, 0, "no script of the header was replaced")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.ok(not Q.striped(head, theme) and Q.sign(head, theme) == 0, "Restore removes the strip and the sign")
    head:Click()
    A.eq(Q.sign(head, theme), 0, "the sign hook does nothing while the area is off")
end)
