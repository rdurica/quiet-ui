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
    for _, bar in ipairs({ p.health, p.mana }) do
        A.deep(U.points(bar), {
            { "TOPLEFT", player, "BOTTOMLEFT", 13, 11 },
            { "BOTTOMRIGHT", player, "BOTTOMLEFT", 91, 0 },
        }, "bar keeps its right edge and starts after the portrait and a 2 px gap")
    end
    A.deep(U.points(p.portrait), {
        { "TOPLEFT", player, "BOTTOMLEFT", 0, 11 },
        { "BOTTOMRIGHT", player, "BOTTOMLEFT", 11, 0 },
    }, "portrait square, as tall as health top to power bottom, at the outer edge")
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
    A.deep(U.points(p.level), { { "BOTTOMLEFT", p.health, "TOPLEFT", 0, 2 } }, "level above the health bar")
    A.deep(U.points(player.Name), { { "BOTTOMLEFT", p.level, "BOTTOMRIGHT", 3, 0 } }, "name right of the level")
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
    A.deep({ p.combat:GetSize() }, { 5, 5 }, "icon under half the portrait's side")
    ns.Modern.Restore()
    A.deep(U.points(p.combat), before, "icon points back")
    A.deep({ p.combat:GetSize() }, { 24, 24 }, "icon size back")
end)

h.test("power value texts are a little smaller than Blizzard's, health texts keep their size", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    ns.Modern.Apply()
    for _, f in ipairs(frames) do
        local p = U.parts(f)
        for _, key in ipairs({ "TextString", "LeftText", "RightText" }) do
            A.deep({ p.mana[key]:GetFont() }, { "Fonts\\FRIZQT__.TTF", 9, "OUTLINE" }, f:GetName() .. " power " .. key)
            A.eq(select(2, p.health[key]:GetFont()), 10, f:GetName() .. " health " .. key)
        end
    end
    ns.Modern.Restore()
    A.eq(select(2, U.parts(frames[1]).mana.TextString:GetFont()), 10, "power font back")
end)

h.test("target and focus bars widen to the right up to a square: a player's class colour, an NPC's portrait", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    U.installColours(mock)
    CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
    mock:setUnit("target", { exists = true, player = true })
    mock:setUnit("focus", { exists = true, player = false })
    enable(ns, { classColors = true })
    local theme = ns.Modern.Theme().bg
    for _, spec in ipairs({ { 3, { 0.25, 0.78, 0.92 } }, { 5, { theme[1], theme[2], theme[3] } } }) do
        local f = frames[spec[1]]
        local p = U.parts(f)
        A.deep(U.points(p.health), {
            { "TOPLEFT", f, "BOTTOMLEFT", 0, 11 },
            { "BOTTOMRIGHT", f, "BOTTOMLEFT", 87, 0 },
        }, f:GetName() .. " bar ends before the box and a 2 px gap")
        local box = U.levelBox(f)
        A.ok(box, f:GetName() .. " box")
        A.deep(U.points(box), { { "TOPRIGHT", f, "BOTTOMLEFT", 100, 11 } }, f:GetName() .. " box at the outer edge")
        A.deep({ box:GetSize() }, { 11, 11 }, f:GetName() .. " box square, as tall as the bars")
        A.deep(box._color, { spec[2][1], spec[2][2], spec[2][3], 1 }, f:GetName() .. " box fill")
        A.deep(U.points(p.level), { { "BOTTOMLEFT", p.health, "TOPLEFT", 0, 2 } }, f:GetName() .. " level above the bar")
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
    A.deep(U.points(p.mana), U.points(p.health), "power bar as long as the health bar")
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

h.test("player, target and focus names sit left-aligned right of the level; pet and target of target keep theirs", function(t)
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
        A.deep(U.points(f.Name), { { "BOTTOMLEFT", U.parts(f).level, "BOTTOMRIGHT", 3, 0 } }, f:GetName() .. " name after the level")
        A.eq(f.Name:GetJustifyH(), "LEFT", f:GetName() .. " name left-aligned")
    end
    for _, i in ipairs({ 2, 4 }) do
        A.deep(U.points(frames[i].Name), before[frames[i]], frames[i]:GetName() .. " name untouched")
    end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do A.deep(U.points(f.Name), before[f], f:GetName() .. " name restored") end
end)
