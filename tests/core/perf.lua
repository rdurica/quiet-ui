-- /quiet profile: temporary CPU timing, its completion, disabled state and unavailable timer.
local h = ...

-- ns.Print prefixes a colored addon name; the tests compare the message itself.
local function body(line)
    return (line:gsub("^.-|r: ", ""))
end

local function bodies(mock)
    local out = {}
    for i, line in ipairs(mock.printed) do out[i] = body(line) end
    return out
end

local function bootDisabled(t)
    QuietUIDB.enabled = false
    t.boot()
    local events = t.mock:eventFrame("PLAYER_LOGIN")
    return function(elapsed) events._scripts.OnUpdate(events, elapsed) end
end

h.test("Temporary CPU timing measures, completes and stops reporting", function(t)
    local A, mock = t.assert, t.mock
    local update = bootDisabled(t)
    -- Each layout retry of the disabled addon costs three milliseconds on the fake timer.
    t.ns.Layout.UpdatePreview = function()
        mock.profile = mock.profile + 3
        return true
    end
    SlashCmdList.QUIETUI("profile")
    A.eq(QuietUIDB.enabled, false, "Profiling must not toggle the addon")
    local started = mock.now
    for _ = 1, 10 do
        mock.now = mock.now + 0.1
        update(0.1)
    end
    mock.now = started + 10
    update(0.1)
    local lines = bodies(mock)
    A.ok(lines[2]:find("CPU timing: 10.0 seconds", 1, true), "CPU timing summary: " .. tostring(lines[2]))
    A.eq(lines[#lines], "layout: 3.000 ms/s, 3.000 ms/call (10 calls).")
    local count = #mock.printed
    mock.now = started + 20
    update(0.1)
    A.eq(#mock.printed, count, "Completed profiling must not keep reporting")
end)

h.test("CPU timing says so when the client has no timer", function(t)
    local A, mock = t.assert, t.mock
    bootDisabled(t)
    debugprofilestop = nil
    SlashCmdList.QUIETUI("profile")
    local lines = bodies(mock)
    A.eq(lines[#lines], "CPU timing is not available on this client.")
    A.eq(QuietUIDB.enabled, false)
end)

h.test("Smooth breakdown rows, total, inactive timer and completion", function(t)
    local A, mock = t.assert, t.mock
    local timerReads = 0
    debugprofilestop = function()
        timerReads = timerReads + 1
        return mock.profile
    end
    QuietUIDB.enabled = true
    t.boot()
    local events = mock:eventFrame("PLAYER_LOGIN")
    local function update(elapsed) events._scripts.OnUpdate(events, elapsed) end
    local ns = t.ns
    ns.Settings.Pinned = function(name)
        if name == "resource" then mock.profile = mock.profile + 1 end
        return false
    end
    -- Visibility and threshold decisions now share this two-millisecond lookup.
    ns.Settings.PlayerStyle = function()
        mock.profile = mock.profile + 2
        return "resource"
    end
    ns.Settings.AlwaysShowDebuffs = function()
        mock.profile = mock.profile + 4
        return true
    end
    UnitPowerType = function()
        mock.profile = mock.profile + 0.5
        return 0, "MANA"
    end
    ns.Faders.UpdateParty = function() mock.profile = mock.profile + 3 end
    -- Keep unrelated frame discovery and regular faders idle.
    ns.Faders.Find, ns.Faders.Update, ns.Faders.UpdateRange = function() end, function() end, function() end
    mock.now = mock.now + 30
    update(0.1)
    A.eq(timerReads, 0, "Inactive profiling must not read the CPU timer")
    SlashCmdList.QUIETUI("profile")
    local started = mock.now
    for i = 1, 9 do
        mock.now = started + i
        update(0.1)
    end
    mock.now = started + 10
    update(0.1)
    local output = table.concat(bodies(mock), "\n")
    local rows = {
        { "resource bar", "0.900 ms/s, 1.000 ms/call (9 calls)." },
        { "player frame", "1.800 ms/s, 2.000 ms/call (9 calls)." },
        { "party frames", "2.700 ms/s, 3.000 ms/call (9 calls)." },
        { "buffs", "3.600 ms/s, 4.000 ms/call (9 calls)." },
    }
    for _, row in ipairs(rows) do
        local text = "smooth / " .. row[1] .. ": " .. row[2]
        A.ok(output:find(text, 1, true), "Missing or incorrect detailed timing: " .. text)
    end
    A.ok(output:find("smooth: 9.450 ms/s, 10.500 ms/call (9 calls).", 1, true),
        "Smooth total must include shared sampling and retain its original meaning")
    local reads = timerReads
    mock.now = started + 11
    update(0.1)
    A.eq(timerReads, reads, "Completed profiling must disable detailed timers too")
end)
