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
    t.ns.ApplyAll()
    t.mock:fire("GATE_EVENT")
    t.assert.eq(c.event, 1)
    on = false
    t.ns.ApplyAll()
    t.mock:fire("GATE_EVENT")
    t.assert.eq(c.event, 1)
end)

h.test("a disabled gate unregisters its event and skips all phases until re-enabled via ApplyAll", function(t)
    local A = t.assert
    local on = false
    local c = gated(t, function() return on end)
    t.boot()
    local regFrame = t.mock:eventFrame("PLAYER_LOGIN")
    A.ok(regFrame, "registry event frame exists")
    A.falsy(regFrame:IsEventRegistered("GATE_EVENT"), "event unregistered while gate is off at boot")
    A.eq(t.mock:eventFrame("GATE_EVENT"), nil, "no frame holds GATE_EVENT while gate is off")
    runAll(t)
    A.deep(c, counters(), "no apply, fade, frame, tick, rescan or event ran while off")

    on = true
    t.ns.ApplyAll()
    A.ok(regFrame:IsEventRegistered("GATE_EVENT"), "event registered after gate turns on and ApplyAll runs")
    A.eq(t.mock:eventFrame("GATE_EVENT"), regFrame)
    runAll(t)
    A.ok(c.apply >= 1, "apply ran")
    A.ok(c.fade >= 1, "fade ran")
    A.ok(c.frame >= 1, "frame ran")
    A.ok(c.tick >= 1, "tick ran")
    A.ok(c.rescan >= 1, "rescan ran")
    A.eq(c.event, 1, "event ran")

    on = false
    t.ns.ApplyAll()
    A.falsy(regFrame:IsEventRegistered("GATE_EVENT"), "event unregistered after gate turns off and ApplyAll runs")
    A.eq(t.mock:eventFrame("GATE_EVENT"), nil, "no frame holds GATE_EVENT after turning off")
    local snap = { apply = c.apply, restore = c.restore, event = c.event, frame = c.frame,
        tick = c.tick, rescan = c.rescan, fade = c.fade }
    runAll(t)
    A.deep(c, snap, "all phases and events stop once turned off")
end)

h.test("a shared event stays registered while any gated listener is enabled and unregisters when all are off", function(t)
    local A = t.assert
    local aOn, bOn = true, false
    local seen = { a = 0, b = 0 }
    t.ns.Feature({
        name = "sharedA", enabled = function() return aOn end,
        events = { SHARED_GATE_EVENT = function() seen.a = seen.a + 1 end },
    })
    t.ns.Feature({
        name = "sharedB", enabled = function() return bOn end,
        events = { SHARED_GATE_EVENT = function() seen.b = seen.b + 1 end },
    })
    t.boot()
    local regFrame = t.mock:eventFrame("PLAYER_LOGIN")
    A.ok(regFrame:IsEventRegistered("SHARED_GATE_EVENT"), "registered while sharedA is on")
    t.mock:fire("SHARED_GATE_EVENT")
    A.deep(seen, { a = 1, b = 0 }, "only enabled listener handles shared event")

    aOn = false
    t.ns.ApplyAll()
    A.falsy(regFrame:IsEventRegistered("SHARED_GATE_EVENT"), "unregistered when both listeners are off")

    bOn = true
    t.ns.ApplyAll()
    A.ok(regFrame:IsEventRegistered("SHARED_GATE_EVENT"), "re-registered when sharedB turns on")
    t.mock:fire("SHARED_GATE_EVENT")
    A.deep(seen, { a = 1, b = 1 })
end)

h.test("while QuietUI is off, normal events unregister while early and always events stay registered", function(t)
    local A = t.assert
    local seen = { plain = 0, always = 0, early = 0 }
    t.ns.Feature({
        name = "evlife",
        enabled = function() return false end,
        always = { "GATED_ALWAYS_EVENT" },
        events = { GATED_ALWAYS_EVENT = function() seen.always = seen.always + 1 end },
    })
    t.ns.Feature({
        name = "evplain",
        early = { "TEST_EARLY_EVENT" },
        events = {
            TEST_EARLY_EVENT = function() seen.early = seen.early + 1 end,
            TEST_PLAIN_EVENT = function() seen.plain = seen.plain + 1 end,
        },
    })
    t.boot()
    local regFrame = t.mock:eventFrame("PLAYER_LOGIN")
    A.ok(regFrame:IsEventRegistered("TEST_EARLY_EVENT"), "early registered")
    A.ok(regFrame:IsEventRegistered("TEST_PLAIN_EVENT"), "plain registered while on")
    A.ok(regFrame:IsEventRegistered("GATED_ALWAYS_EVENT"), "always registered once booted even with gate off")

    SlashCmdList.QUIETUI("off")
    A.ok(regFrame:IsEventRegistered("TEST_EARLY_EVENT"), "early stays registered while off")
    A.ok(regFrame:IsEventRegistered("GATED_ALWAYS_EVENT"), "always stays registered while off")
    A.falsy(regFrame:IsEventRegistered("TEST_PLAIN_EVENT"), "plain unregisters while QuietUI is off")
    t.mock:fire("TEST_EARLY_EVENT")
    t.mock:fire("GATED_ALWAYS_EVENT")
    t.mock:fire("TEST_PLAIN_EVENT")
    A.deep(seen, { plain = 0, always = 1, early = 1 })

    SlashCmdList.QUIETUI("on")
    A.ok(regFrame:IsEventRegistered("TEST_PLAIN_EVENT"), "plain re-registers on /quiet on")
end)

local DISABLED_MODULE_EVENTS = {
    "NAME_PLATE_UNIT_ADDED",
    "PLAYER_SOFT_INTERACT_CHANGED",
    "QUEST_LOG_UPDATE",
    "ACTIONBAR_SLOT_CHANGED",
    "PLAYER_XP_UPDATE",
    "UNIT_FLAGS",
    "UNIT_FACTION",
}

h.test("with only chat enabled, disabled-module events are not registered on the main registry event frame", function(t)
    local A = t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {
        modules = { chat = true, fading = false, helpers = false, layout = false, modernize = false },
    }
    t.boot()
    local regFrame = t.mock:eventFrame("PLAYER_LOGIN")
    A.ok(regFrame, "main registry event frame exists")
    A.ok(regFrame:IsEventRegistered("UPDATE_CHAT_WINDOWS"), "chat event stays registered")
    for _, event in ipairs(DISABLED_MODULE_EVENTS) do
        A.falsy(regFrame:IsEventRegistered(event), event .. " must not be registered at boot")
    end

    t.ns.ApplyAll()
    for _, event in ipairs(DISABLED_MODULE_EVENTS) do
        A.falsy(regFrame:IsEventRegistered(event), event .. " must not be registered after ApplyAll")
    end

    QuietUICharDB.modules.fading = true
    QuietUICharDB.modules.helpers = true
    t.ns.ApplyAll()
    for _, event in ipairs(DISABLED_MODULE_EVENTS) do
        A.ok(regFrame:IsEventRegistered(event), event .. " registers once its module is re-enabled")
    end
end)

h.test("a throwing gate is reported once and treated as off", function(t)
    local c = gated(t, function() error("gate boom") end)
    local out = t.boot(false)
    runAll(t)
    runAll(t)
    t.assert.deep(c, counters())
    t.assert.eq(errors(out) + errors(t.mock.printed), 1, "reports once")
end)

h.test("a throwing gate unregisters its event from the registry frame", function(t)
    gated(t, function() error("gate boom") end)
    t.boot(false)
    local regFrame = t.mock:eventFrame("PLAYER_LOGIN")
    t.assert.falsy(regFrame:IsEventRegistered("GATE_EVENT"), "throwing gate does not keep event registered")
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
    local out = t.boot(false)
    A.eq(errors(out) + errors(t.mock.printed), 1, "reported once")
    A.ok(table.concat(out, "\n"):find("needy events", 1, true), "names the feature events")
end, { beforeLoad = badEvents })

h.test("a failed required event of a disabled feature is silent", function(t)
    t.ns.Feature({
        name = "offneedy", enabled = function() return false end,
        required = { "BAD_REQUIRED" }, events = { BAD_REQUIRED = function() end },
    })
    t.boot()
    t.ns.ApplyAll()
    t.assert.eq(errors(t.mock.printed), 0)
end, { beforeLoad = badEvents })

h.test("a required event is reported for the second listener that requires it", function(t)
    local A = t.assert
    t.ns.Feature({ name = "plain", events = { BAD_REQUIRED = function() end } })
    t.ns.Feature({ name = "strict", required = { "BAD_REQUIRED" }, events = { BAD_REQUIRED = function() end } })
    local out = t.boot(false)
    A.eq(errors(out) + errors(t.mock.printed), 1, "reported once")
    A.ok(table.concat(out, "\n"):find("strict events", 1, true), "names the requiring feature")
end, { beforeLoad = badEvents })

h.test("only early events are registered before boot", function(t)
    local A = t.assert
    t.ns.Feature({
        name = "prebird", early = { "PRE_EARLY" },
        events = { PRE_EARLY = function() end, PRE_PLAIN = function() end },
    })
    local regFrame = t.mock:eventFrame("PRE_EARLY")
    A.ok(regFrame, "early event registered before boot")
    A.falsy(regFrame:IsEventRegistered("PRE_PLAIN"), "plain event waits for boot")
    t.boot()
    A.ok(regFrame:IsEventRegistered("PRE_PLAIN"), "plain event registered at boot")
end)

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

h.test("A module change through ActivatePreset turns its features off at once, before any apply", function(t)
    local A, ns = t.assert, t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true, modules = { modernize = true } }
    t.boot()
    A.eq(ns.Registry.IsOn("modern"), true, "Modernize is on after boot")

    ns.RestoreAll()
    ns.Settings.ActivatePreset(nil, { modules = { modernize = false } })
    A.eq(ns.Registry.IsOn("modern"), false, "Modernize is off right after the settings change")
end)
