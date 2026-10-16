-- Modern XP "Show on big XP gain": quest XP and a gain of at least 5 % of the level show the XP bar
-- for 5 s, even when it is Only on hover; mob-sized gains do not. Off without Modernize, without the
-- XP area or with the option unchecked.
local h = ...

local function setup(t, modernize)
    local ns, mock = t.ns, t.mock
    QuietUICharDB = { modernize = modernize }
    t.boot()
    MainStatusTrackingBarContainer = CreateFrame("Frame", nil, UIParent)
    ns.Faders.Find(false)
    ns.Hit = function() return false end
    ns.World.ShowAll = function() return false end
    ns.World.XPForced = function() return false end
    mock.xp = 100
    UnitXP = function() return mock.xp end
    UnitXPMax = function() return 1000 end
    mock:fire("PLAYER_XP_UPDATE", "player") -- baseline
    return MainStatusTrackingBarContainer
end

local function tick(t) t.ns.NextFadeTick(); t.ns.Faders.Update(1) end

h.test("a gain of 5 % of the level shows the Only on hover XP bar for 5 s; a mob-sized gain does not", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local bar = setup(t, { enabled = true })
    A.ok(ns.Settings.OnlyOnHover("xp"), "XP is Only on hover by default")
    tick(t); A.eq(bar._alpha, 0, "hidden before any gain")
    mock.xp = 130; mock:fire("PLAYER_XP_UPDATE", "player")
    tick(t); A.eq(bar._alpha, 0, "a 3 % gain (a mob) stays on hover")
    mock.xp = 180; mock:fire("PLAYER_XP_UPDATE", "player")
    tick(t); A.eq(bar._alpha, 1, "a 5 % gain shows the bar")
    mock.now = mock.now + 4.5
    tick(t); A.eq(bar._alpha, 1, "still shown inside 5 s")
    mock.now = mock.now + 1
    tick(t); A.eq(bar._alpha, 0, "hidden again after 5 s")
    mock.xp = 20; mock:fire("PLAYER_XP_UPDATE", "player")
    tick(t); A.eq(bar._alpha, 0, "a lower value (level up) is no big gain")
end)

h.test("quest XP shows the Only on hover XP bar for 5 s", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local bar = setup(t, { enabled = true })
    mock:fire("QUEST_TURNED_IN", 1, 500)
    mock.now = mock.now + 4.5
    tick(t); A.eq(bar._alpha, 1, "shown 4.5 s after quest XP")
    mock.now = mock.now + 1
    tick(t); A.eq(bar._alpha, 0, "hidden after 5 s")
end)

h.test("no big gain reveal without Modernize, without the XP area or with Show on big XP gain off", function(t)
    local A, mock = t.assert, t.mock
    for _, modernize in ipairs({ {}, { enabled = true, status = false }, { enabled = true, xpGain = false } }) do
        local bar = setup(t, modernize)
        mock.xp = mock.xp + 200; mock:fire("PLAYER_XP_UPDATE", "player")
        tick(t); A.eq(bar._alpha, 0, "stays on hover")
    end
end)
