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

-- Missing or hostile client pieces --------------------------------------------------------------

local OUTPUT = { output = true }

test("Missing UnitIsRelatedToActiveQuest: no icon, no crash, one report", function(t, w, f)
    C_QuestLog.UnitIsRelatedToActiveQuest = nil
    f.ready()
    local a = f.add("nameplate1", { lines = f.KOBOLD })
    local b = f.add("nameplate2", { lines = f.WOLF })
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    t.ns.ApplyQuestMobs()
    f.A.ok(f.kind(a) == nil and f.kind(b) == nil, "An icon was shown without UnitIsRelatedToActiveQuest")
    f.A.eq(w.reports(), 1, "Expected exactly one report: " .. table.concat(t.mock.printed, " | "))
end, OUTPUT)

local NO_TOOLTIP = {
    { "C_TooltipInfo.GetUnit", function() C_TooltipInfo.GetUnit = nil end },
    { "C_TooltipInfo", function() C_TooltipInfo = nil end },
}
for _, c in ipairs(NO_TOOLTIP) do
    test("Missing " .. c[1] .. ": exclamation, no crash, one report", function(t, w, f)
        c[2]()
        f.ready()
        local a = f.add("nameplate1", { lines = f.KOBOLD })
        local b = f.add("nameplate2", { lines = f.WOLF })
        f.event("QUEST_LOG_UPDATE")
        f.nextFrame()
        f.A.ok(f.kind(a) == "kill" and f.kind(b) == "kill", "Without tooltip data a related mob must show the exclamation")
        f.A.eq(w.reports(), 1, "Expected exactly one report: " .. table.concat(t.mock.printed, " | "))
    end, OUTPUT)
end

test("Missing GetQuestObjectives: exclamation, no crash, one report", function(t, w, f)
    C_QuestLog.GetQuestObjectives = nil
    f.ready()
    local a = f.add("nameplate1", { lines = f.KOBOLD })
    local b = f.add("nameplate2", { lines = f.WOLF })
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.ok(f.kind(a) == "kill" and f.kind(b) == "kill", "Without objectives a related mob must show the exclamation")
    f.A.eq(w.reports(), 1, "Expected exactly one report: " .. table.concat(t.mock.printed, " | "))
end, OUTPUT)

-- Frames cannot be destroyed, so a failed icon must not be retried for every plate.
local function brokenIcons(t, w, f, mode)
    f.ready()
    local plates = {}
    for i = 1, 3 do plates[i] = w.addPlate("nameplate" .. i, { lines = i == 2 and f.WOLF or f.KOBOLD }) end
    local attempts, real = 0, CreateFrame
    CreateFrame = function(...)
        attempts = attempts + 1
        if mode == "throw" then error("CreateFrame is not available") end
        local frame = real(...)
        frame.CreateTexture = function() return nil end
        return frame
    end
    for i = 1, 3 do f.event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i) end
    t.ns.ApplyQuestMobs()
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    for i = 1, 3 do f.A.eq(f.kind(plates[i]), nil, "An icon was shown on nameplate" .. i) end
    f.A.eq(attempts, 1, "Expected exactly one CreateFrame attempt for quest mob icons")
    f.A.eq(w.reports(), 1, "Expected exactly one report: " .. table.concat(t.mock.printed, " | "))
    return t.mock.printed[1]
end

test("CreateTexture returning nil: one CreateFrame, one texture report, no crash", function(t, w, f)
    local line = brokenIcons(t, w, f, "nil")
    f.A.ok(line:lower():find("texture", 1, true), "The report does not mention the texture failure: " .. line)
end, OUTPUT)

test("CreateFrame throwing: one attempt, one report, no crash", function(t, w, f)
    brokenIcons(t, w, f, "throw")
end, OUTPUT)

test("Forbidden plate is skipped without calling its methods", function(t, w, f)
    f.ready()
    local calls = 0
    local proxy
    proxy = setmetatable({}, {
        __index = function(_, key)
            if key == "IsForbidden" then return function() return true end end
            return proxy
        end,
        __call = function() calls = calls + 1 end,
    })
    t.mock.nameplates.nameplate1 = proxy
    t.mock.units.nameplate1 = { exists = true, attackable = true, related = true, lines = f.KOBOLD }
    f.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    t.ns.ApplyQuestMobs()
    f.event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    f.A.eq(calls, 0, "A forbidden plate had method calls")
    f.A.ok(w.nothingShown(), "Something was shown on a forbidden plate")
end)

test("A plate event without a plate does not error", function(t, w, f)
    f.ready()
    t.mock.units.nameplate9 = { exists = true, attackable = true, related = true, lines = f.KOBOLD }
    f.event("NAME_PLATE_UNIT_ADDED", "nameplate9")
    f.event("NAME_PLATE_UNIT_REMOVED", "nameplate9")
    f.event("NAME_PLATE_UNIT_REMOVED", "nameplate8")
    f.A.ok(w.nothingShown(), "An icon appeared without a plate")
end)

test("Missing C_Timer: quest log events do not error", function(t, w, f)
    C_Timer = nil
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    t.mock.units.nameplate1.related = false
    f.event("QUEST_LOG_UPDATE")
    f.event("UNIT_QUEST_LOG_CHANGED", "player")
    t.ns.ApplyQuestMobs()
    f.A.eq(f.kind(plate), nil, "ApplyQuestMobs did not re-evaluate without C_Timer")
end)

test("Unknown event is ignored without error", function(t, w, f)
    f.ready()
    f.event("SOME_UNKNOWN_EVENT", "x")
end)

-- Hygiene ----------------------------------------------------------------------------------------

test("Plates are never moved, faded, shown or hidden through a full cycle", function(t, w, f)
    f.ready()
    local plate = f.add("nameplate1", { lines = f.KOBOLD })
    t.mock.state.combat = true
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.remove("nameplate1")
    t.mock.nameplates.nameplate1 = plate
    t.mock.units.nameplate1 = { exists = true, attackable = true, related = true, lines = f.WOLF }
    f.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    QuietUIDB.enabled = false
    t.ns.RestoreQuestMobs()
    f.A.ok(plate._alpha == 1 and plate._shown, "The plate changed state")
    f.A.ok(#plate._points == 0 and #plate.UnitFrame._points == 0 and #plate.bar._points == 0, "A plate frame was moved")
    -- Plate mutations, OnUpdate scripts and GameTooltip use are asserted after every case.
end)

test("Quest mob lookups never use GameTooltip or SetUnit", function(t, w, f)
    f.ready()
    f.add("nameplate1", { lines = f.KOBOLD })
    f.add("nameplate2", { lines = f.WOLF })
    f.event("QUEST_LOG_UPDATE")
    f.nextFrame()
    f.A.eq(w.tooltipUsed, 0, "GameTooltip was used")
end)

test("Media/quest-kill.tga and Media/quest-loot.tga exist and the icons use them", function(t, w, f)
    f.A.ok(t.fileExists("Media/quest-kill.tga"), "Media/quest-kill.tga does not exist")
    f.A.ok(t.fileExists("Media/quest-loot.tga"), "Media/quest-loot.tga does not exist")
    f.ready()
    local _, kill = w.iconOn(f.add("nameplate1", { lines = f.KOBOLD }))
    local _, loot = w.iconOn(f.add("nameplate2", { lines = f.WOLF }))
    f.A.ok(kill._texture:find("quest-kill.tga", 1, true), "The exclamation does not use Media/quest-kill.tga")
    f.A.ok(loot._texture:find("quest-loot.tga", 1, true), "The pouch does not use Media/quest-loot.tga")
end)
