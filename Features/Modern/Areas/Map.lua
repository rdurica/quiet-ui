local _, ns = ...

-- WorldMapFrame: the 12.0 chrome sits on BorderFrame; the top bar and corner buttons (MapBar) and the quest log
-- inside the map (QuestLog) are restyled, the canvas stays untouched. Only the map itself has a title drag handle.
-- Breadcrumbs, quest headers and the quest details are rebuilt by Blizzard, so they are scanned again after the
-- functions that rebuild them; each hook is set once and does nothing while the area is off.
local Modern = ns.Modern

local styled = nil  -- the area journal while applied
local hooked = {}

local function Parts(skin, map)
    Modern.MapBar.Apply(skin, map)
    Modern.QuestLog.Apply(skin, map.QuestLog or _G.QuestMapFrame)
end

local function Again(fn)
    return function()
        local map = _G.WorldMapFrame
        if styled and ns.Usable(map) then ns.Profiler.Run("modern map", fn, styled, map) end
    end
end

local function Quest(fn)
    return function(skin, map) fn(skin, map.QuestLog or _G.QuestMapFrame) end
end

local function Watch(map)
    local rescans = {
        NavBar_AddButton = function(skin, frame) Modern.MapBar.Breadcrumbs(skin, frame) end,
        QuestLogQuests_Update = Quest(function(skin, quest) Modern.QuestLog.List(skin, quest) end),
        QuestMapFrame_ShowQuestDetails = Quest(function(skin, quest) Modern.QuestLog.Details(skin, quest) end),
    }
    for name, fn in pairs(rescans) do
        if not hooked[name] and type(_G[name]) == "function" then
            hooked[name] = pcall(hooksecurefunc, name, Again(fn))
        end
    end
    if not hooked[map] and type(map.HookScript) == "function" then
        hooked[map] = pcall(map.HookScript, map, "OnShow", Again(Parts))
    end
end

local function Apply(skin)
    local frame = _G.WorldMapFrame
    if not ns.Usable(frame) then return end
    Modern.Window(skin, frame, "WorldMapFrame")
    Modern.Header(skin, frame)
    Modern.WindowChrome(skin, frame.BorderFrame)
    Parts(skin, frame)
    styled = skin
    skin:Remember(frame, "modern map", function() styled = nil end)
    Watch(frame)
end

Modern.Register{ key = "map", label = "Map", apply = Apply, addons = { "Blizzard_WorldMap" } }
