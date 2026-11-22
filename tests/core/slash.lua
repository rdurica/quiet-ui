-- /quiet slash command: empty/whitespace toggles, on/off set enabled, unknown arguments
-- keep state untouched and print a usage message, and valid subcommands dispatch cleanly.
local h = ...

local USAGE = "Try /quiet [on|off|setup|glance|preset|profile|dump]."
local ZERO_COUNTS = {
    applyAll = 0,
    restoreAll = 0,
    registryApply = 0,
    registryRestore = 0,
    registryFade = 0,
    restoreAlpha = 0,
    featureApply = 0,
    featureRestore = 0,
}

local function body(line)
    return (line:gsub("^.-|r: ", ""))
end

local function spyLifecycle(ns)
    local counts = {}
    local function reset()
        for k in pairs(ZERO_COUNTS) do counts[k] = 0 end
    end
    reset()
    local function wrap(tbl, key, field)
        local orig = tbl[key]
        tbl[key] = function(...)
            counts[field] = counts[field] + 1
            return orig(...)
        end
    end
    wrap(ns, "ApplyAll", "applyAll")
    wrap(ns, "RestoreAll", "restoreAll")
    wrap(ns.Registry, "Apply", "registryApply")
    wrap(ns.Registry, "Restore", "registryRestore")
    wrap(ns.Registry, "Fade", "registryFade")
    wrap(ns, "RestoreAlpha", "restoreAlpha")
    ns.Feature({
        name = "slashProbe",
        apply = function() counts.featureApply = counts.featureApply + 1 end,
        restore = function() counts.featureRestore = counts.featureRestore + 1 end,
    })
    return counts, reset
end

h.test("Slash command registers /quiet and /quietui aliases", function(t)
    local A = t.assert
    A.eq(SLASH_QUIETUI1, "/quiet")
    A.eq(SLASH_QUIETUI2, "/quietui")
    A.type(SlashCmdList.QUIETUI, "function")
end)

h.test("Empty or whitespace-only /quiet toggles QuietUIDB.enabled", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true }
    local counts, reset = spyLifecycle(ns)
    t.boot()
    reset()

    local lines = A.capture(mock, SlashCmdList.QUIETUI, "")
    A.eq(QuietUIDB.enabled, false, "empty argument toggles on -> off")
    A.ok(counts.registryRestore > 0 and counts.restoreAlpha > 0 and counts.featureRestore > 0, "disable runs restore")
    A.eq(counts.registryApply, 0, "disable must not run apply")
    A.eq(body(lines[#lines]), "disabled")

    reset()
    lines = A.capture(mock, SlashCmdList.QUIETUI, "   ")
    A.eq(QuietUIDB.enabled, true, "whitespace-only toggles off -> on")
    A.ok(counts.registryApply > 0 and counts.featureApply > 0, "enable runs apply")
    A.eq(counts.registryRestore, 0, "enable must not run restore")
    A.eq(body(lines[#lines]), "enabled")

    reset()
    SlashCmdList.QUIETUI(nil)
    A.eq(QuietUIDB.enabled, false, "nil argument toggles on -> off")

    reset()
    SlashCmdList.QUIETUI(" \t ")
    A.eq(QuietUIDB.enabled, true, "tabs/spaces toggle off -> on")
end)

h.test("/quiet on and /quiet off set QuietUIDB.enabled explicitly", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true }
    local counts, reset = spyLifecycle(ns)
    t.boot()
    reset()

    local lines = A.capture(mock, SlashCmdList.QUIETUI, "off")
    A.eq(QuietUIDB.enabled, false)
    A.ok(counts.registryRestore > 0 and counts.featureRestore > 0, "/quiet off restores")
    A.eq(body(lines[#lines]), "disabled")

    SlashCmdList.QUIETUI("  OFF  ")
    A.eq(QuietUIDB.enabled, false, "/quiet OFF stays off")

    reset()
    lines = A.capture(mock, SlashCmdList.QUIETUI, "on")
    A.eq(QuietUIDB.enabled, true)
    A.ok(counts.registryApply > 0 and counts.featureApply > 0, "/quiet on applies")
    A.eq(body(lines[#lines]), "enabled")

    SlashCmdList.QUIETUI("  On  ")
    A.eq(QuietUIDB.enabled, true, "/quiet On stays on")
end)

h.test("Unknown /quiet subcommands leave enabled state unchanged, skip ApplyAll/RestoreAll, and print usage", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true }
    local counts, reset = spyLifecycle(ns)
    t.boot()
    reset()

    local cases = {
        { raw = "a", trimmed = "a" },
        { raw = "  FooBar  ", trimmed = "FooBar" },
        { raw = "unknown", trimmed = "unknown" },
        { raw = "  on extra  ", trimmed = "on extra" },
    }
    for _, case in ipairs(cases) do
        local lines = A.capture(mock, SlashCmdList.QUIETUI, case.raw)
        A.eq(QuietUIDB.enabled, true, case.raw .. " must not toggle enabled off")
        A.deep(counts, ZERO_COUNTS, case.raw .. " must not run ApplyAll or RestoreAll")
        A.eq(#lines, 1, case.raw .. " must print exactly one line")
        A.ok(lines[1]:find("QuietUI", 1, true), case.raw .. " prints via ns.Print")
        A.eq(body(lines[1]), 'Unknown command "' .. case.trimmed .. '". ' .. USAGE)
    end
end)

h.test("Unknown /quiet subcommand while disabled keeps QuietUIDB.enabled false and prints usage", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = { enabled = false }
    QuietUICharDB = { welcomed = true }
    local counts, reset = spyLifecycle(ns)
    t.boot()
    reset()

    local lines = A.capture(mock, SlashCmdList.QUIETUI, "  NoSuchCmd  ")
    A.eq(QuietUIDB.enabled, false, "unknown command while off must not enable QuietUI")
    A.deep(counts, ZERO_COUNTS, "unknown command while off must not run ApplyAll or RestoreAll")
    A.eq(#lines, 1)
    A.eq(body(lines[1]), 'Unknown command "NoSuchCmd". ' .. USAGE)
end)

h.test("Unknown /quiet subcommand escapes UI codes in the echoed text", function(t)
    local A, mock = t.assert, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true }
    t.boot()

    local lines = A.capture(mock, SlashCmdList.QUIETUI, "|Tx:0|t")
    A.eq(#lines, 1)
    A.eq(body(lines[1]), 'Unknown command "||Tx:0||t". ' .. USAGE)
end)

h.test("Valid /quiet subcommands dispatch without toggling enabled or printing unknown command", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { welcomed = true }
    t.boot()

    local seen = { setup = 0, glance = 0, dump = 0, profile = 0, preset = 0 }
    local origSetup, origGlance = ns.Setup.Show, ns.Glance.Toggle
    local origDump, origProfile = ns.Setup.ShowDump, ns.Profiler.Start
    local origPreset = ns.Settings.PresetCommand
    ns.Setup.Show = function(...) seen.setup = seen.setup + 1; return origSetup(...) end
    ns.Glance.Toggle = function(...) seen.glance = seen.glance + 1; return origGlance(...) end
    ns.Setup.ShowDump = function(...) seen.dump = seen.dump + 1; return origDump(...) end
    ns.Profiler.Start = function(...) seen.profile = seen.profile + 1; return origProfile(...) end
    ns.Settings.PresetCommand = function(...) seen.preset = seen.preset + 1; return origPreset(...) end

    mock.printed = {}
    SlashCmdList.QUIETUI("setup")
    SlashCmdList.QUIETUI("glance")
    SlashCmdList.QUIETUI("dump")
    SlashCmdList.QUIETUI("profile")
    SlashCmdList.QUIETUI("preset")

    A.eq(QuietUIDB.enabled, true, "valid subcommands keep enabled true")
    A.deep(seen, { setup = 1, glance = 1, dump = 1, profile = 1, preset = 1 })
    A.notPrinted(mock, "Unknown command")
end)
