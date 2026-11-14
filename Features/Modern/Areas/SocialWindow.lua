local _, ns = ...

-- The friends window of the current Forever client (SocialUIFrame; FriendsFrame stays hidden there). It is a
-- movable dark window: the metal frame, portrait, fades and gamepad glow are held, the Battle.net bar loses its
-- plate, the four side tabs become icon tabs, and friends stand bare (Social/Rows in SocialRows.lua). Pooled rows
-- change on every list update, so rows are skinned again through the list hook of Shapes.Keep.

local Modern = ns.Modern
local Window = {}
Modern.SocialWindow = Window

local KEY = "SocialUIFrame"
-- Loose art by atlas: the top and bottom fades and the dividers of every list page.
local ART = { "friends-frame-topTexBG", "friends-frame-bottomTexBG", "friends-frame-infoBG", "perks-divider-short" }
local RAID_INFO_ART = { "TopInset", "BottomInset", "TopInsetEdge" }
-- Tertiary square buttons (BattleNetMenuButton, a row's PartyButton) stand as bare glyphs.
local PLATE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
end

local function KindOf(frame)
    return type(frame.GetObjectType) == "function" and frame:GetObjectType() or nil
end

function Window.HoldPlates(skin, button)
    for _, getter in ipairs(PLATE_GETTERS) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok then Hold(skin, texture) end
        end
    end
end

-- The atlas or file name of a texture, lower case.
local function FileOf(texture)
    if not IsTexture(texture) then return "" end
    for _, getter in ipairs({ "GetAtlas", "GetTexture" }) do
        if type(texture[getter]) == "function" then
            local ok, value = pcall(texture[getter], texture)
            if ok and type(value) == "string" then return value:lower() end
        end
    end
    return ""
end

local function IsBareGlyph(frame)
    if KindOf(frame) ~= "Button" or type(frame.GetNormalTexture) ~= "function" then return false end
    local ok, texture = pcall(frame.GetNormalTexture, frame)
    return ok and FileOf(texture):find("button-tertiary-square", 1, true) ~= nil
end

-- The search bar (common-searchbar-a plate, its icons stay) and the broadcast input (nine common-input pieces):
-- a dark field with a thin border.
local function Input(skin, frame)
    if KindOf(frame) ~= "EditBox" then return false end
    local plate = rawget(frame, "Background")
    if IsTexture(plate) and FileOf(plate):find("searchbar", 1, true) then
        Hold(skin, plate)
    elseif IsTexture(rawget(frame, "MiddleBorder")) then
        Modern.Character.HoldArt(skin, frame)
    else
        return false
    end
    skin:Panel(frame)
    skin:Border(frame)
    return true
end

local function Shape(skin, frame)
    if Modern.SocialRows.Row(skin, frame) or Modern.SocialRows.Header(skin, frame) then return true end
    if Input(skin, frame) then return true end
    if IsBareGlyph(frame) then
        Window.HoldPlates(skin, frame)
        return true
    end
    -- A side tab: an unkeyed button with its icon and selected art.
    if IsTexture(rawget(frame, "SelectedTexture")) and IsTexture(rawget(frame, "Icon")) and not Modern.IsCheckbox(frame) then
        Modern.Character.IconTab(skin, frame)
        return true
    end
    return false
end

local OPTS = { shape = Shape }

-- The Battle.net bar: the infoBG plate and the tag pill go; the status dropdown and the tag are walked.
local function Bar(skin, bar)
    if not ns.Usable(bar) then return end
    Hold(skin, rawget(bar, "Background"))
    local controls = rawget(bar, "ControlsContainer")
    if ns.Usable(controls) then Hold(skin, rawget(controls, "BattleNetBackground")) end
end

local function Skin(skin, frame)
    Modern.Window(skin, frame, KEY)
    Modern.Header(skin, frame)
    Hold(skin, rawget(frame, "TopFade"))
    Hold(skin, rawget(frame, "BottomFade"))
    local glow = rawget(frame, "FrameGlow")
    if ns.Usable(glow) then Hold(skin, rawget(glow, "GlowTexture")) end
    Bar(skin, rawget(frame, "BattleNetBar"))
    local info = rawget(frame, "RaidInfoFrame")
    if ns.Usable(info) then
        for _, key in ipairs(RAID_INFO_ART) do Hold(skin, rawget(info, key)) end
    end
    Modern.Shapes.HoldArt(skin, frame, ART)
    Modern.Shapes.Walk(skin, frame, OPTS)
end

local function List(skin, box)
    Modern.SocialRows.Pool(skin, box)
end

function Window.Apply(skin)
    local frame = rawget(_G, KEY)
    if not ns.Usable(frame) then return end
    OPTS.list = List
    Modern.Shapes.Keep(skin, frame, "social", Skin, OPTS)
end
