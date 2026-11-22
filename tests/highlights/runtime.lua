-- Runtime wiring: ApplyAll / RestoreAll call Highlights and the events are forwarded.
local h = ...

local HL_EVENTS = { "PLAYER_SOFT_INTERACT_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }
local ARGS = {
    PLAYER_SOFT_INTERACT_CHANGED = { "Creature-old", "GameObject-0-1-2-3-4-5" },
    NAME_PLATE_UNIT_ADDED = { "nameplate4" },
    NAME_PLATE_UNIT_REMOVED = { "nameplate4" },
    ZONE_CHANGED_NEW_AREA = {},
    PLAYER_REGEN_DISABLED = {},
    PLAYER_REGEN_ENABLED = {},
    PLAYER_ENTERING_WORLD = { false, false },
}

-- Spies that call through, installed before boot. opts.without removes the module functions.
local function setup(t, opts)
    opts = opts or {}
    local ns = t.ns
    local env = { ns = ns, calls = {}, mock = t.mock }
    local short = { ApplyHighlights = "Apply", RestoreHighlights = "Restore", HighlightsEvent = "Event" }
    for _, key in ipairs({ "ApplyHighlights", "RestoreHighlights", "HighlightsEvent" }) do
        local original = ns.Highlights[short[key]]
        if opts.without then
            ns.Highlights[short[key]] = nil
        else
            ns.Highlights[short[key]] = function(...)
                env.calls[key] = env.calls[key] or {}
                env.calls[key][#env.calls[key] + 1] = { n = select("#", ...), ... }
                return original(...)
            end
        end
    end
    function env.count(key) return #(env.calls[key] or {}) end
    function env.frame() return t.mock:eventFrame("PLAYER_LOGIN") end
    function env.dispatch(name, ...)
        local frame = env.frame()
        frame:GetScript("OnEvent")(frame, name, ...)
    end
    function env.forwards(name, from)
        local list = {}
        for i = (from or 0) + 1, env.count("HighlightsEvent") do
            if env.calls.HighlightsEvent[i][1] == name then list[#list + 1] = env.calls.HighlightsEvent[i] end
        end
        return list
    end
    function env.noErrors()
        for _, line in ipairs(t.mock.printed) do
            t.assert.falsy(line:find("error (shown once)", 1, true), "runtime error: " .. line)
        end
    end
    return env
end

h.test("Boot applies highlights without runtime errors", function(t)
    local env = setup(t)
    t.boot()
    env.noErrors()
    t.assert.ok(env.count("ApplyHighlights") > 0, "boot (ApplyAll) must call ApplyHighlights")
end)

h.test("ns.ApplyAll calls ApplyHighlights", function(t)
    local env = setup(t)
    t.boot()
    local n = env.count("ApplyHighlights")
    t.ns.ApplyAll()
    t.assert.ok(env.count("ApplyHighlights") > n, "ApplyAll must call ApplyHighlights")
end)

h.test("Highlight events are registered", function(t)
    local frame = t.mock:eventFrame("PLAYER_LOGIN")
    for _, name in ipairs(HL_EVENTS) do
        t.assert.ok(frame:IsEventRegistered(name), "missing registered " .. name)
    end
end)

h.test("Enabled runtime forwards each highlight event with the original arguments", function(t)
    local A = t.assert
    local env = setup(t)
    t.boot()
    for _, name in ipairs(HL_EVENTS) do
        local n = env.count("HighlightsEvent")
        env.dispatch(name, unpack(ARGS[name]))
        local got = env.forwards(name, n)
        A.eq(#got, 1, "forwards of " .. name)
        local want = ARGS[name]
        A.eq(got[1].n, #want + 1, name .. ": argument count")
        for i, v in ipairs(want) do A.eq(got[1][i + 1], v, name .. ": argument " .. i) end
    end
    env.noErrors()
end)

h.test("Glance toggle does not apply or restore highlights", function(t)
    local env = setup(t)
    t.boot()
    local a, r = env.count("ApplyHighlights"), env.count("RestoreHighlights")
    QuietUIGlance("down")
    SlashCmdList.QUIETUI("glance")
    t.assert.ok(env.count("ApplyHighlights") == a and env.count("RestoreHighlights") == r,
        "Glance must not touch highlights")
    QuietUIGlance("down")
end)

h.test("Edit Mode layout update does not apply or restore highlights", function(t)
    local env = setup(t)
    t.boot()
    local a, r = env.count("ApplyHighlights"), env.count("RestoreHighlights")
    env.dispatch("EDIT_MODE_LAYOUTS_UPDATED")
    t.assert.ok(env.count("ApplyHighlights") == a and env.count("RestoreHighlights") == r,
        "Edit Mode must not touch highlights")
end)

h.test("/quiet off calls RestoreHighlights", function(t)
    local env = setup(t)
    t.boot()
    local n = env.count("RestoreHighlights")
    SlashCmdList.QUIETUI("off")
    t.assert.ok(env.count("RestoreHighlights") > n, "/quiet off (RestoreAll) must call RestoreHighlights")
end)

h.test("Disabled runtime forwards only PLAYER_REGEN_ENABLED", function(t)
    local A = t.assert
    local env = setup(t)
    t.boot()
    SlashCmdList.QUIETUI("off")
    A.eq(t.ns.DB().enabled, false, "precondition: disabled")
    for _, name in ipairs(HL_EVENTS) do
        local n = env.count("HighlightsEvent")
        env.dispatch(name, unpack(ARGS[name]))
        local got = #env.forwards(name, n)
        if name == "PLAYER_REGEN_ENABLED" then
            A.eq(got, 1, "PLAYER_REGEN_ENABLED must reach HighlightsEvent while disabled (deferred CVar restore)")
        else
            A.eq(got, 0, name .. " must not be forwarded while disabled")
        end
    end
    env.noErrors()
end)

h.test("/quiet on calls ApplyHighlights", function(t)
    local env = setup(t)
    t.boot()
    SlashCmdList.QUIETUI("off")
    local n = env.count("ApplyHighlights")
    SlashCmdList.QUIETUI("on")
    t.assert.ok(env.count("ApplyHighlights") > n, "/quiet on must call ApplyHighlights")
    env.noErrors()
end)

h.test("Missing highlights module does not error", function(t)
    local env = setup(t, { without = true })
    t.boot()
    for _, name in ipairs(HL_EVENTS) do env.dispatch(name, unpack(ARGS[name])) end
    t.ns.ApplyAll()
    SlashCmdList.QUIETUI("off")
    env.dispatch("PLAYER_REGEN_ENABLED")
    SlashCmdList.QUIETUI("on")
    env.noErrors()
end)

h.test("Boot while disabled with stale highlightCVars restores them and does not apply", function(t)
    local A = t.assert
    local env = setup(t)
    t.mock.cvars.SoftTargetInteract = "3"
    t.ns.DB().enabled = false
    t.ns.DB().highlightCVars = { SoftTargetInteract = "1" }
    t.boot()
    A.ok(env.count("RestoreHighlights") > 0, "boot while disabled must call RestoreHighlights (ApplyAll -> RestoreAll)")
    A.eq(env.count("ApplyHighlights"), 0, "boot while disabled must not apply highlights")
    A.eq(t.mock.cvars.SoftTargetInteract, "1", "the stale CVar was not restored")
    A.eq(t.ns.DB().highlightCVars, nil, "the stale snapshot was not cleared")
    env.noErrors()
end)

h.test("The highlights module is loaded before the runtime boots", function(t)
    local A = t.assert
    A.type(t.ns.Highlights.Apply, "function")
    A.type(t.ns.Highlights.Restore, "function")
    A.type(t.ns.Highlights.Event, "function")
    local env = setup(t)
    t.boot()
    A.ok(env.count("ApplyHighlights") > 0, "boot did not reach the highlights module")
end)

local CVAR_NAMES = {
    "SoftTargetInteract",
    "SoftTargetInteractRange",
    "SoftTargetNameplateInteract",
    "SoftTargetIconGameObject",
    "SoftTargetInteractArc",
    "SoftTargetIconInteract",
}

local ORIGINAL_CVARS = {
    SoftTargetInteract = "1",
    SoftTargetInteractRange = "10",
    SoftTargetNameplateInteract = "0",
    SoftTargetIconGameObject = "0",
    SoftTargetInteractArc = "0",
    SoftTargetIconInteract = "0",
}

local WANT_CVARS = {
    SoftTargetInteract = "3",
    SoftTargetInteractRange = "15",
    SoftTargetNameplateInteract = "1",
    SoftTargetIconGameObject = "1",
    SoftTargetInteractArc = "2",
    SoftTargetIconInteract = "1",
}

local function seedCVars(t, values)
    for _, name in ipairs(CVAR_NAMES) do
        t.mock.cvars[name] = values[name]
    end
end

local function copyMap(src)
    local out = {}
    for k, v in pairs(src) do out[k] = v end
    return out
end

local function assertCVars(A, t, expected, msg)
    for _, name in ipairs(CVAR_NAMES) do
        A.eq(t.mock.cvars[name], expected[name], msg .. " (" .. name .. ")")
    end
end

h.test("PLAYER_REGEN_ENABLED does not write SoftTargetInteract* CVars when helpers is disabled", function(t)
    local A = t.assert
    local env = setup(t)
    seedCVars(t, ORIGINAL_CVARS)
    QuietUICharDB.modules = { chat = true, helpers = false }
    QuietUICharDB.highlights = { herb = true, ore = true, quest = true }

    t.boot()
    A.eq(#t.mock.cvarLog, 0, "boot must not write CVars when helpers is disabled")
    A.ok(env.frame():IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "PLAYER_REGEN_ENABLED must stay registered for deferred CVar restore")

    t.mock.state.combat = true
    env.dispatch("PLAYER_REGEN_DISABLED")
    t.mock.state.combat = false
    env.dispatch("PLAYER_REGEN_ENABLED")

    A.eq(#t.mock.cvarLog, 0, "PLAYER_REGEN_ENABLED must not write SoftTargetInteract* CVars when helpers is disabled")
    assertCVars(A, t, ORIGINAL_CVARS, "CVars must stay unchanged when helpers is disabled")
    A.eq(t.ns.DB().highlightCVars, nil, "highlightCVars snapshot must remain nil when helpers is disabled")
    A.eq(t.ns.Highlights.Active(), false, "ns.Highlights.Active() must be false when helpers is disabled")

    t.ns.Highlights.SyncCVars()
    A.eq(#t.mock.cvarLog, 0, "SyncCVars must not write CVars when helpers is disabled")
    env.noErrors()
end)

h.test("PLAYER_REGEN_ENABLED after disabling helpers restores saved CVars instead of keeping active ones", function(t)
    local A = t.assert
    local env = setup(t)
    seedCVars(t, ORIGINAL_CVARS)
    QuietUICharDB.modules = { chat = true, helpers = true }
    QuietUICharDB.highlights = { herb = true, ore = true, quest = true }

    t.boot()
    env.dispatch("PLAYER_SOFT_INTERACT_CHANGED", unpack(ARGS.PLAYER_SOFT_INTERACT_CHANGED))
    A.eq(t.ns.Highlights.Active(), true, "precondition: Highlights must be active when helpers is enabled")
    assertCVars(A, t, WANT_CVARS, "precondition: active WANT CVars must be applied")
    A.deep(t.ns.DB().highlightCVars, ORIGINAL_CVARS, "precondition: highlightCVars must hold original snapshot")

    t.mock.state.combat = true
    env.dispatch("PLAYER_REGEN_DISABLED")
    QuietUICharDB.modules = { chat = true, helpers = false }
    t.ns.ApplyAll()

    local writesBeforeEnd = #t.mock.cvarLog
    t.ns.Highlights.SyncCVars()
    A.eq(#t.mock.cvarLog, writesBeforeEnd, "SyncCVars must defer CVar writes while in combat")

    t.mock.state.combat = false
    A.ok(env.frame():IsEventRegistered("PLAYER_REGEN_ENABLED"),
        "PLAYER_REGEN_ENABLED must stay registered when helpers is disabled")
    env.dispatch("PLAYER_REGEN_ENABLED")

    assertCVars(A, t, ORIGINAL_CVARS, "combat end after disabling helpers must restore original CVars")
    A.eq(t.ns.DB().highlightCVars, nil, "highlightCVars snapshot must be cleared after restore")
    A.eq(t.ns.Highlights.Active(), false, "ns.Highlights.Active() must be false after disabling helpers")
    A.ok(#t.mock.cvarLog > writesBeforeEnd, "combat end must write the restored original CVars")
    env.noErrors()
end)

h.test("Stale highlightCVars from prior helpers session are restored on PLAYER_REGEN_ENABLED when helpers is disabled", function(t)
    local A = t.assert
    local env = setup(t)
    seedCVars(t, WANT_CVARS)
    t.ns.DB().highlightCVars = copyMap(ORIGINAL_CVARS)
    QuietUICharDB.modules = { chat = true, helpers = false }
    QuietUICharDB.highlights = { herb = true, ore = true, quest = true }

    t.boot()
    local writesAtBoot = #t.mock.cvarLog
    env.dispatch("PLAYER_REGEN_ENABLED")

    assertCVars(A, t, ORIGINAL_CVARS, "PLAYER_REGEN_ENABLED must restore saved original CVars instead of writing active ones")
    A.eq(t.ns.DB().highlightCVars, nil, "highlightCVars snapshot must be cleared")
    A.eq(t.ns.Highlights.Active(), false, "ns.Highlights.Active() must be false when helpers is disabled")
    local writesAfterRestore = #t.mock.cvarLog
    A.ok(writesAfterRestore > writesAtBoot, "restore must have written original CVars")
    t.ns.Highlights.SyncCVars()
    A.eq(#t.mock.cvarLog, writesAfterRestore, "subsequent SyncCVars must not write CVars")
    env.noErrors()
end)

h.test("Combat-deferred restore finishes on PLAYER_REGEN_ENABLED when helpers is disabled", function(t)
    local A = t.assert
    local env = setup(t)
    seedCVars(t, ORIGINAL_CVARS)
    QuietUICharDB.modules = { chat = true, helpers = true }
    QuietUICharDB.highlights = { herb = true, ore = true, quest = true }

    t.boot()
    env.dispatch("PLAYER_SOFT_INTERACT_CHANGED", unpack(ARGS.PLAYER_SOFT_INTERACT_CHANGED))
    assertCVars(A, t, WANT_CVARS, "precondition: WANT CVars active before combat")

    t.mock.state.combat = true
    env.dispatch("PLAYER_REGEN_DISABLED")
    QuietUICharDB.modules = { chat = true, helpers = false }
    SlashCmdList.QUIETUI("off")

    local writesInCombat = #t.mock.cvarLog
    assertCVars(A, t, WANT_CVARS, "CVars must not change during combat")
    A.deep(t.ns.DB().highlightCVars, ORIGINAL_CVARS, "highlightCVars must stay saved until combat ends")

    t.mock.state.combat = false
    env.dispatch("PLAYER_REGEN_ENABLED")

    assertCVars(A, t, ORIGINAL_CVARS, "combat-deferred restore must restore original CVars")
    A.eq(t.ns.DB().highlightCVars, nil, "highlightCVars must be cleared after combat-deferred restore")
    A.eq(t.ns.Highlights.Active(), false, "ns.Highlights.Active() must remain false")
    A.ok(#t.mock.cvarLog > writesInCombat, "combat-deferred restore must write original CVars on PLAYER_REGEN_ENABLED")
    env.noErrors()
end)
