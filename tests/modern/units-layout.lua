-- Modern unit frames: one compact bar. The portrait is held, a dark bordered box takes its space, health fills
-- it and power is a thin line along its bottom; target, focus and boss keep Blizzard's health bar inside the box.
-- Name and level sit above the box, the player shows neither.
-- Fixture geometry: bars 91 x 11 (left 0, right 91, top 11, bottom 0), portrait 100 wide from 0, frame origin 0.
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

h.test("player bars sit in a dark box over the portrait space, power a thin line, all back on restore", function(t)
    local A, ns = t.assert, t.ns
    local player = U.frames()[1]
    local p = U.parts(player)
    local before = { U.points(p.health), U.points(p.mana), U.points(p.level), U.points(p.portrait) }
    enable(ns)
    local box = U.barBox(player)
    A.ok(box, "box drawn")
    A.deep(U.points(box), { { "TOPLEFT", p.health, "TOPLEFT", -1, 1 }, { "BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 1, -6 } },
        "box around the health bar and the power line below it")
    A.deep(box._color, ns.Modern.Theme().bg, "box in the theme background")
    A.ok(U.onePixelOn(player, box), "box has a 1 px border")
    A.deep(U.points(p.health), {
        { "TOPLEFT", player, "BOTTOMLEFT", 1, 27 },
        { "BOTTOMRIGHT", player, "BOTTOMLEFT", 90, 6 },
    }, "health inside the border, above the power line and a 1 px gap")
    A.deep(U.points(p.mana), {
        { "TOPLEFT", p.health, "BOTTOMLEFT", 0, -1 },
        { "BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 0, -5 },
    }, "power a 4 px line under the health bar, along the box's bottom")
    A.alpha(p.portrait, 0, "portrait held")
    A.eq(p.portrait:GetNumPoints(), 0, "portrait not moved")
    A.eq(p.portrait:GetNumMaskTextures(), 1, "portrait mask untouched")
    ns.Modern.Restore()
    A.deep({ U.points(p.health), U.points(p.mana), U.points(p.level), U.points(p.portrait) }, before, "points restored")
    A.alpha(p.portrait, 1, "portrait released")
    A.ok(not U.barBox(player), "box hidden")
    A.ok(not U.borderOn(player, box), "box border hidden")
end)

h.test("the player frame holds its name, level and level ring; restore releases them", function(t)
    local A, ns = t.assert, t.ns
    local player = U.frames()[1]
    local p = U.parts(player)
    enable(ns)
    A.alpha(p.level, 0, "level held")
    A.alpha(p.ring, 0, "level ring held")
    A.alpha(player.Name, 0, "name held")
    player.Name:SetAlpha(1)
    A.alpha(player.Name, 0, "Blizzard cannot show the name again")
    p.level:SetVertexColor(1, 0.82, 0, 1)
    A.alpha(p.level, 0, "Blizzard colouring the level cannot show it again")
    p.level:SetTextColor(1, 1, 1, 1)
    A.alpha(p.level, 0, "nor setting its text colour")
    ns.Modern.Restore()
    A.alpha(p.level, 1, "level released")
    A.alpha(p.ring, 1, "ring released")
    A.alpha(player.Name, 1, "name released")
end)

h.test("the player's combat icon sits small above the bar's left end and returns on restore", function(t)
    local A, ns = t.assert, t.ns
    local p = U.parts(U.frames()[1])
    local before = U.points(p.combat)
    enable(ns)
    A.deep(U.points(p.combat), { { "BOTTOMLEFT", p.health, "TOPLEFT", -1, 4 } }, "icon above the box")
    A.deep({ p.combat:GetSize() }, { 16, 16 }, "icon small")
    ns.Modern.Restore()
    A.deep(U.points(p.combat), before, "icon points back")
    A.deep({ p.combat:GetSize() }, { 24, 24 }, "icon size back")
end)

h.test("health value texts are 12 pt in Blizzard's face with a shadow; power value texts are held", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    ns.Modern.Apply()
    for _, f in ipairs(frames) do
        local p = U.parts(f)
        for _, key in ipairs({ "TextString", "LeftText", "RightText" }) do
            local text = p.health[key]
            A.deep({ text:GetFont() }, { "Fonts\\FRIZQT__.TTF", 12, "" }, f:GetName() .. " " .. key .. " 12 pt, no outline")
            A.deep({ text:GetShadowOffset() }, { 1, -1 }, f:GetName() .. " " .. key .. " shadow offset")
            A.deep({ text:GetShadowColor() }, { 0, 0, 0, 1 }, f:GetName() .. " " .. key .. " black shadow")
            A.alpha(p.mana[key], 0, f:GetName() .. " power " .. key .. " held")
        end
    end
    ns.Modern.Restore()
    local p = U.parts(frames[1])
    A.deep({ p.health.TextString:GetFont() }, { "Fonts\\FRIZQT__.TTF", 10, "OUTLINE" }, "Blizzard's font back")
    A.deep({ p.health.TextString:GetShadowOffset() }, { 0, 0 }, "shadow offset back")
    A.alpha(p.mana.TextString, 1, "power text released")
end)

h.test("target and focus keep Blizzard's health bar inside the box; the portrait is held", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    mock:setUnit("target", { exists = true, player = true })
    mock:setUnit("focus", { exists = true, player = false })
    local before = { U.points(frames[3].TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar),
        U.points(frames[5].TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar) }
    enable(ns)
    for n, i in ipairs({ 3, 5 }) do
        local f = frames[i]
        local p = U.parts(f)
        A.deep(U.points(U.barBox(f)), { { "TOPLEFT", p.health, "TOPLEFT", -1, 1 }, { "BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 1, -6 } },
            f:GetName() .. " box around the health bar")
        A.deep(U.points(p.health), before[n], f:GetName() .. " health keeps Blizzard's points")
        A.deep(U.points(p.mana), {
            { "TOPLEFT", p.health, "BOTTOMLEFT", 0, -1 },
            { "BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 0, -5 },
        }, f:GetName() .. " thin power along its bottom")
        A.alpha(p.portrait, 0, f:GetName() .. " portrait held")
    end
    mock:setUnit("target", { exists = true, player = false })
    mock:fire("PLAYER_TARGET_CHANGED")
    A.alpha(U.parts(frames[3]).portrait, 0, "an NPC target's portrait is held too")
    ns.Modern.Restore()
    A.alpha(U.parts(frames[3]).portrait, 1, "portrait released")
end)

h.test("target and focus show the level in the name's font, then the name, above the bar; Blizzard's style returns", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    local before = {}
    for _, f in ipairs(frames) do
        f.Name:SetPoint("TOP", f, "TOP", 0, -5)
        before[f] = U.points(f.Name)
    end
    enable(ns)
    for _, i in ipairs({ 3, 5 }) do
        local f = frames[i]
        local p = U.parts(f)
        A.deep(U.points(p.level), { { "BOTTOMLEFT", p.health, "TOPLEFT", 0, 4 } }, f:GetName() .. " level above the box")
        A.eq(select(2, p.level:GetFont()), 10, f:GetName() .. " level in the name's size")
        A.alpha(p.level, 1, f:GetName() .. " level shown")
        A.alpha(p.ring, 0, f:GetName() .. " ring held")
        A.deep(U.points(f.Name), { { "BOTTOMLEFT", p.level, "BOTTOMRIGHT", 3, 0 },
            { "BOTTOMRIGHT", p.health, "TOPRIGHT", 0, 4 } }, f:GetName() .. " name after the level")
        A.eq(f.Name:GetJustifyH(), "LEFT", f:GetName() .. " name left-aligned")
    end
    ns.Modern.Apply()
    A.eq(select(2, U.parts(frames[3]).level:GetFont()), 10, "applying again keeps the size")
    ns.Modern.Restore()
    A.eq(select(2, U.parts(frames[3]).level:GetFont()), 14, "level font back")
    A.alpha(U.parts(frames[3]).ring, 1, "ring released")
    for _, f in ipairs(frames) do A.deep(U.points(f.Name), before[f], f:GetName() .. " name restored") end
end)

h.test("pet and target of target get a smaller box over the portrait space, the name above it", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, i in ipairs({ 2, 4 }) do
        local f = frames[i]
        local p = U.parts(f)
        A.deep(U.points(p.health), {
            { "TOPLEFT", f, "BOTTOMLEFT", 1, 17 },
            { "BOTTOMRIGHT", f, "BOTTOMLEFT", 90, 6 },
        }, f:GetName() .. " bar from the portrait's outer edge in an 18 px box")
        A.deep(U.points(f.Name), { { "BOTTOMLEFT", p.health, "TOPLEFT", 0, 4 },
            { "BOTTOMRIGHT", p.health, "TOPRIGHT", 0, 4 } }, f:GetName() .. " name spans the bar")
        A.alpha(p.portrait, 0, f:GetName() .. " portrait held")
    end
end)

h.test("a wider Blizzard power bar gets the health bar's edges", function(t)
    local A, ns = t.assert, t.ns
    local target = U.frames()[3]
    local p = U.parts(target)
    function p.mana:GetLeft() return -3 end
    enable(ns)
    local mana = U.points(p.mana)
    A.deep({ mana[1][2], mana[1][4] }, { p.health, 0 }, "power bar starts at the health bar's left edge")
    A.deep({ mana[2][2], mana[2][4] }, { p.health, 0 }, "power bar ends at the health bar's right edge")
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

h.test("box and power stay with a target bar that Blizzard puts back on its own point in combat", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local target = U.frames()[3]
    local p = U.parts(target)
    mock:setUnit("target", { exists = true, player = false })
    enable(ns)
    function p.health:IsProtected() return true end
    mock.state.combat = true
    p.health:ClearAllPoints()
    p.health:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, 11)
    mock:fire("PLAYER_TARGET_CHANGED")
    A.deep(U.points(p.health), { { "TOPLEFT", target, "BOTTOMLEFT", 0, 11 } }, "Blizzard's points kept in combat")
    local box = U.points(U.barBox(target))
    A.eq(box[1][2], p.health, "box hangs on the health bar")
    A.eq(box[2][2], p.health, "box ends on the health bar")
    local mana = U.points(p.mana)
    A.ok(mana[1][2] == p.health and mana[2][2] == p.health, "power bar hangs on the health bar")
end)

h.test("laying out again keeps the same points", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local p = U.parts(U.frames()[1])
    enable(ns)
    local first = U.points(p.health)
    mock:fire("PLAYER_TARGET_CHANGED")
    A.deep(U.points(p.health), first, "idempotent")
end)

h.test("Blizzard re-anchoring a laid-out bar gets the layout back", function(t)
    local A, ns = t.assert, t.ns
    local p = U.parts(U.frames()[1])
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

h.test("bar fills lose their fixed-size mask and the health value texts sit on the bar", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, f in ipairs(frames) do
        local health = U.parts(f).health
        for _, bar in ipairs({ health, U.parts(f).mana }) do
            A.eq(bar:GetStatusBarTexture():GetNumMaskTextures(), 0, f:GetName() .. " fill unmasked")
        end
        A.deep(U.points(health.TextString), { { "CENTER", health, "CENTER", 0, 0 } }, f:GetName() .. " value centred")
        A.deep(U.points(health.LeftText), { { "LEFT", health, "LEFT", 4, 0 } }, f:GetName() .. " left text")
        A.deep(U.points(health.RightText), { { "RIGHT", health, "RIGHT", -4, 0 } }, f:GetName() .. " right text")
    end
    ns.Modern.Restore()
    local health = U.parts(frames[1]).health
    A.eq(health:GetStatusBarTexture():GetNumMaskTextures(), 1, "mask back")
    A.deep(U.points(health.TextString), { { "CENTER", health:GetParent(), "CENTER", 0, 0 } }, "text points back")
end)

h.test("the player's resting icon is held; restore releases it", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    local rest = U.parts(frames[1]).rest
    enable(ns)
    A.alpha(rest, 0, "resting icon held")
    rest:SetAlpha(1)
    A.alpha(rest, 0, "Blizzard cannot show it again")
    ns.Modern.Restore()
    A.alpha(rest, 1, "resting icon released")
end)

h.test("bar fills are flat: no light, shade or edge line on them", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, f in ipairs(frames) do
        for _, bar in ipairs({ U.parts(f).health, U.parts(f).mana }) do
            A.eq(#U.gloss(bar), 0, f:GetName() .. " flat fill")
        end
    end
end)

h.test("a player target or focus shows its class icon before the level; an NPC shows none", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    U.installColours(mock)
    CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 } }
    mock:setUnit("target", { exists = true, player = true })
    mock:setUnit("focus", { exists = true, player = false })
    enable(ns)
    local target = U.parts(frames[3])
    local icon = U.classIcon(frames[3])
    A.ok(icon, "class icon shown")
    A.ok(icon._texture:find("CHARACTERCREATE"), "Blizzard's class sheet")
    local c = icon._texCoord
    A.ok(c[1] > 0.25 and c[2] < 0.5 and c[3] > 0 and c[4] < 0.25, "mage cell, rounded corners trimmed")
    A.deep(U.points(icon), { { "BOTTOMLEFT", target.health, "TOPLEFT", -1, 4 } }, "icon at the box's left end")
    A.deep({ icon:GetSize() }, { 14, 14 }, "icon small")
    A.deep(U.points(target.level), { { "LEFT", icon, "RIGHT", 3, 0 } }, "level after the icon")
    A.ok(not U.classIcon(frames[5]), "NPC focus has no icon")
    A.deep(U.points(U.parts(frames[5]).level), { { "BOTTOMLEFT", U.parts(frames[5]).health, "TOPLEFT", 0, 4 } },
        "NPC level at the box's left end")
    for _, i in ipairs({ 1, 2, 4 }) do A.ok(not U.classIcon(frames[i]), frames[i]:GetName() .. " no icon") end
    mock:setUnit("target", { exists = true, player = false })
    mock:fire("PLAYER_TARGET_CHANGED")
    A.ok(not U.classIcon(frames[3]), "icon gone for an NPC target")
    A.deep(U.points(target.level), { { "BOTTOMLEFT", target.health, "TOPLEFT", 0, 4 } }, "level back at the start")
    for n = 1, 3 do
        mock:setUnit("target", { exists = true, player = true })
        mock:fire("PLAYER_TARGET_CHANGED")
        A.ok(U.classIcon(frames[3]), "icon back for a player target #" .. n)
        A.alpha(U.classIcon(frames[3]), 1, "icon visible, not taken for level ring art #" .. n)
    end
    ns.Modern.Restore()
    A.ok(not U.classIcon(frames[3]), "icon hidden on restore")
    CLASS_ICON_TCOORDS = nil
end)

h.test("a value text whose points the client never gives back is still centred, and restore puts it on its parent", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local p = U.parts(U.frames()[1])
    local text = p.health.TextString
    local parent = text:GetParent()
    function text:GetNumPoints() return nil end
    enable(ns)
    ns.Modern.Apply()
    A.eq(#mock.printed, 0, "nothing reported")
    text.GetNumPoints = nil
    A.deep(U.points(text), { { "CENTER", p.health, "CENTER", 0, 0 } }, "centred on the bar")
    function text:GetNumPoints() return nil end
    ns.Modern.Restore()
    text.GetNumPoints = nil
    A.deep(U.points(text), { { "CENTER", parent, "CENTER", 0, 0 } }, "centred on its parent again")
end)
h.test("a value text the client stops giving points for after a restore is laid out again from its last points", function(t)
    local A, ns = t.assert, t.ns
    local p = U.parts(U.frames()[1])
    local text = p.health.TextString
    local before = U.points(text)
    enable(ns)
    local laid = U.points(text)
    ns.Modern.Restore()
    function text:GetNumPoints() return nil end
    enable(ns)
    text.GetNumPoints = nil
    A.deep(U.points(text), laid, "centred on the bar again")
    ns.Modern.Restore()
    A.deep(U.points(text), before, "Blizzard's points back")
end)
