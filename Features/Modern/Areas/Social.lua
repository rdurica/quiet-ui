local _, ns = ...

-- The social windows of the Forever UI source: the friends window (FriendsFrame, Camelot layout: a tab system over
-- the contacts, the Battle.net bar, the ignore list window and the raid tab), the raid info popup, the guild and
-- communities window (CommunitiesFrame) and the vanilla-style group finder (LFGParentFrame with its listing, browse
-- and who pages). Each takes the dark window and the shared shapes; the group finder's stone and parchment
-- backdrops are held. Friend rows, class colours, role icons, the LFG eye portrait and chat stay Blizzard's. Lists
-- are pooled, so a window is walked again when it shows or a list updates.

local Modern = ns.Modern
local Social = {}
Modern.Social = Social

-- Group finder page art by atlas: stone and parchment backdrops, inner frames and divider lines.
local FINDER_ART = { "groupfinder-background", "groupfinder-stat-stonebg", "common-insideframe",
    "groupfinder-scrollline", "groupfinder-roles-background", "common-framedivider" }
-- The communities side tabs (RightSideTabTemplate) and the raid info header art.
local SIDE_ART = { "spellbook-skilllinetab", "ui-raidinfo-header" }

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

-- `bare`: the frame has no art of its own (the group finder's pages are the visible windows inside it).
local WINDOWS = {
    FriendsFrame = { extra = Friends },
    CommunitiesFrame = {},
    LFGParentFrame = { art = FINDER_ART, bare = true },
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
        Modern.Shapes.Walk(skin, frame)
    end
end

function Social.Apply(skin)
    for _, name in ipairs(ORDER) do
        ns.Profiler.Run("modern social", Modern.Shapes.Keep, skin, _G[name], "social", Skin(WINDOWS[name]))
    end
end
