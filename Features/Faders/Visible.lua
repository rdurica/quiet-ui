local _, ns = ...
local Faders = ns.Faders

local state = Faders.state
local statusFrames = state.statusFrames
local cooldownFrames = state.cooldownFrames
local meterFrames = state.meterFrames
local questFrames = state.questFrames

-- Cooldowns matter only when fighting or grouped, so hover does not count.
local function CooldownsShouldShow()
    return ns.World.InCombat() or ns.World.InForcedInstance() or ns.World.InGroup() or ns.World.InEditMode()
end

local function UpdateVisible(name, frames, usual, noHover, exception, glance, elapsed)
    local hovered = Faders.HoverFrames(name, frames)
    if ns.Settings.OnlyOnHover(name) then
        Faders.UpdateGroup(frames, ns.World.InEditMode() or glance or exception or hovered, elapsed)
    else
        Faders.UpdateGroup(frames, usual or ns.Settings.Pinned(name) or glance, elapsed, noHover)
    end
end

function Faders.Update(elapsed)
    local glance = ns.Glance.Active()
    ns.Run("xp bar", UpdateVisible, "xp", statusFrames, Faders.XPShouldShow(), false, ns.World.XPForced(), glance, elapsed)
    ns.Run("cooldown manager", UpdateVisible, "cooldowns", cooldownFrames, CooldownsShouldShow(), true, nil,
        glance, elapsed)
    ns.Run("damage meter", UpdateVisible, "meter", meterFrames, Faders.MeterShouldShow(), true, nil, glance, elapsed)
    ns.Run("quest catcher", Faders.PlaceQuestCatcher)
    local questHot = Faders.QuestTrackerHovered()
    ns.Run("quest tracker", Faders.UpdateGroup, questFrames, ns.Settings.VisibilityShow("quests", false, questHot), elapsed)
end

ns.Feature({
    name = "faders",
    apply = function()
        Faders.Find(false)
        Faders.UpdateParty(0)
    end,
    restore = function()
        Faders.HideHoverCatchers()
        Faders.UpdateParty(0)
        Faders.HideQuestCatcher()
        Faders.HideRangeMark()
        -- Target and action bar events stop while off.
        Faders.ForgetRangeSlot()
        Faders.ForgetRangePlate()
        Faders.RestorePlayer()
    end,
    fade = function(elapsed) Faders.Update(elapsed) end,
    frame = function(elapsed)
        -- Range changes while you walk, with no focus or cursor change, so it cannot wait for a rescan.
        ns.Profiler.Run("range", Faders.UpdateRange, elapsed)
        ns.Profiler.Run("smooth", Faders.UpdateSmooth, elapsed, ns.Profiler.Active() and ns.Profiler.Smooth or nil)
    end,
    rescan = function(deep) Faders.Find(deep and true or false) end,
    events = {
        PLAYER_REGEN_DISABLED = function()
            Faders.UpdateParty(0)
            ns.Registry.Fade(0)
        end,
        PLAYER_REGEN_ENABLED = function()
            Faders.MarkCombatEnd()
            ns.Registry.Fade(0)
        end,
        GROUP_ROSTER_UPDATE = function()
            Faders.ScanParty()
            Faders.UpdateParty(0)
        end,
        PLAYER_TARGET_CHANGED = function() Faders.ForgetRangePlate() end,
        NAME_PLATE_UNIT_REMOVED = function() Faders.ForgetRangePlate() end,
        ACTIONBAR_SLOT_CHANGED = function() Faders.ForgetRangeSlot() end,
        SPELLS_CHANGED = function() Faders.ForgetRangeSlot() end,
        QUEST_TURNED_IN = function(_, xp) Faders.MarkQuestXP(xp) end,
    },
})
