-- The social windows of the Forever UI source: FriendsFrame (Camelot: FriendsFrameIcon, FriendsTabHeader with a
-- TabSystem and the Battle.net bar's unkeyed plate, bottom tabs, the add friend button, the IgnoreListWindow
-- ButtonFrameTemplate) and RaidInfoFrame (DialogBorderDarkTemplate, DialogHeaderTemplate, header art). The group
-- finder has its own file, windows-finder.lua.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")

local function friends(c)
    local frame = P.window(c, "FriendsFrame")
    P.texture(c, frame, "art", "Battlenet-Portrait", "OVERLAY", { name = "FriendsFrameIcon" })
    local header = CreateFrame("Frame", "FriendsTabHeader", frame)
    frame.FriendsTabHeader = header
    header.TabSystem = CreateFrame("Frame", nil, header)
    c.contacts = P.tab(c, header.TabSystem, "FriendsTabContacts")
    header.BattlenetFrame = CreateFrame("Frame", nil, header)
    P.texture(c, header.BattlenetFrame, "art", "battlenet-friends-main", "BACKGROUND")
    P.text(c, header.BattlenetFrame, "Anaxia#2611")
    P.tab(c, frame, "FriendsFrameTab1")
    c.add = P.panelButton(c, frame, "Add Friend", "FriendsFrameAddFriendButton")
    local ignore = P.window(c, nil, frame)
    frame.IgnoreListWindow = ignore
    c.ignore = ignore
    return frame
end

local function raidInfo(c)
    local frame = P.dialog(c, "RaidInfoFrame")
    P.texture(c, frame, "art", "UI-RaidInfo-Header", "ARTWORK")
    return frame
end

h.test("Windows skins the friends window and raid info, and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = P.new()
    local frame, info = friends(c), raidInfo(c)
    local before = L.snapshot(R.all(UIParent))
    W.enable(ns)
    A.ok(W.isDark(frame) and W.isDark(c.ignore), "the friends window and its ignore list are dark windows")
    A.ok(W.isDark(info), "the raid info popup is a dark window")
    A.eq(P.visibleArt(c, R), "", "portraits, tab, plate and dialog art are held")
    A.eq(P.hiddenKeep(c, R), "", "names, tags, icons and selection stay")
    A.ok(W.isDark(c.add) and W.isDark(c.contacts), "buttons and the contacts tab are flat")
    local point, relative = W.point(info.Header.Text)
    A.ok(point[1] == "TOP" and relative == info, "the raid info title sits in the header band")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the social windows restore exactly")
end)
