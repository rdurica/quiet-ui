-- Theme data and the active theme with the background opacity applied.
local h = ...

h.test("Themes lists dark first", function(t)
    local list = t.ns.Modern.Themes()
    t.assert.type(list, "table")
    t.assert.eq(list[1], "dark")
end)

h.test("default theme is dark with background alpha 0.75", function(t)
    local A = t.assert
    QuietUICharDB = {}
    local theme = t.ns.Modern.Theme()
    A.near(theme.bg[1], 0.075); A.near(theme.bg[2], 0.08); A.near(theme.bg[3], 0.09)
    A.near(theme.bg[4], 0.75)
    A.type(theme.border, "table"); A.type(theme.accent, "table")
    A.eq(theme.border[4], 1, "border is opaque so the world cannot tint it")
    A.eq(theme.bar, "Interface\\Buttons\\WHITE8X8")
end)

h.test("opacity 50 and 90 give background alpha 0.5 and 0.9", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = { modernize = { opacity = 50 } }
    A.near(ns.Modern.Theme().bg[4], 0.5)
    QuietUICharDB = { modernize = { opacity = 90 } }
    A.near(ns.Modern.Theme().bg[4], 0.9)
    QuietUICharDB = { modernize = { opacity = 75 } }
    A.near(ns.Modern.Theme().bg[4], 0.75)
end)

h.test("an invalid opacity falls back to 0.75", function(t)
    local A, ns = t.assert, t.ns
    for _, bad in ipairs({ 60, 0, 100, "90", true }) do
        QuietUICharDB = { modernize = { opacity = bad } }
        A.near(ns.Modern.Theme().bg[4], 0.75, 1e-6, "opacity " .. tostring(bad))
    end
end)

h.test("an unknown theme name uses dark", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = { modernize = { theme = "dark" } }
    local dark = ns.Modern.Theme()
    QuietUICharDB = { modernize = { theme = "no-such-theme" } }
    local theme = ns.Modern.Theme()
    A.deep(theme, dark)
    A.eq(ns.Settings.ModernTheme(), "dark", "the getter falls back as well")
end)

h.test("changing a returned theme does not change the theme data", function(t)
    local A, ns = t.assert, t.ns
    QuietUICharDB = {}
    local theme = ns.Modern.Theme()
    theme.bg[4] = 0; theme.accent[1] = 0
    local again = ns.Modern.Theme()
    A.near(again.bg[4], 0.75); A.near(again.accent[1], 0.95)
end)
