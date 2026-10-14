local _, ns = ...
local Faders = ns.Faders

-- Quest XP arrives out of combat, so the XP bar shows it for a moment.
local XP_AFTER_QUEST = 5

local lastQuestXP

function Faders.MarkQuestXP(xp)
    if type(xp) == "number" and not ns.IsSecret(xp) and xp <= 0 then return end
    if type(GetTime) == "function" then
        lastQuestXP = GetTime()
    end
    ns.World.TouchHud()
end

function Faders.XPShouldShow()
    if ns.World.ShowAll() then return true end
    if lastQuestXP and type(GetTime) == "function" then
        return GetTime() - lastQuestXP < XP_AFTER_QUEST
    end
    return false
end
