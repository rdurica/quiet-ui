-- Modern unit frames: a unit without power gets a box that ends under its health bar, and a PvP-flagged
-- target's faction mark sits on the box's bottom-right corner.
local h = ...
local U = h.lib("modern-units")

local function enable(ns)
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
end

h.test("the box drops the power strip while Blizzard hides the power bar and takes it back when shown", function(t)
    local A, ns = t.assert, t.ns
    local target = U.frames()[3]
    local p = U.parts(target)
    enable(ns)
    local box = U.barBox(target)
    A.deep(U.points(box)[2], { "BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 1, -6 }, "box reaches the power line")
    p.mana:Hide()
    A.deep(U.points(box)[2], { "BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 1, -1 }, "box ends under the health bar")
    p.mana:Show()
    A.deep(U.points(box)[2], { "BOTTOMRIGHT", p.health, "BOTTOMRIGHT", 1, -6 }, "power strip back")
    ns.Modern.Restore()
end)

h.test("the target's faction mark sits on the box's bottom-right corner and goes back on restore", function(t)
    local A, ns = t.assert, t.ns
    local target = U.frames()[3]
    local p = U.parts(target)
    local before = U.points(p.faction)
    enable(ns)
    A.deep(U.points(p.faction), { { "CENTER", p.health, "BOTTOMRIGHT", 3, -1 } }, "mark on the box corner")
    ns.Modern.Restore()
    A.deep(U.points(p.faction), before, "Blizzard's point restored")
end)
