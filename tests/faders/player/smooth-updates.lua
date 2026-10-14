-- Smooth updates: player, pet, auras and the resource bar share one power/health sample per
-- frame, reuse curves, keep secret values untouched, skip needless alpha writes and restore.
local h = ...
local S = h.lib("smooth")

local function setup(t)
    local s = S.build(t, h)
    s.tick()
    s.reset()
    return s
end

local function same(a, b) return rawequal(a, b) end

h.test("Idle frames share one sample and one setting read per frame", function(t)
    local A = t.assert
    local s = setup(t)
    local c = s.c
    for _ = 1, 60 do s.tick() end
    A.eq(c.power, 120, "Player and auras must share the selected threshold sample")
    A.eq(c.health, 60, "Player and auras must share the selected threshold sample")
    A.eq(c.type, 60, "Power type should be sampled once per frame")
    A.eq(c.threshold, 60, "Player and auras must read one threshold setting per frame")
    A.eq(c.style, 60, "Visibility and thresholds must share one player-style read per frame")
    A.eq(c.aura, 60, "Aura modes must be read once per frame")
    A.eq(c.grouping, 60, "Aura modes must be read once per frame")
end)

h.test("Stable thresholds reuse curves and never rebuild their points", function(t)
    local A = t.assert
    local s = setup(t)
    for _ = 1, 60 do s.tick() end
    A.eq(s.c.curves, 0, "Stable thresholds must reuse curve objects")
    A.eq(s.c.edits, 0, "Stable thresholds must not rebuild unchanged curve points")
end)

h.test("Secret alpha reaches widgets unchanged and fresh samples follow", function(t)
    local A = t.assert
    local s = setup(t)
    for _ = 1, 3 do s.tick() end
    A.ok(same(PlayerFrame._alpha, s.power) and same(BuffFrame._alpha, s.power),
        "Secret alpha must reach widgets unchanged")
    s.power = s.P.secret(t.mock, 0.5)
    s.tick()
    A.ok(same(PlayerFrame._alpha, s.power), "A new frame must read a fresh secret power value")
end)

h.test("Settled visible debuffs skip repeated frame checks and stay visible", function(t)
    local A = t.assert
    local s = setup(t)
    for _ = 1, 60 do s.tick() end
    A.eq(s.c.debuff, 0, "Already visible debuffs must skip repeated frame checks")
    A.eq(DebuffFrame._alpha, 1, "Always-visible debuffs must stay visible independently of buffs")
end)

h.test("Combat needs no percentages and writes no alpha while visibility is stable", function(t)
    local A = t.assert
    local s = setup(t)
    s.InCombat = true
    s.tick()
    s.reset()
    for _ = 1, 60 do s.tick() end
    A.ok(s.c.power == 0 and s.c.health == 0, "Fully visible frames need no health or power percentage")
    A.ok(s.writes(PlayerFrame) == 0 and s.writes(BuffFrame) == 0,
        "Stable forced visibility should not write alpha again")
    A.ok(PlayerFrame._alpha == 1 and PersonalResourceDisplayFrame._alpha == 1,
        "Combat must show the portrait and resource bar")
end)

h.test("A resource fade allocates its curves once and repeated fades none", function(t)
    local A = t.assert
    local s = setup(t)
    s.InCombat = true
    s.tick()
    s.InCombat = false
    s.reset()
    for _ = 1, 20 do s.tick() end
    A.ok(s.c.curves <= 2, "A resource fade must reuse its health and power curve objects: " .. s.c.curves)
    s.InCombat = true
    s.tick()
    s.InCombat = false
    s.reset()
    for _ = 1, 20 do s.tick() end
    A.eq(s.c.curves, 0, "Repeated fades must not allocate new curve objects")
end)

h.test("Failed curve editing falls back to fresh curves", function(t)
    local A = t.assert
    local s = setup(t)
    s.InCombat = true
    s.tick()
    s.InCombat, s.failClear = false, true
    s.tick()
    A.ok(same(PersonalResourceDisplayFrame._alpha, s.power),
        "Failed curve editing must fall back to fresh curves")
end)

h.test("A target keeps player and auras visible without hover traversal", function(t)
    local A = t.assert
    local s = setup(t)
    s.HasTarget = true
    s.reset()
    s.tick()
    A.ok(PlayerFrame._alpha == 1 and BuffFrame._alpha == 1, "Target must keep player and grouped auras visible")
    A.ok(same(PersonalResourceDisplayFrame._alpha, s.power), "Resource bar must keep its independent power rule")
    A.eq(s.c.hover, 0, "Forced player and grouped aura visibility must skip hover traversal")
end)

h.test("Fading returns to the secret rule, rage holds nothing up and disable restores", function(t)
    local A = t.assert
    local s = setup(t)
    s.HasTarget = true
    s.tick()
    s.HasTarget = false
    for _ = 1, 20 do s.tick() end
    A.ok(same(PlayerFrame._alpha, s.power), "Fading must return to the secret power rule")
    s.token, s.kind = "RAGE", 1
    for _ = 1, 20 do s.tick() end
    A.ok(PlayerFrame._alpha == 0 and BuffFrame._alpha == 0, "Rage must not hold the portrait or auras up")
    t.ns.RestoreAlpha()
    A.ok(PlayerFrame._alpha == 1 and BuffFrame._alpha == 1, "Disable must restore original alpha")
end)

h.test("Resource child bars fade independently, skip stable writes and restore", function(t)
    local A = t.assert
    local s = setup(t)
    local ns = t.ns
    local health = CreateFrame("Frame", nil, PersonalResourceDisplayFrame)
    local powerBar = CreateFrame("Frame", nil, PersonalResourceDisplayFrame)
    PersonalResourceDisplayFrame.HealthBarsContainer = health
    ns.Faders.Find(false)
    s.token, s.kind = "RAGE", 1
    for _ = 1, 20 do s.tick() end
    A.ok(same(health._alpha, s.healthValue) and powerBar._alpha == 0,
        "Missing health and rage must use independent alphas")
    s.InCombat = true
    s.tick()
    health._calls.SetAlpha, powerBar._calls.SetAlpha = 0, 0
    s.tick()
    A.ok(health._alpha == 1 and powerBar._alpha == 1, "Combat must reveal both resource children")
    A.ok(health._calls.SetAlpha == 0 and powerBar._calls.SetAlpha == 0,
        "Stable resource children must skip alpha writes")
    s.InCombat = false
    s.token, s.kind = "MANA", 0
    for _ = 1, 20 do s.tick() end
    A.ok(same(health._alpha, s.healthValue) and same(powerBar._alpha, s.power),
        "Resource children must return to fresh secret results")
    ns.RestoreAlpha()
    A.ok(health._alpha == 1 and powerBar._alpha == 1, "Disable must restore resource children")
end)

h.test("A failing power sample is reported once and never reuses the old secret", function(t)
    local A = t.assert
    local s = setup(t)
    s.tick()
    UnitPowerType = function() error("Unavailable power type") end
    s.allowReports = true
    t.ns.Faders.UpdateSmooth(1 / 60)
    A.ok(t.mock.printed[1] and t.mock.printed[1]:find("player power", 1, true),
        "Failed sampling must be reported without breaking the update")
    A.falsy(PlayerFrame._quietSecret, "Failed power sampling must not reuse the previous secret result")
end)
