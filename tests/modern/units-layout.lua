-- Modern unit frames without portraits: bars widened into the portrait space, the level in a small square box.
-- Fixture geometry: bars 91 x 11 (left 0, right 91, top 11, bottom 0), portrait 100 wide from 0, frame origin 0.
local h = ...
local U = h.lib("modern-units")

local function enable(ns)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
end

h.test("player bars start right of a square level box at the portrait's outer edge and come back on restore", function(t)
    local A, ns = t.assert, t.ns
    local player = U.frames()[1]
    local p = U.parts(player)
    local before = { U.points(p.health), U.points(p.mana), U.points(p.level) }
    enable(ns)
    for _, bar in ipairs({ p.health, p.mana }) do
        A.deep(U.points(bar), {
            { "TOPLEFT", player, "BOTTOMLEFT", 13, 11 },
            { "BOTTOMRIGHT", player, "BOTTOMLEFT", 91, 0 },
        }, "bar keeps its right edge and starts after the box and a 2 px gap")
    end
    local point, box = p.level:GetPoint(1)
    A.eq(point, "CENTER", "level centred")
    A.ok(box ~= player and box ~= p.portrait, "level sits in an own box")
    A.eq(box:GetWidth(), 11, "box as wide as health top to power bottom")
    A.eq(box:GetHeight(), 11, "box square")
    A.deep(U.points(box), { { "TOPLEFT", player, "BOTTOMLEFT", 0, 11 } }, "box flush with the bar tops at the outer edge")
    A.alpha(p.ring, 0, "level ring held")
    A.alpha(p.level, 1, "level text stays visible")
    ns.Modern.Restore()
    A.deep({ U.points(p.health), U.points(p.mana), U.points(p.level) }, before, "points restored")
    A.alpha(p.ring, 1, "ring released")
    A.ok(not box._shown, "box hidden")
end)

h.test("target and focus bars widen to the right where their portrait was", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, i in ipairs({ 3, 5 }) do
        local f = frames[i]
        local p = U.parts(f)
        A.deep(U.points(p.health), {
            { "TOPLEFT", f, "BOTTOMLEFT", 0, 11 },
            { "BOTTOMRIGHT", f, "BOTTOMLEFT", 87, 0 },
        }, f:GetName() .. " bar ends before the box and a 2 px gap")
        local _, box = p.level:GetPoint(1)
        A.deep(U.points(box), { { "TOPRIGHT", f, "BOTTOMLEFT", 100, 11 } }, f:GetName() .. " box at the outer edge")
        A.alpha(p.ring, 0, f:GetName() .. " ring held")
    end
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

h.test("player, target and focus names sit left-aligned just above the health bar; pet and target of target keep theirs", function(t)
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
        A.deep(U.points(f.Name), { { "BOTTOMLEFT", U.parts(f).health, "TOPLEFT", 0, 2 } }, f:GetName() .. " name above the bar")
        A.eq(f.Name:GetJustifyH(), "LEFT", f:GetName() .. " name left-aligned")
    end
    for _, i in ipairs({ 2, 4 }) do
        A.deep(U.points(frames[i].Name), before[frames[i]], frames[i]:GetName() .. " name untouched")
    end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do A.deep(U.points(f.Name), before[f], f:GetName() .. " name restored") end
end)
