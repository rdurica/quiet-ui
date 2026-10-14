-- Runtime wiring for Quest mobs: ApplyAll / RestoreAll and event forwarding by the event frame.
local h = ...

local QM_EVENTS = {
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
    "PLAYER_ENTERING_WORLD",
}
local ARGS = {
    NAME_PLATE_UNIT_ADDED = { "nameplate4" },
    NAME_PLATE_UNIT_REMOVED = { "nameplate4" },
    QUEST_LOG_UPDATE = {},
    UNIT_QUEST_LOG_CHANGED = { "player" },
    PLAYER_ENTERING_WORLD = { false, false },
}
-- Handlers that already ran for these events must keep running next to Quest mobs.
local EXISTING = {
    NAME_PLATE_UNIT_ADDED = { "HighlightsEvent" },
    NAME_PLATE_UNIT_REMOVED = { "HighlightsEvent", "ForgetRangePlate" },
    QUEST_LOG_UPDATE = { "QuestNoticeEvent" },
    PLAYER_ENTERING_WORLD = { "HighlightsEvent", "QuestNoticeEvent" },
}

-- Replaces the feature entry points and the neighbouring handlers with recording spies.
-- opts.noQuestMobs leaves the quest mob entry points missing.
local function spied(t, opts)
    opts = opts or {}
    local env = { calls = {} }
    local function spy(name)
        t.ns[name] = function(...)
            env.calls[name] = env.calls[name] or {}
            env.calls[name][#env.calls[name] + 1] = { n = select("#", ...), ... }
        end
    end
    for _, name in ipairs({ "HighlightsEvent", "QuestNoticeEvent", "ForgetRangePlate" }) do spy(name) end
    for _, name in ipairs({ "ApplyQuestMobs", "RestoreQuestMobs", "QuestMobsEvent" }) do
        if opts.noQuestMobs then t.ns[name] = nil else spy(name) end
    end
    function env.count(name) return #(env.calls[name] or {}) end
    -- Calls of spyName made for event `name` after the first `from` calls.
    function env.forwards(name, from, spyName)
        spyName = spyName or "QuestMobsEvent"
        local list = {}
        for i = (from or 0) + 1, env.count(spyName) do
            local call = env.calls[spyName][i]
            if spyName == "ForgetRangePlate" or call[1] == name then list[#list + 1] = call end
        end
        return list
    end
    function env.dispatch(name, ...) t.mock:fire(name, ...) end
    return env
end

local function noErrors(t) t.assert.notPrinted(t.mock, "error") end

h.test("boot applies quest mobs without runtime errors", function(t)
    local env = spied(t)
    t.boot()
    t.assert.ok(env.count("ApplyQuestMobs") > 0, "Boot (ApplyAll) must call ns.ApplyQuestMobs")
end)

h.test("Save path ns.ApplyAll calls ApplyQuestMobs", function(t)
    local env = spied(t)
    t.boot()
    local n = env.count("ApplyQuestMobs")
    t.ns.ApplyAll()
    t.assert.ok(env.count("ApplyQuestMobs") > n, "ns.ApplyAll must call ns.ApplyQuestMobs")
end)

h.test("quest mob events are registered, including UNIT_QUEST_LOG_CHANGED", function(t)
    for _, name in ipairs(QM_EVENTS) do
        t.assert.ok(t.mock:eventFrame(name), "Missing registered " .. name)
    end
end)

h.test("enabled runtime forwards each quest mob event once with original arguments", function(t)
    local A = t.assert
    local env = spied(t)
    t.boot()
    for _, name in ipairs(QM_EVENTS) do
        local n = env.count("QuestMobsEvent")
        env.dispatch(name, table.unpack(ARGS[name]))
        local got = env.forwards(name, n)
        A.eq(#got, 1, "Forwards of " .. name .. " to ns.QuestMobsEvent")
        local want = ARGS[name]
        A.eq(got[1].n, #want + 1, name .. ": argument count")
        for i, v in ipairs(want) do A.eq(got[1][i + 1], v, name .. ": argument " .. i) end
    end
    noErrors(t)
end)

h.test("existing handlers still run next to the quest mob forward", function(t)
    local env = spied(t)
    t.boot()
    for name, names in pairs(EXISTING) do
        for _, spyName in ipairs(names) do
            local n = env.count(spyName)
            env.dispatch(name, table.unpack(ARGS[name]))
            t.assert.ok(#env.forwards(name, n, spyName) >= 1, name .. " no longer reaches " .. spyName)
        end
    end
    noErrors(t)
end)

h.test("Glance toggle does not apply or restore quest mobs", function(t)
    local env = spied(t)
    t.boot()
    local a, r = env.count("ApplyQuestMobs"), env.count("RestoreQuestMobs")
    QuietUIGlance("down")
    t.mock.slash.QUIETUI("glance")
    t.assert.ok(env.count("ApplyQuestMobs") == a and env.count("RestoreQuestMobs") == r, "Glance must not touch quest mobs")
    QuietUIGlance("down")
end)

h.test("Edit Mode layout update does not apply or restore quest mobs", function(t)
    local env = spied(t)
    t.boot()
    local a, r = env.count("ApplyQuestMobs"), env.count("RestoreQuestMobs")
    env.dispatch("EDIT_MODE_LAYOUTS_UPDATED")
    t.assert.ok(env.count("ApplyQuestMobs") == a and env.count("RestoreQuestMobs") == r, "Edit Mode must not touch quest mobs")
end)

h.test("/quiet off calls RestoreQuestMobs", function(t)
    local env = spied(t)
    t.boot()
    local n = env.count("RestoreQuestMobs")
    t.mock.slash.QUIETUI("off")
    t.assert.ok(env.count("RestoreQuestMobs") > n, "/quiet off (RestoreAll) must call ns.RestoreQuestMobs")
end)

h.test("disabled runtime forwards no plate or quest log events", function(t)
    local env = spied(t)
    t.boot()
    t.mock.slash.QUIETUI("off")
    t.assert.eq(QuietUIDB.enabled, false, "Precondition: disabled")
    for _, name in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED" }) do
        local n = env.count("QuestMobsEvent")
        env.dispatch(name, table.unpack(ARGS[name]))
        t.assert.eq(#env.forwards(name, n), 0, name .. " must not be forwarded while disabled")
    end
    noErrors(t)
end)

h.test("/quiet on calls ApplyQuestMobs", function(t)
    local env = spied(t)
    t.boot()
    t.mock.slash.QUIETUI("off")
    local n = env.count("ApplyQuestMobs")
    t.mock.slash.QUIETUI("on")
    t.assert.ok(env.count("ApplyQuestMobs") > n, "/quiet on must call ns.ApplyQuestMobs")
    noErrors(t)
end)

h.test("missing quest mobs module does not error", function(t)
    spied(t, { noQuestMobs = true })
    t.boot()
    for _, name in ipairs(QM_EVENTS) do t.mock:fire(name, table.unpack(ARGS[name])) end
    t.ns.ApplyAll()
    t.mock.slash.QUIETUI("off")
    t.mock.slash.QUIETUI("on")
    noErrors(t)
end)

h.test("Boot while disabled reaches RestoreQuestMobs and not ApplyQuestMobs", function(t)
    local env = spied(t)
    QuietUIDB.enabled = false
    t.boot()
    t.assert.ok(env.count("RestoreQuestMobs") > 0, "Boot while disabled must call ns.RestoreQuestMobs (ApplyAll -> RestoreAll)")
    t.assert.eq(env.count("ApplyQuestMobs"), 0, "Boot while disabled must not apply quest mobs")
    noErrors(t)
end)

h.test("A throwing QuestMobsEvent keeps the other handlers and reports once under quest mobs", function(t)
    local A = t.assert
    local env = spied(t)
    t.boot()
    local thrown = 0
    t.ns.QuestMobsEvent = function() thrown = thrown + 1; error("quest mobs exploded") end
    local before = {}
    for _, key in ipairs({ "ForgetRangePlate", "HighlightsEvent", "QuestNoticeEvent" }) do before[key] = env.count(key) end
    env.dispatch("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    env.dispatch("QUEST_LOG_UPDATE")
    env.dispatch("NAME_PLATE_UNIT_ADDED", "nameplate4")
    A.eq(thrown, 3, "QuestMobsEvent must be reached for all three events")
    A.eq(env.count("ForgetRangePlate"), before.ForgetRangePlate + 1, "NAME_PLATE_UNIT_REMOVED skipped ForgetRangePlate")
    A.eq(env.count("HighlightsEvent"), before.HighlightsEvent + 2, "Plate events skipped HighlightsEvent")
    A.eq(env.count("QuestNoticeEvent"), before.QuestNoticeEvent + 1, "QUEST_LOG_UPDATE skipped QuestNoticeEvent")
    A.eq(#t.mock.printed, 1, "Expected exactly one error report: " .. table.concat(t.mock.printed, " | "))
    A.printed(t.mock, "quest mobs", 1)
    A.printed(t.mock, "exploded", 1)
end)
