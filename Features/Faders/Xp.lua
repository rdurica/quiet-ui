local _, ns = ...
local Faders = ns.Faders

-- Quest XP arrives out of combat, so the XP bar shows it for a moment.
local XP_AFTER_QUEST = 5
-- Modern XP "Show on big XP gain": quest XP and a gain of at least BIG_GAIN of the level show the
-- bar for a moment, even when it is Only on hover. Mob kills stay quiet.
local XP_AFTER_GAIN = 5
local BIG_GAIN = 0.05

local lastQuestXP, gainUntil, lastXP

local function MarkGain(seconds)
    if type(GetTime) ~= "function" then return end
    local untilTime = GetTime() + seconds
    if not gainUntil or untilTime > gainUntil then gainUntil = untilTime end
end

function Faders.MarkQuestXP(xp)
    if type(xp) == "number" and not ns.IsSecret(xp) and xp <= 0 then return end
    if type(GetTime) == "function" then
        lastQuestXP = GetTime()
    end
    if ns.Settings.ModernXPGain() then MarkGain(XP_AFTER_QUEST) end
    ns.World.TouchHud()
end

local function Plain(value)
    return type(value) == "number" and not ns.IsSecret(value)
end

-- The first value is only the baseline; a lower value (level up) and secret values are no big gain.
function Faders.NoteXP()
    if type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then return end
    local xp, maximum = UnitXP("player"), UnitXPMax("player")
    local old = lastXP
    lastXP = xp
    if not Plain(xp) or not Plain(old) or not Plain(maximum) or maximum <= 0 then return end
    if xp - old < maximum * BIG_GAIN or not ns.Settings.ModernXPGain() then return end
    MarkGain(XP_AFTER_GAIN)
    ns.World.TouchHud()
end

function Faders.XPGainShows()
    if not gainUntil or type(GetTime) ~= "function" then return false end
    if GetTime() < gainUntil and ns.Settings.ModernXPGain() then return true end
    return false
end

function Faders.XPShouldShow()
    if ns.World.ShowAll() then return true end
    if lastQuestXP and type(GetTime) == "function" then
        return GetTime() - lastQuestXP < XP_AFTER_QUEST
    end
    return false
end
