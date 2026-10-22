-- The Forever 12.0 spellbook, shaped after a frame dump of the client: PlayerSpellsFrame.SpellBookFrame with the
-- book page art (BookBGHalved, BookBGLeft, BookBGRight), an icon tabSystem (SquareBackground /
-- SquareBackgroundActive art, the panel tab pieces hidden), a SearchBox with Left / Middle / Right art and
-- PagedSpellsFrame.View1 holding pooled category headers (Backplate, Border divider, Text) and spell items
-- (Backplate and a Button with Icon, ornate Border and BorderSheen). PlayerSpellsFrame.TalentsFrame has the
-- search box and the ApplyButton (UIPanelButton Left / Middle / Right) in its footer.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\Spellbook\\" .. name)
    texture:SetAlpha(0.95)
    if list then list[#list + 1] = texture end
    return texture
end

local function text(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    return font
end

local function field(parent, list, name)
    local box = CreateFrame("EditBox", nil, parent)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do box[key] = art(box, list, name .. key, "BACKGROUND") end
    return box
end

local function tab(system, list, selected)
    local button = CreateFrame("Button", nil, system)
    button:SetSize(43, 31)
    for _, key in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do
        button[key] = art(button, nil, "Tab" .. key, "BACKGROUND")
        button[key]:Hide()
    end
    button.Icon = art(button, nil, "TabIcon")
    button.SquareBackground = art(button, list, "TabFrame")
    button.SquareBackgroundActive = art(button, list, "TabFrameGlow")
    button.SquareBackground:SetShown(not selected)
    button.SquareBackgroundActive:SetShown(selected)
    return button
end

local function header(view, list, title)
    local frame = CreateFrame("Frame", nil, view)
    frame:SetSize(680, 51)
    frame.Backplate = art(frame, list, "ListBackplate", "BACKGROUND")
    frame.Text = text(frame, title)
    frame.Border = art(frame, list, "Divider")
    return frame
end

local function item(view, list, name)
    local frame = CreateFrame("Frame", nil, view)
    frame:SetSize(216, 60)
    frame.Backplate = art(frame, list, "ItemBackplate", "BACKGROUND")
    frame.TextContainer = CreateFrame("Frame", nil, frame)
    frame.TextContainer.Name = text(frame.TextContainer, name)
    local button = CreateFrame("Button", nil, frame)
    frame.Button = button
    button:SetSize(40, 40)
    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetTexture("Interface\\Icons\\" .. name)
    button.Icon:SetTexCoord(0, 1, 0, 1)
    button.Border = art(button, list, "ItemIconFrame", "OVERLAY")
    button.BorderSheen = art(button, list, "Sheen", "OVERLAY")
    return frame
end

local function spells()
    local list = {}
    local frame = R.window("PlayerSpellsFrame", { inset = false })
    PlayerSpellsFrame = frame
    local book = CreateFrame("Frame", nil, frame)
    frame.SpellBookFrame = book
    for _, key in ipairs({ "BookBGHalved", "BookBGLeft", "BookBGRight" }) do book[key] = art(book, list, key, "BACKGROUND") end
    book.tabSystem = CreateFrame("Frame", nil, book)
    local tabs = { tab(book.tabSystem, list, true), tab(book.tabSystem, list, false) }
    book.SearchBox = field(book, list, "Search")
    book.SearchBox.Instructions = text(book.SearchBox, "Search abilities, keywords")
    local paged = CreateFrame("Frame", nil, book)
    book.PagedSpellsFrame = paged
    function paged:DisplayViewsForCurrentPage() end
    paged.View1 = CreateFrame("Frame", nil, paged)
    paged.View2 = CreateFrame("Frame", nil, paged)
    paged.PagingControls = CreateFrame("Frame", nil, paged)
    paged.PagingControls.PageText = text(paged.PagingControls, "Page 1/1")
    local talents = CreateFrame("Frame", nil, frame)
    frame.TalentsFrame = talents
    talents.ClassBackground = art(talents, nil, "TalentTree", "BACKGROUND")
    talents.SearchBox = field(talents, list, "TalentSearch")
    talents.ApplyButton = CreateFrame("Button", nil, talents)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        talents.ApplyButton[key] = art(talents.ApplyButton, list, "Apply" .. key, "BACKGROUND")
    end
    talents.ApplyButton.Text = text(talents.ApplyButton, "Apply Changes")
    return {
        frame = frame, book = book, art = list, tabs = tabs, paged = paged, talents = talents,
        header = header(paged.View1, list, "General"),
        item = item(paged.View1, list, "Attack"),
    }
end

local function visibleArt(c, list)
    local names = {}
    for _, texture in ipairs(list or c.art) do
        if not R.invisible(texture, c.frame) then
            names[#names + 1] = (tostring(texture._texture):gsub("^.*\\", ""))
        end
    end
    return table.concat(names, ",")
end

local function accent(ns, frame)
    return W.marked(ns, frame)
end

h.test("Windows flattens the spellbook pages, spell slots, tabs and search, keeps content and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = spells()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    A.eq(visibleArt(c), "", "book pages, banners, dividers, icon frames, tab frames and field art are all hidden")
    local button = c.item.Button
    A.ok(L.zoomed(button.Icon), "spell icon is square-cropped")
    A.ok(not R.invisible(button.Icon, c.frame), "spell icon stays")
    A.ok(W.isDark(button) and B.border(button) ~= nil, "spell slot gets a dark fill and a thin border")
    A.ok(not R.invisible(c.item.TextContainer.Name, c.frame), "spell name stays")
    A.ok(not R.invisible(c.header.Text, c.frame), "category title stays")
    A.ok(accent(ns, c.tabs[1]), "selected spellbook tab gets the accent line")
    A.ok(not accent(ns, c.tabs[2]), "other spellbook tab has no accent line")
    A.ok(not R.invisible(c.tabs[1].Icon, c.frame), "tab icon stays")
    A.ok(W.isDark(c.book.SearchBox), "spellbook search box becomes a dark field")
    A.ok(W.isDark(c.talents.ApplyButton), "talent apply button becomes a dark field")
    A.ok(not R.invisible(c.talents.ApplyButton.Text, c.frame), "apply button text stays")
    A.ok(not R.invisible(c.talents.ClassBackground, c.frame), "talent tree art is content and stays")
    A.ok(not R.invisible(c.paged.PagingControls.PageText, c.frame), "page text stays")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "spellbook restores exactly")
end)

h.test("Windows skins spell items of a new page and moves the tab accent with Blizzard's selection", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = spells()
    W.enable(ns)
    local list = {}
    local late = item(c.paged.View2, list, "Fireball")
    c.paged:DisplayViewsForCurrentPage()
    A.eq(visibleArt(c, list), "", "an item acquired after apply loses its art when the page is displayed")
    A.ok(L.zoomed(late.Button.Icon), "the late spell icon is square-cropped")
    c.tabs[1].SquareBackgroundActive:Hide()
    c.tabs[2].SquareBackgroundActive:Show()
    A.ok(not accent(ns, c.tabs[1]) and accent(ns, c.tabs[2]), "tab accent follows SquareBackgroundActive")
    ns.Modern.Restore()
    local after = item(c.paged.View1, {}, "Frostbolt")
    c.paged:DisplayViewsForCurrentPage()
    A.ok(not R.invisible(after.Backplate, c.frame), "the page hook does nothing while the area is off")
end)

local INK = { 0.25, 0.15, 0.05, 1 }

local function light(font)
    local r, g, b = font:GetTextColor()
    return 0.3 * r + 0.59 * g + 0.11 * b > 0.5
end

h.test("Windows turns the spellbook's dark ink into light text, keeps grey states and restores the ink", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = spells()
    local name, title = c.item.TextContainer.Name, c.header.Text
    local sub = text(c.item.TextContainer, "Racial")
    c.item.TextContainer.SubName = sub
    name:SetTextColor(unpack(INK))
    title:SetTextColor(unpack(INK))
    sub:SetTextColor(0.5, 0.5, 0.5, 1)
    local page = c.paged.PagingControls.PageText
    page:SetTextColor(unpack(INK))
    W.enable(ns)
    A.ok(light(page), "page number ink becomes light")
    A.ok(light(name), "spell name ink becomes light")
    A.ok(light(title), "category title ink becomes light")
    A.deep({ sub:GetTextColor() }, { 0.5, 0.5, 0.5, 1 }, "a grey state colour stays")
    name:SetTextColor(unpack(INK))
    A.ok(light(name), "Blizzard repainting the ink is answered with light text")
    ns.Modern.Restore()
    A.deep({ name:GetTextColor() }, INK, "spell name ink returns on restore")
    A.deep({ title:GetTextColor() }, INK, "category title ink returns on restore")
    name:SetTextColor(unpack(INK))
    A.deep({ name:GetTextColor() }, INK, "the colour hook does nothing while the area is off")
end)
