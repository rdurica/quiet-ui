-- The Recent Allies page of the friends window (SocialUIFrame.RecentAlliesList, fixture tests/lib/modern-social.lua).
-- An ally row, from the in-game frame stack: a pooled Button with a keyed Background, an unkeyed highlight, the
-- character texts, the online dot and a PartyButton (tertiary square with ActionIcon); it has no FriendName and no
-- group header. It stands bare like a friend row: card and plates held, a quiet rule and a hover wash, texts, the dot
-- and the action icon stay.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local P = h.lib("modern-shapes")
local S = h.lib("modern-social")
local Q = h.lib("modern-social-read")
local Rows = h.lib("modern-social-rows")
Rows.use(P)
S.use(P, Rows)

local function ally(c, target, name)
    local row = CreateFrame("Button", nil, target)
    row:SetSize(364.5, 80)
    row.Background = P.texture(c, row, "art", "friends-card-battleNet", "BACKGROUND", { atlas = true })
    local highlight = P.texture(c, row, "art", "friends-card-selected", "HIGHLIGHT", { atlas = true })
    row.GetHighlightTexture = function() return highlight end
    row.CharacterData = CreateFrame("Frame", nil, row)
    for _, key in ipairs({ "Name", "Level", "Class", "MostRecentInteraction", "Location" }) do
        row.CharacterData[key] = P.text(c, row.CharacterData, key == "Name" and name or key)
    end
    row.OnlineStatusIcon = P.texture(c, row, "keep", "friends-status-online", "OVERLAY", { atlas = true })
    row.PartyButton = Rows.square(c, row, "ActionIcon", "friends-icon-friendsAvailable")
    return row
end

local function setup(t)
    local ns = t.ns
    W.area(ns, "windows")
    local c = P.new()
    local f = S.build(c)
    local box = f.frame.RecentAlliesList.ScrollBox
    local a = P.new()
    local rows = { ally(a, box.ScrollTarget, "Muddy Gragas"), ally(a, box.ScrollTarget, "Soulless Gingerdwarf") }
    return ns, f, box, a, rows
end

h.test("Windows lets Recent Allies rows stand bare: card and party plate held, a rule and a hover wash", function(t)
    local A, mock = t.assert, t.mock
    local ns, f, box, a, rows = setup(t)
    local before = L.snapshot(R.all(f.frame))
    W.enable(ns)
    box:Update()
    A.eq(Q.unheld(a.art), "", "ally cards, highlight and party plates are held")
    A.eq(Q.heldKeep(a.keep), "", "names, texts, the online dot and the action icon stay")
    for index, row in ipairs(rows) do
        A.eq(Q.rules(row), 1, "ally row " .. index .. " has one quiet rule")
        A.eq(Q.washes(row), 1, "ally row " .. index .. " has one hover wash")
    end
    box:Update()
    for index, row in ipairs(rows) do
        A.eq(Q.rules(row), 1, "ally row " .. index .. " keeps one rule after the list updates again")
    end
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.deep(L.diff(before), {}, "the Recent Allies rows restore exactly")
end)
