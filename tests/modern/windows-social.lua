-- The social windows of the Forever UI source: FriendsFrame (Camelot: FriendsFrameIcon, FriendsTabHeader with a
-- TabSystem and the Battle.net bar's unkeyed plate, bottom tabs, the add friend button, the IgnoreListWindow
-- ButtonFrameTemplate), RaidInfoFrame (DialogBorderDarkTemplate, DialogHeaderTemplate, header art) and the
-- vanilla-style group finder: LFGParentFrame without art of its own, its close button and tabs, and the who page
-- (PortraitFrameTemplateNoCloseButton with the stone, parchment and scroll line atlases and pooled list rows).
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

local function finder(c)
    local parent = CreateFrame("Frame", "LFGParentFrame", UIParent)
    parent:SetSize(458, 535)
    local close = CreateFrame("Button", "LFGParentFrameCloseButton", parent)
    P.buttonArt(c, close, { GetNormalTexture = "RedButton-Exit" }, "art")
    P.tab(c, parent, "LFGParentFrameTab3")
    local who = P.window(c, "LFGWhoListFrame", parent)
    who.CloseButton = nil
    for key, atlas in pairs({ BackgroundArt = "groupfinder-background", headerBackground = "groupfinder-Stat-StoneBG",
        insideFrame = "common-insideframe", BarTop = "groupfinder-ScrollLine" }) do
        who[key] = P.texture(c, who, "art", atlas:lower(), "BACKGROUND", { atlas = true })
    end
    who.FilterDropdown = P.dropdown(c, who)
    local box = P.scrollBox(who)
    c.row = P.listRow(c, box.ScrollTarget)
    c.who = who
    return parent
end

h.test("Windows skins the friends window, raid info and the group finder, and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    local c = P.new()
    local frame, info, parent = friends(c), raidInfo(c), finder(c)
    local before = L.snapshot(R.all(UIParent))
    W.enable(ns)
    A.ok(W.isDark(frame) and W.isDark(c.ignore), "the friends window and its ignore list are dark windows")
    A.ok(W.isDark(info), "the raid info popup is a dark window")
    A.ok(W.isDark(c.who), "the who page is a dark window with its own header band")
    A.ok(not W.isDark(parent), "the group finder frame itself gets no panel")
    A.eq(P.visibleArt(c, R), "", "portraits, tab, plate, dialog, stone, parchment and row art are held")
    A.eq(P.hiddenKeep(c, R), "", "names, tags, icons, arrows and selection stay")
    A.ok(W.isDark(c.add) and W.isDark(c.contacts), "buttons and the contacts tab are flat")
    local point, relative = W.point(info.Header.Text)
    A.ok(point[1] == "TOP" and relative == info, "the raid info title sits in the header band")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the social windows restore exactly")
end)

h.test("Windows skins a who list row the list adds later", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    finder(c)
    W.enable(ns)
    local late = P.new()
    P.listRow(late, c.who.ScrollBox.ScrollTarget)
    c.who.ScrollBox:Update()
    A.eq(P.visibleArt(late, R), "", "the new row's plate is held")
end)
