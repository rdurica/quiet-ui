local _, ns = ...
local Faders = ns.Faders

-- Smooth weights and the curves that turn them into secret-safe alphas.

local state = Faders.state
local curveCache = state.curveCache
local thresholdCurves = state.thresholdCurves
local powerWeights, powerAlphas = state.powerWeights, state.powerAlphas
local thresholdWeights, thresholdAlphas = state.thresholdWeights, state.thresholdAlphas

-- The resource bar also shows out of combat below this share of max power.
local LOW_POWER = 0.7

-- Mana, focus and energy rest at max; rage and the rest rest at zero.
local RESTS_AT_MAX = { [0] = true, [2] = true, [3] = true }

-- Same length as the bar fade. Showing snaps to 1. Hiding eases.
local SMOOTH = 0.3
local POWER_FROM = LOW_POWER - 0.001
local HEALTH_FROM = 0.999

local POWER_REST = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { LOW_POWER, 0 },
    { 1, 0 },
}
local POWER_FORCED = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { LOW_POWER, 1 },
    { 1, 1 },
}
local HEALTH_REST = {
    { 0, 1 },
    { HEALTH_FROM, 1 },
    { 1, 0 },
}
local HEALTH_FORCED = {
    { 0, 1 },
    { HEALTH_FROM, 1 },
    { 1, 1 },
}


-- Mana, focus and energy. Rage and the rest stay out even when the type number
-- is hidden, as long as the token is still a plain string.
function Faders.ReadRestingPower()
    if type(UnitPowerType) ~= "function" then return nil end
    local kind, token = UnitPowerType("player")
    if type(token) == "string" and not ns.IsSecret(token) then
        if token == "MANA" or token == "FOCUS" or token == "ENERGY" then return kind end
        return nil
    end
    if not ns.IsSecret(kind) then
        if RESTS_AT_MAX[kind] then return kind end
        return nil
    end
    return kind
end

function Faders.RestingPower()
    if state.samplingPower then return state.sampledKind end
    return Faders.ReadRestingPower()
end

-- Secret values cannot be lerped, so the curve points move and the widget fades.
local function MakeCurve(points)
    if not C_CurveUtil or type(C_CurveUtil.CreateCurve) ~= "function" then
        ns.Report("resource bar", "C_CurveUtil.CreateCurve missing")
        return nil
    end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        for i = 1, #points do
            c:AddPoint(points[i][1], points[i][2])
        end
        return c
    end)
    if not ok then
        ns.Report("resource bar", curve)
        return nil
    end
    return curve
end

local function CurveFor(points, key)
    if key then
        local cached = curveCache[key]
        if cached ~= nil then return cached or nil end
        curveCache[key] = false
    end
    local curve = MakeCurve(points)
    if key then
        curveCache[key] = curve or false
    end
    return curve
end

local function BlendPoints(rest, forced, t)
    if t <= 0 then return rest end
    if t >= 1 then return forced end
    local out = {}
    for i = 1, #rest do
        local y0, y1 = rest[i][2], forced[i][2]
        out[i] = { rest[i][1], y0 + (y1 - y0) * t }
    end
    return out
end

local function BlendedCurve(rest, forced, t, name)
    local curve
    if t <= 0 then
        curve = CurveFor(rest, name .. ":0")
    elseif t >= 1 then
        curve = CurveFor(forced, name .. ":1")
    else
        local key = name .. ":blend"
        curve = CurveFor(rest, key)
        if not curve then return nil end
        if type(curve.ClearPoints) ~= "function" then
            return MakeCurve(BlendPoints(rest, forced, t))
        end
        local ok, err = pcall(function()
            curve:ClearPoints()
            for i = 1, #rest do
                local y0, y1 = rest[i][2], forced[i][2]
                curve:AddPoint(rest[i][1], y0 + (y1 - y0) * t)
            end
        end)
        if not ok then
            curveCache[key] = nil
            ns.Report("resource bar", err)
            return MakeCurve(BlendPoints(rest, forced, t))
        end
    end
    return curve
end

function Faders.NextWeight(current, show, elapsed)
    if show or current <= 0 then return show and 1 or 0 end
    local step = (elapsed or 0) / SMOOTH
    if current <= step then return 0 end
    return current - step
end

function Faders.TakeWeight(curved, weight, show, elapsed, useCurve)
    if not useCurve then return false, weight end
    if not curved then
        weight = show and 1 or 0
    end
    return true, Faders.NextWeight(weight, show, elapsed)
end

function Faders.EvalPower(weight)
    local kind = Faders.RestingPower()
    if kind == nil then return nil end
    if weight >= 1 then return 1 end
    -- Weights are plain numbers; the cached result may be secret and is never compared.
    if state.samplingPower then
        for i = 1, state.powerSampleCount do
            if powerWeights[i] == weight then return powerAlphas[i] end
        end
    end
    local curve = BlendedCurve(POWER_REST, POWER_FORCED, weight, "power")
    if not curve or type(UnitPowerPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitPowerPercent, "player", kind, false, curve)
    if ok and alpha ~= nil then
        if state.samplingPower then
            state.powerSampleCount = state.powerSampleCount + 1
            powerWeights[state.powerSampleCount] = weight
            powerAlphas[state.powerSampleCount] = alpha
        end
        return alpha
    end
    if not ok then ns.Report("player power", alpha) end
    return 0
end

function Faders.EvalHealth(weight)
    if weight >= 1 then return 1 end
    local curve = BlendedCurve(HEALTH_REST, HEALTH_FORCED, weight, "health")
    if not curve or type(UnitHealthPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitHealthPercent, "player", false, curve)
    if ok and alpha ~= nil then return alpha end
    if not ok then ns.Report("player health", alpha) end
    return 0
end

local function ThresholdCurve(name, percent, above, below)
    local cached = thresholdCurves[name]
    if cached and cached.percent == percent and cached.above == above and cached.below == below then
        return cached.curve
    end
    local ok, curve = pcall(function()
        local c = cached and cached.curve
        if not c then
            c = C_CurveUtil.CreateCurve()
            c:SetType(Enum.LuaCurveType.Step)
        end
        c:ClearPoints()
        c:AddPoint(0, below or 1)
        c:AddPoint(percent / 100, above)
        return c
    end)
    if ok then
        cached = cached or {}
        cached.curve, cached.percent, cached.above, cached.below = curve, percent, above, below
        thresholdCurves[name] = cached
        return curve
    end
    thresholdCurves[name] = nil
    ns.Report("player threshold curve", curve)
end

function Faders.ReadThreshold()
    if state.samplingPower and state.thresholdRead then return state.sampledThresholdKind, state.sampledThresholdPercent end
    local kind, percent = "health", 70
    if ns.Settings.PlayerThreshold then kind, percent = ns.Settings.PlayerThreshold() end
    if state.samplingPower then
        state.sampledThresholdKind, state.sampledThresholdPercent = kind, percent
        state.thresholdRead = true
    end
    return kind, percent
end

function Faders.EvalPlayerThresholds(weight, scale, name)
    scale = scale or 1
    if weight >= 1 then return scale end
    if state.samplingPower and not name then
        for i = 1, state.thresholdSampleCount do
            if thresholdWeights[i] == weight then return thresholdAlphas[i] end
        end
    end
    local kind, percent = Faders.ReadThreshold()
    local alpha = weight * scale
    if percent then
        -- Curve points are plain numbers; only the evaluated alpha may be secret.
        local curve = ThresholdCurve(name or kind, percent, weight * scale, scale)
        if curve then
            local fn
            if kind == "health" then fn = UnitHealthPercent else fn = UnitPowerPercent end
            if type(fn) == "function" then
                local ok, result
                if kind == "health" then ok, result = pcall(fn, "player", false, curve)
                else ok, result = pcall(fn, "player", Faders.RestingPower(), false, curve) end
                if ok and result ~= nil then alpha = result
                elseif not ok then ns.Report("player " .. kind, result) end
            else ns.Report("player " .. kind, "Percentage API missing") end
        end
    end
    if state.samplingPower and not name then
        state.thresholdSampleCount = state.thresholdSampleCount + 1
        thresholdWeights[state.thresholdSampleCount] = weight
        thresholdAlphas[state.thresholdSampleCount] = alpha
    end
    return alpha
end
