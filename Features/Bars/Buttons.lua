local _, ns = ...
local Bars = ns.Bars
local S = Bars.state

-- Buttons of a bar: own buttons, deeper pressables, and the texture regions that follow them.
-- Lists are cached per bar until Bars.ForgetButtons.

local BUTTON_PREFIX = {
    MainMenuBar = "ActionButton",
    MainActionBar = "ActionButton",
    MultiBarBottomLeft = "MultiBarBottomLeftButton",
    MultiBarBottomRight = "MultiBarBottomRightButton",
    MultiBarRight = "MultiBarRightButton",
    MultiBarLeft = "MultiBarLeftButton",
    MultiBar5 = "MultiBar5Button",
    MultiBar6 = "MultiBar6Button",
    MultiBar7 = "MultiBar7Button",
    StanceBar = "StanceButton",
    StanceBarFrame = "StanceButton",
    ShapeshiftBarFrame = "ShapeshiftButton",
    PetActionBar = "PetActionButton",
    PetActionBarFrame = "PetActionButton",
}
S.BUTTON_PREFIX = BUTTON_PREFIX

local owner = S.owner

local function LeaveAlone(frame)
    if Bars.IsBagRelated(frame) then return true end
    local name = ns.FrameName(frame)
    return name ~= nil and name:find("Micro") ~= nil
end

local function EachOwnButton(bar, fn)
    local seen = {}
    local function consider(button)
        if not ns.Usable(button) or seen[button] or LeaveAlone(button) or S.UnderOther(button, bar) then return end
        seen[button] = true
        fn(button)
    end
    local buttons = bar.actionButtons or bar.buttons
    if type(buttons) == "table" then
        for _, child in ipairs(buttons) do
            consider(child)
        end
    end
    local prefix = BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if prefix then
        for i = 1, 12 do
            consider(_G[prefix .. i])
        end
    end
end

local function IsPressable(frame)
    if not ns.Usable(frame) or not frame.GetObjectType then return false end
    local ok, kind = pcall(frame.GetObjectType, frame)
    return ok and (kind == "Button" or kind == "CheckButton")
end

local function EachDeepButton(bar, fn, depth)
    depth = depth or 0
    if depth > 4 or not ns.Usable(bar) or not bar.GetChildren then return end
    for _, child in ipairs({ bar:GetChildren() }) do
        if ns.Usable(child) and not owner[child] and not LeaveAlone(child) then
            if IsPressable(child) then
                if not S.UnderOther(child, bar) then
                    fn(child)
                end
            else
                EachDeepButton(child, fn, depth + 1)
            end
        end
    end
end


local function RememberButtons(bar, list, deep)
    local seen = {}
    local function add(button)
        if seen[button] then return end
        seen[button] = true
        list[#list + 1] = button
    end
    EachOwnButton(bar, add)
    if deep then EachDeepButton(bar, add) end
end

function S.ButtonsFor(bar, deep)
    local cache = deep and S.deepCache or S.buttonCache
    local list = cache[bar]
    if list then return list end
    list = {}
    cache[bar] = list
    RememberButtons(bar, list, deep)
    return list
end

function S.RegionsFor(bar)
    local list = S.regionCache[bar]
    if list then return list end
    list = {}
    S.regionCache[bar] = list
    if not bar.GetRegions then return list end
    for _, region in ipairs({ bar:GetRegions() }) do
        if region and region.SetAlpha and region.GetObjectType then
            local ok, kind = pcall(region.GetObjectType, region)
            if ok and kind == "Texture" then
                list[#list + 1] = region
            end
        end
    end
    return list
end
