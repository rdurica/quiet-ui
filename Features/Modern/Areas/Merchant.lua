local _, ns = ...

-- The Forever 12.0 merchant window (MerchantFrame), shaped after a frame dump of the client. Its frames are named
-- globals: the item cards MerchantItemN and MerchantBuyBackItem (SlotTexture and a named NameFrame, both tinted
-- red by Blizzard for unusable items), the page and repair buttons, the money bars and the bottom tabs. Card art
-- is held, so the cards stand bare on the window panel; icons, names, prices, coins, page arrows and the close
-- button stay.

local Modern = ns.Modern
local Merchant = {}
Modern.Merchant = Merchant

-- Ten per merchant page, twelve on the buyback page.
local ITEMS = 12
local TABS = 2
-- Pixels between the item icon and its slot border.
local ICON_INSET = 3
-- Loose art on the window: the buyback page background and the bottom frame above the money bar.
local ART = { "BuybackBG", "MerchantFrameBottomLeftBorder" }
-- Square buttons whose slot art goes and whose Icon stays.
local SQUARE = { "MerchantRepairItemButton", "MerchantRepairAllButton", "MerchantGuildBankRepairButton",
    "MerchantSellAllJunkButton" }
local PAGES = { "MerchantPrevPageButton", "MerchantNextPageButton" }
-- Bars the money and extra currency sit on: held bare, so the coins are text on the window panel.
local BARS = { "MerchantMoneyInset", "MerchantMoneyBg", "MerchantExtraCurrencyInset", "MerchantExtraCurrencyBg" }

local function Hold(skin, texture)
    if ns.Usable(texture) then skin:Hold(texture) end
end

local function LayerOf(texture)
    if type(texture.GetDrawLayer) ~= "function" then return nil end
    local ok, layer = pcall(texture.GetDrawLayer, texture)
    return ok and layer or nil
end

local function Regions(frame)
    if type(frame.GetRegions) ~= "function" then return {} end
    return { frame:GetRegions() }
end

-- Unkeyed BACKGROUND art of a button (the slot behind a repair icon, the ring behind a page arrow).
local function HoldBackground(skin, button)
    for _, region in ipairs(Regions(button)) do
        if region ~= button.Icon and LayerOf(region) == "BACKGROUND" then Hold(skin, region) end
    end
end

-- An item card: slot and label art go, the name and price stand on the window panel. The item button is a bag
-- slot whose icon sits inset, so the flat border frames it without filling the card's height.
local function Item(skin, item)
    if not ns.Usable(item) then return end
    local name = type(item.GetName) == "function" and item:GetName()
    Hold(skin, item.SlotTexture)
    if name then Hold(skin, _G[name .. "NameFrame"]) end
    local button = item.ItemButton
    if not ns.Usable(button) then return end
    Modern.Bags.Item(skin, button)
    local icon = button.icon or button.Icon
    if not ns.Usable(icon) or type(icon.ClearAllPoints) ~= "function" then return end
    -- The journal remembers Blizzard's points on the first call; the icon is then anchored afresh.
    skin:Set(icon, "SetPoint", "TOPLEFT", button, "TOPLEFT", ICON_INSET, -ICON_INSET)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", ICON_INSET, -ICON_INSET)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -ICON_INSET, ICON_INSET)
end

local function Square(skin, button)
    if not ns.Usable(button) then return end
    HoldBackground(skin, button)
    skin:Panel(button)
    skin:Border(button)
end

local function Bar(skin, frame)
    if not ns.Usable(frame) then return end
    Modern.WindowChrome(skin, frame)
    Modern.Character.HoldArt(skin, frame)
end

-- The class filter: its text holder goes behind a dark field, the arrow stays.
local function Dropdown(skin, dropdown)
    if not ns.Usable(dropdown) then return end
    Hold(skin, dropdown.Background)
    skin:Panel(dropdown)
    skin:Border(dropdown)
end

function Merchant.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    Modern.Window(skin, frame)
    Modern.Header(skin, frame)
    for _, name in ipairs(ART) do Hold(skin, _G[name]) end
    for index = 1, TABS do Modern.TabChrome(skin, _G["MerchantFrameTab" .. index]) end
    for index = 1, ITEMS do Item(skin, _G["MerchantItem" .. index]) end
    Item(skin, _G.MerchantBuyBackItem)
    for _, name in ipairs(SQUARE) do Square(skin, _G[name]) end
    for _, name in ipairs(PAGES) do
        if ns.Usable(_G[name]) then HoldBackground(skin, _G[name]) end
    end
    for _, name in ipairs(BARS) do Bar(skin, _G[name]) end
    Dropdown(skin, frame.FilterDropdown)
end
