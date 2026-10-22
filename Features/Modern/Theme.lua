local _, ns = ...

-- Theme data. An entry here is a new theme; the background alpha comes from the setting.

local Modern = ns.Modern

local ORDER = { "dark" }
-- Panels let 10 % of the world through.
local BG_ALPHA = 0.9
local THEMES = {
    dark = {
        -- Graphite with a cool cast rather than black, so a window does not read as a hole in the world.
        bg = { 0.075, 0.08, 0.09 },
        -- Opaque: a translucent border over a translucent fill lets the world tint it.
        border = { 0.33, 0.33, 0.33, 1 },
        -- A window's outer edge, quieter than `border`.
        outline = { 0.22, 0.23, 0.25, 1 },
        -- The darkening laid over a sunken inset.
        sunk = { 0, 0, 0, 0.3 },
        accent = { 0.95, 0.75, 0.25 },
        -- The close cross, and its colour under the mouse.
        glyph = { 0.75, 0.75, 0.75, 1 },
        -- Body text that Blizzard inked for parchment (NPC dialogs).
        text = { 0.9, 0.9, 0.9 },
        danger = { 0.85, 0.25, 0.20, 1 },
        -- A section strip (quest log zone headers): a step above the panel, with an accent edge.
        strip = { 0.16, 0.165, 0.18, 1 },
        -- A tooltip: a grey a step under the header band, nearly opaque so text stays readable over the world.
        tip = { 0.11, 0.115, 0.13, 0.95 },
        -- An empty bag or action slot: a socket a step above the panel (top colour, darker towards the bottom), quieter edge.
        well = { 0.13, 0.135, 0.15, 0.9 },
        wellEdge = { 0.22, 0.225, 0.24, 1 },
        -- The track under a Blizzard stat bar fill: near black, so it blends with the fill art's dark rim and rounded ends.
        track = { 0.02, 0.02, 0.03, 0.9 },
        bar = "Interface\\Buttons\\WHITE8X8",
    },
}

function Modern.Themes()
    return ns.Copy(ORDER)
end

-- A fresh copy of the active theme with the panel background alpha applied.
function Modern.Theme()
    local theme = ns.Copy(THEMES[ns.Settings.ModernTheme()] or THEMES.dark)
    theme.bg[4] = BG_ALPHA
    return theme
end
