-- Fixture for the smooth-update cost tests and measurement (player, pet, auras, resource bar).
-- Test code only. Loaded with h.lib("smooth") or loadfile by tests/measure/performance.lua.
-- Health and power are strict secrets (tests/lib/player.lua); every percentage read returns
-- the same secret box until the test replaces it, so shared samples are visible as identity.
local S = {}

local function load(h)
    if h then return h.lib("player") end
    local dir = (S.dir or ".")
    return assert(loadfile(dir .. "/player.lua"))()
end

-- t: harness context (ns, mock). h: harness (tests) or nil (measure script, S.dir set).
function S.build(t, h)
    local P = load(h)
    local ns, mock = t.ns, t.mock
    local s = P.env(t, { plain = true })
    s.P = P
    s.power, s.healthValue = P.secret(mock, 0.5), P.secret(mock, 0.5)
    s.token, s.kind = "MANA", 0
    s.c = { power = 0, health = 0, type = 0, curves = 0, edits = 0, debuff = 0,
        threshold = 0, style = 0, aura = 0, grouping = 0, hover = 0 }
    s.failClear = false
    local c = s.c
    UnitPowerType = function() c.type = c.type + 1; return s.kind, s.token end
    UnitPowerPercent = function() c.power = c.power + 1; return s.power end
    UnitHealthPercent = function() c.health = c.health + 1; return s.healthValue end
    local create = C_CurveUtil.CreateCurve
    C_CurveUtil.CreateCurve = function()
        c.curves = c.curves + 1
        local curve = create()
        local add, clear = curve.AddPoint, curve.ClearPoints
        function curve:AddPoint(...) c.edits = c.edits + 1; return add(self, ...) end
        function curve:ClearPoints(...)
            if s.failClear and not self.stepSet then error("Curve editing unavailable") end
            c.edits = c.edits + 1
            return clear(self, ...)
        end
        local set = curve.SetType
        function curve:SetType(...) self.stepSet = true; return set(self, ...) end
        return curve
    end
    ns.Settings.PlayerStyle = function() c.style = c.style + 1; return "classic" end
    ns.Settings.PlayerThreshold = function() c.threshold = c.threshold + 1; return "resource", 70 end
    ns.Settings.GroupAuras = function() c.grouping = c.grouping + 1; return true end
    ns.Settings.OnlyOnHover = function(name)
        if name == "auras" then c.aura = c.aura + 1 end
        return false
    end
    ns.Settings.AlwaysShowDebuffs = function() return true end
    ns.Hit = function() c.hover = c.hover + 1; return false end
    local isForbidden = DebuffFrame.IsForbidden
    DebuffFrame.IsForbidden = function(self)
        c.debuff = c.debuff + 1
        return isForbidden(self)
    end
    -- A resource bar without child bars: the container itself takes the power alpha.
    PersonalResourceDisplayFrame.HealthBarsContainer = nil
    PersonalResourceDisplayFrame._children = {}
    ns.FindFaders(false)
    function s.tick() ns.UpdateSmooth(1 / 60) end
    function s.reset()
        for k in pairs(c) do c[k] = 0 end
        for _, f in ipairs({ PlayerFrame, PetFrame, BuffFrame, PersonalResourceDisplayFrame }) do
            f._calls.SetAlpha = 0
        end
    end
    function s.writes(f) return f._calls.SetAlpha or 0 end
    return s
end

return S
