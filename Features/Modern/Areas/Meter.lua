local _, ns = ...

-- The damage meter (load-on-demand Blizzard_DamageMeter), shaped after a frame dump of the client: the named
-- DamageMeterSessionWindowN frames and the children of DamageMeter with rows in MinimizeContainer.ScrollBox. The
-- textures a window had when first seen are its chrome and are held, every StatusBar below it (a row) gets the
-- flat theme texture and keeps Blizzard's colour, and the header controls become bare glyphs. Rows are pooled, so
-- the ScrollBox update skins them again; the hook does nothing for a window the area did not skin. Meter values
-- are never read and the window alpha stays owned by the Faders meter rule.

local Modern = ns.Modern

local MAX_DEPTH = 6
local MAX_WINDOWS = 10

local chrome = setmetatable({}, { __mode = "k" })  -- window -> its Blizzard textures, taken before own regions
local styled = setmetatable({}, { __mode = "k" })  -- window -> skin while the area is applied
local hooked = setmetatable({}, { __mode = "k" })

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function IsType(obj, kind)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == kind
end

local function Textures(frame)
    local list = {}
    if type(frame.GetRegions) ~= "function" then return list end
    for _, region in ipairs({ frame:GetRegions() }) do
        if IsTexture(region) then list[#list + 1] = region end
    end
    return list
end

local function ScrollBox(window)
    local container = window.MinimizeContainer
    if ns.Usable(container) and ns.Usable(container.ScrollBox) then return container.ScrollBox end
    if ns.Usable(window.ScrollBox) then return window.ScrollBox end
end

local function IsWindow(frame)
    local name = ns.FrameName(frame)
    return ScrollBox(frame) ~= nil or (type(name) == "string" and name:find("^DamageMeterSessionWindow") ~= nil)
end

local function Windows()
    local list, seen = {}, {}
    local function Add(frame)
        if frame == nil or seen[frame] or not ns.Usable(frame) then return end
        seen[frame] = true
        if IsWindow(frame) then list[#list + 1] = frame end
    end
    for index = 1, MAX_WINDOWS do Add(_G["DamageMeterSessionWindow" .. index]) end
    -- Windows the meter keeps as its own children; UIParent is never scanned.
    local root = _G.DamageMeter
    if ns.Usable(root) and type(root.GetChildren) == "function" then
        for _, child in ipairs({ root:GetChildren() }) do Add(child) end
    end
    return list
end

local function CurrentTexture(bar)
    local fill = bar:GetStatusBarTexture()
    if not ns.Usable(fill) then return end
    local atlas = type(fill.GetAtlas) == "function" and fill:GetAtlas()
    if type(atlas) == "string" and atlas ~= "" then return atlas end
    if type(fill.GetTexture) == "function" then return fill:GetTexture() end
end

-- A row: the theme fill, Blizzard's colour kept; the bar's other textures (its track art) are held.
local function Bar(skin, bar)
    if type(bar.SetStatusBarTexture) ~= "function" or type(bar.GetStatusBarTexture) ~= "function" then return end
    local old = CurrentTexture(bar)
    if old then skin:Remember(bar, "status texture", function() pcall(bar.SetStatusBarTexture, bar, old) end) end
    local color = type(bar.GetStatusBarColor) == "function" and { bar:GetStatusBarColor() } or nil
    bar:SetStatusBarTexture(Modern.Theme().bar)
    if color and #color > 0 then bar:SetStatusBarColor(unpack(color)) end
    local fill = bar:GetStatusBarTexture()
    for _, texture in ipairs(Textures(bar)) do
        if texture ~= fill then skin:Hold(texture) end
    end
    -- The class / spec icon left of the bar loses its rounded edge.
    local row = type(bar.GetParent) == "function" and bar:GetParent()
    local icon = ns.Usable(row) and ns.Usable(row.Icon) and row.Icon.Icon
    if IsTexture(icon) then skin:Icon(icon) end
end

-- The header controls lose their gold square art for bare grey glyphs that turn light under the mouse:
-- a chevron for the meter type, three bars for settings, one bar for minimize. Places and clicks stay.
local function ChevronParts(button)
    return { Modern.GlyphLine(button, 7, 2, -2.5, 0, -45), Modern.GlyphLine(button, 7, 2, 2.5, 0, 45) }
end

local function MenuParts(button)
    return { Modern.GlyphLine(button, 10, 2, 0, 3), Modern.GlyphLine(button, 10, 2, 0, 0),
        Modern.GlyphLine(button, 10, 2, 0, -3) }
end

local function BarParts(button)
    return { Modern.GlyphLine(button, 10, 2, 0, 0) }
end

local function Controls(skin, window)
    local glyph = Modern.Theme().glyph
    local kind = window.DamageMeterTypeDropdown
    if ns.Usable(kind) then
        if IsTexture(kind.Arrow) then skin:Hold(kind.Arrow) end
        Modern.GlyphButton(skin, kind, "meter type", ChevronParts, "text")
    end
    local settings = window.SettingsDropdown
    if ns.Usable(settings) then
        if IsTexture(settings.Icon) then skin:Hold(settings.Icon) end
        Modern.GlyphButton(skin, settings, "meter settings", MenuParts, "text")
    end
    Modern.GlyphButton(skin, window.MinimizeButton, "meter minimize", BarParts, "text")
    local session = window.SessionDropdown
    if ns.Usable(session) then
        for _, key in ipairs({ "Background", "Arrow" }) do
            if IsTexture(session[key]) then skin:Hold(session[key]) end
        end
        if ns.Usable(session.SessionName) then skin:Set(session.SessionName, "SetTextColor", unpack(glyph)) end
    end
    if ns.Usable(window.SessionTimer) then skin:Set(window.SessionTimer, "SetTextColor", unpack(glyph)) end
    local container = window.MinimizeContainer
    if ns.Usable(container) and IsTexture(container.Background) then skin:Hold(container.Background) end
end

local function Rows(skin, frame, depth)
    if depth > MAX_DEPTH or type(frame.GetChildren) ~= "function" then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if IsType(child, "StatusBar") then
            Bar(skin, child)
        elseif ns.Usable(child) then
            Rows(skin, child, depth + 1)
        end
    end
end

local function Watch(window)
    local box = ScrollBox(window)
    if hooked[window] or not ns.Usable(box) or type(box.Update) ~= "function" then return end
    hooked[window] = true
    pcall(hooksecurefunc, box, "Update", function()
        local skin = styled[window]
        if skin then ns.Run("modern meter", Rows, skin, window, 0) end
    end)
end

local function Window(skin, window)
    if not chrome[window] then chrome[window] = Textures(window) end
    if styled[window] ~= skin then
        styled[window] = skin
        for _, texture in ipairs(chrome[window]) do skin:Hold(texture) end
        if ns.Usable(window.Header) then
            for _, texture in ipairs(Textures(window.Header)) do skin:Hold(texture) end
            Modern.Header(skin, window)
        end
        skin:Panel(window)
        skin:Border(window)
        Controls(skin, window)
        Watch(window)
    end
    Rows(skin, window, 0)
end

local function Apply(skin)
    for _, window in ipairs(Windows()) do Window(skin, window) end
end

Modern.Register{
    key = "meter",
    label = "Damage meter",
    apply = Apply,
    restore = function()
        for window in pairs(styled) do styled[window] = nil end
    end,
    addons = { "Blizzard_DamageMeter" },
    -- A window added since the last apply is skinned when combat starts.
    events = { "PLAYER_REGEN_DISABLED" },
    onEvent = Apply,
}
