local _, ns = ...

-- The quest tracker (ObjectiveTrackerFrame of the 11.0+ tracker): the "All Objectives" header and each module
-- header (Quests, Campaign, ...) lose their gold banner for a section strip, and their minimize buttons become accent
-- plus / minus signs. Quest blocks, POI buttons, text and the tracker's place stay Blizzard's. Modules are added
-- as the tracker fills, so its Update scans for headers not skinned yet; the hook does nothing while the area is off.

local Modern = ns.Modern

local styled = nil  -- the area journal while applied
local done = setmetatable({}, { __mode = "k" })  -- header -> journal it was skinned with
local hooked = false

local function Header(skin, header)
    if not ns.Usable(header) or done[header] == skin then return end
    done[header] = skin
    Modern.Character.HoldArt(skin, header)
    Modern.Strip(skin, header)
    Modern.Expander(skin, header.MinimizeButton)
end

local function Modules(tracker)
    local list = {}
    if type(tracker.modules) == "table" then
        for _, module in ipairs(tracker.modules) do list[#list + 1] = module end
    end
    for _, child in ipairs(Modern.Character.Children(tracker)) do list[#list + 1] = child end
    return list
end

local function Scan(skin, tracker)
    Header(skin, tracker.Header)
    for _, module in ipairs(Modules(tracker)) do
        if ns.Usable(module) and module ~= tracker.Header and ns.Usable(module.Header) then Header(skin, module.Header) end
    end
end

local function Apply(skin)
    local tracker = _G.ObjectiveTrackerFrame
    if not ns.Usable(tracker) then return end
    styled = skin
    skin:Remember(tracker, "modern tracker", function() styled = nil end)
    Scan(skin, tracker)
    if hooked or type(tracker.Update) ~= "function" then return end
    hooked = pcall(hooksecurefunc, tracker, "Update", function()
        if styled then ns.Profiler.Run("modern tracker", Scan, styled, tracker) end
    end)
end

Modern.Register{
    key = "tracker",
    label = "Quest tracker",
    apply = Apply,
    restore = function()
        for header in pairs(done) do done[header] = nil end
    end,
    addons = { "Blizzard_ObjectiveTracker" },
}
