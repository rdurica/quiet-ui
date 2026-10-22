-- The Forever 12.0 auction house, shaped after a frame dump of the client: AuctionHouseFrame (PortraitFrame
-- chrome) with BuyTab / SellTab (panel tab art), MoneyFrameInset (InsetFrame) and MoneyFrameBorder (unkeyed
-- three-piece art), a SearchBar (FavoritesSearchButton, SearchBox and SearchButton with Left / Middle / Right,
-- FilterButton with a dropdown Background), a CategoriesList (Background, NineSlice, pooled category buttons with
-- Lines / NormalTexture / SelectedTexture in ScrollBox.ScrollTarget, minimal ScrollBar) and BrowseResultsFrame.
-- ItemList (Background, NineSlice, RefreshFrame.RefreshButton, HeaderContainer of three-piece column headers).
-- The sell page (ItemSellFrame) has the CreateAuctionTab strip and an ItemDisplay whose unkeyed header frame is
-- an atlas, with an ItemButton (EmptyBackground, Icon, IconBorder) and bid boxes with left / right and a named
-- Middle.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\AuctionHouse\\" .. name)
    texture:SetAlpha(0.95)
    if list then list[#list + 1] = texture end
    return texture
end

local function text(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    return font
end

local function threePiece(kind, parent, list, name)
    local frame = CreateFrame(kind, nil, parent)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do frame[key] = art(frame, list, name .. key, "BACKGROUND") end
    frame.Text = text(frame, name)
    return frame
end

local function square(parent, list, name)
    local button = CreateFrame("Button", nil, parent)
    local normal = art(button, list, name .. "Normal")
    function button:GetNormalTexture() return normal end
    button.Icon = art(button, nil, name .. "Icon", "OVERLAY")
    return button
end

local function scrollBar(parent, list)
    local bar = CreateFrame("Frame", nil, parent)
    bar.Track = CreateFrame("Frame", nil, bar)
    bar.Track.Middle = art(bar.Track, list, "TrackMiddle")
    return bar
end

local function category(target, list, name)
    local button = CreateFrame("Button", nil, target)
    button.Lines = art(button, nil, "FilterLine", "BACKGROUND")
    button.Lines:Hide()
    button.NormalTexture = art(button, list, "NavButton", "BACKGROUND")
    button.SelectedTexture = art(button, nil, "NavButtonSelect")
    button.Text = text(button, name)
    return button
end

local function inner(parent, list, key, background)
    local frame = CreateFrame("Frame", nil, parent)
    parent[key] = frame
    frame.Background = art(frame, list, background)
    frame.NineSlice = R.nineSlice(frame, list)
    return frame
end

local function auctionHouse()
    local list = {}
    local frame = R.window("AuctionHouseFrame", { inset = false })
    AuctionHouseFrame = frame
    frame.BuyTab = R.tab(frame, "AuctionHouseFrameBuyTab")
    frame.SellTab = R.tab(frame, "AuctionHouseFrameSellTab")
    frame.BuyTab.Left:Hide()
    frame.SellTab.LeftActive:Hide()

    frame.MoneyFrameInset = R.inset(frame, list)
    local border = CreateFrame("Frame", nil, frame)
    frame.MoneyFrameBorder = border
    art(border, list, "MoneyLeft", "BACKGROUND")
    art(border, list, "MoneyRight", "BACKGROUND")
    border.MoneyFrame = CreateFrame("Frame", nil, border)
    border.MoneyFrame.Gold = text(border.MoneyFrame, "4")

    local bar = CreateFrame("Frame", nil, frame)
    frame.SearchBar = bar
    bar.FavoritesSearchButton = square(bar, list, "Favorites")
    bar.SearchBox = threePiece("EditBox", bar, list, "Search")
    bar.SearchButton = threePiece("Button", bar, list, "SearchButton")
    bar.FilterButton = CreateFrame("Button", nil, bar)
    bar.FilterButton.Background = art(bar.FilterButton, list, "DropdownButton", "BACKGROUND")
    bar.FilterButton.Text = text(bar.FilterButton, "Filter")

    local categories = inner(frame, list, "CategoriesList", "CategoriesBackground")
    categories.ScrollBox = CreateFrame("Frame", nil, categories)
    categories.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, categories.ScrollBox)
    function categories.ScrollBox:Update() end
    local weapons = category(categories.ScrollBox.ScrollTarget, list, "Weapons")
    categories.ScrollBar = scrollBar(categories, list)

    local results = CreateFrame("Frame", nil, frame)
    frame.BrowseResultsFrame = results
    local items = inner(results, list, "ItemList", "IndexBackground")
    items.RefreshFrame = CreateFrame("Frame", nil, items)
    items.RefreshFrame.RefreshButton = square(items.RefreshFrame, list, "Refresh")
    items.HeaderContainer = CreateFrame("Frame", nil, items)
    local header = threePiece("Button", items.HeaderContainer, list, "Price")
    items.ScrollBox = CreateFrame("Frame", nil, items)
    function items.ScrollBox:Update() end
    local row = CreateFrame("Button", nil, items.ScrollBox)
    local cell = CreateFrame("Frame", nil, row)
    cell:SetSize(300, 16)
    cell.Icon = cell:CreateTexture(nil, "ARTWORK")
    cell.Icon:SetTexture("Interface\\Icons\\Belt")
    cell.Icon:SetTexCoord(0, 1, 0, 1)
    cell.IconBorder = art(cell, list, "CellIconBorder", "OVERLAY")
    cell.Text = text(cell, "Gnomish Harm Prevention Belt")
    header.Arrow = art(header, nil, "SortArrow", "OVERLAY")

    local sell = inner(frame, list, "ItemSellFrame", "SellBackground")
    sell.CreateAuctionTabLeft = art(sell, list, "SellTabLeft")
    local display = CreateFrame("Button", nil, sell)
    sell.ItemDisplay = display
    display.Background = art(display, list, "ItemDisplayBackground")
    local headerFrame = art(display, list, "ItemHeaderFrame")
    function headerFrame:GetAtlas() return "auctionhouse-itemheaderframe" end
    display.NineSlice = R.nineSlice(display, list)
    local slot = CreateFrame("Button", nil, display)
    display.ItemButton = slot
    slot:SetSize(40, 40)
    slot.EmptyBackground = art(slot, list, "ItemIconEmpty", "BACKGROUND")
    slot.Icon = slot:CreateTexture(nil, "BORDER")
    slot.Icon:SetTexture("Interface\\Icons\\Sword")
    slot.Icon:SetTexCoord(0, 1, 0, 1)
    slot.IconBorder = art(slot, list, "ItemIconBorder", "OVERLAY")
    local gold = CreateFrame("EditBox", "BidAmountGold", sell)
    gold.left = art(gold, list, "BidLeft", "BACKGROUND")
    gold.right = art(gold, list, "BidRight", "BACKGROUND")
    BidAmountGoldMiddle = art(gold, list, "BidMiddle", "BACKGROUND")
    gold.texture = art(gold, nil, "CoinGold", "OVERLAY")
    return { frame = frame, art = list, categories = categories, weapons = weapons, header = header, slot = slot,
        gold = gold, display = display, cell = cell }
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

h.test("Windows flattens the auction house, keeps icons, texts and selection art, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = auctionHouse()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    local frame, bar = c.frame, c.frame.SearchBar
    A.eq(R.visibleChrome(frame), "", "window chrome is hidden")
    A.eq(visibleArt(c), "", "panel, field, button, category, money, header and slot art are all hidden")
    A.ok(B.same(B.border(frame.BuyTab), ns.Modern.Theme().accent), "the selected tab gets the accent")
    for _, field in ipairs({ bar.SearchBox, bar.SearchButton, bar.FilterButton, c.gold }) do
        A.ok(W.isDark(field), "field, button and dropdown become a dark field")
    end
    A.ok(not W.isDark(c.header), "a column header stays bare")
    A.ok(not R.invisible(c.header.Text, frame) and not R.invisible(c.header.Arrow, frame),
        "header text and sort arrow stay")
    A.ok(not R.invisible(c.weapons.Text, frame), "category text stays")
    A.ok(c.weapons.SelectedTexture._alpha ~= 0, "category selection art stays")
    A.ok(not R.invisible(bar.FavoritesSearchButton.Icon, frame), "the favourites star stays")
    A.ok(W.isDark(bar.FavoritesSearchButton), "the favourites button becomes a flat square")
    A.ok(not W.isDark(frame.MoneyFrameBorder), "the money stays bare")
    A.ok(not R.invisible(frame.MoneyFrameBorder.MoneyFrame.Gold, frame), "the money text stays")
    A.ok(B.border(c.categories) == nil, "an inner panel stands bare, without a border")
    A.ok(B.border(c.display) == nil, "the item display stands bare, without a border")
    A.ok(B.border(c.cell) == nil and not W.isDark(c.cell), "a name cell gets no slot field or border")
    A.ok(L.zoomed(c.cell.Icon) and not R.invisible(c.cell.Icon, frame), "a name cell keeps its cropped icon")
    A.ok(not R.invisible(c.cell.Text, frame), "a name cell keeps its name")
    A.ok(L.zoomed(c.slot.Icon), "the item icon is square-cropped")
    A.ok(not R.invisible(c.gold.texture, frame), "the coin icon of a bid box stays")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "auction house restores exactly")
end)

h.test("Windows skins a pooled category button when the category list updates", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = auctionHouse()
    W.enable(ns)
    local late = category(c.categories.ScrollBox.ScrollTarget, nil, "Armor")
    c.categories.ScrollBox:Update()
    A.ok(R.invisible(late.NormalTexture, c.frame), "the late category button loses its art")
    ns.Modern.Restore()
    local after = category(c.categories.ScrollBox.ScrollTarget, nil, "Recipes")
    c.categories.ScrollBox:Update()
    A.ok(not R.invisible(after.NormalTexture, c.frame), "nothing is skinned while the area is off")
end)
