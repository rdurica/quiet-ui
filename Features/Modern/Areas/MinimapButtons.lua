local _, ns = ...

-- The round buttons around the minimap become small flat plates inside the square map's edge, lit like the header
-- band: QuietUI's setup button, every LibDBIcon button and the day / night dial. Ring, background and glow art is
-- held, the icon stays; every button keeps its click (the dial shrinks to its plate). LibDBIcon places its buttons from one shared radius,
-- which is pulled inside the map while applied and put back on undo.

local Modern = ns.Modern

local PLATE = 22
local ICON = 16
local INSIDE = 14      -- button centre inside the map's edge; Setup/Minimap.lua uses the same
local RING_KEYS = { "border", "background" }
local DAY_ATLAS = "UI-HUD-Minimap-DayCycle"     -- the sky with the sun or moon
local RING_ATLAS = "UI-HUD-Minimap-FrameCycle"   -- the dial's gold ring

local active           -- the skin while applied; LibDBIcon reports buttons created later
local listening
local listener = {}

local function Plate(skin, button)
    local plate = skin:Own(button, "minimap plate", function()
        local texture = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        texture:SetSize(PLATE, PLATE)
        texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        return texture
    end)
    if not plate then return end
    Modern.Band(plate)
    plate:Show()
    skin:Border(plate)
end

local function Icon(skin, icon)
    if not ns.Usable(icon) or type(icon.ClearAllPoints) ~= "function" or type(icon.GetParent) ~= "function" then return end
    skin:Set(icon, "SetSize", ICON, ICON)
    local parent = icon:GetParent()
    skin:Set(icon, "SetPoint", "CENTER", parent, "CENTER", 0, 0)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", parent, "CENTER", 0, 0)
end

local function Flat(skin, button, icon)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    for _, key in ipairs(RING_KEYS) do
        if ns.Usable(button[key]) then skin:Hold(button[key]) end
    end
    if type(button.GetHighlightTexture) == "function" then
        local ok, glow = pcall(button.GetHighlightTexture, button)
        if ok and ns.Usable(glow) then skin:Hold(glow) end
    end
    Plate(skin, button)
    Icon(skin, icon or button.icon)
end

local function Library()
    local stub = _G.LibStub
    if type(stub) ~= "table" or type(stub.GetLibrary) ~= "function" then return nil end
    local ok, lib = pcall(stub.GetLibrary, stub, "LibDBIcon-1.0", true)
    if ok and type(lib) == "table" then return lib end
end

local function Icons(skin)
    local lib = Library()
    if not lib then return end
    if type(lib.objects) == "table" then
        for _, button in pairs(lib.objects) do Flat(skin, button) end
    end
    if type(lib.SetButtonRadius) == "function" and type(lib.radius) == "number" then
        local radius = lib.radius
        skin:Remember(lib, "radius", function() pcall(lib.SetButtonRadius, lib, radius) end)
        pcall(lib.SetButtonRadius, lib, -INSIDE)
    end
    if listening or type(lib.RegisterCallback) ~= "function" then return end
    listening = pcall(lib.RegisterCallback, listener, "LibDBIcon_IconCreated", function(_, button)
        if active then ns.Profiler.Run("modern minimap", Flat, active, button) end
    end)
end

-- WoW Forever's day / night dial: an unnamed child of the container, known by its background atlas.
local function Atlas(region)
    local ok, atlas = pcall(function() return region:GetAtlas() end)
    return ok and atlas or nil
end

-- Returns the dial, its sky and its ring.
local function DayDial(container)
    if type(container.GetChildren) ~= "function" then return nil end
    for _, child in ipairs({ container:GetChildren() }) do
        if ns.Usable(child) and child ~= Minimap and type(child.GetRegions) == "function" then
            local sky, ring
            for _, region in ipairs({ child:GetRegions() }) do
                local atlas = Atlas(region)
                if atlas == DAY_ATLAS then sky = region elseif atlas == RING_ATLAS then ring = region end
            end
            if sky then return child, sky, ring end
        end
    end
end

-- The dial moves into the map's top-right corner, as far inside as the other buttons.
local function Dial(skin, container, map)
    local dial, sky, ring = DayDial(container)
    if not dial or dial:GetNumPoints() ~= 1 then return end
    local point, relative, relativePoint = dial:GetPoint(1)
    if point ~= "CENTER" or relative ~= container or relativePoint ~= "CENTER" then return end
    local offset = map:GetHeight() * (map:GetScale() or 1) / 2 - INSIDE
    skin:Set(dial, "SetPoint", "CENTER", container, "CENTER", offset, offset)
    dial:ClearAllPoints()
    dial:SetPoint("CENTER", container, "CENTER", offset, offset)
    -- Full size, the dial's mouse area would reach over the calendar in the header band.
    skin:Set(dial, "SetSize", PLATE, PLATE)
    if ns.Usable(ring) then skin:Hold(ring) end
    Flat(skin, dial, sky)
end

function Modern.MinimapButtons(skin, map, container)
    active = skin
    skin:Remember(map, "minimap buttons", function() active = nil end)
    local setup = ns.Setup and ns.Setup.MinimapButton and ns.Setup.MinimapButton()
    Flat(skin, setup)
    Icons(skin)
    if ns.Usable(container) then Dial(skin, container, map) end
end

-- QuietUI's setup button is created after boot, often after the area was applied.
function Modern.MinimapButtonCreated(button)
    if active then ns.Profiler.Run("modern minimap", Flat, active, button) end
end
