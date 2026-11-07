-- The vanilla-style group finder under the Windows area (fixture: tests/lib/modern-finder.lua, whose key block marks
-- what is assumed): the listing, browse and who pages are dark windows inside LFGParentFrame; the browse stone
-- backdrop and the round portrait are held; the three side tabs are icon tabs; role, dungeon and level-range boxes
-- are flat checkboxes; refresh and search are bare glyph icons, delist a thin cross; dropdown arrows are chevrons;
-- results stand bare with section strips for groupings. The minimap eye, role icons and empty role dots stay.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")
local F = h.lib("modern-finder")
F.use(P)

local function setup(t)
    local ns = t.ns
    W.area(ns, "windows")
    local c = P.new()
    local f = F.build(c)
    return ns, c, f
end

h.test("Windows skins the group finder's three pages, holds all its art and restores it exactly", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    local before = L.snapshot(R.all(UIParent))
    W.enable(ns)
    A.ok(W.isDark(f.listing) and W.isDark(f.browse) and W.isDark(f.who), "all three pages are dark windows")
    A.ok(not W.isDark(f.parent), "the group finder frame itself gets no panel")
    A.eq(P.visibleArt(c, R), "", "portrait, tabs, boxes, plates and backdrops are held")
    A.eq(P.visibleArt(f.results, R), "", "result art is held")
    A.eq(P.visibleArrows(c, R), "", "the dropdown arrows are held")
    A.eq(P.hiddenKeep(c, R) .. P.hiddenKeep(f.results, R), "", "names, tags, icons, role icons and the minimap eye stay")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the group finder restores exactly")
end)

h.test("Windows holds the browse page's stone backdrop at alpha 0 without hiding it, on a graphite panel", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    A.alpha(f.backdrop, 0, "the brown stone behind the results is held")
    A.ok(f.backdrop._shown ~= false, "it is held by alpha, never hidden")
    f.backdrop:SetAlpha(1)
    A.alpha(f.backdrop, 0, "it stays held when Blizzard repaints it")
    A.ok(W.isDark(f.browse), "the panel is the graphite window fill")
    ns.Modern.Restore()
    A.alpha(f.backdrop, 0.9, "the stone is back on restore")
end)

-- The round portrait sits on LFGParentFrame, whichever page is open.
for _, page in ipairs({ "listing", "browse", "who" }) do
    h.test("Windows holds the group finder's round portrait with the " .. page .. " page open and restores it", function(t)
        local A = t.assert
        local ns, c, f = setup(t)
        for name, frame in pairs(f.pages) do frame:SetShown(name == page) end
        W.enable(ns)
        A.alpha(f.portrait, 0, "the portrait is held")
        A.alpha(f.portraitFrame, 0, "and its ring")
        A.ok(f.portrait._shown ~= false, "by alpha, not hidden")
        f.portrait:SetAlpha(1)
        A.alpha(f.portrait, 0, "it stays held when Blizzard repaints it")
        ns.Modern.Restore()
        A.alpha(f.portrait, 0.9, "the portrait is back after unchecking the area")
        A.alpha(f.portraitFrame, 0.9, "with its ring")
    end)
end

h.test("Windows turns the group finder's side tabs into small square icon tabs marked by the accent line", function(t)
    local A, mock = t.assert, t.mock
    local ns, c, f = setup(t)
    local before = L.snapshot(R.all(f.parent))
    W.enable(ns)
    for index, tab in ipairs(f.tabs) do
        local width, height = tab:GetSize()
        A.ok(width < 44 and width == height, "side tab " .. index .. " shrinks to a small square")
        A.ok(L.zoomed(tab.Icon), "side tab " .. index .. " icon is cropped square")
        A.eq(tab.Icon:GetNumPoints(), 2, "side tab " .. index .. " icon fills the tab")
        A.alpha(tab.Background, 0, "side tab " .. index .. " stone plate is held")
        A.alpha(tab.HighlightTexture, 0, "side tab " .. index .. " gold hover art is held")
    end
    A.ok(W.marked(ns, f.tabs[1]), "the selected tab gets the accent line and border")
    A.ok(not W.marked(ns, f.tabs[2]) and not W.marked(ns, f.tabs[3]), "the others have none")
    f.tabs[1].SelectedTexture:Hide()
    f.tabs[3].SelectedTexture:Show()
    A.ok(not W.marked(ns, f.tabs[1]) and W.marked(ns, f.tabs[3]), "the accent line follows Blizzard's selection")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    f.tabs[1].SelectedTexture:Show()
    A.ok(not W.marked(ns, f.tabs[1]), "the selection hook does nothing while the area is off")
    A.deep({ f.tabs[2]:GetSize() }, { 44, 44 }, "a tab is back at Blizzard's size")
    f.tabs[3].SelectedTexture:Hide()
    A.deep(L.diff(before), {}, "the side tabs restore exactly")
end)

h.test("Windows keeps a role button's icon and holds its box and border", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    for role, button in pairs(f.roles) do
        A.ok(not R.invisible(button.icon, f.parent), role .. " icon stays")
        A.alpha(button.Border, 0, role .. " round border is held")
        A.alpha(button:GetNormalTexture(), 0, role .. " box art is held")
        A.ok(not W.isDark(button), role .. " button gets no dark box")
    end
    ns.Modern.Restore()
    A.alpha(f.roles.Tank.Border, 0.9, "the border is back on restore")
    A.alpha(f.roles.Tank:GetNormalTexture(), 0.9, "and the box art")
end)

h.test("Windows flattens a role button's label-less checkbox and it follows Blizzard's checked state", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    for role, button in pairs(f.roles) do
        local check = button.check
        A.alpha(check:GetNormalTexture(), 0, role .. " Blizzard checkbox art is held")
        A.alpha(check:GetCheckedTexture(), 0, role .. " gold checkmark is held")
        A.ok(F.flat(check, theme), role .. " checkbox is a flat Modern checkbox")
        A.ok(check:GetSize() <= 24, role .. " checkbox keeps its small size")
    end
    A.ok(F.mark(f.roles.Healer.check, theme), "a checked role shows the accent mark")
    A.ok(not F.mark(f.roles.Tank.check, theme), "an unchecked one does not")
    f.roles.Tank.check:SetChecked(true)
    A.ok(F.mark(f.roles.Tank.check, theme), "the mark follows Blizzard's SetChecked")
    f.roles.Tank.check:SetChecked(false)
    A.ok(not F.mark(f.roles.Tank.check, theme), "and clears with it")
    ns.Modern.Restore()
    A.ok(not F.flat(f.roles.Tank.check, theme) and not F.mark(f.roles.Healer.check, theme), "the flat box is gone")
    A.alpha(f.roles.Tank.check:GetCheckedTexture(), 0.9, "Blizzard's checkmark art is back")
end)

h.test("Windows gives the listing page's Dungeons, dungeon rows and level range boxes the flat look", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    local boxes = { f.dungeons, f.levels, table.unpack(f.rows) }
    for index, box in ipairs(boxes) do
        A.alpha(box:GetNormalTexture(), 0, "box " .. index .. " Blizzard art is held")
        A.alpha(box:GetCheckedTexture(), 0, "box " .. index .. " gold checkmark is held")
        A.ok(F.flat(box, theme), "box " .. index .. " is a flat Modern checkbox")
        A.ok(not R.invisible(box.Text, f.parent), "box " .. index .. " label stays")
    end
    A.ok(F.mark(f.levels, theme), "a checked box shows the accent mark")
    A.ok(not F.mark(f.dungeons, theme), "an unchecked one does not")
    f.dungeons:SetChecked(true)
    A.ok(F.mark(f.dungeons, theme), "the mark follows Blizzard's SetChecked")
    ns.Modern.Restore()
    A.ok(not F.flat(f.dungeons, theme) and not F.mark(f.dungeons, theme), "Restore removes the flat box")
    A.alpha(f.dungeons:GetCheckedTexture(), 0.9, "Blizzard's checkmark art is back")
end)

-- Refresh (browse) and search (who): the gold plate goes, the icon is desaturated grey and light under the mouse.
for _, name in ipairs({ "refresh", "search" }) do
    h.test("Windows turns the " .. name .. " button into a bare grey icon that lights up and still clicks", function(t)
        local A = t.assert
        local ns, c, f = setup(t)
        local button = f[name]
        local watch = L.watchScripts(button)
        W.enable(ns)
        local theme = ns.Modern.Theme()
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
            A.alpha(button[getter](button), 0, "the gold plate (" .. getter .. ") is held")
        end
        A.ok(not W.isDark(button), "no box is drawn")
        A.ok(not R.invisible(button.Icon, f.parent), "the icon stays")
        A.ok(button.Icon:IsDesaturated(), "the icon is desaturated")
        A.deep({ button.Icon:GetVertexColor() }, theme.glyph, "and grey at rest")
        button:GetScript("OnEnter")(button)
        A.deep({ button.Icon:GetVertexColor() }, theme.text, "and light under the mouse")
        button:GetScript("OnLeave")(button)
        A.deep({ button.Icon:GetVertexColor() }, theme.glyph, "and grey again after")
        button:GetScript("OnClick")(button)
        A.eq(button.clicks, 1, "the click still works")
        A.eq(watch.n, 0, "no script of the button was replaced")
        ns.Modern.Restore()
        A.ok(not button.Icon:IsDesaturated(), "the icon is in colour again")
        A.deep({ button.Icon:GetVertexColor() }, { 1, 1, 1, 1 }, "with Blizzard's tint")
        A.alpha(button:GetNormalTexture(), 0.9, "the plate is back")
        local enter = button:GetScript("OnEnter")
        if enter then enter(button) end
        A.deep({ button.Icon:GetVertexColor() }, { 1, 1, 1, 1 }, "the hover hook does nothing while the area is off")
    end)
end

h.test("Windows turns the delist button into a thin cross, grey at rest and danger red under the mouse", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    local button = f.delist
    local iconAlpha = button.Icon:GetAlpha()
    W.enable(ns)
    local theme = ns.Modern.Theme()
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        A.alpha(button[getter](button), 0, "the red plate (" .. getter .. ") is held")
    end
    A.alpha(button.Icon, 0, "the red X icon is held under the thin cross")
    A.ok(not W.isDark(button), "no plate or box is drawn")
    A.eq(P.glyphs(button, theme.glyph), 2, "a cross of two thin lines, grey at rest")
    button:GetScript("OnEnter")(button)
    A.eq(P.glyphs(button, theme.danger), 2, "danger red under the mouse")
    button:GetScript("OnLeave")(button)
    A.eq(P.glyphs(button, theme.glyph), 2, "grey again after")
    button:GetScript("OnClick")(button)
    A.eq(button.clicks, 1, "the click still works")
    ns.Modern.Restore()
    A.eq(P.glyphs(button, theme.glyph) + P.glyphs(button, theme.danger), 0, "Restore removes the cross")
    A.alpha(button:GetNormalTexture(), 0.9, "the red plate is back")
    A.alpha(button.Icon, iconAlpha, "the red X icon is back")
end)

h.test("Windows gives every group finder dropdown a bare grey chevron in place of its gold arrow", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    for _, dropdown in ipairs({ f.listing.ActivityDropdown, f.browse.CategoryDropdown, f.who.FilterDropdown }) do
        A.ok(W.isDark(dropdown), "the dropdown keeps its dark field")
        A.alpha(dropdown.Arrow, 0, "the gold arrow box is held")
        A.eq(P.glyphs(dropdown, theme.glyph), 2, "a chevron of two strokes, grey at rest")
        dropdown:GetScript("OnEnter")(dropdown)
        A.eq(P.glyphs(dropdown, theme.text), 2, "light under the mouse")
        dropdown:GetScript("OnLeave")(dropdown)
    end
end)

h.test("Windows leaves role icons in results, the empty role dots and the minimap eye unchanged", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    local watched = L.snapshot({ f.eye, f.eyeFrame, f.eye.Background, f.eye.Highlight, f.eyeFrame.Portrait,
        f.nested.RoleIcon, f.nested.EmptyDot, f.plain.RoleIcon, f.nested.PartyIcon })
    W.enable(ns)
    A.deep(L.diff(watched), {}, "none of them changed")
    A.eq(P.hiddenKeep(c, R), "", "and none is hidden")
    ns.Modern.Restore()
    A.deep(L.diff(watched), {}, "nor after Restore")
end)

h.test("Windows skins a who list row the list adds later", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local late = P.new()
    P.listRow(late, f.whoBox.ScrollTarget)
    f.whoBox:Update()
    A.eq(P.visibleArt(late, R), "", "the new row's plate is held")
end)

local function striped(frame, strip)
    for _, region in ipairs(frame._regions) do
        if region._color and region._color[1] == strip[1] and region._shown ~= false then return true end
    end
    return false
end

-- Shown accent strokes of a sign: 1 minus, 2 plus.
local function sign(frame, accent)
    local count = 0
    for _, region in ipairs(frame._regions) do
        local col = region._color
        if region._shown and (region._alpha or 1) > 0 and col and col[1] == accent[1]
            and (region._w == 10 or region._h == 10) then count = count + 1 end
    end
    return count
end

h.test("Windows lets group finder results stand bare and turns their groupings into strips with a sign", function(t)
    local A = t.assert
    local ns, c, f = setup(t)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    local head, nested, plain = f.head, f.nested, f.plain
    A.eq(P.visibleArt(f.results, R), "", "result plates, hover art, grouping art and Blizzard's signs are held")
    A.eq(P.hiddenKeep(f.results, R), "", "names, labels, leader and role icons and the selection stay")
    A.ok(P.hasHover(nested) and P.hasHover(plain), "a listing lights up under the mouse")
    A.ok(striped(head, theme.strip), "a grouping is a section strip")
    A.eq(sign(head, theme.accent), 1, "an expanded grouping shows a minus")
    head.CollapseIcon:Hide()
    head.ExpandIcon:Show()
    A.eq(sign(head, theme.accent), 2, "a collapsed grouping shows a plus")
    local late = P.new()
    local later = F.results(late, f.box.ScrollTarget)
    f.box:Update()
    A.eq(P.visibleArt(late, R), "", "results pooled in later stand bare on the list update")
    A.ok(striped(later, theme.strip), "a later grouping is a strip")
    A.eq(sign(later, theme.accent), 1, "with its accent sign")
    ns.Modern.Restore()
    A.ok(not striped(head, theme.strip) and sign(head, theme.accent) == 0, "Restore removes the strip and the sign")
end)
