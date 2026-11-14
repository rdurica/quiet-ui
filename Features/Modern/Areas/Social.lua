local _, ns = ...

-- The social windows of the Forever UI source: the friends window (FriendsFrame, Camelot layout: a tab system over
-- the contacts, the Battle.net bar, the ignore list window and the raid tab), the raid info popup, the guild and
-- communities window (CommunitiesFrame). Each takes the dark window and the shared shapes. Friend rows and class
-- colours stay Blizzard's (the group finder is Finder.lua). Lists are pooled, so a window is walked again when it
-- shows or a list updates.

local Modern = ns.Modern
local Social = {}
Modern.Social = Social

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

local WINDOWS = {
    FriendsFrame = { extra = Friends },
    CommunitiesFrame = {},
    RaidInfoFrame = { dialog = true },
}
local ORDER = { "FriendsFrame", "RaidInfoFrame", "CommunitiesFrame" }

local function Skin(def)
    return function(skin, frame)
        if def.dialog then
            Modern.Dialog(skin, frame)
        else
            Modern.Window(skin, frame)
            Modern.Header(skin, frame)
        end
        if def.extra then def.extra(skin, frame) end
        Modern.Shapes.HoldArt(skin, frame, SIDE_ART)
        Modern.Shapes.Walk(skin, frame, def.opts)
    end
end

function Social.Apply(skin, only)
    for _, name in ipairs(ORDER) do
        if not only or name == only then
            local def = WINDOWS[name]
            ns.Profiler.Run("modern social", Modern.Shapes.Keep, skin, _G[name], "social", Skin(def), def.opts)
        end
    end
end
