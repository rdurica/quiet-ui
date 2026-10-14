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
