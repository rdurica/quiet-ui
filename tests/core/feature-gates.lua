-- Registry gates: enabled, restore, hooks, required and early events.
local h = ...

local function errors(lines)
    local n = 0
    for _, line in ipairs(lines) do
        if line:find("error (shown once)", 1, true) then n = n + 1 end
    end
    return n
end

local function counters()
    return { apply = 0, restore = 0, event = 0, frame = 0, tick = 0, rescan = 0, fade = 0 }
end

local function gated(t, gate)
    local c = counters()
    t.ns.Feature({
        name = "gated", enabled = gate,
        apply = function() c.apply = c.apply + 1 end,
        restore = function() c.restore = c.restore + 1 end,
        events = { GATE_EVENT = function() c.event = c.event + 1 end },
        frame = function() c.frame = c.frame + 1 end,
        tick = function() c.tick = c.tick + 1 end,
        rescan = function() c.rescan = c.rescan + 1 end,
        fade = function() c.fade = c.fade + 1 end,
    })
    return c
end

local function runAll(t)
    t.ns.ApplyAll()
    t.mock:fire("GATE_EVENT")
    for _ = 1, 12 do t.mock:tick(0.1) end
    t.ns.RequestRescan()
    t.mock:drain()
end

h.test("a false gate skips apply, fade, frame, tick, rescan and events", function(t)
    local c = gated(t, function() return false end)
    t.boot()
    runAll(t)
    t.assert.deep(c, counters())
end)

h.test("a true gate lets every phase and event through", function(t)
    local c = gated(t, function() return true end)
    t.boot()
    runAll(t)
    local A = t.assert
    A.ok(c.apply >= 1 and c.event == 1 and c.frame >= 1 and c.tick >= 1 and c.rescan >= 1, "phases ran")
end)

h.test("a gate that follows live state switches the feature on and off", function(t)
    local on = false
    local c = gated(t, function() return on end)
    t.boot()
    t.mock:fire("GATE_EVENT")
    t.assert.eq(c.event, 0)
    on = true
    t.mock:fire("GATE_EVENT")
    t.assert.eq(c.event, 1)
end)

h.test("a throwing gate is reported once and treated as off", function(t)
    local c = gated(t, function() error("gate boom") end)
    local out = t.boot(false)
    runAll(t)
    runAll(t)
    t.assert.deep(c, counters())
    t.assert.eq(errors(out) + errors(t.mock.printed), 1, "reports once")
end)

h.test("restore runs even when the gate is off", function(t)
    local c = gated(t, function() return false end)
    t.boot()
    t.ns.RestoreAll()
    t.assert.eq(c.restore, 1)
end)

h.test("a throwing gate does not stop restore", function(t)
    local c = gated(t, function() error("gate boom") end)
    t.boot(false)
    t.ns.RestoreAll()
    t.assert.eq(c.restore, 1)
end)

------------------------------------------------------------------------------
-- hooks
------------------------------------------------------------------------------
h.test("a hook on an existing global runs after it, and only while QuietUI is on", function(t)
    local A = t.assert
    local hooked, original = 0, 0
    _G.QuietTestGlobal = function() original = original + 1 end
    t.ns.Feature({ name = "hooker", hooks = { QuietTestGlobal = function() hooked = hooked + 1 end } })
    t.boot()
    _G.QuietTestGlobal()
    A.deep({ original, hooked }, { 1, 1 })
    SlashCmdList.QUIETUI("off")
    _G.QuietTestGlobal()
    A.deep({ original, hooked }, { 2, 1 }, "no hook while off")
    SlashCmdList.QUIETUI("on")
    _G.QuietTestGlobal()
    A.deep({ original, hooked }, { 3, 2 })
end)

h.test("a hook waits for a global that appears later and is installed at boot", function(t)
    local A = t.assert
    local hooked = 0
    t.ns.Feature({ name = "late", hooks = { QuietLateGlobal = function() hooked = hooked + 1 end } })
    A.eq(errors(t.mock.printed), 0, "a missing global is not an error")
    _G.QuietLateGlobal = function() end
    t.boot()
    _G.QuietLateGlobal()
    A.eq(hooked, 1)
end)

h.test("a hook is installed once however often InstallHooks runs", function(t)
    local hooked = 0
    _G.QuietTwiceGlobal = function() end
    t.ns.Feature({ name = "twice", hooks = { QuietTwiceGlobal = function() hooked = hooked + 1 end } })
    t.boot()
    t.ns.Registry.InstallHooks()
    t.ns.Registry.InstallHooks()
    _G.QuietTwiceGlobal()
    t.assert.eq(hooked, 1)
end)

------------------------------------------------------------------------------
-- required and early events
------------------------------------------------------------------------------
local function badEvents(mock) mock.badEvents.BAD_REQUIRED = true; mock.badEvents.BAD_OPTIONAL = true end

h.test("a failed RegisterEvent of a required event is reported once as '<name> events'", function(t)
    local A = t.assert
    t.ns.Feature({ name = "needy", required = { "BAD_REQUIRED" }, events = { BAD_REQUIRED = function() end } })
    t.ns.Feature({ name = "needy2", required = { "BAD_REQUIRED" }, events = { BAD_REQUIRED = function() end } })
    local out = t.mock.printed
    A.eq(errors(out), 1, "reported once")
    A.ok(table.concat(out, "\n"):find("needy events", 1, true), "names the feature events")
end, { beforeLoad = badEvents })

h.test("a failed RegisterEvent of a non-required event is silent", function(t)
    t.ns.Feature({ name = "relaxed", events = { BAD_OPTIONAL = function() end } })
    t.assert.eq(errors(t.mock.printed), 0)
    t.boot()
end, { beforeLoad = badEvents })

h.test("early events are delivered before boot and while off; others are not", function(t)
    local A = t.assert
    local early, plain = 0, 0
    t.ns.Feature({
        name = "earlybird", early = { "EARLY_EVENT" },
        events = {
            EARLY_EVENT = function() early = early + 1 end,
            PLAIN_EVENT = function() plain = plain + 1 end,
        },
    })
    t.mock:fire("EARLY_EVENT")
    t.mock:fire("PLAIN_EVENT")
    A.deep({ early, plain }, { 1, 0 }, "before boot")
    t.boot()
    SlashCmdList.QUIETUI("off")
    t.mock:fire("EARLY_EVENT")
    t.mock:fire("PLAIN_EVENT")
    A.deep({ early, plain }, { 2, 0 }, "while off only the early event arrives")
end)
