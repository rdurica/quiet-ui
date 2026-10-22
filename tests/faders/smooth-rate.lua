-- Range and the smooth sampler run at most 30 times a second, with the elapsed time summed, so
-- fades keep their speed at a fraction of the per-frame cost.
local h = ...

h.test("range and smooth run about 30 times a second with the summed elapsed time", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    t.boot()
    local smooth, range, total = 0, 0, 0
    local updateSmooth, updateRange = ns.Faders.UpdateSmooth, ns.Faders.UpdateRange
    ns.Faders.UpdateSmooth = function(elapsed, ...)
        smooth = smooth + 1; total = total + elapsed
        return updateSmooth(elapsed, ...)
    end
    ns.Faders.UpdateRange = function(...) range = range + 1; return updateRange(...) end
    local events = mock:eventFrame("PLAYER_LOGIN")
    for _ = 1, 120 do
        mock.now = mock.now + 1 / 120
        events._scripts.OnUpdate(events, 1 / 120)
    end
    A.ok(smooth >= 25 and smooth <= 31, "smooth ran " .. smooth .. " times in 1 s at 120 fps")
    A.eq(range, smooth, "range runs with smooth")
    A.near(total, 1, 0.05, "the summed elapsed time is passed on")
end)
