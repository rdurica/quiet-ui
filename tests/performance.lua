-- Run from the addon directory: lua tests/performance.lua [runtime-directory]
local root = arg[1] or '.'
local check = arg[2] == '--measure' and function() end or assert
local function loadAddon(file, ns) assert(loadfile(root .. '/' .. file))('QuietUI', ns) end
local function frame(parent)
    local obj = { alpha = 1, writes = 0, parent = parent }
    function obj:IsForbidden() return false end
    function obj:IsShown() return true end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(alpha) self.alpha = alpha; self.writes = self.writes + 1 end
    function obj:GetParent() return self.parent end
    function obj:GetChildren() return end
    return obj
end
QuietUIDB = { enabled = true }
UIParent = frame()
PlayerFrame, PetFrame = frame(UIParent), frame(UIParent)
BuffFrame, PersonalResourceDisplayFrame = frame(UIParent), frame(UIParent)
local powerCalls, healthCalls, typeCalls, curves = 0, 0, 0, 0
local curveEdits = 0
local failCurveClear = false
local power = { secret = true }
local token, kind = 'MANA', 0
issecretvalue = function(value) return type(value) == 'table' and value.secret == true end
UnitPowerType = function() typeCalls = typeCalls + 1; return kind, token end
UnitPowerPercent = function() powerCalls = powerCalls + 1; return power end
UnitHealthPercent = function() healthCalls = healthCalls + 1; return 0 end
Enum = { LuaCurveType = { Step = 1 } }
C_CurveUtil = { CreateCurve = function()
    curves = curves + 1
    return { AddPoint = function() curveEdits = curveEdits + 1 end,
        ClearPoints = function(self)
            if failCurveClear and not self.step then error('Curve editing unavailable') end
            curveEdits = curveEdits + 1
        end, SetType = function(self) self.step = true end }
end }
hooksecurefunc = function() end
local ns = {}
loadAddon('Core.lua', ns)
local combat = false
for _, key in ipairs({ 'InEditMode', 'InForcedInstance', 'InGroup', 'InVehicle',
    'HasTarget', 'Glancing', 'Pinned', 'OnlyOnHover', 'RequireLivingTarget', 'Hit' }) do
    ns[key] = function() return false end
end
ns.InCombat = function() return combat end
ns.PlayerStyle = function() return 'classic' end
ns.PlayerThreshold = function() return 'resource', 70 end
ns.GroupAuras = function() return true end
ns.AlwaysShowDebuffs = function() return true end
loadAddon('Faders.lua', ns)
ns.FindFaders(false)
local function reset()
    powerCalls, healthCalls, typeCalls, curves = 0, 0, 0, 0
    curveEdits = 0
    for _, obj in ipairs({ PlayerFrame, PetFrame, BuffFrame, PersonalResourceDisplayFrame }) do
        obj.writes = 0
    end
end
local function tick() ns.UpdateSmooth(1 / 60) end
tick()
reset()
for _ = 1, 60 do tick() end
print(('Idle 60 frames: power=%d health=%d powerType=%d curves=%d playerWrites=%d')
    :format(powerCalls, healthCalls, typeCalls, curves, PlayerFrame.writes))
check(powerCalls == 120 and healthCalls == 60, 'Player and auras must share the selected threshold sample')
check(curves == 0, 'Stable thresholds must reuse curve objects')
print(('Idle 60 frames: curve edits=%d'):format(curveEdits))
check(curveEdits == 0, 'Stable thresholds must not rebuild unchanged curve points')
check(typeCalls == 60, 'Power type should be sampled once per frame')
check(PlayerFrame.alpha == power and BuffFrame.alpha == power, 'Secret alpha must reach widgets unchanged')
power = { secret = true }
tick()
check(PlayerFrame.alpha == power, 'A new frame must read a fresh secret power value')
combat = true
tick()
reset()
for _ = 1, 60 do tick() end
print(('Combat 60 frames: power=%d health=%d powerType=%d curves=%d playerWrites=%d')
    :format(powerCalls, healthCalls, typeCalls, curves, PlayerFrame.writes))
check(powerCalls == 0 and healthCalls == 0, 'Fully visible frames need no health or power percentage')
check(PlayerFrame.writes == 0 and BuffFrame.writes == 0, 'Stable forced visibility should not write alpha again')
check(PlayerFrame.alpha == 1 and PersonalResourceDisplayFrame.alpha == 1)
combat = false
reset()
for _ = 1, 20 do tick() end
print(('First fade, 20 frames: curves=%d'):format(curves))
check(curves <= 2, 'A resource fade must reuse its health and power curve objects')
combat = true
tick()
combat = false
reset()
for _ = 1, 20 do tick() end
print(('Repeated fade, 20 frames: curves=%d'):format(curves))
check(curves == 0, 'Repeated fades must not allocate new curve objects')
combat = true
tick()
combat, failCurveClear = false, true
tick()
check(PersonalResourceDisplayFrame.alpha == power, 'Failed curve editing must fall back to fresh curves')
failCurveClear = false
combat = false
ns.HasTarget = function() return true end
local hoverReads = 0
ns.Hit = function() hoverReads = hoverReads + 1; return false end
reset()
tick()
check(PlayerFrame.alpha == 1 and BuffFrame.alpha == 1, 'Target must keep player and grouped auras visible')
check(PersonalResourceDisplayFrame.alpha == power, 'Resource bar must keep its independent power rule')
print(('Target visible: hover reads=%d'):format(hoverReads))
check(hoverReads == 0, 'Forced player and grouped aura visibility must skip hover traversal')
ns.HasTarget = function() return false end
for _ = 1, 20 do tick() end
check(PlayerFrame.alpha == power, 'Fading must return to the secret power rule')
token, kind = 'RAGE', 1
for _ = 1, 20 do tick() end
check(PlayerFrame.alpha == 0 and BuffFrame.alpha == 0, 'Rage must not hold the portrait or auras up')
ns.RestoreAlpha()
check(PlayerFrame.alpha == 1 and BuffFrame.alpha == 1, 'Disable must restore original alpha')
local health, powerBar = frame(PersonalResourceDisplayFrame), frame(PersonalResourceDisplayFrame)
PersonalResourceDisplayFrame.HealthBarsContainer = health
function PersonalResourceDisplayFrame:GetChildren() return health, powerBar end
ns.FindFaders(false)
local healthValue = { secret = true }
UnitHealthPercent = function() healthCalls = healthCalls + 1; return healthValue end
for _ = 1, 20 do tick() end
check(health.alpha == healthValue and powerBar.alpha == 0, 'Missing health and rage must use independent alphas')
combat = true
tick()
reset()
health.writes, powerBar.writes = 0, 0
tick()
check(health.alpha == 1 and powerBar.alpha == 1, 'Combat must reveal both resource children')
check(health.writes == 0 and powerBar.writes == 0, 'Stable resource children must skip alpha writes')
combat = false
token, kind = 'MANA', 0
for _ = 1, 20 do tick() end
check(health.alpha == healthValue and powerBar.alpha == power, 'Resource children must return to fresh secret results')
UnitPowerType = function() error('Unavailable power type') end
local reported
ns.Report = function(name) reported = name end
tick()
check(reported == 'player power', 'Failed sampling must be reported without breaking the update')
check(not PlayerFrame._quietSecret, 'Failed power sampling must not reuse the previous secret result')
ns.RestoreAlpha()
check(health.alpha == 1 and powerBar.alpha == 1, 'Disable must restore resource children')
if arg[2] ~= '--measure' then
    print('PASS smooth updates share power work, preserve secrets, independent rules, fades and restore')
end
