-- Theme data and the active theme with the fixed panel background alpha.
local h = ...

h.test("Themes lists dark first", function(t)
    local list = t.ns.Modern.Themes()
    t.assert.type(list, "table")
    t.assert.eq(list[1], "dark")
end)

h.test("default theme is dark with background alpha 0.9", function(t)
    local A = t.assert
    QuietUICharDB = {}
    local theme = t.ns.Modern.Theme()
    A.near(theme.bg[1], 0.075); A.near(theme.bg[2], 0.08); A.near(theme.bg[3], 0.09)
    A.near(theme.bg[4], 0.9)
    A.type(theme.border, "table"); A.type(theme.accent, "table")
    A.eq(theme.border[4], 1, "border is opaque so the world cannot tint it")
    A.eq(theme.bar, "Interface\\Buttons\\WHITE8X8")
end)

h.test("a stored opacity from an older version is ignored: background alpha stays 0.9", function(t)
    local A, ns = t.assert, t.ns
    for _, old in ipairs({ 50, 75, 90, 60, "90", true }) do
        QuietUICharDB = { modernize = { opacity = old } }
        A.near(ns.Modern.Theme().bg[4], 0.9, 1e-6, "opacity " .. tostring(old))
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
    A.near(again.bg[4], 0.9); A.near(again.accent[1], 0.95)
end)
