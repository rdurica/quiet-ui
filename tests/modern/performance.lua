-- Performance tests with Modernize on and every area applied: the existing per-frame budgets
-- (tests/faders/player/smooth-updates.lua, tests/bars/perf.lua) must hold unchanged, and Modernize
-- adds no per-frame script and no idle frame walks of its own.
local h = ...
local L = h.lib("modern")
local R = h.lib("modern-retail")
local S = h.lib("smooth")

local function status(mock)
    mock.xp, mock.rested = 0.25, 0.1
    UnitXP = function() return mock.xp end
    UnitXPMax = function() return 1 end
    GetXPExhaustion = function() return mock.rested end
    C_Reputation = { GetWatchedFactionData = function()
        return { factionID = 72, currentReactionThreshold = 0, nextReactionThreshold = 1000, currentStanding = 500 }
    end }
end

-- Retail-shaped frames for the minimap, tooltip, aura and status areas.
local function world(t)
    R.installAuraUtil()
    R.auraFrame(BuffFrame, { { "Buff" }, { "TempEnchant" } })
    R.auraFrame(DebuffFrame, { { "Debuff", "Magic" } })
    R.minimap()
    GameTooltip, GameTooltipStatusBar = R.tooltip("GameTooltip", true)
    ItemRefTooltip = R.tooltip("ItemRefTooltip")
    status(t.mock)
end

local function onUpdateFrames(mock)
    local n = 0
    for _, f in ipairs(mock.frames) do
        if f._scripts.OnUpdate then n = n + 1 end
    end
    return n
end

local function build(t)
    local s = S.build(t, h)
    s.tick()
    s.reset()
    return s
end

h.test("Modernize on: idle frames keep one shared sample, one setting read and no curve rebuilds", function(t)
    local A = t.assert
    local s = build(t)
    world(t)
    L.enable()
    t.ns.Modern.Apply()
    A.eq(L.errors(t.mock), 0, "every area applied without a Report: " .. table.concat(t.mock.printed, "; "))
    s.tick()
    s.reset()
    local c = s.c
    for _ = 1, 60 do s.tick() end
    A.eq(c.power, 120, "power samples shared by player and auras")
    A.eq(c.health, 60, "health samples shared")
    A.eq(c.type, 60, "power type sampled once per frame")
    A.eq(c.threshold, 60, "one threshold setting read per frame")
    A.eq(c.style, 60, "one player-style read per frame")
    A.eq(c.aura, 60, "aura modes read once per frame")
    A.eq(c.grouping, 60, "aura grouping read once per frame")
    A.eq(c.curves, 0, "stable thresholds reuse curves")
    A.eq(c.edits, 0, "stable thresholds do not rebuild curve points")
    A.eq(c.debuff, 0, "settled debuffs skip repeated frame checks")
end)

h.test("Modernize on: combat with stable visibility writes no alpha and needs no percentages", function(t)
    local A = t.assert
    local s = build(t)
    world(t)
    L.enable()
    t.ns.Modern.Apply()
    s.InCombat = true
    s.tick()
    s.reset()
    for _ = 1, 60 do s.tick() end
    A.ok(s.c.power == 0 and s.c.health == 0, "fully visible frames need no percentages")
    A.ok(s.writes(PlayerFrame) == 0 and s.writes(BuffFrame) == 0, "stable forced visibility writes no alpha")
    A.eq(BuffFrame._alpha, 1, "Modernize did not take over the aura alpha")
    A.eq(L.errors(t.mock), 0)
end)

h.test("Modernize on: Modern keeps no per-frame script while idle", function(t)
    local A = t.assert
    local s = build(t)
    world(t)
    local before = onUpdateFrames(t.mock)
    L.enable()
    t.ns.Modern.Apply()
    for _ = 1, 60 do s.tick() end
    A.eq(onUpdateFrames(t.mock), before, "no OnUpdate script was added by any area")
end)

h.test("Modernize on: idle scheduler ticks walk no more frames than with Modernize off", function(t)
    local A, mock = t.assert, t.mock
    world(t)
    t.boot()
    local f = mock:eventFrame("PLAYER_LOGIN")
    local function run(n)
        local start = R.calls(mock)
        for _ = 1, n do
            mock.now = mock.now + 0.1
            f._scripts.OnUpdate(f, 0.1)
        end
        local d = {}
        for _, key in ipairs({ "GetChildren", "GetRegions" }) do d[key] = (mock.calls[key] or 0) - (start[key] or 0) end
        return d
    end
    run(10)
    local off = run(100)
    L.enable()
    t.ns.Modern.Apply()
    run(10)
    local on = run(100)
    A.ok(on.GetChildren <= off.GetChildren, "Modernize adds frame child walks: " .. on.GetChildren .. " > " .. off.GetChildren)
    A.ok(on.GetRegions <= off.GetRegions, "Modernize adds region walks: " .. on.GetRegions .. " > " .. off.GetRegions)
    A.eq(L.errors(mock), 0)
end)

h.test("Modernize on: UNIT_AURA for other units and a static XP bar cost no frame walks", function(t)
    local A, mock = t.assert, t.mock
    world(t)
    L.enable()
    t.ns.Modern.Apply()
    local start = R.calls(mock)
    for _ = 1, 100 do
        mock:fire("UNIT_AURA", "target")
        mock:fire("UNIT_AURA", "party1")
    end
    R.sameCalls(A, start, mock.calls, "other-unit UNIT_AURA")
end)

-- The gamepad bar walk budget of tests/bars/perf.lua, now with Modernize on.
h.test("Modernize on: the periodic bar refresh still waits for a child-count change", function(t)
    local A = t.assert
    local bar = CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
    _G.GamepadMainActionBarFrame = bar
    CreateFrame("Button", nil, bar)
    L.enable()
    t.boot()
    local f = t.mock:eventFrame("PLAYER_LOGIN")
    local function tick() f._scripts.OnUpdate(f, 1) end
    tick(); tick()
    local before = bar._calls.GetChildren or 0
    tick(); tick()
    A.eq((bar._calls.GetChildren or 0) - before, 0, "stable bars were walked again with Modernize on")
    CreateFrame("Button", nil, bar)
    tick(); tick()
    A.ok((bar._calls.GetChildren or 0) - before <= 2, "a new child costs at most one rebuild per owner")
    A.eq(L.errors(t.mock), 0, "idle ticks reported: " .. table.concat(t.mock.printed, "; "))
end)
