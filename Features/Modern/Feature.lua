local _, ns = ...

-- Registers Modernize with the feature registry. Loads after the Areas so the order of the
-- files is the order of the checkboxes.

ns.Feature{
    name = "modern",
    apply = ns.Modern.Apply,
    restore = ns.Modern.Restore,
    events = {
        ADDON_LOADED = ns.Modern.AddonLoaded,
        PLAYER_REGEN_ENABLED = function() ns.Modern.PlaceWindows(true) end,
    },
    always = { "PLAYER_REGEN_ENABLED" },
    hooks = {
        UpdateUIPanelPositions = function() ns.Modern.PlaceWindows(false) end,
    },
}
