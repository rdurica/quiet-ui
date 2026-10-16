-- Modernize settings: getters, presets, Reset default.
local h = ...
local L = h.lib("modern")

h.test("Modernize is on only for enabled == true", function(t)
    local A, ns = t.assert, t.ns
    local cases = { { nil, false }, { {}, false }, { { enabled = true }, true }, { { enabled = false }, false },
        { { enabled = "yes" }, false }, { { enabled = 1 }, false }, { "x", false } }
    for i, case in ipairs(cases) do
        QuietUICharDB = { modernize = case[1] }
        A.eq(ns.Settings.Modernize(), case[2], "case " .. i)
    end
    QuietUICharDB = {}
    A.eq(ns.Settings.Modernize(), false, "no modernize table")
end)

h.test("ModernArea is off with Modernize off, on by default, off only for an explicit false", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = { modernize = { bars = true } }
    A.eq(ns.Settings.ModernArea("bars"), false, "Modernize off")
    QuietUICharDB = { modernize = { enabled = true } }
    A.eq(ns.Settings.ModernArea("bars"), true, "default on")
    A.eq(ns.Settings.ModernArea("anything-registered-later"), true, "any key without a list in Settings")
    QuietUICharDB = { modernize = { enabled = true, bars = false } }
    A.eq(ns.Settings.ModernArea("bars"), false)
    A.eq(ns.Settings.ModernArea("units"), true)
end)

h.test("ModernOpacity is 0.5, 0.75 or 0.9", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    A.near(ns.Settings.ModernOpacity(), 0.75)
    QuietUICharDB = { modernize = { opacity = 50 } }; A.near(ns.Settings.ModernOpacity(), 0.5)
    QuietUICharDB = { modernize = { opacity = 75 } }; A.near(ns.Settings.ModernOpacity(), 0.75)
    QuietUICharDB = { modernize = { opacity = 90 } }; A.near(ns.Settings.ModernOpacity(), 0.9)
    QuietUICharDB = { modernize = { opacity = 33 } }; A.near(ns.Settings.ModernOpacity(), 0.75)
end)

h.test("ModernClassColors defaults to on, off only for an explicit false", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    A.eq(ns.Settings.ModernClassColors(), true)
    QuietUICharDB = { modernize = { classColors = false } }
    A.eq(ns.Settings.ModernClassColors(), false)
    QuietUICharDB = { modernize = { classColors = true } }
    A.eq(ns.Settings.ModernClassColors(), true)
end)

h.test("ModernTheme defaults to dark", function(t)
    QuietUICharDB = {}
    t.assert.eq(t.ns.Settings.ModernTheme(), "dark")
end)

h.test("modernize is a preset key: a preset saved on one character applies on another", function(t)
    local A, ns = t.assert, t.ns
    QuietUIDB = {}
    local modernize = { enabled = true, theme = "dark", opacity = 90, classColors = false, bars = false }
    QuietUICharDB = { modernize = modernize }
    local id = ns.Settings.SavePreset(nil, "Modern", { layoutName = "Raid", layoutType = 1 }, QuietUICharDB)
    A.deep(ns.Settings.Presets()[id].settings.modernize, modernize, "stored in the preset")
    A.ok(ns.Settings.Presets()[id].settings.modernize ~= modernize, "the preset keeps its own copy")
    QuietUICharDB = {}
    A.eq(ns.Settings.Modernize(), false, "other character starts off")
    A.ok(ns.Settings.ActivatePreset(id))
    A.deep(QuietUICharDB.modernize, modernize)
    A.eq(ns.Settings.Modernize(), true)
    A.near(ns.Settings.ModernOpacity(), 0.9)
    A.eq(ns.Settings.ModernArea("bars"), false)
end)

h.test("windowPoints is character only: not in presets", function(t)
    local A, ns = t.assert, t.ns
    QuietUIDB = {}
    QuietUICharDB = { windowPoints = { CharacterFrame = { "CENTER", "CENTER", 1, 2 } }, modernize = { enabled = true } }
    local id = ns.Settings.SavePreset(nil, "P", { layoutName = "Raid", layoutType = 1 }, QuietUICharDB)
    A.eq(ns.Settings.Presets()[id].settings.windowPoints, nil)
end)

h.test("Reset default clears modernize, Modernize is off, windowPoints is kept", function(t)
    local A, ns = t.assert, t.ns
    QuietUIDB = {}
    QuietUICharDB = { windowPoints = { ZzA = { "CENTER", "CENTER", 1, 2 } }, modernize = { enabled = true, opacity = 90 } }
    ns.Settings.ActivatePreset(nil, {})
    A.eq(QuietUICharDB.modernize, nil, "modernize cleared")
    A.eq(ns.Settings.Modernize(), false)
    A.deep(QuietUICharDB.windowPoints, { ZzA = { "CENTER", "CENTER", 1, 2 } })
end)
