-- The icon texture may be filled one frame after the event, so Highlights looks again on the next frame.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

-- Timers queued since the first n entries, as callbacks that were due immediately.
local function queuedSince(w, n)
    local out = {}
    for i = n + 1, #w.mock.timers do out[#out + 1] = w.mock.timers[i] end
    return out
end

local function run(list)
    for _, timer in ipairs(list) do timer.fn() end
end

case("Icon filled one frame after the target event shows after the re-check", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-A", nil)
    local before = #t.mock.timers
    w.target("GameObject-A")
    A.ok(w.nothingShown(), "something was shown with an empty icon")
    local timers = queuedSince(w, before)
    A.ok(#timers >= 1, "no next-frame re-check was scheduled after the target event")
    for _, timer in ipairs(timers) do A.eq(timer.at, t.mock.now, "the re-check must run on the next frame (delay 0)") end
    plate.soft.Icon:SetTexture(H.MINE)
    run(timers)
    A.ok(w.shownOn(plate), "the re-check did not show the glow for the late icon")
    return w
end)

case("Icon filled one frame after NAME_PLATE_UNIT_ADDED shows after the re-check", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.target("GameObject-A")
    t.mock:drain()
    local plate = w.addPlate("nameplate4", "GameObject-A", nil)
    local before = #t.mock.timers
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate4")
    A.ok(w.nothingShown(), "something was shown with an empty icon")
    local timers = queuedSince(w, before)
    A.ok(#timers >= 1, "no next-frame re-check was scheduled after the plate was added")
    plate.soft.Icon:SetTexture(H.MINE)
    run(timers)
    A.ok(w.shownOn(plate), "the re-check did not show the glow for the late plate icon")
    return w
end)

case("A newer target event cancels the older pending re-check", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", nil)
    local b = w.addPlate("nameplate2", "GameObject-B", nil)
    local start = #t.mock.timers
    w.target("GameObject-A")
    local first = queuedSince(w, start)
    A.ok(#first >= 1, "no re-check was scheduled for the first target")
    local mid = #t.mock.timers
    w.target("GameObject-B", "GameObject-A")
    local second = queuedSince(w, mid)
    A.ok(#second >= 1, "no re-check was scheduled for the second target")
    b.soft.Icon:SetTexture(H.MINE)
    run(first)
    A.ok(w.nothingShown(), "an outdated re-check still evaluated")
    run(second)
    A.ok(w.shownOn(b), "the newest re-check did not show the glow")
    return w
end)

case("RestoreHighlights cancels a pending re-check", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-A", nil)
    local start = #t.mock.timers
    w.target("GameObject-A")
    local timers = queuedSince(w, start)
    w.restore()
    plate.soft.Icon:SetTexture(H.MINE)
    run(timers)
    A.ok(w.nothingShown(), "a re-check after restore showed the glow")
    return w
end)

case("Missing C_Timer: late icon events do not error", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    C_Timer = nil
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-A", nil)
    w.target("GameObject-A")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    A.ok(w.nothingShown(), "something was shown with an empty icon")
    plate.soft.Icon:SetTexture(H.MINE)
    w.target("GameObject-A", "GameObject-A")
    A.ok(w.shownOn(plate), "the next target event did not show the glow")
    return w
end)
