local _, ns = ...

-- The five modules as a set of booleans: reading, storing, comparing. Shared by Draft, Window and Welcome.

local Setup = ns.Setup

-- The five modules, in the order of the Modules tab. Modernize is the only one that starts off.
Setup.MODULES = {
    { key = "chat", label = "Chat", text = "Fading message bubbles, chat tabs and input history." },
    { key = "fading", label = "Fading", text = "Action bars, HUD, player frames, micro menu and Glance fade until needed." },
    { key = "helpers", label = "Helpers", text = "Quest updates, Interact highlights and quest mob icons." },
    { key = "layout", label = "Layout", text = "The QuietUI Edit Mode layout, its prompt and preset layouts." },
    { key = "modernize", label = "Modernize", text = "A flat dark look for Blizzard's windows and frames (experimental)." },
}

-- The modules of a settings table as booleans. Missing means on, except Modernize.
function Setup.ReadModules(source)
    local stored = type(source.modules) == "table" and source.modules or {}
    local set = {}
    for _, info in ipairs(Setup.MODULES) do
        if info.key == "modernize" then set[info.key] = stored[info.key] == true
        else set[info.key] = stored[info.key] ~= false end
    end
    return set
end

-- Only the modules that differ from the defaults are stored; nil when none does.
function Setup.StoredModules(set)
    local stored
    for _, info in ipairs(Setup.MODULES) do
        local key = info.key
        if key == "modernize" then
            if set[key] then stored = stored or {}; stored[key] = true end
        elseif not set[key] then
            stored = stored or {}
            stored[key] = false
        end
    end
    return stored
end

function Setup.SameModules(a, b)
    for _, info in ipairs(Setup.MODULES) do
        if (a[info.key] and true or false) ~= (b[info.key] and true or false) then return false end
    end
    return true
end

-- The modules in effect now.
function Setup.ActiveModules()
    local set = {}
    for _, info in ipairs(Setup.MODULES) do set[info.key] = ns.Settings.Module(info.key) end
    return set
end

function Setup.AnyModule(set)
    for _, info in ipairs(Setup.MODULES) do
        if set[info.key] then return true end
    end
    return false
end
