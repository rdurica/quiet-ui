local _, ns = ...

-- WorldMapFrame: the 12.0 chrome sits on BorderFrame; the canvas and the quest log inside the map
-- (QuestMapFrame) stay untouched. Only the map itself has a title drag handle.
local Modern = ns.Modern

local function Apply(skin)
    local frame = _G.WorldMapFrame
    if not ns.Usable(frame) then return end
    Modern.Window(skin, frame, "WorldMapFrame")
    Modern.WindowChrome(skin, frame.BorderFrame)
end

Modern.Register{ key = "map", label = "Map", apply = Apply, addons = { "Blizzard_WorldMap" } }
