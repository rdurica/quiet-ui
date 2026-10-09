-- Run from the addon directory: lua tests/player-thresholds.lua
local ns = {}
local function loadAddon(file) assert(loadfile(file))('QuietUI', ns) end
local function frame(parent)
    local obj = { alpha = 1, parent = parent }
    function obj:IsForbidden() return false end
    function obj:IsShown() return true end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    function obj:GetParent() return self.parent end
    function obj:GetChildren() end
    return obj
end
local function secret(value) return { secret = true, value = value } end
local function unwrap(value) return type(value) == 'table' and value.value or value end
issecretvalue = function(value) return type(value) == 'table' and value.secret end
local rejectSecretPoints = true
Enum = { LuaCurveType = { Step = 1 } }
C_CurveUtil = { CreateCurve = function()
    local curve = { points = {} }
    function curve:SetType(kind) self.kind = kind end
    function curve:ClearPoints() self.points = {} end
    function curve:AddPoint(x, y)
        assert(not issecretvalue(x), 'Threshold coordinates must be plain numbers')
        if rejectSecretPoints and issecretvalue(y) then error('Secret point values are forbidden in tainted code') end
        self.points[#self.points + 1] = { x, y }
    end
    -- API internals evaluate secret inputs; addon curve points must stay plain.
    function curve:evaluate(value)
        local x = unwrap(value)
        local points = self.points
        for i = 2, #points do
            if x < points[i][1] then
                if self.kind == Enum.LuaCurveType.Step then return secret(unwrap(points[i - 1][2])) end
                local a, b = points[i - 1], points[i]
                local t = (x - a[1]) / (b[1] - a[1])
                return secret(unwrap(a[2]) + (unwrap(b[2]) - unwrap(a[2])) * t)
            end
        end
        return secret(unwrap(points[#points][2]))
    end
    return curve
end }
local health, power, kind, token = 1, 1, 0, 'MANA'
local reads = 0
UnitHealthPercent = function(_, _, curve) reads = reads + 1; return curve:evaluate(secret(health)) end
UnitPowerPercent = function(_, _, _, curve) reads = reads + 1; return curve:evaluate(secret(power)) end
UnitPowerType = function() return kind, token end
hooksecurefunc = function() end
QuietUIDB, QuietUICharDB = { enabled = true }, {}
UIParent = frame()
PlayerFrame, PetFrame = frame(UIParent), frame(UIParent)
BuffFrame, DebuffFrame = frame(UIParent), frame(UIParent)
loadAddon('Core.lua')
for _, name in ipairs({ 'InEditMode', 'InCombat', 'InForcedInstance', 'InGroup', 'InVehicle',
    'HasTarget', 'Glancing', 'Pinned', 'OnlyOnHover', 'Hit' }) do ns[name] = function() return false end end
loadAddon('Presets.lua')
loadAddon('Setup.lua')
loadAddon('Faders.lua')
ns.FindFaders(false)
local function tick() ns.UpdateSmooth(1) end
local function check(expected)
    tick()
    assert(unwrap(PlayerFrame.alpha) == expected, 'Unexpected portrait alpha')
    assert(unwrap(PetFrame.alpha) == expected, 'Pet must follow the portrait')
    assert(unwrap(BuffFrame.alpha) == expected, 'Grouped buffs must follow thresholds')
    assert(unwrap(DebuffFrame.alpha) == 1, 'Default debuffs must stay visible')
end
check(0)
health = 0.69999; check(1)
health = 0.7; check(0)
health, power = 1, 0.4; check(0)
QuietUICharDB.playerThresholdPercent = 40
health = 0.4; check(0)
health = 0.39999; check(1)
QuietUICharDB.playerThresholdKind = 'resource'
health, power = 0.1, 0.4; check(0)
power = 0.39999; check(1)
QuietUICharDB.playerThresholdPercent = 80
health, power = 1, 0.8; check(0)
power = 0.79999; check(1)
QuietUICharDB.playerThresholdPercent = false
health, power = 0.1, 0.1; check(0)
for _, thresholdKind in ipairs({ 'health', 'resource' }) do
    QuietUICharDB.playerThresholdKind = thresholdKind
    for _, forced in ipairs({ 'InCombat', 'InForcedInstance' }) do
        for _, disabled in ipairs({ false, true }) do
            if disabled then QuietUICharDB.playerThresholdPercent = false
            else QuietUICharDB.playerThresholdPercent = 70 end
            health, power = 1, 1
            ns[forced] = function() return true end
            reads = 0; check(1)
            assert(reads == 0, 'Combat and instance visibility must not read percentages')
            ns[forced] = function() return false end
            check(0)
        end
    end
end
QuietUICharDB.playerThresholdPercent = nil
kind, token = 1, 'RAGE'
health, power = 0.5, 0; check(0)
QuietUICharDB.playerThresholdKind = 'health'; check(1)
kind, token = 0, 'MANA'
QuietUICharDB.groupAuras, QuietUICharDB.alwaysShowDebuffs = false, false
tick()
assert(unwrap(PlayerFrame.alpha) == 1 and unwrap(BuffFrame.alpha) == 0 and unwrap(DebuffFrame.alpha) == 0)
QuietUICharDB.player = 'resource'
tick(); assert(unwrap(PlayerFrame.alpha) == 0 and unwrap(PetFrame.alpha) == 0)
ns.InEditMode = function() return true end
tick(); assert(unwrap(PlayerFrame.alpha) == 1)
ns.InEditMode = function() return false end
QuietUICharDB.player, QuietUICharDB.requireLivingTarget = nil, true
UnitIsDeadOrGhost = function(unit) return unit == 'target' end
TargetFrame = frame(UIParent)
ns.InCombat = function() return true end
for _, thresholdKind in ipairs({ 'health', 'resource' }) do
    QuietUICharDB.playerThresholdKind = thresholdKind
    health, power = 1, 1
    tick()
    assert(unwrap(PlayerFrame.alpha) == 0 and unwrap(PetFrame.alpha) == 0 and unwrap(TargetFrame.alpha) == 0,
        'Dead target must still block ordinary combat visibility above the threshold')
    if thresholdKind == 'health' then health = 0.5 else power = 0.5 end
    tick()
    assert(unwrap(PlayerFrame.alpha) == 1 and unwrap(PetFrame.alpha) == 1 and unwrap(TargetFrame.alpha) == 0,
        'Selected threshold must override dead-target blocking for player and pet only')
    QuietUICharDB.playerThresholdPercent = false
    tick()
    assert(unwrap(PlayerFrame.alpha) == 0 and unwrap(PetFrame.alpha) == 0, 'Empty threshold must not override dead target')
    QuietUICharDB.playerThresholdPercent = nil
    QuietUICharDB.player = 'resource'
    tick()
    assert(unwrap(PlayerFrame.alpha) == 0 and unwrap(PetFrame.alpha) == 0, 'Disabled portrait must stay hidden even below threshold')
    QuietUICharDB.player = nil
end
QuietUICharDB.playerThresholdKind = 'health'
ns.InEditMode = function() return true end
tick(); assert(unwrap(PlayerFrame.alpha) == 1 and TargetFrame.alpha == 1)
ns.InEditMode = function() return false end
ns.InCombat = function() return false end
QuietUICharDB.requireLivingTarget = nil
health, power = 1, 1
ns.HasTarget = function() return true end
tick(); assert(unwrap(PlayerFrame.alpha) == 1)
ns.HasTarget = function() return false end
ns.UpdateSmooth(0.15)
assert(unwrap(PlayerFrame.alpha) > 0 and unwrap(PlayerFrame.alpha) < 1, 'Leaving forced visibility must fade')
ns.UpdateSmooth(0.15)
assert(unwrap(PlayerFrame.alpha) == 0)
local reported
ns.Report = function(name) reported = name end
local savedHealth = UnitHealthPercent
UnitHealthPercent = nil
local savedPower = UnitPowerPercent
UnitPowerPercent = function(unit, powerKind, unmodified, curve)
    assert(powerKind ~= false and curve, 'Power received health arguments')
    return savedPower(unit, powerKind, unmodified, curve)
end
tick()
assert(reported == 'player health', 'Missing health API must be reported without substituting power')
UnitPowerPercent = savedPower
UnitHealthPercent = savedHealth
ns.RestoreAlpha()
assert(PlayerFrame.alpha == 1 and PetFrame.alpha == 1 and BuffFrame.alpha == 1)
PersonalResourceDisplayFrame = frame(UIParent)
local resourceHealth, resourcePower = frame(PersonalResourceDisplayFrame), frame(PersonalResourceDisplayFrame)
PersonalResourceDisplayFrame.HealthBarsContainer = resourceHealth
function PersonalResourceDisplayFrame:GetChildren() return resourceHealth, resourcePower end
ns.FindFaders(false)
for cycle = 1, 2 do
    health, power = 1, 1
    ns.InCombat = function() return true end
    tick()
    ns.InCombat = function() return false end
    local total = 0
    for _, elapsed in ipairs({ 0.017, 0.083, 0.071, 0.129 }) do
        total = total + elapsed
        ns.UpdateSmooth(elapsed)
        local expected = math.max(0, 1 - total / 0.3)
        assert(math.abs(unwrap(resourceHealth.alpha) - expected) < 1e-9, 'Health fade must retain exact weights')
        assert(math.abs(unwrap(resourcePower.alpha) - expected) < 1e-9, 'Power fade must retain exact weights')
    end
    health, power = 0.2, 0.2
    ns.UpdateSmooth(0.017)
    assert(unwrap(resourceHealth.alpha) == 1 and unwrap(resourcePower.alpha) == 1,
        'Reused curves must still reveal fresh low health and power immediately')
end
ns.RestoreAlpha()
assert(resourceHealth.alpha == 1 and resourcePower.alpha == 1, 'Resource alpha must restore after reused curves')
print('PASS single health/resource threshold with native secret-point restrictions, boundaries, empty, forced visibility and restore')
