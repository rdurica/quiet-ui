-- Rescans coalesce to one per frame; login and zoning greet and arm the layout correctly.
local h = ...

-- Counts full rescans (the only caller of FindFaders(true)) without changing them.
local function countRescans(ns)
    local state = { n = 0 }
    local real = ns.FindFaders
    ns.FindFaders = function(full, ...)
        if full then state.n = state.n + 1 end
        return real(full, ...)
    end
    return state
end

-- Runs callbacks queued for the next frame (delay 0) only.
local function nextFrame(t) t.mock:advance(0) end

-- Timers still waiting for `delay` seconds from now.
local function pending(t, delay)
    local n = 0
    for _, timer in ipairs(t.mock.timers) do
        if timer.at == t.mock.now + delay then n = n + 1 end
    end
    return n
end

local function slash(t, msg)
    t.mock.printed = {}
    SlashCmdList.QUIETUI(msg)
end

local function bootedAndSettled(t)
    t.boot()
    nextFrame(t)
    return countRescans(t.ns)
end

h.test("Three foreign ADDON_LOADED in one frame rescan exactly once", function(t)
    local A = t.assert
    local rescans = bootedAndSettled(t)
    t.mock:fire("ADDON_LOADED", "Foo")
    t.mock:fire("ADDON_LOADED", "Bar")
    t.mock:fire("ADDON_LOADED", "Baz")
    A.eq(rescans.n, 0, "ADDON_LOADED must not rescan synchronously")
    nextFrame(t)
    A.eq(rescans.n, 1, "rescans after the timer")
end)

h.test("Login then initial PLAYER_ENTERING_WORLD greets and arms the layout once", function(t)
    local A, mock = t.assert, t.mock
    QuietUICharDB.forceLayout = true
    mock:fire("PLAYER_LOGIN")
    mock:fire("PLAYER_ENTERING_WORLD", true, false)
    A.printed(mock, "is on, enjoy the quiet", 1)
    -- The layout settle schedules its retries at 1, 3 and 6 seconds.
    A.eq(pending(t, 1), 1, "layout settle armed")
    local rescans = countRescans(t.ns)
    nextFrame(t)
    A.ok(rescans.n <= 1, "rescans after PEW in one frame: " .. rescans.n)
end)

h.test("Zoning PLAYER_ENTERING_WORLD rescans once by next frame without a greeting", function(t)
    local A, mock = t.assert, t.mock
    local rescans = bootedAndSettled(t)
    mock.printed = {}
    mock:fire("PLAYER_ENTERING_WORLD", false, false)
    nextFrame(t)
    A.eq(rescans.n, 1, "zoning rescans")
    A.notPrinted(mock, "is on, enjoy the quiet")
end)

h.test("RequestRescan without C_Timer rescans immediately", function(t)
    local A = t.assert
    local rescans = bootedAndSettled(t)
    A.type(t.ns.RequestRescan, "function", "ns.RequestRescan")
    C_Timer = nil
    t.ns.RequestRescan()
    A.eq(rescans.n, 1, "rescans without C_Timer")
end)

h.test("RequestRescan does nothing while QuietUI is disabled", function(t)
    local A = t.assert
    local rescans = bootedAndSettled(t)
    QuietUIDB.enabled = false
    local queued = pending(t, 0)
    A.type(t.ns.RequestRescan, "function", "ns.RequestRescan")
    t.ns.RequestRescan()
    A.eq(pending(t, 0), queued, "disabled RequestRescan must not schedule a timer")
    nextFrame(t)
    A.eq(rescans.n, 0, "disabled RequestRescan rescanned")
end)

h.test("Enabling after a rescan skipped while disabled rescans once", function(t)
    local A = t.assert
    local rescans = bootedAndSettled(t)
    slash(t, "off")
    t.mock:fire("PLAYER_ENTERING_WORLD", false, false)
    nextFrame(t)
    rescans.n = 0
    slash(t, "on")
    nextFrame(t)
    A.eq(rescans.n, 1, "missed zoning rescan after enable")
    rescans.n = 0
    slash(t, "off")
    slash(t, "on")
    nextFrame(t)
    A.eq(rescans.n, 0, "enable without a missed rescan must not rescan")
end)
