-- Feature registry contract: ns.Feature, ns.Features, ns.ApplyAll, ns.RestoreAll, /quiet on|off|profile
-- and the OnUpdate scheduler, all driven through the real event frame of the mock.
local h = ...

local function errors(lines)
    local n = 0
    for _, line in ipairs(lines) do
        if line:find("error (shown once)", 1, true) then n = n + 1 end
    end
    return n
end

-- ns.Feature or a clear failure when the registry does not exist yet.
local function register(t, spec)
    t.assert.type(t.ns.Feature, "function", "ns.Feature")
    t.ns.Feature(spec)
end

local function logger()
    local log = {}
    return log, function(tag) return function() log[#log + 1] = tag end end
end

-- Registers a feature that counts every callback it gets. Returns the counters.
local function probe(t, name, extra)
    local c = { apply = 0, restore = 0, event = 0, frame = 0, tick = 0, rescan = 0, fade = 0 }
    local spec = {
        name = name,
        apply = function() c.apply = c.apply + 1 end,
        restore = function() c.restore = c.restore + 1 end,
        events = { PROBE_EVENT = function(...) c.event = c.event + 1; c.args = { ... } end },
        frame = function(elapsed) c.frame = c.frame + 1; c.elapsed = elapsed end,
        tick = function() c.tick = c.tick + 1 end,
        rescan = function() c.rescan = c.rescan + 1 end,
        fade = function(elapsed) c.fade = c.fade + 1; c.fadeElapsed = elapsed end,
    }
    for k, v in pairs(extra or {}) do spec[k] = v end
    register(t, spec)
    return c
end

------------------------------------------------------------------------------
-- Validation
------------------------------------------------------------------------------
h.test("a duplicate name is reported once, that feature is skipped, the others apply", function(t)
    local A = t.assert
    local log, rec = logger()
    register(t, { name = "dup", apply = rec("first") })
    register(t, { name = "dup", apply = rec("second") })
    register(t, { name = "other", apply = rec("other") })
    A.eq(errors(t.boot(false)), 1, "reports for the duplicate")
    for i = #log, 1, -1 do log[i] = nil end
    t.ns.ApplyAll()
    A.deep(log, { "first", "other" })
end)

h.test("an unknown field is reported once, that feature is skipped, the others apply", function(t)
    local A = t.assert
    local log, rec = logger()
    register(t, { name = "typo", apply = rec("typo"), aply = function() end })
    register(t, { name = "good", apply = rec("good") })
    A.eq(errors(t.boot(false)), 1, "reports for the unknown field")
    for i = #log, 1, -1 do log[i] = nil end
    t.ns.ApplyAll()
    A.deep(log, { "good" })
    local names = t.ns.Features()
    A.eq(names[#names], "good")
    for _, name in ipairs(names) do A.ne(name, "typo", "skipped feature is not listed") end
end)

h.test("ns.Features lists the names in registration order", function(t)
    local A = t.assert
    register(t, { name = "zeta" })
    register(t, { name = "alpha" })
    register(t, { name = "mid" })
    t.boot()
    local names = t.ns.Features()
    A.deep({ names[#names - 2], names[#names - 1], names[#names] }, { "zeta", "alpha", "mid" })
end)

------------------------------------------------------------------------------
-- Lifecycle moments
------------------------------------------------------------------------------
h.test("apply runs on ApplyAll, in registration order", function(t)
    local A = t.assert
    local log, rec = logger()
    register(t, { name = "a", apply = rec("a") })
    register(t, { name = "b", apply = rec("b") })
    register(t, { name = "c", apply = rec("c") })
    t.boot()
    for i = #log, 1, -1 do log[i] = nil end
    t.ns.ApplyAll()
    A.deep(log, { "a", "b", "c" })
end)

h.test("restore runs on RestoreAll in reverse registration order, before RestoreAlpha", function(t)
    local A = t.assert
    local held = CreateFrame("Frame")
    local log, seen = {}, {}
    local function restore(tag)
        return function()
            log[#log + 1] = tag
            seen[tag] = held._alpha
        end
    end
    register(t, { name = "r1", restore = restore("r1") })
    register(t, { name = "r2", restore = restore("r2") })
    register(t, { name = "r3", restore = restore("r3") })
    t.boot()
    t.ns.HoldAlpha(held, 0.2)
    A.alpha(held, 0.2)
    t.assert.type(t.ns.RestoreAll, "function", "ns.RestoreAll")
    t.ns.RestoreAll()
    A.deep(log, { "r3", "r2", "r1" })
    for tag, alpha in pairs(seen) do
        A.near(alpha, 0.2, 1e-6, tag .. " must still see the held alpha (RestoreAlpha runs after all feature restores)")
    end
    A.alpha(held, 1, "RestoreAlpha ran after the feature restores")
end)

h.test("/quiet off restores features and /quiet on applies them again", function(t)
    local A = t.assert
    local c = probe(t, "probe")
    t.boot()
    SlashCmdList.QUIETUI("off")
    A.eq(c.restore, 1, "restore on /quiet off")
    local applied = c.apply
    SlashCmdList.QUIETUI("on")
    A.eq(c.apply, applied + 1, "apply on /quiet on")
end)

h.test("an event reaches its handler with its payload", function(t)
    local A = t.assert
    local c = probe(t, "probe")
    t.boot()
    t.mock:fire("PROBE_EVENT", "x", "y")
    A.eq(c.event, 1)
    A.eq(c.args[#c.args], "y")
    A.eq(c.args[#c.args - 1], "x")
end)

h.test("frame runs every frame with the elapsed time", function(t)
    local A = t.assert
    local c = probe(t, "probe")
    t.boot()
    t.mock:tick(0.016)
    t.mock:tick(0.016)
    A.eq(c.frame, 2)
    A.near(c.elapsed, 0.016, 1e-9)
end)

h.test("tick runs every 0.1 s, not every frame", function(t)
    local A = t.assert
    local c = probe(t, "probe")
    t.boot()
    t.mock:tick(0.06)
    A.eq(c.tick, 0, "before 0.1 s")
    t.mock:tick(0.06)
    A.eq(c.tick, 1, "after 0.12 s")
end)

h.test("rescan runs about every second and on RequestRescan", function(t)
    local A = t.assert
    local c = probe(t, "probe")
    t.boot()
    t.mock:tick(0.6)
    A.eq(c.rescan, 0, "before 1 s")
    t.mock:tick(0.6)
    A.eq(c.rescan, 1, "after 1.2 s")
    t.ns.RequestRescan()
    t.mock:drain()
    A.eq(c.rescan, 2, "after RequestRescan")
end)

h.test("fade runs when focus changes, with the elapsed time", function(t)
    local A = t.assert
    local c = probe(t, "probe")
    t.boot()
    t.mock:tick(0.06)
    t.mock:tick(0.06)
    A.ok(c.fade >= 1, "fade not called on the first focus sample")
    A.type(c.fadeElapsed, "number")
end)

------------------------------------------------------------------------------
-- Shared events and errors
------------------------------------------------------------------------------
h.test("two features on one event both run in registration order; an error in the first is reported once", function(t)
    local A = t.assert
    local log = {}
    register(t, { name = "first", events = { SHARED_EVENT = function() log[#log + 1] = "first"; error("boom") end } })
    register(t, { name = "second", events = { SHARED_EVENT = function() log[#log + 1] = "second" end } })
    t.boot()
    t.mock:fire("SHARED_EVENT")
    t.mock:fire("SHARED_EVENT")
    A.deep(log, { "first", "second", "first", "second" })
    A.eq(errors(t.mock.printed), 1, "reports")
end)

h.test("two features on one event run in order when neither fails", function(t)
    local log = {}
    register(t, { name = "one", events = { SHARED_EVENT = function() log[#log + 1] = "one" end } })
    register(t, { name = "two", events = { SHARED_EVENT = function() log[#log + 1] = "two" end } })
    t.boot()
    t.mock:fire("SHARED_EVENT")
    t.assert.deep(log, { "one", "two" })
end)

h.test("a callback that throws every frame is reported once and the others keep updating", function(t)
    local A = t.assert
    local good = 0
    register(t, { name = "broken", frame = function() error("every frame") end })
    register(t, { name = "healthy", frame = function() good = good + 1 end })
    t.boot()
    for _ = 1, 5 do t.mock:tick(0.016) end
    A.eq(errors(t.mock.printed), 1, "reports")
    A.eq(good, 5, "healthy feature updates")
end)

------------------------------------------------------------------------------
-- While QuietUI is off
------------------------------------------------------------------------------
h.test("while off, feature events are not delivered except those listed in always", function(t)
    local A = t.assert
    local got = { plain = 0, kept = 0 }
    register(t, {
        name = "gated",
        events = {
            PLAIN_EVENT = function() got.plain = got.plain + 1 end,
            KEPT_EVENT = function() got.kept = got.kept + 1 end,
        },
        always = { "KEPT_EVENT" },
    })
    t.boot()
    t.mock:fire("PLAIN_EVENT")
    t.mock:fire("KEPT_EVENT")
    A.deep(got, { plain = 1, kept = 1 }, "delivered while on")
    SlashCmdList.QUIETUI("off")
    t.mock:fire("PLAIN_EVENT")
    t.mock:fire("KEPT_EVENT")
    A.deep(got, { plain = 1, kept = 2 }, "only the always event while off")
    SlashCmdList.QUIETUI("on")
    t.mock:fire("PLAIN_EVENT")
    A.eq(got.plain, 2, "delivered again after /quiet on")
end)

h.test("PLAYER_REGEN_ENABLED listed in always still arrives while off", function(t)
    local seen = 0
    register(t, { name = "deferred", events = { PLAYER_REGEN_ENABLED = function() seen = seen + 1 end },
        always = { "PLAYER_REGEN_ENABLED" } })
    t.boot()
    SlashCmdList.QUIETUI("off")
    local before = seen
    t.mock:fire("PLAYER_REGEN_ENABLED")
    t.assert.eq(seen, before + 1)
end)

h.test("events are not delivered before boot", function(t)
    local seen = 0
    register(t, { name = "early", events = { EARLY_EVENT = function() seen = seen + 1 end } })
    t.mock:fire("EARLY_EVENT")
    t.assert.eq(seen, 0)
end)

------------------------------------------------------------------------------
-- /quiet profile
------------------------------------------------------------------------------
h.test("/quiet profile lists one row per feature phase", function(t)
    local A, mock = t.assert, t.mock
    local function costly(fn)
        return function(...)
            mock.profile = mock.profile + 5
            return fn and fn(...)
        end
    end
    register(t, { name = "probe", frame = costly(), tick = costly(), fade = costly(), rescan = costly() })
    t.boot()
    SlashCmdList.QUIETUI("profile")
    for _ = 1, 110 do
        mock.now = mock.now + 0.1
        mock:tick(0.1)
    end
    for _, phase in ipairs({ "frame", "tick", "fade", "rescan" }) do
        A.printed(mock, "probe." .. phase .. ":", 1)
    end
end)
