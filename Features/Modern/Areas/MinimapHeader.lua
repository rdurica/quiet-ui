local _, ns = ...

-- The 12.0 minimap header (shaped after a frame dump of the Forever client) becomes a band exactly as wide as the
-- square map and joined to its top edge, like a window title row: the tracking magnifier at its left end, the zone
-- name centred, a small calendar page with today's day at its right end. The clock and the addon compartment
-- move to the row under the map, beside the coordinates, so the zone name has room. Blizzard's boxed art is held;
-- every control keeps its size and click. The zone button itself stays where Blizzard put it: the map is docked
-- to it (Minimap.lua).

local Modern = ns.Modern

local BAND = 25
local INSET = 4
local FOOTER = -13     -- centre of the coordinates row under the map
local PAGE = 15        -- calendar page
local DAY_EVERY = 60   -- seconds between checks of today's date
-- The art Blizzard's minimap header buttons draw: the button atlas and its hover copy.
local STATE_KEYS = { "StateTexture", "AddTexture" }
local LENS_ATLAS = "common-search-magnifyingglass"

local glyphs = setmetatable({}, { __mode = "k" })  -- button -> { parts, label } while applied
local hooked = setmetatable({}, { __mode = "k" })
local tickers = setmetatable({}, { __mode = "k" }) -- calendar page -> day ticker while applied

local function Hold(skin, owner, keys)
    if not ns.Usable(owner) then return end
    for _, key in ipairs(keys) do
        if ns.Usable(owner[key]) then skin:Hold(owner[key]) end
    end
end

-- One point instead of Blizzard's; the original points return on undo.
local function Move(skin, frame, ...)
    if not ns.Usable(frame) or type(frame.ClearAllPoints) ~= "function" then return end
    skin:Set(frame, "SetPoint", ...)
    frame:ClearAllPoints()
    frame:SetPoint(...)
end

-- Grey at rest, light under the mouse, like the window glyphs.
local function Paint(button, over)
    local state = glyphs[button]
    if not state then return end
    local theme = Modern.Theme()
    local color = over and theme.text or theme.glyph
    for _, part in ipairs(state.parts) do
        if part.SetVertexColor then part:SetVertexColor(color[1], color[2], color[3], 1) end
    end
    if state.label then state.label:SetTextColor(color[1], color[2], color[3]) end
end

local function Today()
    return tostring(tonumber(date("%d")) or "")
end

local function Hover(button)
    if hooked[button] or type(button.HookScript) ~= "function" then return end
    hooked[button] = true
    for script, over in pairs({ OnEnter = true, OnLeave = false }) do
        pcall(button.HookScript, button, script, function() ns.Profiler.Run("modern minimap", Paint, button, over) end)
    end
end

local function Lens(skin, button)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    local lens = skin:Own(button, "lens", function()
        local texture = button:CreateTexture(nil, "OVERLAY")
        texture:SetSize(12, 12)
        texture:SetPoint("CENTER", button, "CENTER", 0, 0)
        return texture
    end)
    -- Without the atlas Blizzard's art stays.
    if not lens or type(lens.SetAtlas) ~= "function" or not pcall(lens.SetAtlas, lens, LENS_ATLAS) then return end
    Hold(skin, button, STATE_KEYS)
    lens:Show()
    glyphs[button] = { parts = { lens } }
    skin:Remember(button, "modern lens", function() glyphs[button] = nil end)
    Hover(button)
    Paint(button, false)
end

-- A page with a heavier top edge and today's day on it.
local function Calendar(skin, button, font)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    local page, label = unpack(skin:Own(button, "calendar page", function()
        local frame = CreateFrame("Frame", nil, button)
        frame:SetSize(PAGE, PAGE)
        frame:SetPoint("CENTER", button, "CENTER", 0, 0)
        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER", frame, "CENTER", 0, -1)
        return { frame, text }
    end))
    Hold(skin, button, STATE_KEYS)
    local top = skin:Own(page, "top", function()
        local texture = page:CreateTexture(nil, "OVERLAY")
        texture:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        texture:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
        texture:SetHeight(3)
        texture:SetColorTexture(1, 1, 1, 1)
        return texture
    end)
    top:Show()
    skin:Border(page, Modern.Theme().glyph)
    local face = font and font.GetFont and font:GetFont()
    if face then
        label:SetFont(face, 8, "")
    elseif _G.GameFontHighlightSmall then
        label:SetFontObject(_G.GameFontHighlightSmall)
    end
    label:SetText(Today())
    label:Show()
    page:Show()
    glyphs[button] = { parts = { top }, label = label }
    skin:Remember(button, "modern calendar", function() glyphs[button] = nil end)
    Hover(button)
    Paint(button, false)
    -- A slow ticker turns the page after midnight; it stops on undo.
    if tickers[page] or type(C_Timer) ~= "table" or type(C_Timer.NewTicker) ~= "function" then return end
    local ok, ticker = pcall(C_Timer.NewTicker, DAY_EVERY, function()
        if glyphs[button] then label:SetText(Today()) end
    end)
    if not ok or not ticker then return end
    tickers[page] = ticker
    skin:Remember(page, "day ticker", function()
        tickers[page] = nil
        pcall(ticker.Cancel, ticker)
    end)
end

local function Band(skin, cluster, map)
    local band = skin:Own(cluster, "minimap header", function()
        local texture = cluster:CreateTexture(nil, "BACKGROUND", nil, -7)
        texture:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 0)
        texture:SetPoint("BOTTOMRIGHT", map, "TOPRIGHT", 0, 0)
        texture:SetHeight(BAND)
        return texture
    end)
    if not band then return end
    Modern.Band(band)
    band:Show()
    skin:Border(band)
    return band
end

-- The zone name is centred between the magnifier and the calendar and cut only when it still does not fit.
local function ZoneText(skin, header, band)
    local zone = _G.MinimapZoneText
    if not ns.Usable(zone) or type(zone.ClearAllPoints) ~= "function" then return end
    local inner = 2 * INSET + 18
    skin:Set(zone, "SetPoint", "LEFT", header, "LEFT", 0, 0)
    zone:ClearAllPoints()
    zone:SetPoint("RIGHT", band, "RIGHT", -inner, 0)
    zone:SetPoint("LEFT", band, "LEFT", inner, 0)
    if type(zone.GetJustifyH) == "function" then skin:Set(zone, "SetJustifyH", "CENTER") end
    if type(zone.GetWordWrap) == "function" then skin:Set(zone, "SetWordWrap", false) end
end

function Modern.MinimapHeader(skin, cluster, map)
    local header = cluster.ZoneTextButton
    if not ns.Usable(header) then return end
    local band = Band(skin, cluster, map)
    if not band then return end
    Hold(skin, header, STATE_KEYS)
    local tracking, calendar = cluster.Tracking, _G.GameTimeFrame
    if ns.Usable(tracking) then
        Hold(skin, tracking, { "Background" })
        Move(skin, tracking, "LEFT", band, "LEFT", INSET, 0)
        Lens(skin, tracking.Button)
    end
    if ns.Usable(calendar) then
        Move(skin, calendar, "RIGHT", band, "RIGHT", -INSET + 3, 0)
        Calendar(skin, calendar, _G.MinimapZoneText)
    end
    ZoneText(skin, header, band)
    -- The footer row: the addon count at the map's left corner, the clock at its right, coordinates between.
    local compartment = _G.AddonCompartmentFrame
    Hold(skin, compartment, STATE_KEYS)
    Move(skin, compartment, "LEFT", map, "BOTTOMLEFT", -4, FOOTER)
    Move(skin, _G.TimeManagerClockButton, "RIGHT", map, "BOTTOMRIGHT", 3, FOOTER)
end
