local _, ns = ...

-- Theme data. An entry here is a new theme; the background alpha comes from the setting.

local Modern = ns.Modern

local ORDER = { "dark" }
local THEMES = {
    dark = {
        bg = { 0.05, 0.05, 0.05 },
        -- Opaque: a translucent border over a translucent fill lets the world tint it.
        border = { 0.33, 0.33, 0.33, 1 },
        accent = { 0.95, 0.75, 0.25 },
        -- The close cross, and its colour under the mouse.
        glyph = { 0.75, 0.75, 0.75, 1 },
        -- Body text that Blizzard inked for parchment (NPC dialogs).
        text = { 0.9, 0.9, 0.9 },
        danger = { 0.85, 0.25, 0.20, 1 },
        -- A section strip (quest log zone headers): a step above the panel, with an accent edge.
        strip = { 0.16, 0.16, 0.16, 1 },
        -- A tooltip: a grey a step under the header band, nearly opaque so text stays readable over the world.
        tip = { 0.11, 0.11, 0.12, 0.95 },
        -- An empty bag slot: a socket a step above the panel (top colour, darker towards the bottom), quieter edge.
        well = { 0.13, 0.13, 0.13, 0.9 },
        wellEdge = { 0.22, 0.22, 0.22, 1 },
        bar = "Interface\\Buttons\\WHITE8X8",
    },
}

function Modern.Themes()
    return ns.Copy(ORDER)
end

-- A fresh copy of the active theme with the background opacity applied.
function Modern.Theme()
    local theme = ns.Copy(THEMES[ns.Settings.ModernTheme()] or THEMES.dark)
    theme.bg[4] = ns.Settings.ModernOpacity()
    return theme
end
