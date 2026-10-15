-- The Forever 12.0 professions window, shaped after a frame dump of the client: ProfessionsFrame (PortraitFrame
-- chrome with Bg), side tabs ProfessionsOverviewTab / ProfessionsNTab (common-sidetab art), BookPage.
-- ProfessionsContentFrame with cards PrimaryProfession1..2 / SecondaryProfession1..3 (Background card art,
-- SpellButtonN with IconTexture and the IconTextureOverlay square frame, a StatusBar with Background, Fill and
-- Border) and a CraftingPage (unnamed background, RecipeList with Background, SearchBox and minimal scroll bar,
-- RankBar, the red CreateButton with Left / Center / Right art and gear slots).
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\Professions\\" .. name)
    texture:SetAlpha(0.95)
    if list then list[#list + 1] = texture end
    return texture
end

local function text(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    return font
end

local function sideTab(parent, list, selected)
    local tab = CreateFrame("Frame", nil, parent)
    tab.Background = art(tab, list, "SideTab", "BACKGROUND")
    tab.Icon = art(tab, nil, "SideTabIcon")
    tab.SelectedTexture = art(tab, list, "SideTabSelected", "OVERLAY")
    tab.SelectedTexture:SetShown(selected)
    return tab
end

local function bar(parent, list, key, name)
    local status = CreateFrame("Frame", nil, parent)
    parent[key] = status
    status.Background = art(status, list, name .. "BarBG")
    status.Fill = art(status, nil, name .. "BarFill")
    status.Border = art(status, list, name .. "BarFrame")
    status.Rank = CreateFrame("Frame", nil, status)
    status.Rank.Text = text(status.Rank, name .. " 73/75")
    return status
end

local function card(content, list, key, name)
    local frame = CreateFrame("Frame", nil, content)
    content[key] = frame
    frame.Background = art(frame, list, "Card" .. name, "BACKGROUND")
    frame.ProfessionName = text(frame, name)
    local button = CreateFrame("CheckButton", nil, frame)
    frame.SpellButton1 = button
    button.IconTexture = button:CreateTexture(nil, "BORDER")
    button.IconTexture:SetTexture("Interface\\Icons\\" .. name)
    button.IconTexture:SetTexCoord(0, 1, 0, 1)
    button.IconTextureOverlay = art(button, list, "SquareFrame", "OVERLAY")
    button.spellString = text(button, name)
    bar(frame, list, "StatusBar", name)
    return frame
end

local function professions()
    local list = {}
    local frame = R.window("ProfessionsFrame", { inset = false })
    ProfessionsFrame = frame
    frame.ProfessionsOverviewTab = sideTab(frame, list, true)
    frame.Professions1Tab = sideTab(frame, list, false)
    frame.BookPage = CreateFrame("Frame", nil, frame)
    local content = CreateFrame("Frame", nil, frame.BookPage)
    frame.BookPage.ProfessionsContentFrame = content
    local primary = card(content, list, "PrimaryProfession1", "Tailoring")
    local secondary = card(content, list, "SecondaryProfession1", "Cooking")

    local page = CreateFrame("Frame", nil, frame)
    frame.CraftingPage = page
    art(page, list, "CraftingBackground", "BACKGROUND")
    page.RecipeList = CreateFrame("Frame", nil, page)
    page.RecipeList.Background = art(page.RecipeList, list, "RecipeList", "BACKGROUND")
    page.RecipeList.SearchBox = CreateFrame("EditBox", nil, page.RecipeList)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        page.RecipeList.SearchBox[key] = art(page.RecipeList.SearchBox, list, "Search" .. key, "BACKGROUND")
    end
    local scroll = CreateFrame("Frame", nil, page.RecipeList)
    page.RecipeList.ScrollBar = scroll
    scroll.Track = CreateFrame("Frame", nil, scroll)
    scroll.Track.Middle = art(scroll.Track, list, "TrackMiddle")
    bar(page, list, "RankBar", "Rank")
    page.CreateButton = CreateFrame("Button", nil, page)
    for _, key in ipairs({ "Left", "Center", "Right" }) do
        page.CreateButton[key] = art(page.CreateButton, list, "RedButton" .. key, "BACKGROUND")
    end
    page.CreateButton.Text = text(page.CreateButton, "Create")
    local slot = CreateFrame("Button", nil, page)
    page.Prof0ToolSlot = slot
    slot.icon = slot:CreateTexture(nil, "BORDER")
    slot.icon:SetTexture("Interface\\Icons\\Tool")
    slot.icon:SetTexCoord(0, 1, 0, 1)
    slot.NormalTexture = art(slot, list, "SlotNormal")
    return { frame = frame, art = list, primary = primary, secondary = secondary, page = page, slot = slot }
end

local function visibleArt(c)
    local names = {}
    for _, texture in ipairs(c.art) do
        if not R.invisible(texture, c.frame) then
            names[#names + 1] = (tostring(texture._texture):gsub("^.*\\", ""))
        end
    end
    return table.concat(names, ",")
end

h.test("Windows flattens the professions window, keeps bar fills, icons and texts, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = professions()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    A.eq(R.visibleChrome(c.frame), "", "window chrome is hidden")
    A.eq(visibleArt(c), "", "card, icon frame, bar, tab, recipe list, field, button and slot art are all hidden")
    for _, card in ipairs({ c.primary, c.secondary }) do
        A.ok(W.isDark(card), "card becomes a dark panel")
        local button = card.SpellButton1
        A.ok(L.zoomed(button.IconTexture), "spell icon is square-cropped")
        A.ok(W.isDark(button) and B.border(button) ~= nil, "spell gets a dark slot with a thin border")
        A.ok(W.isDark(card.StatusBar), "skill bar becomes a dark field")
        A.ok(not R.invisible(card.StatusBar.Fill, c.frame), "skill bar fill stays")
        A.ok(not R.invisible(card.StatusBar.Rank.Text, c.frame), "rank text stays")
        A.ok(not R.invisible(card.ProfessionName, c.frame), "profession name stays")
    end
    A.ok(B.same(B.border(c.frame.ProfessionsOverviewTab), ns.Modern.Theme().accent), "selected side tab gets the accent")
    A.ok(not R.invisible(c.frame.ProfessionsOverviewTab.Icon, c.frame), "side tab icon stays")
    A.ok(W.isDark(c.page.CreateButton), "create button becomes a dark field")
    A.ok(not R.invisible(c.page.CreateButton.Text, c.frame), "create button text stays")
    A.ok(L.zoomed(c.slot.icon), "gear slot icon is square-cropped")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "professions window restores exactly")
end)

h.test("Windows skins a professions card filled in after apply when the window shows", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = professions()
    W.enable(ns)
    c.frame:Hide()
    local list = {}
    local late = card(c.frame.BookPage.ProfessionsContentFrame, list, "SecondaryProfession2", "Fishing")
    c.frame:Show()
    A.ok(R.invisible(late.Background, c.frame), "the late card loses its art on show")
    A.ok(W.isDark(late.StatusBar), "the late card's bar becomes a dark field")
end)
