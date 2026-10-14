local _, ns = ...

local Modern = ns.Modern

local function Apply(skin)
    local frame = _G.WorldMapFrame
    if not ns.Usable(frame) then return end
    skin:Panel(frame)
    skin:Border(frame)
    Modern.WindowChrome(skin, frame)
    skin:Remember(frame, "modern movable", function() Modern.ReleaseMovable(frame) end)
    Modern.MakeMovable(frame, "WorldMapFrame")
end

Modern.Register{ key = "map", label = "Map", apply = Apply, addons = { "Blizzard_WorldMap" } }
