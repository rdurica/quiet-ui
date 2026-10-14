local _, ns = ...

-- Modernize getters and the saved window points. Missing values mean the default.

local OPACITY = { [50] = 0.5, [75] = 0.75, [90] = 0.9 }

local function Stored()
    local stored = ns.Settings.Effective().modernize
    if type(stored) == "table" then return stored end
    return {}
end

-- Missing means off. Only an explicit true turns Modernize on.
function ns.Settings.Modernize()
    return Stored().enabled == true
end

-- Missing means on while Modernize is on. Only an explicit false turns one area off.
function ns.Settings.ModernArea(key)
    return ns.Settings.Modernize() and Stored()[key] ~= false
end

-- Background alpha: 0.5, 0.75 or 0.9. Anything else means 0.75.
function ns.Settings.ModernOpacity()
    return OPACITY[Stored().opacity] or 0.75
end

-- Missing means on. Only an explicit false turns class colours off.
function ns.Settings.ModernClassColors()
    return Stored().classColors ~= false
end

-- A name the theme list does not know means dark.
function ns.Settings.ModernTheme()
    local name = Stored().theme
    if type(name) == "string" and ns.Modern and ns.Modern.Themes then
        for _, known in ipairs(ns.Modern.Themes()) do
            if known == name then return name end
        end
    end
    return "dark"
end

-- Character only: not part of presets and kept by Reset default.
function ns.Settings.WindowPoint(key)
    local points = ns.Settings.CharDB().windowPoints
    local p = type(points) == "table" and points[key]
    if type(p) ~= "table" then return nil end
    if type(p[1]) ~= "string" or type(p[2]) ~= "string" or type(p[3]) ~= "number" or type(p[4]) ~= "number"
        or ns.IsSecret(p[3]) or ns.IsSecret(p[4]) then return nil end
    return p[1], p[2], p[3], p[4]
end

function ns.Settings.SaveWindowPoint(key, point, relativePoint, x, y)
    local char = ns.Settings.CharDB()
    if type(char.windowPoints) ~= "table" then char.windowPoints = {} end
    char.windowPoints[key] = { point, relativePoint, x, y }
end

function ns.Settings.ResetWindowPoints()
    ns.Settings.CharDB().windowPoints = nil
end
