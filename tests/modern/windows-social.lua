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

-- The browse page's pooled results (Blizzard_LFGVanilla_Browse.xml): a grouping header (common-button-list-
-- collapseExpand with plus / minus icons), a nested listing (common-button-list-mid2 with hover and selection) and
-- a plain one (groupfinder-highlightbar).
local function results(c, target)
    local head = CreateFrame("Button", nil, target)
    head:SetSize(312, 36)
    head.ResultBG = P.texture(c, head, "art", "common-button-list-collapseExpand", "BACKGROUND", { atlas = true })
    head.Highlight = P.texture(c, head, "art", "common-button-list-collapseExpand", "HIGHLIGHT", { atlas = true })
    head.ExpandIcon = P.texture(c, head, "art", "common-button-list-plus", "ARTWORK", { atlas = true })
    head.CollapseIcon = P.texture(c, head, "art", "common-button-list-minus", "ARTWORK", { atlas = true })
    head.ExpandIcon:Hide()
    head.CategoryLabel = P.text(c, head, "Groups")
    local nested = CreateFrame("Button", nil, target)
    nested.ResultBG = P.texture(c, nested, "art", "common-button-list-mid2", "BACKGROUND", { atlas = true })
    nested.Highlight = P.texture(c, nested, "art", "common-button-list-mid2-hover", "BACKGROUND", { atlas = true })
    nested.Selected = P.texture(c, nested, "keep", "common-button-list-mid2-selected", "OVERLAY", { atlas = true })
    nested.Name = P.text(c, nested, "Milk Ninja")
    nested.PartyIcon = P.texture(c, nested, "keep", "groupfinder-icon-leader", "ARTWORK", { atlas = true })
    local plain = CreateFrame("Button", nil, target)
    plain.ResultBG = P.texture(c, plain, "art", "groupfinder-highlightbar", "BACKGROUND", { atlas = true })
    plain.Name = P.text(c, plain, "Leif Jorunn")
    return head, nested, plain
end

local function striped(frame, strip)
    for _, region in ipairs(frame._regions) do
        if region._color and region._color[1] == strip[1] and region._shown ~= false then return true end
    end
    return false
end

-- Shown accent strokes of a sign: 1 minus, 2 plus.
local function sign(frame, accent)
    local count = 0
    for _, region in ipairs(frame._regions) do
        local col = region._color
        if region._shown and (region._alpha or 1) > 0 and col and col[1] == accent[1]
            and (region._w == 10 or region._h == 10) then count = count + 1 end
    end
    return count
end

h.test("Windows lets group finder results stand bare and turns their groupings into strips with a sign", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = P.new()
    local parent = finder(c)
    local browse = P.window(c, "LFGBrowseFrame", parent)
    local box = P.scrollBox(browse)
    local head, nested, plain = results(c, box.ScrollTarget)
    W.enable(ns)
    local theme = ns.Modern.Theme()
    A.eq(P.visibleArt(c, R), "", "result plates, hover art, grouping art and Blizzard's signs are held")
    A.eq(P.hiddenKeep(c, R), "", "names, labels, leader icons and the selection stay")
    A.ok(P.hasHover(nested) and P.hasHover(plain), "a listing lights up under the mouse")
    A.ok(striped(head, theme.strip), "a grouping is a section strip")
    A.eq(sign(head, theme.accent), 1, "an expanded grouping shows a minus")
    head.CollapseIcon:Hide()
    head.ExpandIcon:Show()
    A.eq(sign(head, theme.accent), 2, "a collapsed grouping shows a plus")
    local late = P.new()
    local later = results(late, box.ScrollTarget)
    box:Update()
    A.eq(P.visibleArt(late, R), "", "results pooled in later stand bare on the list update")
    A.ok(striped(later, theme.strip), "a later grouping is a strip")
    ns.Modern.Restore()
    A.ok(not striped(head, theme.strip) and sign(head, theme.accent) == 0, "Restore removes the strip and the sign")
end)
