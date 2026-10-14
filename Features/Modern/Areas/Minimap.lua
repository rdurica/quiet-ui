local _, ns = ...

-- Square minimap chrome.  Controls owned by Blizzard (tracking, mail and the
-- queue eye) deliberately stay out of this area.
local Modern = ns.Modern

local function Part(map, name)
    local frame = _G[name]
    if ns.Usable(frame) then return frame end
    if not ns.Usable(map) or not map.GetChildren then return end
    for _, child in ipairs({ map:GetChildren() }) do
        if child.GetName and child:GetName() == name then return child end
    end
end

local function Art(skin, frame)
    if ns.Usable(frame) then skin:Hold(frame) end
end

local function Zoom(skin, map, button)
    if not ns.Usable(button) then return end
    skin:Hold(button)
    local mouse = button.IsMouseEnabled and button:IsMouseEnabled()
    skin:Remember(button, "mouse", function() button:EnableMouse(mouse) end)
    button:EnableMouse(false)
end

local function Wheel(map)
    if not ns.Usable(map) then return end
    local enabled = map.IsMouseWheelEnabled and map:IsMouseWheelEnabled()
    local previous = map.GetScript and map:GetScript("OnMouseWheel")
    return enabled, previous
end

Modern.Register{
    key = "minimap",
    label = "Minimap",
    apply = function(skin)
        local map = Minimap
        if not ns.Usable(map) then return end
        if map.SetMaskTexture then
            local old = map.GetMaskTexture and map:GetMaskTexture() or "Textures\\MinimapMask"
            skin:Remember(map, "mask", function() map:SetMaskTexture(old) end)
            map:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
        end
        Art(skin, Part(map, "MinimapBorder"))
        Art(skin, Part(map, "MinimapNorthTag"))
        Zoom(skin, map, Part(map, "MinimapZoomIn"))
        Zoom(skin, map, Part(map, "MinimapZoomOut"))
        skin:Border(map)
        local strip = skin:Own(map, "zone strip", function()
            local frame = CreateFrame("Frame", nil, map)
            frame:SetHeight(16)
            frame:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 2)
            frame:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 0, 2)
            return frame
        end)
        if ns.Usable(strip) then
            skin:Remember(strip, "shown", function() strip:Hide() end)
            skin:Panel(strip); skin:Border(strip); strip:Show()
            local zone = _G.MinimapZoneText
            if ns.Usable(zone) and zone.SetPoint then skin:Set(zone, "SetPoint", "CENTER", strip, "CENTER", 0, 0) end
        end

        local wheel, old = Wheel(map)
        if map.EnableMouseWheel and map.SetScript then
            skin:Remember(map, "wheel", function()
                map:EnableMouseWheel(wheel)
                map:SetScript("OnMouseWheel", old)
            end)
            map:EnableMouseWheel(true)
            map:SetScript("OnMouseWheel", function(_, delta)
                local zoom = map.GetZoom and map:GetZoom() or 0
                if delta > 0 and zoom < 5 and map.SetZoom then map:SetZoom(zoom + 1) end
                if delta < 0 and zoom > 0 and map.SetZoom then map:SetZoom(zoom - 1) end
            end)
        end

        local shape = GetMinimapShape
        skin:Remember(map, "shape", function()
            GetMinimapShape = shape
            if ns.Setup and ns.Setup.PlaceMinimap then ns.Setup.PlaceMinimap() end
        end)
        GetMinimapShape = function() return "SQUARE" end
        if ns.Setup and ns.Setup.PlaceMinimap then ns.Setup.PlaceMinimap() end
    end,
}
