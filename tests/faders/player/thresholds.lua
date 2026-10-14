-- Player portrait threshold: one health or resource percentage reveals portrait, pet and grouped
-- auras. Health and power are secret values; curve points must stay plain numbers.
local h = ...
local P = h.lib("player")
local unwrap = P.unwrap

local function setup(t)
    local ns = t.ns
    local s = P.env(t, { plain = true })
    local function tick() ns.UpdateSmooth(1) end
    local function check(expected)
        tick()
        local A = t.assert
        A.eq(unwrap(PlayerFrame._alpha), expected, "Unexpected portrait alpha")
        A.eq(unwrap(PetFrame._alpha), expected, "Pet must follow the portrait")
        A.eq(unwrap(BuffFrame._alpha), expected, "Grouped buffs must follow thresholds")
        A.eq(unwrap(DebuffFrame._alpha), 1, "Default debuffs must stay visible")
    end
    return s, tick, check
end

h.test("Health threshold reveals at the boundary and hides at or above it", function(t)
    local s, _, check = setup(t)
    check(0)
    s.health = 0.69999; check(1)
    s.health = 0.7; check(0)
    s.health, s.power = 1, 0.4; check(0)
end)

h.test("Custom health threshold honours its own boundary", function(t)
    local s, _, check = setup(t)
    QuietUICharDB.playerThresholdPercent = 40
    s.health = 0.4; check(0)
    s.health = 0.39999; check(1)
end)

h.test("Resource threshold reads power, ignores health, and an empty threshold never reveals", function(t)
    local s, _, check = setup(t)
    QuietUICharDB.playerThresholdPercent = 40
    QuietUICharDB.playerThresholdKind = "resource"
    s.health, s.power = 0.1, 0.4; check(0)
    s.power = 0.39999; check(1)
    QuietUICharDB.playerThresholdPercent = 80
    s.health, s.power = 1, 0.8; check(0)
    s.power = 0.79999; check(1)
    QuietUICharDB.playerThresholdPercent = false
    s.health, s.power = 0.1, 0.1; check(0)
end)

h.test("Combat and instance visibility do not read percentages and end with the trigger", function(t)
    local A = t.assert
    local s, _, check = setup(t)
    for _, thresholdKind in ipairs({ "health", "resource" }) do
        QuietUICharDB.playerThresholdKind = thresholdKind
        for _, forced in ipairs({ "InCombat", "InForcedInstance" }) do
            for _, disabled in ipairs({ false, true }) do
                QuietUICharDB.playerThresholdPercent = disabled and false or 70
                s.health, s.power = 1, 1
                s[forced] = true
                s.reads = 0; check(1)
                A.eq(s.reads, 0, "Combat and instance visibility must not read percentages")
                s[forced] = false
                check(0)
            end
        end
    end
end)

h.test("A resource that is not mana still follows the selected threshold kind", function(t)
    local s, _, check = setup(t)
    QuietUICharDB.playerThresholdKind = "resource"
    UnitPowerType = function() return 1, "RAGE" end
    s.health, s.power = 0.5, 0; check(0)
    QuietUICharDB.playerThresholdKind = "health"; check(1)
end)

h.test("Portrait off and grouped auras off keep their own visibility", function(t)
    local A = t.assert
    local s, tick = setup(t)
    QuietUICharDB.groupAuras, QuietUICharDB.alwaysShowDebuffs = false, false
    s.health = 0.5
    tick()
    A.ok(unwrap(PlayerFrame._alpha) == 1 and unwrap(BuffFrame._alpha) == 0 and unwrap(DebuffFrame._alpha) == 0)
    QuietUICharDB.player = "resource"
    tick(); A.ok(unwrap(PlayerFrame._alpha) == 0 and unwrap(PetFrame._alpha) == 0)
    s.InEditMode = true
    tick(); A.eq(unwrap(PlayerFrame._alpha), 1)
end)

for _, thresholdKind in ipairs({ "health", "resource" }) do
    h.test(thresholdKind .. " threshold overrides the dead-target block for player and pet only", function(t)
        local A = t.assert
        local s, tick = setup(t)
        QuietUICharDB.requireLivingTarget = true
        s.targetDead, s.InCombat = true, true
        QuietUICharDB.playerThresholdKind = thresholdKind
        s.health, s.power = 1, 1
        tick()
        A.ok(unwrap(PlayerFrame._alpha) == 0 and unwrap(PetFrame._alpha) == 0 and unwrap(TargetFrame._alpha) == 0,
            "Dead target must still block ordinary combat visibility above the threshold")
        s[thresholdKind == "health" and "health" or "power"] = 0.5
        tick()
        A.ok(unwrap(PlayerFrame._alpha) == 1 and unwrap(PetFrame._alpha) == 1 and unwrap(TargetFrame._alpha) == 0,
            "Selected threshold must override dead-target blocking for player and pet only")
        QuietUICharDB.playerThresholdPercent = false
        tick()
        A.ok(unwrap(PlayerFrame._alpha) == 0 and unwrap(PetFrame._alpha) == 0,
            "Empty threshold must not override dead target")
        QuietUICharDB.playerThresholdPercent = nil
        QuietUICharDB.player = "resource"
        tick()
        A.ok(unwrap(PlayerFrame._alpha) == 0 and unwrap(PetFrame._alpha) == 0,
            "Disabled portrait must stay hidden even below threshold")
    end)
end

h.test("Edit Mode reveals portrait and target despite a dead target", function(t)
    local A = t.assert
    local s, tick = setup(t)
    QuietUICharDB.requireLivingTarget = true
    s.targetDead, s.InCombat = true, true
    s.InEditMode = true
    tick(); A.ok(unwrap(PlayerFrame._alpha) == 1 and TargetFrame._alpha == 1)
end)

h.test("Leaving forced visibility fades the portrait instead of snapping", function(t)
    local A = t.assert
    local s, tick = setup(t)
    s.HasTarget = true
    tick(); A.eq(unwrap(PlayerFrame._alpha), 1)
    s.HasTarget = false
    t.ns.UpdateSmooth(0.15)
    A.ok(unwrap(PlayerFrame._alpha) > 0 and unwrap(PlayerFrame._alpha) < 1, "Leaving forced visibility must fade")
    t.ns.UpdateSmooth(0.15)
    A.eq(unwrap(PlayerFrame._alpha), 0)
end)

h.test("A missing health API is reported without substituting power", function(t)
    local A = t.assert
    local ns = t.ns
    setup(t)
    local reported
    ns.Report = function(name) reported = name end
    UnitHealthPercent = nil
    ns.UpdateSmooth(1)
    A.eq(reported, "player health", "Missing health API must be reported without substituting power")
end)

h.test("Disable restores portrait, pet and grouped buffs", function(t)
    local A = t.assert
    local s, tick = setup(t)
    s.health = 0.1
    tick(); A.eq(unwrap(PlayerFrame._alpha), 1)
    s.health = 1
    tick(); A.eq(unwrap(PlayerFrame._alpha), 0)
    t.ns.RestoreAlpha()
    A.ok(PlayerFrame._alpha == 1 and PetFrame._alpha == 1 and BuffFrame._alpha == 1)
end)

h.test("Reused curves keep exact fade weights and reveal fresh low health and power at once", function(t)
    local A = t.assert
    local ns = t.ns
    local s = setup(t)
    local resourceHealth, resourcePower = PersonalResourceDisplayFrame.HealthBarsContainer, s.resourcePower
    ns.FindFaders(false)
    for _ = 1, 2 do
        s.health, s.power = 1, 1
        s.InCombat = true
        ns.UpdateSmooth(1)
        s.InCombat = false
        local total = 0
        for _, elapsed in ipairs({ 0.017, 0.083, 0.071, 0.129 }) do
            total = total + elapsed
            ns.UpdateSmooth(elapsed)
            local expected = math.max(0, 1 - total / 0.3)
            A.near(unwrap(resourceHealth._alpha), expected, 1e-9, "Health fade must retain exact weights")
            A.near(unwrap(resourcePower._alpha), expected, 1e-9, "Power fade must retain exact weights")
        end
        s.health, s.power = 0.2, 0.2
        ns.UpdateSmooth(0.017)
        A.ok(unwrap(resourceHealth._alpha) == 1 and unwrap(resourcePower._alpha) == 1,
            "Reused curves must still reveal fresh low health and power immediately")
    end
    ns.RestoreAlpha()
    A.ok(resourceHealth._alpha == 1 and resourcePower._alpha == 1, "Resource alpha must restore after reused curves")
end)
