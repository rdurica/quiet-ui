local _, ns = ...

-- Same number fades together. Missing saved values use group.
-- Gamepad follows bar 1 and has no setup row.
ns.BAR_ROWS = {
    { id = "1", label = "Bar 1", group = 1, names = { "MainMenuBar", "MainActionBar", "GamepadMainActionBarFrame" } },
    { id = "2", label = "Bar 2", group = 1, names = { "MultiBarBottomLeft" } },
    { id = "3", label = "Bar 3", group = 1, names = { "MultiBarBottomRight" } },
    { id = "4", label = "Bar 4", group = 2, names = { "MultiBarRight" } },
    { id = "5", label = "Bar 5", group = 2, names = { "MultiBarLeft" } },
    { id = "6", label = "Bar 6", group = 3, names = { "MultiBar5" } },
    { id = "7", label = "Bar 7", group = 4, names = { "MultiBar6" } },
    { id = "8", label = "Bar 8", group = 5, names = { "MultiBar7" } },
    { id = "stance", label = "Stance bar", group = 1, names = { "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame" } },
    { id = "pet", label = "Pet bar", group = 1, names = { "PetActionBar", "PetActionBarFrame" } },
    { id = "totem", label = "Totem bar", group = 1, names = { "MultiCastActionBarFrame", "TotemFrame" } },
    { id = "swing", label = "Swing timer", group = 10, names = {
        "SwingTimerFrame",
        "SwingTimer",
        "MainHandSwingTimer",
        "OffHandSwingTimer",
        "RangedSwingTimer",
        "SwingTimerMainHand",
        "SwingTimerOffHand",
    } },
}

function ns.Settings.GroupVisibility(group)
    local settings = ns.Settings.Effective()
    local modes = settings.groupVisibility
    local mode = type(modes) == "table" and modes[group]
    if mode == "always" or mode == "hover" then return mode end
end

function ns.Settings.AnyBarsAlwaysVisible()
    for _, row in ipairs(ns.BAR_ROWS) do
        if row.id ~= "swing" and ns.Settings.GroupVisibility(ns.Settings.BarGroup(row.id)) == "always" then return true end
    end
    return false
end

function ns.Settings.BarGroup(id)
    local fallback = 1
    for _, row in ipairs(ns.BAR_ROWS) do
        if row.id == id then
            fallback = row.group
            break
        end
    end
    local groups = ns.Settings.Effective().groups
    local n = type(groups) == "table" and groups[id]
    if type(n) ~= "number" or n ~= n then return fallback end
    n = math.floor(n)
    if n < 1 or n > #ns.BAR_ROWS then return fallback end
    return n
end

-- Missing means off. kind is "hostile" or "friendly".
function ns.Settings.BarTarget(id, kind)
    local map = ns.Settings.Effective()[kind]
    return type(map) == "table" and map[id] and true or false
end
