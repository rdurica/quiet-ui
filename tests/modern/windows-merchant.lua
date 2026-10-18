-- The Forever 12.0 merchant window, shaped after a frame dump of the client: MerchantFrame (PortraitFrame chrome
-- with an Inset) with the loose BuybackBG and MerchantFrameBottomLeftBorder art, MerchantFrameTab1..2 (panel tab
-- art), item cards MerchantItemN with a SlotTexture, a named NameFrame and an ItemButton (icon, IconBorder,
-- NormalTexture), MerchantRepairAllButton (unkeyed BACKGROUND slot and an Icon), MerchantNextPageButton (unkeyed
-- BACKGROUND ring and the arrow art), MerchantMoneyInset (InsetFrame), MerchantMoneyBg (named three-piece art)
-- and a FilterDropdown with a Background and an Arrow.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local B = h.lib("modern-bags")
B.use(R)

local function art(parent, list, name, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture("Interface\\MerchantFrame\\" .. name)
    texture:SetAlpha(0.95)
    if list then list[#list + 1] = texture end
    return texture
end

local function text(parent, value)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetText(value)
    return font
end

local function item(frame, list, name)
    local card = CreateFrame("Frame", name, frame)
    card.SlotTexture = art(card, list, "SlotTexture", "BACKGROUND")
    _G[name .. "NameFrame"] = art(card, list, "LabelSlot", "BACKGROUND")
    card.Name = text(card, name)
    local button = CreateFrame("Button", name .. "ItemButton", card)
    card.ItemButton = button
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetTexture("Interface\\Icons\\Sword")
    button.icon:SetTexCoord(0, 1, 0, 1)
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.IconBorder = art(button, list, "IconBorder", "OVERLAY")
    button.NormalTexture = art(button, list, "Quickslot")
    return card
end

local function merchant()
    local list = {}
    local frame = R.window("MerchantFrame")
    BuybackBG = art(frame, list, "BuybackBG", "BACKGROUND")
    MerchantFrameBottomLeftBorder = art(frame, list, "BotFrame", "OVERLAY")
    MerchantPageText = text(frame, "Page 1 of 4")
    local first = R.tab(frame, "MerchantFrameTab1")
    R.tab(frame, "MerchantFrameTab2").LeftActive:Hide()
    first.Left:Hide()
    local cutlass = item(frame, list, "MerchantItem1")
    item(frame, list, "MerchantBuyBackItem")

    local repair = CreateFrame("Button", "MerchantRepairAllButton", frame)
    art(repair, list, "RepairSlot", "BACKGROUND")
    repair.Icon = art(repair, nil, "RepairAll", "BORDER")
    local next = CreateFrame("Button", "MerchantNextPageButton", frame)
    art(next, list, "PageRing", "BACKGROUND")
    local arrow = art(next, nil, "NextPage-Up")
    next.Text = text(next, "Next")

    local inset = R.inset(frame, list)
    MerchantMoneyInset = inset
    local money = CreateFrame("Frame", "MerchantMoneyBg", frame)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do art(money, list, "MoneyBg" .. key, "BACKGROUND") end
    local coins = CreateFrame("Frame", "MerchantMoneyFrame", frame)
    coins.Gold = text(coins, "4")

    local filter = CreateFrame("Button", nil, frame)
    frame.FilterDropdown = filter
    filter.Background = art(filter, list, "DropdownTextHolder", "BACKGROUND")
    filter.Arrow = art(filter, nil, "DropdownArrow", "OVERLAY")
    return { frame = frame, art = list, tab = first, cutlass = cutlass, repair = repair, arrow = arrow,
        next = next, coins = coins, filter = filter }
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

h.test("Windows flattens the merchant window, keeps icons, texts and arrows, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = merchant()
    local before = L.snapshot(R.all(c.frame))
    W.enable(ns)
    local frame = c.frame
    A.eq(R.visibleChrome(frame), "", "window chrome is hidden")
    A.eq(visibleArt(c), "", "card, slot, button, money, dropdown and loose art are all hidden")
    A.ok(B.same(B.border(c.tab), ns.Modern.Theme().accent), "the selected tab gets the accent")
    A.ok(not W.isDark(c.cutlass) and B.border(c.cutlass) == nil, "an item card stays bare")
    local point, relative = W.point(c.cutlass.ItemButton.icon)
    A.deep(point, { "TOPLEFT", "TOPLEFT", 3, -3 }, "the item icon sits inset in its slot")
    A.ok(relative == c.cutlass.ItemButton, "the icon inset follows the item button")
    A.ok(L.zoomed(c.cutlass.ItemButton.icon), "the item icon is square-cropped")
    A.ok(not R.invisible(c.cutlass.Name, frame), "the item name stays")
    A.ok(W.isDark(c.repair) and not R.invisible(c.repair.Icon, frame), "the repair button is flat and keeps its icon")
    A.ok(not R.invisible(c.arrow, frame) and not R.invisible(c.next.Text, frame), "the page arrow and label stay")
    A.ok(not W.isDark(_G.MerchantMoneyBg), "the money stays bare")
    A.ok(not R.invisible(c.coins.Gold, frame), "the money text stays")
    A.ok(not R.invisible(_G.MerchantPageText, frame), "the page text stays")
    A.ok(W.isDark(c.filter) and not R.invisible(c.filter.Arrow, frame), "the filter is a dark field with its arrow")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "merchant window restores exactly")
end)
