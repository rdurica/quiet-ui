-- A running fade steps about 30 times a second with the summed time; a change applies on its own frame.
local h = ...

h.test("A running fade steps at 30 Hz and still finishes; Glance applies on its frame", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local bar = CreateFrame("Frame", "MultiBarBottomLeft", UIParent)
    _G.MultiBarBottomLeft = bar
    t.boot()
    ns.Hit = function() return false end
    local events = mock:eventFrame("PLAYER_LOGIN")
    local function tick(elapsed) events._scripts.OnUpdate(events, elapsed) end
    for _ = 1, 3 do tick(1) end
    A.eq(bar._alpha, 0, "precondition: the bar faded out")
    ns.Glance.Toggle()
    tick(1 / 120)
    A.eq(bar._alpha, 1, "Glance shows the bar on its own frame")
    ns.Glance.Toggle()
    tick(1 / 120)
    A.ok(bar._alpha < 1, "leaving Glance starts the fade on its own frame")
    local passes = 0
    local fade = ns.Registry.Fade
    ns.Registry.Fade = function(...)
        passes = passes + 1
        return fade(...)
    end
    for _ = 1, 12 do tick(1 / 120) end
    A.ok(passes >= 2 and passes <= 4, "a running fade ran " .. passes .. " passes in 12 frames at 120 fps")
    for _ = 1, 48 do tick(1 / 120) end
    A.eq(bar._alpha, 0, "the fade finishes in about 0.3 s")
    ns.Registry.Fade = fade
end)
