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
        function f.event(name, ...) t.ns.QuestMobs.Event(name, ...) end
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
            t.ns.QuestMobs.Apply()
        end
        fn(t, w, f)
        w.check(opts and opts.output)
    end)
end

-- Recycling ------------------------------------------------------------------------------------

test("NAME_PLATE_UNIT_REMOVED hides the icon and returns it to UIParent", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    local other = f.add("nameplate2", { lines = f.WOLF })
    local roots = w.roots(plate)
    f.A.ok(#roots >= 1 and f.kind(plate) == "kill", "Precondition: icon on the plate")
    f.remove("nameplate1")
    f.A.eq(f.kind(plate), nil, "The icon still shows on a removed plate")
    f.A.eq(#w.roots(plate), 0, "An icon object stayed attached to the removed plate")
    for _, o in ipairs(roots) do
        f.A.ok(o._parent == UIParent or w.within(o._parent, other), "The released icon was not returned to UIParent")
        if o._parent == UIParent then f.A.falsy(w.visible(o), "The released icon is still visible on UIParent") end
    end
    f.A.eq(f.kind(other), "loot", "Removing another plate hid an unrelated icon")
end)

-- The client hands the same plate object to another unit.
local function recycle(t, w, plate, token, spec)
    t.mock.nameplates[token] = plate
    plate.namePlateUnitToken = token
    plate.UnitFrame.unit = token
    t.mock.units[token] = { exists = true, attackable = true, related = spec.related, lines = spec.lines }
end

test("A recycled plate for an unrelated mob shows no stale icon", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    f.remove("nameplate1")
    recycle(t, w, plate, "nameplate5", { related = false, lines = {} })
    f.event("NAME_PLATE_UNIT_ADDED", "nameplate5")
    f.A.eq(f.kind(plate), nil, "A recycled plate showed the previous mob's icon")
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(f.kind(plate), nil, "A recycled plate showed a stale icon after recalculation")
end)

test("A recycled plate for another quest mob shows only its own icon", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    f.remove("nameplate1")
    recycle(t, w, plate, "nameplate6", { related = true, lines = f.WOLF })
    f.event("NAME_PLATE_UNIT_ADDED", "nameplate6")
    f.A.eq(f.kind(plate), "loot", "Expected only the pouch on the recycled plate")
end)

test("Removing a plate with a recalculation pending shows nothing on it later", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    f.event("QUEST_LOG_UPDATE")
    f.remove("nameplate1")
    f.nextFrame()
    f.A.eq(f.kind(plate), nil, "A removed plate got its icon back from the pending recalculation")
end)

-- Restore ----------------------------------------------------------------------------------------

test("RestoreQuestMobs hides every icon at once and returns them to UIParent", function(t, w, f)
    f.ready()
    local a = f.add("nameplate1", { lines = f.KOBOLD })
    local b = f.add("nameplate2", { lines = f.WOLF })
    local roots = {}
    for _, o in ipairs(w.roots(a)) do roots[#roots + 1] = o end
    for _, o in ipairs(w.roots(b)) do roots[#roots + 1] = o end
    f.A.ok(#roots >= 2, "Precondition: two icons attached")
    QuietUIDB.enabled = false
    t.ns.QuestMobs.Restore()
    f.A.ok(w.nothingShown(), "An icon is still visible after RestoreQuestMobs")
    for _, o in ipairs(roots) do
        f.A.eq(o._parent, UIParent, "A restored icon was not returned to UIParent")
    end
    -- A recalculation queued before the restore must not bring them back.
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.ok(w.nothingShown(), "A pending recalculation showed icons after RestoreQuestMobs")
end)

test("A recalculation pending at restore time stays without effect", function(t, w, f)
    f.ready()
    f.add("nameplate1", { lines = f.KOBOLD })
    f.event("QUEST_LOG_UPDATE")
    QuietUIDB.enabled = false
    t.ns.QuestMobs.Restore()
    f.nextFrame()
    f.A.ok(w.nothingShown(), "The pending recalculation showed an icon after restore")
end)

test("Re-enabling after RestoreQuestMobs evaluates the plates again", function(t, w, f)
    f.ready()
    local a = f.add("nameplate1", { lines = f.KOBOLD })
    QuietUIDB.enabled = false
    t.ns.QuestMobs.Restore()
    -- While off the quest state changed and another mob appeared.
    local b = w.addPlate("nameplate2", { lines = f.WOLF })
    t.mock.units.nameplate1.related = false
    QuietUIDB.enabled = true
    t.ns.QuestMobs.Apply()
    f.A.eq(f.kind(a), nil, "A stale icon came back after re-enable")
    f.A.eq(f.kind(b), "loot", "Re-enable did not evaluate the visible plates")
end)

test("Unchecking Quest mobs and applying hides all icons at once; checking again shows them", function(t, w, f)
    f.ready()
    local a = f.add("nameplate1", { lines = f.KOBOLD })
    local b = f.add("nameplate2", { lines = f.WOLF })
    QuietUICharDB.questMobs = false
    t.ns.QuestMobs.Apply()
    f.A.ok(w.nothingShown(), "Icons stayed after Quest mobs was unchecked")
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.ok(w.nothingShown(), "Icons came back while Quest mobs is unchecked")
    QuietUICharDB.questMobs = nil
    t.ns.QuestMobs.Apply()
    f.A.ok(f.kind(a) == "kill" and f.kind(b) == "loot", "Checking Quest mobs again did not show the icons")
end)
