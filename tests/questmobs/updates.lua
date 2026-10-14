local h = ...
local KILL_Q, LOOT_Q, OTHER_Q = 101, 102, 103

-- Runs fn(t, w, f) with a quest mob world (tests/lib/mock.lua questWorld) and checks the
-- end-of-test invariants. opts.output allows chat output (expected reports).
local function test(name, fn, opts)
    h.test(name, function(t)
        local w = t.mock:questWorld()
        local Q, O = w.quest, w.objective
        local f = { w = w, Q = Q, O = O, A = t.assert }
        f.KOBOLD = { { type = 2, leftText = "Kobold Vermin" }, Q(KILL_Q, "Kobold Clearing"),
            O("0/10 Kobold Vermin slain") }
        f.WOLF = { { type = 2, leftText = "Timber Wolf" }, Q(LOOT_Q, "Wolves Across the Border"),
            O("4/8 Tough Wolf Meat") }
        function f.event(name, ...) t.ns.QuestMobsEvent(name, ...) end
        function f.add(token, spec, o)
            local plate = w.addPlate(token, spec, o)
            f.event("NAME_PLATE_UNIT_ADDED", token)
            return plate
        end
        function f.remove(token)
            w.removePlate(token)
            f.event("NAME_PLATE_UNIT_REMOVED", token)
        end
        function f.nextFrame() t.mock:advance(0) end
        function f.kind(plate) return (w.iconOn(plate)) end
        -- Quest log with the kill and loot quests, then the feature applies.
        function f.ready()
            w.objectives[KILL_Q] = { { text = "Kobold Vermin slain: 0/10", type = "monster", finished = false } }
            w.objectives[LOOT_Q] = { { text = "Tough Wolf Meat: 4/8", type = "item", finished = false } }
            t.ns.ApplyQuestMobs()
        end
        fn(t, w, f)
        w.check(opts and opts.output)
    end)
end

-- Updates ----------------------------------------------------------------------------------------

test("A finished objective (related turns false) loses its icon after QUEST_LOG_UPDATE", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    f.A.eq(f.kind(plate), "kill", "Precondition: exclamation shown")
    t.mock.units.nameplate1.related = false
    t.mock.units.nameplate1.lines = { f.Q(KILL_Q), f.O("10/10 Kobold Vermin slain") }
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(f.kind(plate), nil, "The icon stayed after the objective was finished")
end)

test("UNIT_QUEST_LOG_CHANGED for the player re-evaluates the plates", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    t.mock.units.nameplate1.related = false
    f.event("UNIT_QUEST_LOG_CHANGED", "player")
    f.nextFrame()
    f.A.eq(f.kind(plate), nil, 'UNIT_QUEST_LOG_CHANGED("player") did not re-evaluate')
end)

test("A quest log change switches the icon on the same plate without a second icon", function(t, w, f)
    f.ready()
    w.objectives[OTHER_Q] = {
        { text = "Kobold Vermin slain: 0/10", type = "monster", finished = false },
        { text = "Tough Wolf Meat: 0/8", type = "item", finished = false },
    }
    local plate = f.add("nameplate1", { lines = { f.Q(OTHER_Q), f.O("0/10 Kobold Vermin slain"),
        f.O("0/8 Tough Wolf Meat") } })
    f.A.eq(f.kind(plate), "kill", "Precondition: exclamation shown")
    t.mock.units.nameplate1.lines = { f.Q(OTHER_Q), f.O("10/10 Kobold Vermin slain"), f.O("0/8 Tough Wolf Meat") }
    w.objectives[OTHER_Q][1] = { text = "Kobold Vermin slain: 10/10", type = "monster", finished = true }
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(f.kind(plate), "loot", "Expected the pouch after the kill objective was done")
end)

test("Several quest log events in one frame cause exactly one recalculation and no polling", function(t, w, f)
    f.ready()
    f.add("nameplate1", { lines = f.KOBOLD })
    f.add("nameplate2", { lines = f.WOLF })
    f.add("nameplate3", { related = false, lines = f.KOBOLD })
    f.nextFrame()
    local scans, reads = w.total.GetNamePlates or 0, w.total.GetUnit or 0
    f.event("QUEST_LOG_UPDATE")
    f.event("QUEST_LOG_UPDATE")
    f.event("UNIT_QUEST_LOG_CHANGED", "player")
    f.event("QUEST_LOG_UPDATE")
    f.A.eq(w.total.GetUnit or 0, reads, "Quest log events must only mark dirty, not recalculate at once")
    f.A.ok(w.pending() <= 1, "Expected one scheduled recalculation")
    f.nextFrame()
    f.A.eq((w.total.GetNamePlates or 0) - scans, 1, "Expected one plate scan")
    f.A.eq((w.total.GetUnit or 0) - reads, 2, "Expected one tooltip read per quest plate")
    f.A.eq(w.pending(), 0, "A recalculation rescheduled itself without a new event")
    -- A later frame without events does no work.
    f.nextFrame()
    f.A.eq((w.total.GetNamePlates or 0) - scans, 1, "Work happened on a frame without events")
end)

test("Quest objectives are read once per quest within one recalculation and again in the next", function(t, w, f)
    f.ready()
    f.add("nameplate1", { lines = f.KOBOLD })
    f.add("nameplate2", { lines = f.KOBOLD })
    local plate3 = f.add("nameplate3", { lines = f.WOLF })
    f.nextFrame()
    local before = w.count("Objectives", KILL_Q)
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(w.count("Objectives", KILL_Q) - before, 1, "Expected one GetQuestObjectives per quest per recalculation")
    -- The next recalculation must not reuse old objectives.
    w.objectives[LOOT_Q] = { { text = "Tough Wolf Meat: 4/8", type = "monster", finished = false } }
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(f.kind(plate3), "kill", "Objectives from an earlier recalculation were reused")
end)

test("PLAYER_ENTERING_WORLD re-evaluates the visible plates", function(t, w, f)
    f.ready()
    local plate = w.addPlate("nameplate1", { lines = f.KOBOLD })
    f.event("PLAYER_ENTERING_WORLD", false, false)
    f.nextFrame()
    f.A.eq(f.kind(plate), "kill", "PLAYER_ENTERING_WORLD did not evaluate the visible plate")
end)

test("ApplyQuestMobs evaluates plates already on screen", function(t, w, f)
    w.objectives[KILL_Q] = { { text = "Kobold Vermin slain: 0/10", type = "monster", finished = false } }
    w.objectives[LOOT_Q] = { { text = "Tough Wolf Meat: 4/8", type = "item", finished = false } }
    local a = w.addPlate("nameplate1", { lines = f.KOBOLD })
    local b = w.addPlate("nameplate2", { lines = f.WOLF })
    t.ns.ApplyQuestMobs()
    f.A.ok(f.kind(a) == "kill" and f.kind(b) == "loot", "ApplyQuestMobs did not evaluate visible plates")
end)

-- Combat, instances, HUD rules -----------------------------------------------------------------

test("In combat a new plate shows its icon and existing icons stay", function(t, w, f)
    f.ready()
    local a = f.add("nameplate1", { lines = f.KOBOLD })
    t.mock.state.combat = true
    f.event("PLAYER_REGEN_DISABLED")
    local b = f.add("nameplate2", { lines = f.WOLF })
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(f.kind(a), "kill", "The existing icon disappeared in combat")
    f.A.eq(f.kind(b), "loot", "A plate added in combat got no icon")
end)

for _, kind in ipairs({ "party", "raid", "pvp", "arena" }) do
    test("Icons show in a " .. kind .. " instance", function(t, w, f)
        f.ready()
        local a = f.add("nameplate1", { lines = f.KOBOLD })
        t.mock.state.instance, t.mock.state.instanceType = true, kind
        f.event("PLAYER_ENTERING_WORLD", false, false)
        f.event("ZONE_CHANGED_NEW_AREA")
        f.nextFrame()
        local b = f.add("nameplate2", { lines = f.WOLF })
        t.ns.ApplyQuestMobs()
        f.A.eq(f.kind(a), "kill", "The icon disappeared in a " .. kind .. " instance")
        f.A.eq(f.kind(b), "loot", "No icon in a " .. kind .. " instance")
    end)
end

test("Glance, Edit Mode and ShowAll do not change the icons", function(t, w, f)
    f.ready()
    local a = f.add("nameplate1", { lines = f.KOBOLD })
    local b = f.add("nameplate2", { related = false, lines = f.KOBOLD })
    t.ns.Glancing = function() return true end
    t.ns.World.InEditMode = function() return true end
    t.ns.World.ShowAll = function() return true end
    t.ns.ApplyQuestMobs()
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    local c = f.add("nameplate3", { lines = f.WOLF })
    f.A.ok(f.kind(a) == "kill" and f.kind(c) == "loot", "HUD flags changed a quest icon")
    f.A.eq(f.kind(b), nil, "HUD flags revealed an icon on an unrelated mob")
end)
