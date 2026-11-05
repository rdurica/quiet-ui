-- Movable windows must not replace Blizzard's scripts: the saved point comes back through one
-- HookScript("OnShow") per frame (inert after release), and Reset positions only re-anchors active windows.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")

local function point(f)
    local p, _, rp, x, y = f:GetPoint(1)
    return { p, rp, x, y }
end

-- A window with a Blizzard OnShow script of its own; counts SetScript and ClearAllPoints.
local function blizzard(name)
    local f = W.window(name)
    f.blizzardShows = 0
    f:SetScript("OnShow", function(self) self.blizzardShows = self.blizzardShows + 1 end)
    f.spy = L.watchScripts(f)
    f.clears = 0
    local clear = f.ClearAllPoints
    f.ClearAllPoints = function(self, ...) self.clears = self.clears + 1; return clear(self, ...) end
    return f
end

h.test("MakeMovable, ReleaseMovable and ResetPositions never call SetScript on the Blizzard window", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local f = blizzard("ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.drag(f, "CENTER", "CENTER", 30, 40)
    ns.Modern.ReleaseMovable(f)
    ns.Modern.MakeMovable(f, "ZzWindow")
    ns.Modern.ResetPositions()
    ns.Modern.ReleaseMovable(f)
    A.eq(f.spy.n, 0, "SetScript was called on the window for: " .. table.concat(f.spy.names, ","))
end)

h.test("Blizzard's own OnShow still runs once per show, with or without the movable hook", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local f = blizzard("ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    f:Hide(); f:Show()
    A.eq(f.blizzardShows, 1, "own OnShow ran once while movable")
    ns.Modern.ReleaseMovable(f)
    f:Hide(); f:Show()
    A.eq(f.blizzardShows, 2, "own OnShow still runs after release")
end)

h.test("the saved point is applied once per show however often the window was made movable", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = { windowPoints = { ZzWindow = { "CENTER", "CENTER", 10, 20 } } }
    t.boot()
    local f = blizzard("ZzWindow")
    f:Hide()
    ns.Modern.MakeMovable(f, "ZzWindow")
    ns.Modern.ReleaseMovable(f)
    ns.Modern.MakeMovable(f, "ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    L.blizzardPoint(f, "TOPLEFT", 0, -116)
    f.clears = 0
    f:Show()
    A.deep(point(f), { "CENTER", "CENTER", 10, 20 }, "saved point wins over Blizzard's on show")
    A.eq(f.clears, 1, "one hook, one placement per show")
    A.eq(f.spy.n, 0, "no SetScript on the window")
end)

h.test("after ReleaseMovable showing the window does not touch its points", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = { windowPoints = { ZzWindow = { "CENTER", "CENTER", 10, 20 } } }
    t.boot()
    local f = blizzard("ZzWindow")
    ns.Modern.MakeMovable(f, "ZzWindow")
    ns.Modern.ReleaseMovable(f)
    L.blizzardPoint(f, "TOPLEFT", 3, -4)
    f.clears = 0
    f:Hide(); f:Show()
    A.eq(f.clears, 0, "the hook is inert")
    A.deep(point(f), { "TOPLEFT", "TOPLEFT", 3, -4 })
    A.eq(f.spy.n, 0)
end)

h.test("ResetPositions clears saved points but re-anchors only windows whose movable entry is active", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    t.boot()
    local on, off = W.window("ZzOn"), W.window("ZzOff")
    ns.Modern.MakeMovable(on, "ZzOn"); ns.Modern.MakeMovable(off, "ZzOff")
    L.drag(on, "CENTER", "CENTER", 1, 2)
    L.drag(off, "CENTER", "CENTER", 3, 4)
    ns.Modern.ReleaseMovable(off)
    L.blizzardPoint(off, "TOP", 5, 6)           -- Blizzard owns this window again
    ns.Modern.ResetPositions()
    A.eq(QuietUICharDB.windowPoints, nil, "saved points cleared")
    A.deep(point(on), { "TOPLEFT", "TOPLEFT", 31, -71 }, "active window returns to its original point")
    A.deep(point(off), { "TOP", "TOP", 5, 6 }, "released window is left where Blizzard put it")
end)

h.test("ResetPositions in combat leaves a released window alone when combat ends", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUICharDB = {}
    t.boot()
    local on, off = W.window("ZzOn"), W.window("ZzOff")
    ns.Modern.MakeMovable(on, "ZzOn"); ns.Modern.MakeMovable(off, "ZzOff")
    ns.Modern.ReleaseMovable(off)
    L.blizzardPoint(off, "TOP", 5, 6)
    mock.state.combat = true
    ns.Modern.ResetPositions()
    mock.state.combat = false
    mock:fire("PLAYER_REGEN_ENABLED")
    A.deep(point(off), { "TOP", "TOP", 5, 6 }, "released window stays with Blizzard")
    A.deep(point(on), { "TOPLEFT", "TOPLEFT", 31, -71 })
end)

h.test("Windows and Map areas make Blizzard windows movable without SetScript, and area off keeps it so", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local character, spellbook = W.window("CharacterFrame"), W.window("PlayerSpellsFrame")
    CharacterFrame, PlayerSpellsFrame = character, spellbook
    local map = R.worldMap()
    local spies = { L.watchScripts(character), L.watchScripts(spellbook), L.watchScripts(map) }
    W.enable(ns)
    L.drag(character, "CENTER", "CENTER", 8, 9)
    character:Hide(); character:Show()
    A.deep(point(character), { "CENTER", "CENTER", 8, 9 }, "saved point returns on show")
    QuietUICharDB.modernize.windows = false
    QuietUICharDB.modernize.map = false
    ns.Modern.Apply()
    ns.Modern.ResetPositions()
    ns.Modern.Restore()
    for i, spy in ipairs(spies) do
        A.eq(spy.n, 0, "window " .. i .. " got SetScript for: " .. table.concat(spy.names, ","))
    end
end)
