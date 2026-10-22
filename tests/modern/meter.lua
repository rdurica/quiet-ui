-- Modern damage meter: session windows lose their art for the theme panel, rows get the flat bar and keep
-- Blizzard's colour, pooled rows are skinned on ScrollBox updates, and restore gives everything back.
local h = ...
local W = h.lib("modern-windows")
local D = h.lib("modern-meter")
local I = h.lib("modern-icons")

h.test("Damage meter windows get the theme panel and rows the flat bar in Blizzard's colour", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "meter")
    local window = D.window(1)
    W.enable(ns)
    A.alpha(window.Header, 0, "header art is held")
    A.alpha(window.MinimizeContainer.Background, 0, "window background art is held")
    A.ok(W.isDark(window), "window has the theme panel")
    A.eq(window.row:GetStatusBarTexture():GetTexture(), ns.Modern.Theme().bar, "row has the flat bar")
    A.deep({ window.row:GetStatusBarColor() }, D.CLASS, "row keeps Blizzard's colour")
    A.alpha(window.row.Background, 0, "row track art is held")
end)

h.test("Damage meter rows pooled after apply are skinned when the ScrollBox updates, and not after restore", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "meter")
    local window = D.window(1)
    W.enable(ns)
    local late = D.row(window)
    window.MinimizeContainer.ScrollBox:Update()
    A.eq(late:GetStatusBarTexture():GetTexture(), ns.Modern.Theme().bar, "late row is skinned")
    ns.Modern.Restore()
    local after = D.row(window)
    window.MinimizeContainer.ScrollBox:Update()
    A.eq(after:GetStatusBarTexture():GetTexture(), "Interface\\DamageMeter\\Bar", "restored area skins nothing")
end)

h.test("Damage meter restore returns the art, bar textures and hides the panel", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "meter")
    local window = D.window(1)
    W.enable(ns)
    ns.Modern.Restore()
    A.alpha(window.Header, 0.9, "header art is back")
    A.alpha(window.MinimizeContainer.Background, 0.5, "window background art is back")
    A.alpha(window.row.Background, 0.8, "row track art is back")
    A.eq(window.row:GetStatusBarTexture():GetTexture(), "Interface\\DamageMeter\\Bar", "row texture is back")
    A.falsy(W.isDark(window) and window._regions[#window._regions]:IsShown(), "own panel is hidden")
    W.enable(ns)
    A.alpha(window.Header, 0, "a second apply holds the art again")
    A.ok(W.isDark(window), "and shows the panel again")
end)

h.test("Damage meter windows made by the load-on-demand addon are skinned when it loads", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "meter")
    W.enable(ns)
    local window = D.window(2)
    ns.Modern.AddonLoaded("Blizzard_DamageMeter")
    A.alpha(window.Header, 0, "window art is held")
    A.eq(window.row:GetStatusBarTexture():GetTexture(), ns.Modern.Theme().bar, "row is skinned")
end)

local function glyphs(button)
    local n = 0
    for _, region in ipairs(button._regions) do
        if region._color and region._shown and region._layer == "OVERLAY" then n = n + 1 end
    end
    return n
end

h.test("Damage meter header controls lose their gold art for bare grey glyphs and get it back on restore", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "meter")
    local window = D.window(1)
    W.enable(ns)
    local glyph = ns.Modern.Theme().glyph
    A.alpha(window.DamageMeterTypeDropdown.Arrow, 0, "type dropdown arrow art is held")
    A.eq(glyphs(window.DamageMeterTypeDropdown), 2, "type dropdown shows a chevron")
    A.alpha(window.SettingsDropdown.Icon, 0, "settings art is held")
    A.eq(glyphs(window.SettingsDropdown), 3, "settings shows three bars")
    A.alpha(window.MinimizeButton.normal, 0, "minimize art is held")
    A.eq(glyphs(window.MinimizeButton), 1, "minimize shows one bar")
    A.alpha(window.SessionDropdown.Background, 0, "session button art is held")
    A.alpha(window.SessionDropdown.Arrow, 0, "session hover arrow is held")
    A.deep({ window.SessionDropdown.SessionName:GetTextColor() }, glyph, "session letter is grey")
    A.deep({ window.SessionTimer:GetTextColor() }, glyph, "timer is grey")
    A.ok(I.zoomed(window.row:GetParent().Icon.Icon), "row icon is cropped")
    ns.Modern.Restore()
    A.alpha(window.SettingsDropdown.Icon, 1, "settings art is back")
    A.alpha(window.MinimizeButton.normal, 1, "minimize art is back")
    A.eq(glyphs(window.SettingsDropdown), 0, "glyphs are hidden")
    A.deep({ window.SessionTimer:GetTextColor() }, D.GOLD, "timer colour is back")
end)
