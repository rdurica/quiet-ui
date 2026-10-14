local _, ns = ...

-- The first registered feature: world state is refreshed before any other feature reads it.
-- Also the fade pass that events and the scheduler share.

-- One fade pass over every feature. `idle` marks the slow pass with no focus change.
function ns.Registry.Fade(elapsed, rescan, idle)
    if not ns.DB().enabled then return end
    ns.NextFadeTick()
    ns.World.BeginTick(rescan)
    ns.Registry.Phase("fade", elapsed, rescan, ns.World.ShowAll(), idle)
end

ns.Feature({
    name = "world",
    apply = function() ns.World.RefreshWorld() end,
    rescan = function() ns.World.RefreshWorld() end,
    events = {
        PLAYER_REGEN_DISABLED = function() ns.World.NoteCombat(true) end,
        PLAYER_REGEN_ENABLED = function() ns.World.NoteCombat(false) end,
        GROUP_ROSTER_UPDATE = function() ns.World.RefreshWorld() end,
        PLAYER_TARGET_CHANGED = function() ns.World.RefreshWorld() end,
        UNIT_FLAGS = function(unit) if unit == "target" then ns.World.RefreshWorld() end end,
        UNIT_FACTION = function(unit) if unit == "target" then ns.World.RefreshWorld() end end,
        UNIT_ENTERED_VEHICLE = function() ns.World.RefreshWorld() end,
        UNIT_EXITED_VEHICLE = function() ns.World.RefreshWorld() end,
    },
})
