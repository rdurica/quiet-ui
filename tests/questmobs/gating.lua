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

-- Unreadable data: any secret or missing value in the tooltip lines or quest objectives
-- leads to the exclamation, even next to a readable unfinished item objective.

local UNREADABLE = {
    { "a quest title with a secret id", function(f, secret)
        return { f.Q(secret, "Hidden Quest"), f.O("0/3 Gnoll Paws"), f.Q(LOOT_Q), f.O("4/8 Tough Wolf Meat") } end },
    { "a quest title with a missing id", function(f)
        return { f.Q(nil, "Hidden Quest"), f.O("0/3 Gnoll Paws"), f.Q(LOOT_Q), f.O("4/8 Tough Wolf Meat") } end },
    { "an objective line with secret text", function(f, secret)
        return { f.Q(LOOT_Q), { type = f.w.OBJECTIVE, leftText = secret }, f.O("4/8 Tough Wolf Meat") } end },
    { "a line with a secret type", function(f, secret)
        return { f.Q(LOOT_Q), { type = secret, leftText = "0/3 Gnoll Paws" }, f.O("4/8 Tough Wolf Meat") } end },
}
for _, c in ipairs(UNREADABLE) do
    test("Readable item objective next to " .. c[1] .. " shows the exclamation, not the pouch", function(t, w, f)
        f.ready()
        local plate = f.add("nameplate1", { lines = c[2](f, t.mock:secret("hidden")) })
        f.A.eq(f.kind(plate), "kill", "Unreadable data must lead to the exclamation")
    end)
end

test("A matched quest objective with a secret type shows the exclamation without error", function(t, w, f)
    f.ready()
    w.objectives[OTHER_Q] = {
        { text = "Gnoll Paws: 0/3", type = t.mock:secret("object"), finished = false },
        { text = "Tough Wolf Meat: 4/8", type = "item", finished = false },
    }
    local plate = f.add("nameplate1", { lines = { f.Q(OTHER_Q), f.O("4/8 Tough Wolf Meat"), f.O("0/3 Gnoll Paws") } })
    f.A.eq(f.kind(plate), "kill", "A secret objective type must lead to the exclamation")
end)

-- Gating ---------------------------------------------------------------------------------------

test("Unrelated mob shows nothing and its tooltip data is never read", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { related = false, lines = f.KOBOLD })
    f.A.eq(f.kind(plate), nil, "An unrelated mob got an icon")
    f.A.eq(w.count("GetUnit", "nameplate1"), 0, "C_TooltipInfo.GetUnit was called for an unrelated mob")
end)

test("Friendly NPC shows nothing and neither quest relation nor tooltip is asked", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { attack = false, lines = f.KOBOLD })
    f.A.eq(f.kind(plate), nil, "A friendly NPC got an icon")
    f.A.ok(w.count("UnitCanAttack", "nameplate1") >= 1, "UnitCanAttack was not asked")
    f.A.eq(w.count("Related", "nameplate1"), 0, "UnitIsRelatedToActiveQuest was called for a friendly NPC")
    f.A.eq(w.count("GetUnit", "nameplate1"), 0, "C_TooltipInfo.GetUnit was called for a friendly NPC")
end)

local HOSTILE = {
    { "a secret UnitCanAttack", function(secret, lines) return { attack = secret, lines = lines } end },
    { "a nil UnitCanAttack", function(_, lines) return { noAttack = true, attack = nil, lines = lines } end },
    { "a secret UnitIsRelatedToActiveQuest", function(secret, lines) return { related = secret, lines = lines } end },
    { "a nil UnitIsRelatedToActiveQuest", function(_, lines) return { noRelated = true, related = nil, lines = lines } end },
}
for _, c in ipairs(HOSTILE) do
    test(c[1] .. " shows nothing without error", function(t, w, f)
        f.ready()
        local plate = f.add("nameplate1", c[2](t.mock:secret(true), f.KOBOLD))
        f.event("QUEST_LOG_UPDATE")
        f.nextFrame()
        f.A.eq(f.kind(plate), nil, "An icon was shown for " .. c[1])
        f.A.eq(w.count("GetUnit", "nameplate1"), 0, "Tooltip data was read for " .. c[1])
    end)
end

test("Disabled QuietUI shows nothing and reads no tooltip", function(t, w, f)
    QuietUIDB.enabled = false
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(f.kind(plate), nil, "An icon was shown while QuietUI is off")
    f.A.eq(w.count("GetUnit", "nameplate1"), 0, "Tooltip data was read while QuietUI is off")
end)

test("Quest mobs off shows nothing", function(t, w, f)
    QuietUICharDB.questMobs = false
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(f.kind(plate), nil, "An icon was shown with Quest mobs off")
end)
