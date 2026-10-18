local _, ns = ...

-- The Forever 12.0 auction house (AuctionHouseFrame, Blizzard_AuctionHouseUI), shaped after a frame dump of the
-- client. Its pages repeat a few templates (inner panels with NineSlice and a Background, three-piece buttons and
-- input fields, minimal scroll bars, item buttons, category buttons), so the window is walked and each frame is
-- skinned by its shape. Item icons, texts, prices, coins, sort arrows and row highlights stay.

local Modern = ns.Modern
local Auction = {}
Modern.Auction = Auction

local MAX_DEPTH = 12
-- The sell pages' tab-shaped strip above the item slot.
local SELL_TAB = { "CreateAuctionTabLeft", "CreateAuctionTabMiddle", "CreateAuctionTabRight" }
-- Flat square buttons that keep their icon.
local SQUARE = { "FavoritesSearchButton", "RefreshButton" }
-- The ornate frame of an item header (an unnamed texture).
local HEADER_ATLAS = "auctionhouse-itemheaderframe"

local styled = setmetatable({}, { __mode = "k" })  -- AuctionHouseFrame -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })
local headers = setmetatable({}, { __mode = "k" }) -- column header button -> true
local bare = setmetatable({}, { __mode = "k" })    -- inner panel without a border

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) then skin:Hold(texture) end
end

local function KindOf(frame)
    return type(frame.GetObjectType) == "function" and frame:GetObjectType() or nil
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

-- UIPanelButton, input field or column header: Left / Middle / Right art (the bid boxes use left / right and a
-- named Middle). Headers stay bare, the rest become a dark field with a thin border.
local function Field(skin, frame)
    for _, key in ipairs({ "Left", "Middle", "Center", "Right", "left", "right" }) do Hold(skin, frame[key]) end
    local name = type(frame.GetName) == "function" and frame:GetName()
    if name then Hold(skin, _G[name .. "Middle"]) end
    if headers[frame] then return end
    skin:Panel(frame)
    skin:Border(frame)
end

local function IsField(frame)
    return (IsTexture(frame.Left) or IsTexture(frame.left)) and (IsTexture(frame.Right) or IsTexture(frame.right))
end

-- An inner panel (InsetFrameTemplate-like): its Background, Bg and NineSlice are held, the window panel shows
-- through and a thin border keeps the sections apart. A nested window gets the full window treatment.
local function Panel(skin, frame)
    if frame.PortraitContainer then
        Modern.Window(skin, frame)
        return
    end
    Modern.WindowChrome(skin, frame)
    for _, key in ipairs(SELL_TAB) do Hold(skin, frame[key]) end
    for _, region in ipairs(Regions(frame)) do
        if IsTexture(region) and AtlasOf(region) == HEADER_ATLAS then skin:Hold(region) end
    end
    if not bare[frame] then skin:Border(frame) end
end

-- One frame by its shape; true when its children need no walk.
local function Shape(skin, frame)
    if IsTexture(frame.LeftActive) and IsTexture(frame.Left) then
        Modern.TabChrome(skin, frame)
        return true
    end
    if ns.Usable(frame.Track) then
        Modern.Character.ScrollBar(skin, frame)
        return true
    end
    if IsTexture(frame.IconBorder) and (IsTexture(frame.Icon) or IsTexture(frame.icon)) then
        Hold(skin, frame.EmptyBackground)
        Modern.Bags.Item(skin, frame)
        return true
    end
    if IsField(frame) then
        Field(skin, frame)
        return true
    end
    -- A category button: the button art goes, the tree lines, highlight and selection stay.
    if IsTexture(frame.Lines) and IsTexture(frame.NormalTexture) then
        skin:Hold(frame.NormalTexture)
        return true
    end
    -- The filter and duration dropdowns: the arrow stays.
    if KindOf(frame) == "Button" and IsTexture(frame.Background) and not frame.NineSlice then
        skin:Hold(frame.Background)
        skin:Panel(frame)
        skin:Border(frame)
    end
    if ns.Usable(frame.NineSlice) then Panel(skin, frame) end
    for _, key in ipairs(SQUARE) do
        if ns.Usable(frame[key]) then skin:Button(frame[key]) end
    end
    local header = frame.HeaderContainer
    if ns.Usable(header) then
        Modern.Character.Rule(skin, header)
        for _, button in ipairs(Modern.Character.Children(header)) do headers[button] = true end
    end
    return false
end

local function Walk(skin, frame, depth)
    if not ns.Usable(frame) or depth > MAX_DEPTH then return end
    if Shape(skin, frame) then return end
    for _, child in ipairs(Modern.Character.Children(frame)) do Walk(skin, child, depth + 1) end
end

-- Rows, category buttons and column headers are pooled: a list is walked again when its ScrollBox updates.
local function WatchLists(root, frame, depth)
    if not ns.Usable(frame) or depth > MAX_DEPTH then return end
    local box = frame.ScrollBox
    if ns.Usable(box) and not hooked[box] and type(box.Update) == "function" then
        hooked[box] = true
        pcall(hooksecurefunc, box, "Update", function()
            local skin = styled[root]
            if skin then ns.Run("modern auction", Walk, skin, frame, 0) end
        end)
    end
    for _, child in ipairs(Modern.Character.Children(frame)) do WatchLists(root, child, depth + 1) end
end

local function Watch(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    if type(frame.HookScript) == "function" then
        pcall(frame.HookScript, frame, "OnShow", function()
            local skin = styled[frame]
            if skin then ns.Run("modern auction", Walk, skin, frame, 0) end
        end)
    end
    WatchLists(frame, frame, 0)
end

function Auction.Apply(skin, frame)
    if not ns.Usable(frame) then return end
    styled[frame] = skin
    skin:Remember(frame, "modern auction", function() styled[frame] = nil end)
    Modern.Window(skin, frame)
    -- The money stays bare text, like the bags' money bar.
    if ns.Usable(frame.MoneyFrameInset) then bare[frame.MoneyFrameInset] = true end
    if ns.Usable(frame.MoneyFrameBorder) then Modern.Character.HoldArt(skin, frame.MoneyFrameBorder) end
    Walk(skin, frame, 0)
    Watch(frame)
end
