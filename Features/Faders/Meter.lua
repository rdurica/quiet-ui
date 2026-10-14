local _, ns = ...
local Faders = ns.Faders

-- Keep the meter readable for a moment after combat ends.
local METER_AFTER_COMBAT = 10

local state = Faders.state
local meterFrames = state.meterFrames
local meterSet = {}
local lastCombat

local function AddMeter(frame)
    if meterSet[frame] or not Faders.IsFadeable(frame) then return end
    meterSet[frame] = true
    meterFrames[#meterFrames + 1] = frame
end

-- The meter is load-on-demand and its window names are not fixed, so a deep
-- scan of UIParent picks up whatever DamageMeter* frames exist.
function Faders.FindMeters(deep)
    AddMeter(_G.DamageMeter)
    for i = 1, 10 do
        AddMeter(_G["DamageMeterSessionWindow" .. i])
    end
    if not deep or not UIParent or not UIParent.GetChildren then return end
    for _, child in ipairs({ UIParent:GetChildren() }) do
        local name = ns.FrameName(child)
        if name and name:find("^DamageMeter") then
            AddMeter(child)
        end
    end
end

function Faders.MarkCombatEnd()
    if type(GetTime) == "function" then
        lastCombat = GetTime()
    end
    ns.World.TouchHud()
end

function Faders.MeterShouldShow()
    if ns.World.InCombat() or ns.World.InForcedInstance() or ns.World.InGroup() or ns.World.InEditMode() then return true end
    if lastCombat and type(GetTime) == "function" then
        return GetTime() - lastCombat < METER_AFTER_COMBAT
    end
    return false
end
