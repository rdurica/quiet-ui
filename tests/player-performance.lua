-- Run from the addon directory: lua tests/player-performance.lua
local ns, combat, targetDead, playerDead = {}, false, false, false
local targetReads, parentReads, parentHooks, styleReads = 0, 0, 0, 0
local style = 'classic'
local function frame(parent)
    local obj = { parent = parent, alpha = 1, hooks = {} }
    function obj:IsForbidden() return false end
    function obj:IsShown() return true end
    function obj:GetParent() parentReads = parentReads + 1; return self.parent end
    function obj:SetParent(parent)
        self.parent = parent
        for _, hook in ipairs(self.hooks.SetParent or {}) do hook(self, parent) end
    end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value)
        self.alpha = value
        for _, hook in ipairs(self.hooks.SetAlpha or {}) do hook(self, value) end
    end
    function obj:GetChildren() end
    function obj:IsIgnoringParentAlpha() return self.ignoring or false end
    function obj:SetIgnoreParentAlpha(value) self.ignoring = value end
    return obj
end
QuietUIDB = { enabled = true }
UIParent = frame()
PlayerFrame, PetFrame = frame(UIParent), frame(UIParent)
TargetFrame = frame(UIParent)
local secretAlpha = { secret = true }
issecretvalue = function(value) return type(value) == 'table' and value.secret == true end
UnitPowerType = function() return 0, 'MANA' end
UnitHealthPercent, UnitPowerPercent = function() return secretAlpha end, function() return secretAlpha end
UnitIsDeadOrGhost = function(unit)
    if unit == 'target' then targetReads = targetReads + 1; return targetDead end
    return playerDead
end
Enum = { LuaCurveType = { Step = 1 } }
C_CurveUtil = { CreateCurve = function()
    return { SetType = function() end, AddPoint = function() end, ClearPoints = function() end }
end }
-- Successful hooks can keep the method identity unchanged.
hooksecurefunc = function(obj, method, hook)
    if method == 'SetParent' then parentHooks = parentHooks + 1 end
    obj.hooks[method] = obj.hooks[method] or {}
    table.insert(obj.hooks[method], hook)
end
assert(loadfile('Core.lua'))('QuietUI', ns)
for _, key in ipairs({ 'InEditMode', 'InForcedInstance', 'InGroup', 'InVehicle', 'HasTarget',
    'Glancing', 'Pinned', 'OnlyOnHover', 'Hit', 'GroupAuras' }) do ns[key] = function() return false end end
ns.InCombat = function() return combat end
ns.RequireLivingTarget = function() return true end
ns.PlayerStyle = function() styleReads = styleReads + 1; return style end
ns.PlayerThreshold = function() return 'health', 70 end
ns.AlwaysShowDebuffs = function() return true end
assert(loadfile('Faders.lua'))('QuietUI', ns)
local function tick() ns.UpdateSmooth(1 / 60) end
tick()
targetReads = 0
for _ = 1, 60 do tick() end
print(('60 frames: target life reads=%d'):format(targetReads))
assert(targetReads == 60, 'Player and target visibility must share one target-life read per frame')
styleReads = 0
for _ = 1, 60 do tick() end
assert(styleReads == 60, 'Player visibility and thresholds must share one style read per frame')
parentReads, parentHooks = 0, 0
for _ = 1, 60 do tick() end
print(('Stable pet, 60 frames: parent reads=%d hook installs=%d'):format(parentReads, parentHooks))
assert(parentReads == 0 and parentHooks == 0, 'A successful stable-parent hook must prevent repeated ancestry walks')
secretAlpha = { secret = true }
tick()
assert(PlayerFrame.alpha == secretAlpha and PetFrame.alpha == secretAlpha, 'Alpha samples must stay fresh every frame')
combat, targetDead = true, true
tick()
assert(TargetFrame.alpha ~= 1, 'A dead target must still fade during combat')
targetDead = false
tick()
assert(TargetFrame.alpha == 1 and TargetFrame._quietAlpha == nil, 'Reviving the target must release its alpha immediately')
PetFrame:SetParent(PlayerFrame)
tick()
assert(PetFrame.ignoring, 'Reparenting under PlayerFrame must invalidate ancestry and isolate the pet')
playerDead = true
tick()
assert(PlayerFrame.alpha < 1 and PetFrame.alpha == 1, 'Player death must leave the isolated pet visible')
ns.RestorePlayerFader()
ns.RestoreAlpha()
assert(not PetFrame.ignoring, 'Disable must restore original alpha inheritance')
playerDead = false
PetFrame:SetParent(UIParent)
tick()
assert(PetFrame.alpha == 1, 'Moving the pet back to UIParent must invalidate ancestry again')
style = 'resource'
ns.UpdateSmooth(0.3)
assert(PlayerFrame.alpha == 0 and PetFrame.alpha == 0, 'Changing player style must take effect on the next frame')
style = 'classic'
tick()
assert(PlayerFrame.alpha == 1 and PetFrame.alpha == 1, 'Re-enabling the portrait must immediately refresh cached style')
local container = frame(UIParent)
PetFrame:SetParent(container)
tick()
container:SetParent(PlayerFrame)
tick()
assert(PetFrame.ignoring, 'Reparenting an intermediate ancestor must not leave a stale cache')
ns.RestorePlayerFader()
ns.RestoreAlpha()
local workingHook = hooksecurefunc
for _, mode in ipairs({ 'missing', 'failed' }) do
    if mode == 'missing' then hooksecurefunc = nil
    else
        hooksecurefunc = function(obj, method, hook)
            if method == 'SetParent' then error('Parent hook unavailable') end
            workingHook(obj, method, hook)
        end
    end
    PetFrame = frame(UIParent)
    tick()
    parentReads = 0
    tick()
    assert(parentReads > 0, 'Unavailable parent hooks must keep checking ancestry')
    PetFrame:SetParent(PlayerFrame)
    tick()
    assert(PetFrame.ignoring, 'Reparenting must still isolate the pet without a parent hook')
    ns.RestorePlayerFader()
    ns.RestoreAlpha()
end
hooksecurefunc = workingHook
print('PASS shared player decisions, stable pet hooks, fresh alpha, reparenting, death and restore')
