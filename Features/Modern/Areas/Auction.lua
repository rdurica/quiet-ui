local _, ns = ...

-- The Forever 12.0 auction house (AuctionHouseFrame, Blizzard_AuctionHouseUI), shaped after a frame dump of the
-- client. Its pages repeat a few templates (inner panels with NineSlice and a Background, three-piece buttons and
-- input fields, minimal scroll bars, item buttons, category buttons), so the window is walked and each frame is
-- skinned by its shape. Item icons, texts, prices, coins, sort arrows and row highlights stay.

local Modern = ns.Modern
local Auction = {}
Modern.Auction = Auction

-- The sell pages' tab-shaped strip above the item slot.
local SELL_TAB = { "CreateAuctionTabLeft", "CreateAuctionTabMiddle", "CreateAuctionTabRight" }
-- Flat square buttons that keep their icon.
local SQUARE = { "FavoritesSearchButton", "RefreshButton" }
-- The ornate frame of an item header (an unnamed texture).
local HEADER_ATLAS = "auctionhouse-itemheaderframe"

local bare = setmetatable({}, { __mode = "k" })    -- column header buttons and the money inset: art held, no field

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) then skin:Hold(texture) end
end

local function AtlasOf(texture)
    if type(texture.GetAtlas) ~= "function" then return nil end
    local ok, atlas = pcall(texture.GetAtlas, texture)
    return ok and atlas or nil
end

local function Regions(frame)
    if type(frame.GetRegions) ~= "function" then return {} end
    return { frame:GetRegions() }
end

local function Number(value)
    return type(value) == "number" and not ns.IsSecret(value) and value or 0
end

-- A result row's name cell: an icon and quality border beside the name text, far wider than a slot.
local function IsCell(frame)
    if not IsTexture(rawget(frame, "IconBorder")) or not IsTexture(frame.Icon or frame.icon) then return false end
    local text = rawget(frame, "Text")
    if ns.Usable(text) and type(text.GetObjectType) == "function" and text:GetObjectType() == "FontString" then
        return true
    end
    local width = type(frame.GetWidth) == "function" and Number(frame:GetWidth()) or 0
    local height = type(frame.GetHeight) == "function" and Number(frame:GetHeight()) or 0
    return height > 0 and width > height * 2
end

-- What the shared shapes do not know: name cells, bare inner panels, category buttons, the sell tab strip, item
-- header frames, the favourite and refresh buttons and the bare column headers.
local function Particular(skin, frame)
    -- A name cell keeps a cropped icon beside its name; the slot treatment would stretch over the whole column.
    if IsCell(frame) then
        skin:Hold(frame.IconBorder)
        skin:Icon(frame.Icon or frame.icon)
        return true
    end
    -- Inner panels (category list, result lists, the sell form, the item display) stand bare on the panel.
    if ns.Usable(rawget(frame, "NineSlice")) and not Modern.Shapes.IsField(frame) then bare[frame] = true end
    -- A category button: the button art goes, the tree lines, highlight and selection stay.
    if IsTexture(frame.Lines) and IsTexture(frame.NormalTexture) then
        skin:Hold(frame.NormalTexture)
        return true
    end
    for _, key in ipairs(SELL_TAB) do Hold(skin, frame[key]) end
    for _, region in ipairs(Regions(frame)) do
        if IsTexture(region) and AtlasOf(region) == HEADER_ATLAS then skin:Hold(region) end
    end
    for _, key in ipairs(SQUARE) do
        if ns.Usable(frame[key]) then Modern.Shapes.Square(skin, frame[key]) end
    end
    local header = frame.HeaderContainer
    if ns.Usable(header) then
        Modern.Character.Rule(skin, header)
        for _, button in ipairs(Modern.Character.Children(header)) do bare[button] = true end
    end
    return false
end

local OPTIONS = { bare = bare, shape = Particular }

function Auction.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    Modern.Window(skin, frame)
    Modern.Header(skin, frame)
    -- The money stays bare text, like the bags' money bar.
    if ns.Usable(frame.MoneyFrameInset) then bare[frame.MoneyFrameInset] = true end
    if ns.Usable(frame.MoneyFrameBorder) then Modern.Character.HoldArt(skin, frame.MoneyFrameBorder) end
    -- Rows, category buttons and column headers are pooled: a list is walked again when it updates.
    Modern.Shapes.Keep(skin, frame, "auction", function(owner, window) Modern.Shapes.Walk(owner, window, OPTIONS) end,
        OPTIONS)
end
