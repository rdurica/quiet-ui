local _, ns = ...
local Faders = ns.Faders

local state = Faders.state
local auraFrames = state.auraFrames

-- Aura buttons can sit outside their container's bounds, so children count too.
local function MouseOverAny(frame)
    if ns.Hit(frame) then return true end
    local kids = Faders.KidsOf(frame)
    for i = 1, #kids do
        if ns.Usable(kids[i]) and ns.Hit(kids[i]) then return true end
    end
    return false
end

local function AurasShouldShow(hoverOnly, grouped)
    if hoverOnly then
        local hovered = false
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then hovered = true; break end
        end
        return ns.Settings.VisibilityShow("auras", false, hovered)
    end
    local show = ns.World.InCombat() or ns.World.InForcedInstance() or ns.World.InGroup() or ns.World.InEditMode()
        or ns.Settings.Pinned("auras") or ns.Glance.Active()
    if not show and grouped and Faders.PlayerShouldShow() then
        show = true
    end
    if not show then
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then
                show = true
                break
            end
        end
    end
    return show
end

function Faders.UpdateAuras(elapsed)
    local hoverOnly = ns.Settings.OnlyOnHover("auras")
    local grouped = not hoverOnly and ns.Settings.GroupAuras()
    local show = AurasShouldShow(hoverOnly, grouped) and true or false
    local useCurve = grouped and Faders.PlayerUsesThresholds()
    state.aurasCurved, state.auraWeight = Faders.TakeWeight(state.aurasCurved, state.auraWeight, show, elapsed, useCurve)
    local alpha = useCurve and Faders.EvalPlayerThresholds(state.auraWeight) or nil
    local keepDebuffs = not hoverOnly and ns.Settings.AlwaysShowDebuffs()
    for _, frame in ipairs(auraFrames) do
        if keepDebuffs and frame == _G.DebuffFrame then
            if frame._quietSecret ~= nil or frame._quietAlpha ~= 1 then
                Faders.PaintNumeric(frame, true, elapsed)
            end
        elseif alpha ~= nil then
            Faders.PaintSecret(frame, alpha)
        else
            Faders.PaintNumeric(frame, show, elapsed)
        end
    end
end
