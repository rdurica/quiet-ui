-- Modernize module (settings.modules.modernize): missing or false means no Modern area applies and no
-- Modern hook runs; true applies the areas as before. Restore runs whatever the gate says.
local h = ...
local L = h.lib("modern")

local function start(t, modules)
    QuietUIDB = { enabled = true }
    QuietUICharDB = { modules = modules, modernize = {} }
    UpdateUIPanelPositions = function() end
    UpdateContainerFrameAnchors = function() end
    local placed = 0
    local place = t.ns.Modern.PlaceWindows
    t.ns.Modern.PlaceWindows = function(...) placed = placed + 1; return place(...) end
    local area = L.area(t, "zz_module", { countRestore = true })
    t.boot()
    return area, function() return placed end
end

h.test("Modernize off (missing): boot and ApplyAll apply no Modern area", function(t)
    local area = start(t, nil)
    t.ns.ApplyAll()
    t.assert.eq(area.apply, 0, "area applied with Modernize off")
end)

h.test("Modernize off (modules without it): ApplyAll applies no Modern area", function(t)
    local area = start(t, { chat = true, fading = true, helpers = true, layout = true })
    t.ns.ApplyAll()
    t.assert.eq(area.apply, 0, "area applied with Modernize off")
end)

h.test("Modernize on: boot and ApplyAll apply the area as today", function(t)
    local area = start(t, { modernize = true })
    t.ns.ApplyAll()
    t.assert.ok(area.apply >= 1, "area applies with Modernize on")
end)

h.test("Modernize off: the window placement hooks do nothing when their globals run", function(t)
    local _, placed = start(t, nil)
    local before = placed()
    UpdateUIPanelPositions()
    UpdateContainerFrameAnchors()
    t.assert.eq(placed(), before, "a Modern hook ran with Modernize off")
end)

h.test("Modernize on: the window placement hooks run", function(t)
    local _, placed = start(t, { modernize = true })
    local before = placed()
    UpdateUIPanelPositions()
    t.assert.ok(placed() > before, "the hook runs with Modernize on")
end)

h.test("Modernize switched off after it applied: RestoreAll still restores the area", function(t)
    local area = start(t, { modernize = true })
    t.ns.ApplyAll()
    QuietUICharDB.modules = {}
    t.ns.RestoreAll()
    t.assert.ok(area.restore >= 1, "area restored")
end)
