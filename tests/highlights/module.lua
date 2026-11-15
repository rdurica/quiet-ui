-- Helpers module (settings.modules.helpers): off means Highlights changes no soft-target CVar and
-- shows no glow, even with Herbs, Ore and Interact objects checked.
local h = ...
local H = h.lib("highlights")

local function run(t, modules)
    local w = H.world(t, { flags = { ore = true, herbs = true, interact = true } })
    QuietUICharDB.modules = modules
    UnitExists = function() return false end
    t.boot()
    t.ns.ApplyAll()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    t.mock.units.softinteract = { exists = true, guid = "GameObject-A" }
    t.mock:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    t.mock:fire("PLAYER_SOFT_INTERACT_CHANGED", nil, "GameObject-A")
    for _ = 1, 10 do t.mock:tick(0.1) end
    t.mock:drain()
    return w
end

h.test("Helpers on (missing): the Highlights apply changes the soft-target CVars", function(t)
    local w = run(t, nil)
    t.assert.ok(w.writes() > 0, "a CVar was written with Helpers on")
end)

h.test("Helpers off: no soft-target CVar is written or stored, and no glow shows", function(t)
    local A = t.assert
    local w = run(t, { helpers = false })
    A.eq(w.writes(), 0, "a CVar was written with Helpers off")
    A.eq(w.saved(), nil, "originals were stored with Helpers off")
    for name, value in pairs(H.ORIGINAL) do A.eq(w.cvar(name), value, name .. " changed") end
    A.ok(w.nothingShown(), "something was shown with Helpers off")
end)
