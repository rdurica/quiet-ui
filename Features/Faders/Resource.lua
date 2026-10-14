local _, ns = ...
local Faders = ns.Faders

local state = Faders.state
local resourceFrames = state.resourceFrames

local function ResourceForced()
    return ns.World.InCombat() or ns.World.InForcedInstance() or ns.World.InEditMode() or ns.Settings.Pinned("resource")
        or ns.Glancing()
end

local function HealthPart(frame)
    local health = frame.HealthBarsContainer
    if ns.Usable(health) and health.SetAlpha then return health end
end

-- Two secret alphas cannot be merged, so the health part follows missing
-- health and every other child follows low power. The frame itself stays at 1.
local function PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    if not (Faders.IsFadeable(frame) and frame:IsShown()) then return end
    local health = HealthPart(frame)
    local kids = Faders.KidsOf(frame)
    if not health or #kids == 0 then
        if powerAlpha ~= nil then
            Faders.PaintSecret(frame, powerAlpha)
        else
            Faders.PaintNumeric(frame, show, elapsed)
        end
        return
    end
    if frame._quietAlpha ~= 1 or frame._quietSecret ~= nil then
        ns.HoldAlpha(frame, 1)
    end
    for i = 1, #kids do
        local child = kids[i]
        if ns.Usable(child) and child.SetAlpha then
            if child == health then
                Faders.HoldResult(child, healthAlpha)
            elseif powerAlpha ~= nil then
                Faders.HoldResult(child, powerAlpha)
            else
                ns.EaseAlpha(child, show, elapsed)
            end
        end
    end
end

function Faders.UpdateResource(elapsed)
    if ns.Settings.OnlyOnHover("resource") then
        local hovered = Faders.HoverFrames("resource", resourceFrames)
        for _, frame in ipairs(resourceFrames) do
            if ns.Hit(frame) then hovered = true; break end
            for _, child in ipairs(Faders.KidsOf(frame)) do
                if ns.Usable(child) and ns.Hit(child) then hovered = true; break end
            end
        end
        local show = ns.Settings.VisibilityShow("resource", false, hovered)
        state.resourceWeight = show and 1 or 0
        for _, frame in ipairs(resourceFrames) do
            if Faders.IsFadeable(frame) and frame:IsShown() then
                local kids = Faders.KidsOf(frame)
                if #kids == 0 then Faders.PaintNumeric(frame, show, elapsed)
                else ns.HoldAlpha(frame, 1) end
                for _, child in ipairs(kids) do
                    if Faders.IsFadeable(child) then ns.EaseAlpha(child, show, elapsed) end
                end
            end
        end
        return
    end
    Faders.ParkHover("resource")
    local show = ResourceForced() and true or false
    state.resourceWeight = Faders.NextWeight(state.resourceWeight, show, elapsed)
    local powerAlpha = Faders.EvalPower(state.resourceWeight)
    local healthAlpha = Faders.EvalHealth(state.resourceWeight)
    for _, frame in ipairs(resourceFrames) do
        PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    end
end
