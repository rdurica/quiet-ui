-- Helpers module (settings.modules.helpers): off means no quest mob icon, even with Quest mobs checked.
local h = ...
local KILL_Q = 101

local function nameplate(t, modules)
    local w = t.mock:questWorld()
    QuietUICharDB = { questMobs = true, modules = modules }
    w.objectives[KILL_Q] = { { text = "Kobold Vermin slain: 0/10", type = "monster", finished = false } }
    t.boot()
    local kobold = { { type = 2, leftText = "Kobold Vermin" }, w.quest(KILL_Q, "Kobold Clearing"),
        w.objective("0/10 Kobold Vermin slain") }
    local plate = w.addPlate("nameplate1", { lines = kobold })
    t.mock:fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    t.mock:fire("QUEST_LOG_UPDATE")
    t.mock:fire("UNIT_QUEST_LOG_CHANGED", "player")
    for _ = 1, 10 do t.mock:tick(0.1) end
    t.mock:drain()
    return w, plate
end

h.test("Helpers on (missing): a kill quest mob gets its icon", function(t)
    local w, plate = nameplate(t, nil)
    t.assert.eq(w.iconOn(plate), "kill")
end)

h.test("Helpers off: no quest mob icon appears, with Quest mobs checked", function(t)
    local w, plate = nameplate(t, { helpers = false })
    t.assert.eq(w.iconOn(plate), nil, "icon shown with Helpers off")
    t.assert.ok(w.nothingShown(), "a quest icon is visible somewhere")
end)
