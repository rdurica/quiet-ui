-- Modern unit frames: bars widened into the portrait space, the level in a small square box; the player keeps
-- a square portrait there.
-- Fixture geometry: bars 91 x 11 (left 0, right 91, top 11, bottom 0), portrait 100 wide from 0, frame origin 0.
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

h.test("player bars start right of a square bordered portrait and come back on restore", function(t)
    local A, ns = t.assert, t.ns
    local player = U.frames()[1]
    local p = U.parts(player)
    local before = { U.points(p.health), U.points(p.mana), U.points(p.level), U.points(p.portrait) }
    enable(ns)
    A.deep(U.points(p.health), {
        { "TOPLEFT", player, "BOTTOMLEFT", 43, 11 },
        { "BOTTOMRIGHT", player, "BOTTOMLEFT", 91, 0 },
    }, "health keeps its right edge and starts after the portrait and a 2 px gap")
    A.deep(U.points(p.mana), {
        { "TOPLEFT", player, "BOTTOMLEFT", 43, 1 },
        { "BOTTOMRIGHT", player, "BOTTOMLEFT", 91, -15 },
    }, "power 16 px tall, its top border on the health bar's bottom border")
    local rim = U.points(p.portrait)[1][2]
    A.deep(U.points(rim), { { "TOPLEFT", player, "BOTTOMLEFT", 0, 26 } }, "rim at the outer edge, level with the name strip's top")
    A.deep({ rim:GetSize() }, { 41, 41 }, "rim square, from power bottom to the name strip's top")
    A.deep(rim._color, ns.Modern.Theme().border, "rim in the theme border colour")
    A.deep(U.points(p.portrait), { { "TOPLEFT", rim, "TOPLEFT", 1, -1 }, { "BOTTOMRIGHT", rim, "BOTTOMRIGHT", -1, 1 } },
        "portrait 1 px inside the rim")
    A.alpha(p.portrait, 1, "portrait visible")
    A.eq(p.portrait:GetNumMaskTextures(), 0, "round mask removed")
    local l, r = p.portrait:GetTexCoord()
    A.ok(l > 0 and r < 1, "portrait cropped")
    A.alpha(p.ring, 0, "level ring held")
    ns.Modern.Restore()
    A.deep({ U.points(p.health), U.points(p.mana), U.points(p.level), U.points(p.portrait) }, before, "points restored")
    A.eq(p.portrait:GetNumMaskTextures(), 1, "mask back")
    A.alpha(p.ring, 1, "ring released")
end)

h.test("player level is a small number in the name's font left of the name; Blizzard's font returns", function(t)
    local A, ns = t.assert, t.ns
    local player = U.frames()[1]
    local p = U.parts(player)
    enable(ns)
    local strip = U.nameStrip(player)
    A.deep(U.points(p.level), { { "LEFT", strip, "LEFT", 3, 0 } }, "level at the start of the name strip")
    A.deep(U.points(player.Name), { { "LEFT", p.level, "RIGHT", 3, 0 }, { "RIGHT", strip, "RIGHT", -3, 0 } },
        "name right of the level, up to the strip's end")
    A.eq(select(2, p.level:GetFont()), 10, "level in the name's size")
    A.eq(p.level:GetText(), "20", "level text stays")
    ns.Modern.Apply()
    A.eq(select(2, p.level:GetFont()), 10, "applying again keeps the size")
    ns.Modern.Restore()
    A.eq(select(2, p.level:GetFont()), 14, "Blizzard's level font back")
end)

h.test("the player's combat icon sits small in the portrait's corner and returns on restore", function(t)
    local A, ns = t.assert, t.ns
    local p = U.parts(U.frames()[1])
    local before = U.points(p.combat)
    enable(ns)
    A.deep(U.points(p.combat), { { "BOTTOMLEFT", p.portrait, "BOTTOMLEFT", 1, 1 } }, "icon in the portrait corner")
    A.deep({ p.combat:GetSize() }, { 18, 18 }, "icon under half the portrait's side")
    ns.Modern.Restore()
    A.deep(U.points(p.combat), before, "icon points back")
    A.deep({ p.combat:GetSize() }, { 24, 24 }, "icon size back")
end)

h.test("bar value texts are 12 pt in Blizzard's face with a shadow instead of the outline; Blizzard's style returns", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    ns.Modern.Apply()
    for _, f in ipairs(frames) do
        local p = U.parts(f)
        for _, bar in ipairs({ p.health, p.mana }) do
            for _, key in ipairs({ "TextString", "LeftText", "RightText" }) do
                local text = bar[key]
                A.deep({ text:GetFont() }, { "Fonts\\FRIZQT__.TTF", 12, "" }, f:GetName() .. " " .. key .. " 12 pt, no outline")
                A.deep({ text:GetShadowOffset() }, { 1, -1 }, f:GetName() .. " " .. key .. " shadow offset")
                A.deep({ text:GetShadowColor() }, { 0, 0, 0, 1 }, f:GetName() .. " " .. key .. " black shadow")
            end
        end
    end
    ns.Modern.Restore()
    local text = U.parts(frames[1]).mana.TextString
    A.deep({ text:GetFont() }, { "Fonts\\FRIZQT__.TTF", 10, "OUTLINE" }, "Blizzard's font back")
    A.deep({ text:GetShadowOffset() }, { 0, 0 }, "shadow offset back")
end)

h.test("target and focus bars widen to the right up to a square: a player's class colour, an NPC's portrait", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    U.installColours(mock)
    CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
    mock:setUnit("target", { exists = true, player = true })
    mock:setUnit("focus", { exists = true, player = false })
    enable(ns, { classColors = true })
    local theme = ns.Modern.Theme().border
    for _, spec in ipairs({ { 3, { 0.25, 0.78, 0.92 } }, { 5, { theme[1], theme[2], theme[3] } } }) do
        local f = frames[spec[1]]
        local p = U.parts(f)
        A.deep(U.points(p.health), {
            { "TOPLEFT", f, "BOTTOMLEFT", 0, 11 },
            { "BOTTOMRIGHT", f, "BOTTOMLEFT", 57, 0 },
        }, f:GetName() .. " bar ends before the box and a 2 px gap")
        local box = U.levelBox(f)
        A.ok(box, f:GetName() .. " box")
        A.deep(U.points(box), { { "TOPRIGHT", f, "BOTTOMLEFT", 100, 26 } }, f:GetName() .. " box at the outer edge")
        A.deep({ box:GetSize() }, { 41, 41 }, f:GetName() .. " box square, as tall as the bars and the name strip")
        A.deep(box._color, { spec[2][1], spec[2][2], spec[2][3], 1 }, f:GetName() .. " box fill")
        A.deep(U.points(p.level), { { "LEFT", U.nameStrip(f), "LEFT", 3, 0 } }, f:GetName() .. " level in the name strip")
        A.eq(select(2, p.level:GetFont()), 10, f:GetName() .. " level in the name's size")
        A.alpha(p.ring, 0, f:GetName() .. " ring held")
    end
    local focus = U.parts(frames[5])
    local box = U.levelBox(frames[5])
    A.alpha(focus.portrait, 1, "NPC portrait shown")
    A.eq(focus.portrait:GetNumMaskTextures(), 0, "NPC portrait square")
    A.deep(U.points(focus.portrait), { { "TOPLEFT", box, "TOPLEFT", 1, -1 }, { "BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1 } },
        "NPC portrait inside the box border")
    A.alpha(U.parts(frames[3]).portrait, 0, "player target's portrait held")
    ns.Modern.Restore()
    A.ok(not U.levelBox(frames[3]), "box hidden")
    A.eq(select(2, U.parts(frames[3]).level:GetFont()), 14, "level font back")
    A.eq(focus.portrait:GetNumMaskTextures(), 1, "portrait mask back")
    A.alpha(U.parts(frames[3]).portrait, 1, "portrait released")
    CLASS_ICON_TCOORDS = nil
end)

h.test("a new target switches between class icon and portrait", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local target = U.frames()[3]
    local p = U.parts(target)
    U.installColours(mock)
    CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
    mock:setUnit("target", { exists = true, player = true })
    enable(ns, { classColors = true })
    A.alpha(p.portrait, 0, "player target: portrait held")
    mock:setUnit("target", { exists = true, player = false })
    mock:fire("PLAYER_TARGET_CHANGED")
    A.alpha(p.portrait, 1, "NPC target: portrait shown")
    A.ok(not U.classIcon(target), "NPC target: no class icon")
    mock:setUnit("target", { exists = true, player = true })
    mock:fire("PLAYER_TARGET_CHANGED")
    A.alpha(p.portrait, 0, "player target again: portrait held")
    A.ok(U.classIcon(target), "player target again: class icon")
    CLASS_ICON_TCOORDS = nil
end)

h.test("a wider Blizzard power bar gets the health bar's inner edge", function(t)
    local A, ns = t.assert, t.ns
    local target = U.frames()[3]
    local p = U.parts(target)
    function p.mana:GetLeft() return -3 end
    enable(ns)
    local health, mana = U.points(p.health), U.points(p.mana)
    A.eq(mana[1][4], health[1][4], "power bar starts at the health bar's left edge")
    A.eq(mana[2][4], health[2][4], "power bar ends at the health bar's right edge")
end)

h.test("a player target shows the class icon in the box with a class-coloured border; an NPC shows none", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    U.installColours(mock)
    CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
    mock:setUnit("target", { exists = true, player = true })
    mock:setUnit("focus", { exists = true, player = false })
    enable(ns, { classColors = true })
    local icon = U.classIcon(frames[3])
    A.ok(icon, "class icon shown")
    A.ok(icon._texture:find("CHARACTERCREATE"), "Blizzard's class sheet")
    local c = icon._texCoord
    A.ok(c[1] > 0.25 and c[2] < 0.5 and c[3] > 0 and c[4] < 0.25, "mage cell, rounded corners trimmed")
    local box = U.levelBox(frames[3])
    A.deep(U.points(icon), { { "TOPLEFT", box, "TOPLEFT", 1, -1 }, { "BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1 } },
        "icon inside the border")
    A.ok(not U.classIcon(frames[5]), "NPC focus has no icon")
    mock:setUnit("target", { exists = true, player = false })
    mock:fire("PLAYER_TARGET_CHANGED")
    A.ok(not U.classIcon(frames[3]), "icon gone for an NPC target")
    mock:setUnit("target", { exists = true, player = true })
    mock:fire("PLAYER_TARGET_CHANGED")
    ns.Modern.Restore()
    A.ok(not U.classIcon(frames[3]), "icon hidden on restore")
    CLASS_ICON_TCOORDS = nil
end)

h.test("pet and target of target bars fill the portrait space without a level box", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, i in ipairs({ 2, 4 }) do
        local f = frames[i]
        A.deep(U.points(U.parts(f).health), {
            { "TOPLEFT", f, "BOTTOMLEFT", 0, 11 },
            { "BOTTOMRIGHT", f, "BOTTOMLEFT", 91, 0 },
        }, f:GetName() .. " bar from the portrait's outer edge")
    end
end)

h.test("bars move in combat unless the client protects them, then wait for combat to end", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local p = U.parts(U.frames()[1])
    local before = U.points(p.health)
    function p.health:IsProtected() return true end
    mock.state.combat = true
    enable(ns)
    A.deep(U.points(p.health), before, "a protected bar is not moved in combat")
    mock.state.combat = false
    mock:fire("PLAYER_REGEN_ENABLED")
    A.eq(p.health:GetNumPoints(), 2, "laid out after combat")
    local mana = U.parts(U.frames()[3]).mana
    mock.state.combat = true
    mock:fire("PLAYER_TARGET_CHANGED")
    A.eq(mana:GetNumPoints(), 2, "an unprotected bar is laid out in combat")
end)

h.test("laying out again keeps the same points", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local p = U.parts(U.frames()[1])
    enable(ns)
    local first = U.points(p.health)
    mock:fire("PLAYER_TARGET_CHANGED")
    A.deep(U.points(p.health), first, "idempotent")
end)

h.test("Blizzard re-anchoring a laid-out bar (target classification) gets the layout back", function(t)
    local A, ns = t.assert, t.ns
    local target = U.frames()[3]
    local p = U.parts(target)
    enable(ns)
    local laid = U.points(p.health)
    p.health:ClearAllPoints()
    p.health:SetPoint("TOPLEFT", p.health:GetParent(), "TOPLEFT", 0, 0)
    p.health:SetPoint("BOTTOMRIGHT", p.health:GetParent(), "BOTTOMRIGHT", 0, -10)
    A.deep(U.points(p.health), laid, "layout reasserted")
    ns.Modern.Restore()
    p.health:ClearAllPoints()
    p.health:SetPoint("TOPLEFT", p.health:GetParent(), "TOPLEFT", 1, 1)
    A.deep(U.points(p.health), { { "TOPLEFT", p.health:GetParent(), "TOPLEFT", 1, 1 } }, "Blizzard owns the bar again")
end)

h.test("bar fills lose their fixed-size mask and the value texts centre on the bar", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, f in ipairs(frames) do
        for _, bar in ipairs({ U.parts(f).health, U.parts(f).mana }) do
            A.eq(bar:GetStatusBarTexture():GetNumMaskTextures(), 0, f:GetName() .. " fill unmasked")
            A.deep(U.points(bar.TextString), { { "CENTER", bar, "CENTER", 0, 0 } }, f:GetName() .. " value centred")
            A.deep(U.points(bar.LeftText), { { "LEFT", bar, "LEFT", 2, 0 } }, f:GetName() .. " left text")
            A.deep(U.points(bar.RightText), { { "RIGHT", bar, "RIGHT", -2, 0 } }, f:GetName() .. " right text")
        end
    end
    ns.Modern.Restore()
    local health = U.parts(frames[1]).health
    A.eq(health:GetStatusBarTexture():GetNumMaskTextures(), 1, "mask back")
    A.deep(U.points(health.TextString), { { "CENTER", health:GetParent(), "CENTER", 0, 0 } }, "text points back")
end)

h.test("player, target and focus names sit left-aligned right of the level; pet and target of target names span the health bar", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    local before = {}
    for _, f in ipairs(frames) do
        f.Name:SetPoint("TOP", f, "TOP", 0, -5)
        before[f] = U.points(f.Name)
    end
    enable(ns)
    for _, i in ipairs({ 1, 3, 5 }) do
        local f = frames[i]
        A.deep(U.points(f.Name), { { "LEFT", U.parts(f).level, "RIGHT", 3, 0 }, { "RIGHT", U.nameStrip(f), "RIGHT", -3, 0 } },
            f:GetName() .. " name after the level")
        A.eq(f.Name:GetJustifyH(), "LEFT", f:GetName() .. " name left-aligned")
    end
    for _, i in ipairs({ 2, 4 }) do
        local f, strip = frames[i], U.nameStrip(frames[i])
        A.deep(U.points(f.Name), { { "LEFT", strip, "LEFT", 3, 0 }, { "RIGHT", strip, "RIGHT", -3, 0 } },
            f:GetName() .. " name spans the strip")
        A.eq(f.Name:GetJustifyH(), "LEFT", f:GetName() .. " name left-aligned")
    end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do A.deep(U.points(f.Name), before[f], f:GetName() .. " name restored") end
end)

h.test("every unit name sits on a dark bordered strip above the health bar, hidden on restore", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    enable(ns)
    local bg = ns.Modern.Theme().bg
    for _, f in ipairs(frames) do
        local strip, health = U.nameStrip(f), U.parts(f).health
        A.ok(strip, f:GetName() .. " strip")
        A.deep(U.points(strip), { { "BOTTOMLEFT", health, "TOPLEFT", 0, -1 }, { "BOTTOMRIGHT", health, "TOPRIGHT", 0, -1 } },
            f:GetName() .. " strip as wide as the health bar, sharing its top border line")
        A.eq(strip._h, 16, f:GetName() .. " strip fits the name with padding")
        local fills = U.anchoredTo(f, strip, "BACKGROUND")
        A.ok(#fills >= 2, f:GetName() .. " strip filled")
        for _, fill in ipairs(fills) do
            A.deep(fill._color or fill._vertex, bg, f:GetName() .. " strip in the theme background")
        end
        A.ok(U.borderOn(f, strip), f:GetName() .. " strip bordered")
    end
    mock:fire("PLAYER_TARGET_CHANGED")
    for _, f in ipairs(frames) do A.alpha(U.nameStrip(f), 1, f:GetName() .. " strip stays visible after laying out again") end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do A.ok(not U.nameStrip(f), f:GetName() .. " strip hidden") end
end)

h.test("bar fills get a light top and a shaded bottom that follow the fill; only health gets a top edge line", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, f in ipairs(frames) do
        A.eq(#U.gloss(U.parts(f).health), 3, f:GetName() .. " health gloss with the edge line")
        A.eq(#U.gloss(U.parts(f).mana), 2, f:GetName() .. " power gloss without the edge line")
    end
    ns.Modern.Apply()
    A.eq(#U.gloss(U.parts(frames[1]).health), 3, "applying again adds no more")
    ns.Modern.Restore()
    A.eq(#U.gloss(U.parts(frames[1]).health), 0, "gloss hidden on restore")
end)

h.test("the name strip's top corner away from the portrait is rounded", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, spec in ipairs({ { 1, "TOPRIGHT" }, { 3, "TOPLEFT" }, { 5, "TOPLEFT" } }) do
        local f = frames[spec[1]]
        local strip, found = U.nameStrip(f), {}
        for _, r in ipairs(U.anchoredTo(f, strip)) do
            if type(r._texture) == "string" and r._texture:find("corner%-") then
                A.deep(U.points(r), { { spec[2], strip, spec[2], 0, 0 } }, f:GetName() .. " corner piece at " .. spec[2])
                found[r._texture:match("corner%-%a+")] = true
            end
        end
        A.ok(found["corner-fill"] and found["corner-line"], f:GetName() .. " quarter disc fill and arc")
    end
end)
