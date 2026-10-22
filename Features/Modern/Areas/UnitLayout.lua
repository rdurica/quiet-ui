local _, ns = ...

-- Unit frames as one compact bar: no portrait, one dark box with a 1 px border takes the portrait's space;
-- the health bar fills it and the power bar is a thin line along its bottom. Target, focus and boss keep
-- Blizzard's health bar where it stands, the box around it. The value sits in the health
-- bar; name and level sit above the box, the player shows neither. Edges are layout numbers, never unit values.
-- Each bar's rect is read once per apply cycle, before anything moves: Blizzard re-anchors target bars
-- on every classification check, and its SetPoint is answered by putting the layout back.

local Modern = ns.Modern

local BOX_HEIGHT = 28     -- the box on frames with a level (and the player's)
local SMALL_HEIGHT = 18   -- on pet and target of target
local INSET = 1           -- the box border
local POWER_HEIGHT = 4    -- a thin line, too small for its value text
local POWER_GAP = 1       -- dark line between health and power
local BAR_TEXT = 12       -- value text size; Blizzard's is too small to read
local TEXT_POINTS = { TextString = { "CENTER", 0 }, LeftText = { "LEFT", 4 }, RightText = { "RIGHT", -4 } }
local NAME_GAP = 3        -- between the health bar's top and the name
local COMBAT_ICON = 16
local CLASS_ICON = 14     -- the class icon before a player target's level

local rects = setmetatable({}, { __mode = "k" })  -- bar -> Blizzard rect relative to the frame, this cycle
local laid = setmetatable({}, { __mode = "k" })   -- region -> points held while applied
local blizzard = setmetatable({}, { __mode = "k" }) -- region -> Blizzard's points, last read while not laid out
local fallback = setmetatable({}, { __mode = "k" }) -- region -> points to restore when none could be read
local hooked = setmetatable({}, { __mode = "k" })
local fonts = setmetatable({}, { __mode = "k" })  -- font string -> Blizzard font, while applied
local busy = false

local function Numbers(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) ~= "number" or ns.IsSecret(v) then return false end
    end
    return true
end

-- Bars are plain StatusBars; the client may still protect one, which then waits for combat to end.
local function Locked(region)
    if type(InCombatLockdown) ~= "function" or not InCombatLockdown() then return false end
    return type(region.IsProtected) ~= "function" or region:IsProtected() and true or false
end

local function Place(region)
    local points = laid[region]
    if not points or busy or Locked(region) then return end
    busy = true
    ns.Profiler.Run("modern unit layout", function()
        region:ClearAllPoints()
        for _, p in ipairs(points) do region:SetPoint(unpack(p, 1, 5)) end
    end)
    busy = false
end

local function Hook(region)
    if hooked[region] or type(hooksecurefunc) ~= "function" then return end
    hooked[region] = true
    pcall(hooksecurefunc, region, "SetPoint", function() Place(region) end)
    pcall(hooksecurefunc, region, "SetAllPoints", function() Place(region) end)
end

-- Holds the given points on the region; the first call this cycle remembers Blizzard's points. The client
-- does not always give a value text's points back (its value is secret), so the last readable ones are kept,
-- and without any the region's fallback is restored.
local function Anchor(skin, region, ...)
    if Locked(region) then return end
    if not laid[region] then blizzard[region] = Modern.Points(region) or blizzard[region] end
    local saved = blizzard[region] or fallback[region]
    if not saved then return end
    skin:Remember(region, "points", function()
        laid[region] = nil
        Modern.SetPoints(region, saved)
    end)
    laid[region] = { ... }
    Hook(region)
    Place(region)
end

-- Left, right, top, bottom relative to the frame's bottom left corner, read once per cycle.
local function Rect(skin, region, fl, fb)
    if rects[region] then return rects[region] end
    local l, r, t, b = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
    if not Numbers(l, r, t, b) then return end
    rects[region] = { l - fl, r - fl, t - fb, b - fb }
    skin:Remember(region, "rect", function() rects[region] = nil end)
    return rects[region]
end

local function IsTexture(region)
    return ns.Usable(region) and type(region.GetObjectType) == "function" and region:GetObjectType() == "Texture"
end

-- The ring art around the level: textures anchored to the level text, or the one it is anchored to. Our
-- own class icon is skipped: once laid out, the level is anchored to it.
local function Ring(skin, level, own)
    local _, rel = level:GetPoint(1)
    if rel ~= own and IsTexture(rel) then skin:Hold(rel) end
    local parent = type(level.GetParent) == "function" and level:GetParent()
    if not ns.Usable(parent) or type(parent.GetRegions) ~= "function" then return end
    for _, region in ipairs({ parent:GetRegions() }) do
        if region ~= level and region ~= own and IsTexture(region) and type(region.GetPoint) == "function" then
            for _, point in ipairs(Modern.Points(region) or {}) do
                if point[2] == level then
                    skin:Hold(region)
                    break
                end
            end
        end
    end
end

-- Blizzard's font, read once while applied, so applying again does not shrink it further.
local function BaseFont(skin, text)
    if fonts[text] then return fonts[text] end
    if type(text.GetFont) ~= "function" or type(text.SetFont) ~= "function" then return end
    local ok, face, size, flags = pcall(text.GetFont, text)
    if not ok or type(face) ~= "string" or type(size) ~= "number" then return end
    fonts[text] = { face, size, flags }
    skin:Remember(text, "base font", function() fonts[text] = nil end)
    return fonts[text]
end

local function Font(skin, text, face, size, flags)
    if type(text.SetFont) ~= "function" or not BaseFont(skin, text) then return end
    skin:Set(text, "SetFont", face, math.max(1, math.floor(size + 0.5)), flags)
end

-- Blizzard's outline fills the digits in on a light fill; a drop shadow keeps them open.
local function Unoutlined(flags)
    if type(flags) ~= "string" then return "" end
    return (flags:gsub("THICKOUTLINE", ""):gsub("OUTLINE", ""):gsub("^[%s,]+", ""):gsub("[%s,]+$", ""))
end

local function Shadow(skin, text)
    if type(text.GetShadowOffset) == "function" then skin:Set(text, "SetShadowOffset", 1, -1) end
    if type(text.GetShadowColor) == "function" then skin:Set(text, "SetShadowColor", 0, 0, 0, 1) end
end

-- The fill's mask has the old bar size and would clip the widened fill. Health texts follow the bar, at
-- BAR_TEXT points in Blizzard's face, without outline and with a shadow; the thin power bar holds its own.
local function Contents(skin, bar, thin)
    local fill = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
    if ns.Usable(fill) then Modern.NoMask(skin, fill) end
    for key, spec in pairs(TEXT_POINTS) do
        local text = bar[key]
        if ns.Usable(text) and thin then
            skin:Hold(text)
        elseif ns.Usable(text) and type(text.SetPoint) == "function" then
            local parent = type(text.GetParent) == "function" and text:GetParent() or bar
            fallback[text] = { { spec[1], parent, spec[1], 0, 0, n = 5 } }
            Anchor(skin, text, { spec[1], bar, spec[1], spec[2], 0 })
            local base = BaseFont(skin, text)
            if base then Font(skin, text, base[1], BAR_TEXT, Unoutlined(base[3])) end
            Shadow(skin, text)
        end
    end
end

local function Movable(region)
    return ns.Usable(region) and type(region.SetPoint) == "function" and type(region.GetPoint) == "function"
end

-- A player target's class icon at the box's left end; hidden for an NPC. Returns it while shown.
local function Icon(skin, frame, parts)
    local icon = skin:Own(frame, "class icon", function() return frame:CreateTexture(nil, "ARTWORK") end)
    if not icon then return end
    if not parts.icon then
        icon:Hide()
        return
    end
    icon:ClearAllPoints()
    icon:SetPoint("BOTTOMLEFT", parts.health, "TOPLEFT", -INSET, NAME_GAP + INSET)
    icon:SetSize(CLASS_ICON, CLASS_ICON)
    icon:SetTexture(parts.icon[1])
    icon:SetTexCoord(unpack(parts.icon, 2, 5))
    icon:Show()
    return icon
end

-- Target and focus: a player's class icon, the level in the name's font, then the name, above the health
-- bar's left end. The high-level skull takes the level's place. Without a level (pet, target of target) the
-- name starts there.
local function Labels(skin, frame, parts)
    local health, level, name = parts.health, parts.level, parts.name
    local start = { "BOTTOMLEFT", health, "TOPLEFT", 0, NAME_GAP + INSET }
    local icon = parts.right and Icon(skin, frame, parts)
    if icon then start = { "LEFT", icon, "RIGHT", 3, 0 } end
    local after = start
    if Movable(level) then
        Ring(skin, level, skin:Own(frame, "class icon", function() return frame:CreateTexture(nil, "ARTWORK") end))
        local nameFont = ns.Usable(name) and BaseFont(skin, name)
        local base = BaseFont(skin, level)
        if nameFont and base then Font(skin, level, nameFont[1], nameFont[2], base[3]) end
        Anchor(skin, level, start)
        if Movable(parts.skull) then Anchor(skin, parts.skull, { "CENTER", level, "CENTER", 0, 0 }) end
        after = { "BOTTOMLEFT", level, "BOTTOMRIGHT", 3, 0 }
    end
    if not Movable(name) then return end
    if type(name.SetJustifyH) == "function" then skin:Set(name, "SetJustifyH", "LEFT") end
    Anchor(skin, name, after, { "BOTTOMRIGHT", health, "TOPRIGHT", 0, NAME_GAP + INSET })
end

-- The player knows their own name and level; the combat icon sits small above the bar's left end.
local function PlayerLabels(skin, parts)
    for _, text in ipairs({ parts.name, parts.level }) do
        if ns.Usable(text) then skin:Hold(text) end
    end
    if Movable(parts.level) then Ring(skin, parts.level) end
    local combat = parts.combat
    if not Movable(combat) then return end
    if type(combat.SetSize) == "function" then skin:Set(combat, "SetSize", COMBAT_ICON, COMBAT_ICON) end
    Anchor(skin, combat, { "BOTTOMLEFT", parts.health, "TOPLEFT", -INSET, NAME_GAP + INSET })
end

-- The dark box behind both bars, with the 1 px border in the theme or the target's rarity colour. Box and
-- power bar hang on the health bar, so they stay with it wherever Blizzard puts it.
local function Box(skin, frame, parts)
    local box = skin:Own(frame, "bar box", function() return frame:CreateTexture(nil, "BACKGROUND") end)
    if not box then return end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", parts.health, "TOPLEFT", -INSET, INSET)
    box:SetPoint("BOTTOMRIGHT", parts.health, "BOTTOMRIGHT", INSET, -(INSET + POWER_HEIGHT + POWER_GAP))
    box:SetColorTexture(unpack(Modern.Theme().bg))
    box:Show()
    skin:Border(frame, parts.border, box)
end

-- parts: health, mana, portrait (held at alpha 0 by the caller), right (portrait right of the bars),
-- player (no name or level, the combat icon instead), border (box border colour), icon ({ file, l, r, t, b }
-- of a player target's class icon), level, skull, name, combat.
function Modern.UnitLayout(skin, frame, parts)
    local health, mana, portrait = parts.health, parts.mana, parts.portrait
    if not ns.Usable(health) or not ns.Usable(mana) or not ns.Usable(portrait) then return end
    local fl, fb = frame:GetLeft(), frame:GetBottom()
    if not Numbers(fl, fb) then return end
    local hr, pr = Rect(skin, health, fl, fb), Rect(skin, portrait, fl, fb)
    if not hr or not pr then return end
    Box(skin, frame, parts)
    if not parts.right then
        -- The box reaches from the portrait's outer edge to the health bar's far edge, up from its bottom.
        -- Target, focus and boss keep Blizzard's health bar: Blizzard puts it back on its own point and size
        -- on a target change in combat, while it is protected.
        local l, r = pr[1], hr[2]
        local bottom = hr[4]
        local top = bottom + ((parts.player or Movable(parts.level)) and BOX_HEIGHT or SMALL_HEIGHT)
        Anchor(skin, health, { "TOPLEFT", frame, "BOTTOMLEFT", l + INSET, top - INSET },
            { "BOTTOMRIGHT", frame, "BOTTOMLEFT", r - INSET, bottom + INSET + POWER_HEIGHT + POWER_GAP })
    end
    Anchor(skin, mana, { "TOPLEFT", health, "BOTTOMLEFT", 0, -POWER_GAP },
        { "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, -(POWER_GAP + POWER_HEIGHT) })
    Contents(skin, health)
    Contents(skin, mana, true)
    if parts.player then PlayerLabels(skin, parts) else Labels(skin, frame, parts) end
end
