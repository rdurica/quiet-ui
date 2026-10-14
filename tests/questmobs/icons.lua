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

-- Icon choice ---------------------------------------------------------------------------------

test("Kill objective shows the exclamation left of the health bar, parented to the plate, no mouse", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    local kind, tex = w.iconOn(plate)
    f.A.eq(kind, "kill", "Expected the exclamation (Media/quest-kill)")
    f.A.ok(w.count("GetUnit", "nameplate1") >= 1, "C_TooltipInfo.GetUnit was not asked for nameplate1")
    local roots = w.roots(plate)
    f.A.ok(#roots >= 1, "The icon is not attached to the plate")
    local direct, anchored = false, false
    for _, o in ipairs(roots) do
        if o._parent == plate then direct = true end
    end
    f.A.ok(direct, "The icon frame must be parented to the plate itself")
    for _, o in ipairs(t.mock.frames) do
        if w.within(o, plate) then
            for _, p in ipairs(o._points) do
                if p[1] == "RIGHT" and p[2] == plate.bar and p[3] == "LEFT" then anchored = true end
            end
            f.A.ok(o._mouse ~= true, "The icon must not take the mouse")
        end
    end
    f.A.ok(anchored, "The icon must anchor its RIGHT to the LEFT of UnitFrame.healthBar")
    f.A.ok(w.within(tex, plate), "The icon texture is not on the plate")
end)

test("Without a health bar the icon anchors to the left of UnitFrame", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD }, { noHealthBar = true })
    f.A.eq(f.kind(plate), "kill", "Expected the exclamation without a health bar")
    local anchored = false
    for _, o in ipairs(t.mock.frames) do
        if w.within(o, plate) then
            for _, p in ipairs(o._points) do
                if p[1] == "RIGHT" and p[2] == plate.UnitFrame and p[3] == "LEFT" then anchored = true end
            end
        end
    end
    f.A.ok(anchored, "The icon must anchor its RIGHT to the LEFT of UnitFrame as fallback")
end)

test("Item objective \"4/8 Tough Wolf Meat\" shows the pouch", function(t, w, f)
    f.ready()
    f.A.eq(f.kind(f.add("nameplate1", { lines = f.WOLF })), "loot", "Expected the pouch (Media/quest-loot)")
end)

test("Monster and item both unfinished show only the exclamation", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = { f.Q(KILL_Q), f.O("0/10 Kobold Vermin slain"),
        f.Q(LOOT_Q), f.O("4/8 Tough Wolf Meat") } })
    f.A.eq(f.kind(plate), "kill", "Exclamation must win over the pouch")
end)

test("Monster and item in one quest show only the exclamation", function(t, w, f)
    f.ready()
    w.objectives[OTHER_Q] = {
        { text = "Tough Wolf Meat: 1/8", type = "item", finished = false },
        { text = "Kobold Vermin slain: 0/10", type = "monster", finished = false },
    }
    local plate = f.add("nameplate1", { lines = { f.Q(OTHER_Q), f.O("1/8 Tough Wolf Meat"),
        f.O("0/10 Kobold Vermin slain") } })
    f.A.eq(f.kind(plate), "kill", "Exclamation must win over the pouch within one quest")
end)

local FALLBACKS = {
    { "an unmatched objective line", function(f) return { f.Q(LOOT_Q), f.O("0/3 Gnoll Paws") } end },
    { "an objective of another type", function(f) return { f.Q(OTHER_Q), f.O("0/1 Old Lockbox") } end },
    { "a quest title without objective lines", function(f) return { f.Q(LOOT_Q) } end },
    { "no tooltip lines at all", function() return {} end },
}
for _, c in ipairs(FALLBACKS) do
    test("Related quest mob with " .. c[1] .. " shows the exclamation", function(t, w, f)
        f.ready()
        w.objectives[OTHER_Q] = { { text = "Old Lockbox: 0/1", type = "object", finished = false } }
        f.A.eq(f.kind(f.add("nameplate1", { lines = c[2](f) })), "kill", "Expected the exclamation fallback")
    end)
end

test("Related quest mob whose tooltip data is nil shows the exclamation", function(t, w, f)
    f.ready()
    f.A.eq(f.kind(f.add("nameplate1", { lines = nil })), "kill", "Expected the exclamation without tooltip data")
end)

test("Objectives are matched per quest block", function(t, w, f)
    f.ready()
    -- "Red Bandana" is an item of quest 102 but the tooltip lists it under quest 103.
    w.objectives[LOOT_Q] = { { text = "Red Bandana: 0/5", type = "item", finished = false } }
    w.objectives[OTHER_Q] = { { text = "Something Else: 0/2", type = "item", finished = false } }
    local plate = f.add("nameplate1", { lines = { f.Q(LOOT_Q), f.Q(OTHER_Q), f.O("0/5 Red Bandana") } })
    f.A.eq(f.kind(plate), "kill", "A line must only match objectives of its own quest")
end)

test("A completed \"10/10\" line is skipped and the other unfinished item shows the pouch", function(t, w, f)
    f.ready()
    w.objectives[OTHER_Q] = {
        { text = "Kobold Vermin slain: 10/10", type = "monster", finished = true },
        { text = "Tough Wolf Meat: 2/8", type = "item", finished = false },
    }
    local plate = f.add("nameplate1", { lines = { f.Q(OTHER_Q), f.O("10/10 Kobold Vermin slain"),
        f.O("2/8 Tough Wolf Meat") } })
    f.A.eq(f.kind(plate), "loot", "The completed monster line must not count")
end)

test("A tooltip line at its goal is skipped even while the quest log still lags behind", function(t, w, f)
    f.ready()
    w.objectives[OTHER_Q] = {
        { text = "Kobold Vermin slain: 9/10", type = "monster", finished = false },
        { text = "Tough Wolf Meat: 2/8", type = "item", finished = false },
    }
    local plate = f.add("nameplate1", { lines = { f.Q(OTHER_Q), f.O("10/10 Kobold Vermin slain"),
        f.O("2/8 Tough Wolf Meat") } })
    f.A.eq(f.kind(plate), "loot", "x >= y on the tooltip line marks it done")
end)

-- Icon size follows the health bar height, clamped to 12..24.
for _, height in ipairs({ 8, 10, 20 }) do
    test("With a health bar of height " .. height .. " the icon is a square about that tall", function(t, w, f)
        f.ready()
        local plate = f.add("nameplate1", { lines = f.KOBOLD }, { barHeight = height })
        local kind, tex = w.iconOn(plate)
        f.A.eq(kind, "kill", "Expected the exclamation")
        local width, tall = tex._parent:GetSize()
        f.A.type(width, "number", "The icon frame size was not set")
        f.A.eq(width, tall, "The icon must be square")
        local want = math.min(24, math.max(12, height))
        f.A.ok(math.abs(tall - want) <= 2, "Icon size " .. tall .. " must be within 2 of " .. want)
    end)
end

h.test("Quest icon textures ship as TGA images", function(t)
    for _, file in ipairs({ "Media/quest-kill.tga", "Media/quest-loot.tga" }) do
        t.assert.ok(t.fileExists(file), file .. " does not exist")
        local data = t.readFile(file)
        t.assert.ok(data and #data > 18, file .. " is not a TGA image")
    end
end)
