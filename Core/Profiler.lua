local _, ns = ...

-- CPU profile for /quiet profile: ten seconds of per-section timing.

local Profiler = {}
ns.Profiler = Profiler

local profile

function Profiler.Active()
    return profile ~= nil
end

function Profiler.Start()
    if type(debugprofilestop) ~= "function" then
        ns.Print("CPU timing is not available on this client.")
        return
    end
    profile = { started = GetTime(), sections = {}, smooth = {}, frames = 0 }
    ns.Print("Measuring QuietUI for 10 seconds. Keep playing in the same situation.")
end

local function Rows(sections)
    local rows = {}
    for name, section in pairs(sections) do
        rows[#rows + 1] = { name = name, ms = section.ms, calls = section.calls }
    end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    return rows
end

local function PrintRow(row, duration, prefix)
    ns.Print(string.format("%s%s: %.3f ms/s, %.3f ms/call (%d calls).",
        prefix or "", row.name, row.ms / duration, row.ms / row.calls, row.calls))
end

-- Called every frame; prints the result after ten seconds. `pending` names a pending layout job.
function Profiler.Finish(pending)
    if not profile then return end
    profile.frames = profile.frames + 1
    local duration = GetTime() - profile.started
    if duration < 10 then return end
    local rows = Rows(profile.sections)
    local preset = ns.Settings.ActivePreset and ns.Settings.ActivePreset()
    ns.Print(string.format("CPU timing: %.1f seconds, %d frames, preset %s; pending layout: %s.", duration,
        profile.frames, preset and preset.name or "<no preset>", tostring(pending or "none")))
    if ns.LayoutStatus then ns.Print(ns.LayoutStatus()) end
    for i = 1, math.min(8, #rows) do
        PrintRow(rows[i], duration)
    end
    -- Details are included in the smooth total and do not consume the top-eight slots.
    for _, row in ipairs(Rows(profile.smooth)) do
        PrintRow(row, duration, "smooth / ")
    end
    profile = nil
end

local function Record(sections, label, started)
    local ms = math.max(0, debugprofilestop() - started)
    local section = sections[label]
    if not section then section = { ms = 0, calls = 0 }; sections[label] = section end
    section.ms, section.calls = section.ms + ms, section.calls + 1
end

-- ns.Run that also times the call while a profile runs. A nil label is not timed.
function Profiler.Run(label, fn, ...)
    local active = label and profile
    local started = active and debugprofilestop()
    ns.Run(label or "fades", fn, ...)
    if active then
        Record(active.sections, label, started)
    end
end

-- Times one detail of the smooth sampler. Only called while a profile runs.
function Profiler.Smooth(label, fn, ...)
    local started = debugprofilestop()
    local ok, err = pcall(fn, ...)
    Record(profile.smooth, label, started)
    if not ok then ns.Report(label, err) end
end
