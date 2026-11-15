local _, ns = ...

-- Blocked or forbidden actions of QuietUI are reported like errors; `early` keeps them
-- visible before boot and while the addon is off. There is nothing to apply or restore.
local function Reported(kind, event)
    return function(addon, fn)
        if addon ~= "QuietUI" then return end
        fn = fn ~= nil and tostring(fn) or "?"
        ns.Report("action " .. kind .. ": " .. fn, event .. " " .. fn, "")
    end
end

ns.Feature({
    name = "blocked",
    early = { "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" },
    events = {
        ADDON_ACTION_BLOCKED = Reported("blocked", "ADDON_ACTION_BLOCKED"),
        ADDON_ACTION_FORBIDDEN = Reported("forbidden", "ADDON_ACTION_FORBIDDEN"),
    },
})
