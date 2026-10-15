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
