local _, ns = ...

-- The social windows of the Forever UI source: the friends window (FriendsFrame, Camelot layout: a tab system over
-- the contacts, the Battle.net bar, the ignore list window and the raid tab), the raid info popup, the guild and
-- communities window (CommunitiesFrame) and the vanilla-style group finder (LFGParentFrame with its listing, browse
-- and who pages). Each takes the dark window and the shared shapes; the group finder's stone and parchment
-- backdrops are held, its results stand bare and their groupings become section strips. Friend rows, class colours, role icons, the LFG eye portrait and chat stay Blizzard's. Lists
-- are pooled, so a window is walked again when it shows or a list updates.

local Modern = ns.Modern
local Social = {}
Modern.Social = Social

-- Group finder page art by atlas: stone and parchment backdrops, inner frames and divider lines.
local FINDER_ART = { "groupfinder-background", "groupfinder-stat-stonebg", "common-insideframe",
    "groupfinder-scrollline", "groupfinder-roles-background", "common-framedivider" }
-- The communities side tabs (RightSideTabTemplate) and the raid info header art.
local SIDE_ART = { "spellbook-skilllinetab", "ui-raidinfo-header" }
-- The plus / minus sign of a grouping, and its strip: the art fills the lower 28 px of a 36 px row.
local SIGN = 10
local GROUPING_DROP = 4

local signs = setmetatable({}, { __mode = "k" })   -- grouping row -> skin while applied
local hooked = setmetatable({}, { __mode = "k" })

local function Hold(skin, texture)
    if ns.Usable(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
end

local function Friends(skin, frame)
    Hold(skin, _G.FriendsFrameIcon)
    local header = frame.FriendsTabHeader
    if ns.Usable(header) then
        Modern.TabSystemChrome(skin, header)
        -- The Battle.net bar's plate is one unkeyed texture; the tag, status and broadcast stay.
        Modern.Character.HoldArt(skin, header.BattlenetFrame)
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
    local function Again() ns.Profiler.Run("modern social", PaintSign, row) end
    for _, method in ipairs({ "Show", "Hide", "SetShown" }) do pcall(hooksecurefunc, row.ExpandIcon, method, Again) end
end

-- A browse result (keyed ResultBG): a listing stands bare with a quiet hover and Blizzard's selection; a grouping
-- (Groups, Players) becomes a section strip with an accent sign.
local function Result(skin, row)
    if not ns.Usable(rawget(row, "ResultBG")) then return false end
    Hold(skin, row.ResultBG)
    Hold(skin, rawget(row, "Highlight"))
    Modern.Shapes.Hover(skin, row)
    if ns.Usable(rawget(row, "CollapseIcon")) and ns.Usable(rawget(row, "ExpandIcon")) then
        Modern.Strip(skin, row, Modern.Character.STRIP, GROUPING_DROP)
        Sign(skin, row)
    end
    return false
end

-- `bare`: the frame has no art of its own (the group finder's pages are the visible windows inside it).
local WINDOWS = {
    FriendsFrame = { extra = Friends },
    CommunitiesFrame = {},
    LFGParentFrame = { art = FINDER_ART, bare = true, opts = { shape = Result } },
    RaidInfoFrame = { dialog = true },
}
local ORDER = { "FriendsFrame", "RaidInfoFrame", "CommunitiesFrame", "LFGParentFrame" }

local function Skin(def)
    return function(skin, frame)
        if def.dialog then
            Modern.Dialog(skin, frame)
        elseif def.bare then
            Modern.CloseButton(skin, frame)
        else
            Modern.Window(skin, frame)
            Modern.Header(skin, frame)
        end
        if def.extra then def.extra(skin, frame) end
        Modern.Shapes.HoldArt(skin, frame, def.art or SIDE_ART)
        Modern.Shapes.Walk(skin, frame, def.opts)
    end
end

function Social.Apply(skin)
    for _, name in ipairs(ORDER) do
        local def = WINDOWS[name]
        ns.Profiler.Run("modern social", Modern.Shapes.Keep, skin, _G[name], "social", Skin(def), def.opts)
    end
end
