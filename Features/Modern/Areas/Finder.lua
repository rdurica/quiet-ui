local _, ns = ...

-- The vanilla-style group finder (LFGParentFrame with its listing, browse and who pages; keys as the Forever client
-- has them). The pages are the visible windows inside the bare frame: they take the dark window and the shared
-- shapes. Held: the stone and parchment backdrops and the round eye portrait (LFGParentFramePortrait, a button with
-- its flipbooks). The side tabs (ListingTab, BrowsingTab, WhoListingTab) become icon tabs, role buttons keep their
-- icon without plate or box, refresh (RefreshButton) and search (WhoSearch) are bare grey icons, delist
-- (DelistButton) a thin cross, results stand bare and their groupings become section strips. Role and party icons
-- and the minimap eye (outside the frame) stay Blizzard's. The walk runs again when the finder shows or a list
-- updates.

local Modern = ns.Modern
local Finder = {}
Modern.Finder = Finder

-- Page art by atlas: stone and parchment backdrops, inner frames and divider lines.
local FINDER_ART = { "groupfinder-background", "groupfinder-stat-stonebg", "common-insideframe",
    "groupfinder-scrollline", "groupfinder-roles-background", "common-framedivider" }
-- UIMenuButtonStretchTemplate pieces of the delist button.
local STRETCH_KEYS = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "MiddleLeft", "MiddleRight",
    "BottomMiddle", "MiddleMiddle" }
-- The pages whose rock backdrop (<page>Bg) is reached only by name: on the browse page the key Bg is its stone header.
local PAGES = { "LFGListingFrame", "LFGBrowseFrame", "LFGWhoListFrame" }
-- A category button lights up under the mouse: the same faint wash as flat buttons, over its picture only.
local CATEGORY_HOVER = { 1, 1, 1, 0.07 }
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

-- The key a frame has on its parent (the finder's buttons are pooled or unnamed).
local function KeyOf(frame, key)
    local parent = type(frame.GetParent) == "function" and frame:GetParent()
    return parent and type(parent) == "table" and rawget(parent, key) == frame
end

-- The own listing's delist button: its stretch plate and red X go, a thin cross turns red under the mouse.
local function Delist(skin, button)
    HoldKeys(skin, button, STRETCH_KEYS)
    Hold(skin, rawget(button, "Icon"))
    Modern.GlyphButton(skin, button, "delist", Modern.CrossParts, "danger")
end

-- A role button (its NormalTexture is the role icon): the round plate goes, the icon and its dim cover stay, and
-- its checkbox is walked on its own so the button itself is never taken for a dropdown.
local function RoleButton(skin, button)
    local icon = PlateOf(button)
    if not icon or icon:find("ui-lfg-roleicon", 1, true) ~= 1 then return false end
    Hold(skin, rawget(button, "Background"))
    Modern.Shapes.Walk(skin, button, Finder.opts)
    return true
end

-- A listing category (Dungeons, Quests & Zones, ...): the rounded gold cover goes, the picture stands flat in a thin
-- square border that fits it, with a faint wash under the mouse.
local function Category(skin, button)
    local cover, picture = rawget(button, "Cover"), rawget(button, "Icon")
    if not IsTexture(cover) or not IsTexture(picture) then return false end
    Hold(skin, cover)
    for _, getter in ipairs({ "GetPushedTexture", "GetHighlightTexture" }) do
        if type(button[getter]) == "function" then
            local ok, texture = pcall(button[getter], button)
            if ok and texture ~= picture then Hold(skin, texture) end
        end
    end
    skin:Border(button, nil, picture)
    local wash = skin:Own(button, "category hover", function()
        local texture = button:CreateTexture(nil, "HIGHLIGHT")
        texture:SetAllPoints(picture)
        return texture
    end)
    if wash then
        wash:SetColorTexture(unpack(CATEGORY_HOVER))
        wash:Show()
    end
    return true
end

-- A page is a flat window: one even panel, its inset gets no sunken fill; its children are walked here.
local function Page(skin, frame)
    local name = type(frame.GetName) == "function" and frame:GetName()
    for _, page in ipairs(PAGES) do
        if name == page then
            Modern.Window(skin, frame, nil, nil, true)
            Modern.Header(skin, frame)
            Modern.Shapes.Walk(skin, frame, Finder.opts)
            return true
        end
    end
    return false
end

local function Shape(skin, frame)
    if Page(skin, frame) or Result(skin, frame) then return true end
    -- A side tab (ListingTab, BrowsingTab, WhoListingTab).
    if IsTexture(rawget(frame, "SelectedTexture")) and IsTexture(rawget(frame, "Icon")) and not Modern.IsCheckbox(frame) then
        Modern.Character.IconTab(skin, frame)
        return true
    end
    if KindOf(frame) ~= "Button" then return false end
    if KeyOf(frame, "RefreshButton") or KeyOf(frame, "WhoSearch") then
        Modern.IconButton(skin, frame)
        return true
    end
    if KeyOf(frame, "DelistButton") then
        Delist(skin, frame)
        return true
    end
    return Category(skin, frame) or RoleButton(skin, frame)
end

local OPTS = { shape = Shape }
Finder.opts = OPTS

local function Skin(skin, frame)
    Modern.CloseButton(skin, frame)
    -- The whole portrait button: its flipbook frames show and hide the eye art inside it.
    Hold(skin, rawget(_G, "LFGParentFramePortrait"))
    Modern.Shapes.HoldArt(skin, frame, FINDER_ART)
    for _, name in ipairs(PAGES) do Hold(skin, rawget(_G, name .. "Bg")) end
    Modern.Shapes.Walk(skin, frame, OPTS)
end

local function Apply(skin)
    local parent = _G.LFGParentFrame
    local again = Modern.Shapes.Keep(skin, parent, "finder", Skin, OPTS)
    if not again then return end
    -- A page fills its views (the listing categories) in its own OnShow, after the finder's: walk again then.
    for _, name in ipairs(PAGES) do
        local page = rawget(_G, name)
        if ns.Usable(page) then
            Modern.Shapes.Watch(page, "finder", again)
            Modern.Shapes.Watch(rawget(page, "CategoryView"), "finder", again)
        end
    end
end

function Finder.Apply(skin)
    ns.Profiler.Run("modern finder", Apply, skin)
end
