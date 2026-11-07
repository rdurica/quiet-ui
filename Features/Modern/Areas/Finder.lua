local _, ns = ...

-- The vanilla-style group finder (LFGParentFrame with its listing, browse and who pages). The pages are the visible
-- windows inside the bare frame: they take the dark window and the shared shapes. Held: the stone and parchment
-- backdrops, the round portrait and its ring. Side tabs become icon tabs, role buttons keep their icon without box
-- or border, refresh and search are bare grey icons, delist a thin cross, results stand bare and their groupings
-- become section strips. Role and party icons and the minimap eye (outside the frame) stay Blizzard's. Frames are
-- recognised by their keys and art, never by name; the walk runs again when the finder shows or a list updates.

local Modern = ns.Modern
local Finder = {}
Modern.Finder = Finder

-- Page art by atlas: stone and parchment backdrops, inner frames, divider lines, the portrait and its ring.
local FINDER_ART = { "groupfinder-background", "groupfinder-stat-stonebg", "common-insideframe",
    "groupfinder-scrollline", "groupfinder-roles-background", "common-framedivider", "groupfinder-browse-stone",
    "eye-portrait" }
local PORTRAIT_KEYS = { "Portrait", "portrait", "PortraitFrame" }
local BACKDROP_KEYS = { "BackgroundArt" }
-- The plus / minus sign of a grouping, and its strip: the art fills the lower 28 px of a 36 px row.
local SIGN = 10
local GROUPING_DROP = 4

local signs = setmetatable({}, { __mode = "k" })   -- grouping row -> skin while applied
local hooked = setmetatable({}, { __mode = "k" })

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if ns.Usable(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
end

local function HoldKeys(skin, frame, keys)
    for _, key in ipairs(keys) do Hold(skin, rawget(frame, key)) end
end

local function KindOf(frame)
    return type(frame.GetObjectType) == "function" and frame:GetObjectType() or nil
end

-- Lower-case atlas or file of a button's normal texture.
local function PlateOf(button)
    if type(button.GetNormalTexture) ~= "function" then return nil end
    local ok, texture = pcall(button.GetNormalTexture, button)
    if not ok or not ns.Usable(texture) then return nil end
    for _, read in ipairs({ "GetAtlas", "GetTexture" }) do
        if type(texture[read]) == "function" then
            local okRead, value = pcall(texture[read], texture)
            if okRead and type(value) == "string" then return value:lower() end
        end
    end
end

local function PaintSign(row)
    local skin = signs[row]
    if not skin then return end
    local parts = skin:Own(row, "finder sign", function()
        return { Modern.GlyphLine(row, SIGN, 2), Modern.GlyphLine(row, 2, SIGN) }
    end)
    for _, line in ipairs(parts) do
        line:ClearAllPoints()
        line:SetPoint("CENTER", row.CollapseIcon, "CENTER", 0, 0)
        line:SetColorTexture(unpack(Modern.Theme().accent))
    end
    parts[1]:Show()
    parts[2]:SetShown(row.ExpandIcon:IsShown() == true)
end

-- Blizzard shows one of two icons; the sign follows the plus icon.
local function Sign(skin, row)
    Hold(skin, row.CollapseIcon)
    Hold(skin, row.ExpandIcon)
    signs[row] = skin
    skin:Remember(row, "finder sign", function() signs[row] = nil end)
    PaintSign(row)
    if hooked[row] then return end
    hooked[row] = true
    local function Again() ns.Profiler.Run("modern finder", PaintSign, row) end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do pcall(hooksecurefunc, row.ExpandIcon, method, Again) end
end

-- A browse result (keyed ResultBG): a listing stands bare with a quiet hover and Blizzard's selection; a grouping
-- (Groups, Players) becomes a section strip with an accent sign.
local function Result(skin, row)
    if not IsTexture(rawget(row, "ResultBG")) then return false end
    Hold(skin, row.ResultBG)
    Hold(skin, rawget(row, "Highlight"))
    Modern.Shapes.Hover(skin, row)
    if ns.Usable(rawget(row, "CollapseIcon")) and ns.Usable(rawget(row, "ExpandIcon")) then
        Modern.Strip(skin, row, Modern.Character.STRIP, GROUPING_DROP)
        Sign(skin, row)
    end
    return false
end

-- A Button with a keyed Icon over a gold or red square plate (refresh, search, delist).
local function PlateButton(skin, button)
    local plate = PlateOf(button)
    if not plate or not plate:find("iconbutton", 1, true) then return false end
    if plate:find("iconbutton-red", 1, true) then
        -- The red X icon goes with its plate; the thin cross replaces both.
        Hold(skin, rawget(button, "Icon"))
        Modern.GlyphButton(skin, button, "delist", Modern.CrossParts, "danger")
    else
        Modern.IconButton(skin, button)
    end
    return true
end

-- A role button: round border and box art held, the role icon stays; its checkbox child is walked on.
local function RoleButton(skin, button)
    Hold(skin, rawget(button, "Border"))
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok then Hold(skin, texture) end
        end
    end
end

local function Shape(skin, frame)
    if Result(skin, frame) then return true end
    local kind = KindOf(frame)
    if kind == "CheckButton" and IsTexture(rawget(frame, "SelectedTexture")) and IsTexture(rawget(frame, "Icon"))
        and not Modern.IsCheckbox(frame) then
        Modern.Character.IconTab(skin, frame)
        return true
    end
    if kind ~= "Button" then return false end
    if IsTexture(rawget(frame, "Icon")) and PlateButton(skin, frame) then return true end
    if IsTexture(rawget(frame, "icon")) and IsTexture(rawget(frame, "Border")) then RoleButton(skin, frame) end
    return false
end

local OPTS = { shape = Shape }

local function Skin(skin, frame)
    Modern.CloseButton(skin, frame)
    HoldKeys(skin, frame, PORTRAIT_KEYS)
    Modern.Shapes.HoldArt(skin, frame, FINDER_ART)
    for _, key in ipairs({ "LFGBrowseFrame", "LFGListingFrame", "LFGWhoListFrame" }) do
        local page = rawget(_G, key)
        if ns.Usable(page) then HoldKeys(skin, page, BACKDROP_KEYS) end
    end
    Modern.Shapes.Walk(skin, frame, OPTS)
end

function Finder.Apply(skin)
    ns.Profiler.Run("modern finder", Modern.Shapes.Keep, skin, _G.LFGParentFrame, "finder", Skin, OPTS)
end
