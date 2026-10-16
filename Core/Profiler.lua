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
        rows[#rows + 1] = { name = name, ms = section.ms, calls = section.calls, max = section.max }
    end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    return rows
end

local function RowText(row, duration, prefix)
    return string.format("%s%s: %.3f ms/s, %.3f ms/call, max %.2f ms (%d calls).",
        prefix or "", row.name, row.ms / duration, row.ms / row.calls, row.max, row.calls)
end

-- Called every frame; prints the result after ten seconds. `pending` names a pending layout job.
function Profiler.Finish(pending)
    if not profile then return end
    profile.frames = profile.frames + 1
    local duration = GetTime() - profile.started
    if duration < 10 then return end
    local rows = Rows(profile.sections)
    local preset = ns.Settings.ActivePreset and ns.Settings.ActivePreset()
    -- Every row is kept in QuietUIDB.lastProfile, so the result can be read after /reload.
    local saved = {}
    local function emit(text, print)
        saved[#saved + 1] = text
        if print then ns.Print(text) end
    end
    emit(string.format("CPU timing: %.1f seconds, %d frames, preset %s; pending layout: %s.", duration,
        profile.frames, preset and preset.name or "<no preset>", tostring(pending or "none")), true)
    if ns.Layout.Status then emit(ns.Layout.Status(), true) end
    for i, row in ipairs(rows) do
        emit(RowText(row, duration), i <= 8)
    end
    -- Details are included in the smooth total and do not consume the top-eight slots.
    for _, row in ipairs(Rows(profile.smooth)) do
        emit(RowText(row, duration, "smooth / "), true)
    end
    ns.DB().lastProfile = saved
    profile = nil
end

local function Record(sections, label, started)
    local ms = math.max(0, debugprofilestop() - started)
    local section = sections[label]
    if not section then section = { ms = 0, calls = 0, max = 0 }; sections[label] = section end
    section.ms, section.calls = section.ms + ms, section.calls + 1
    if ms > section.max then section.max = ms end
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
