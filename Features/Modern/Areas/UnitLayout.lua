local _, ns = ...

-- Unit frames without portraits: health and power bars take the portrait's space. Where the frame has a
-- level, a square as tall as the bars sits at the outer edge: the player's portrait; for target and focus
-- a player's class icon or an NPC's portrait. The level is a small number before the name. Edges are layout numbers, never unit values.
-- Each bar's rect is read once per apply cycle, before anything moves: Blizzard re-anchors target bars
-- on every classification check, and its SetPoint is answered by putting the layout back.

local Modern = ns.Modern

local GAP = 2
local TEXT_POINTS = { TextString = { "CENTER", 0 }, LeftText = { "LEFT", 2 }, RightText = { "RIGHT", -2 } }
local POWER_TEXT = 0.85   -- the power bar is thinner than its value text
local PORTRAIT_CROP = 0.12
local COMBAT_ICON = 0.45  -- of the portrait's side

local rects = setmetatable({}, { __mode = "k" })  -- bar -> Blizzard rect relative to the frame, this cycle
local laid = setmetatable({}, { __mode = "k" })   -- region -> points held while applied
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

local function Pack(...)
    return { n = select("#", ...), ... }
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
    ns.Run("modern unit layout", function()
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

-- Holds the given points on the region; the first call this cycle remembers Blizzard's points.
local function Anchor(skin, region, ...)
    if Locked(region) then return end
    local saved = {}
    for i = 1, region:GetNumPoints() do saved[i] = Pack(region:GetPoint(i)) end
    skin:Remember(region, "points", function()
        laid[region] = nil
        region:ClearAllPoints()
        for _, p in ipairs(saved) do region:SetPoint(unpack(p, 1, p.n)) end
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

-- The ring art around the level: textures anchored to the level text, or the one it is anchored to.
local function Ring(skin, level, box)
    local _, rel = level:GetPoint(1)
    if rel ~= box and IsTexture(rel) then skin:Hold(rel) end
    local parent = type(level.GetParent) == "function" and level:GetParent()
    if not ns.Usable(parent) or type(parent.GetRegions) ~= "function" then return end
    for _, region in ipairs({ parent:GetRegions() }) do
        if region ~= level and region ~= box and IsTexture(region) and type(region.GetPoint) == "function" then
            for i = 1, region:GetNumPoints() do
                if select(2, region:GetPoint(i)) == level then
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

-- The fill's mask has the old bar size and would clip the widened fill; the texts follow the bar.
local function Contents(skin, bar, scale)
    local fill = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
    if ns.Usable(fill) then Modern.NoMask(skin, fill) end
    for key, spec in pairs(TEXT_POINTS) do
        local text = bar[key]
        if ns.Usable(text) and type(text.SetPoint) == "function" then
            Anchor(skin, text, { spec[1], bar, spec[1], spec[2], 0 })
            local base = scale and BaseFont(skin, text)
            if base then Font(skin, text, base[1], base[2] * scale, base[3]) end
        end
    end
end

-- The level is a small number in the name's font left of the name, both just above the health bar.
local function LevelName(skin, parts, box)
    local level, name = parts.level, parts.name
    Ring(skin, level, box)
    local nameFont = ns.Usable(name) and BaseFont(skin, name)
    local base = BaseFont(skin, level)
    if nameFont and base then Font(skin, level, nameFont[1], nameFont[2], base[3]) end
    Anchor(skin, level, { "BOTTOMLEFT", parts.health, "TOPLEFT", 0, 2 })
    if ns.Usable(name) and type(name.SetPoint) == "function" then
        if type(name.SetJustifyH) == "function" then skin:Set(name, "SetJustifyH", "LEFT") end
        Anchor(skin, name, { "BOTTOMLEFT", level, "BOTTOMRIGHT", 3, 0 })
    end
end

-- Without a level (pet, target of target) the name spans the health bar, just above it.
local function BarName(skin, parts)
    local name = parts.name
    if not ns.Usable(name) or type(name.SetPoint) ~= "function" then return end
    if type(name.SetJustifyH) == "function" then skin:Set(name, "SetJustifyH", "LEFT") end
    Anchor(skin, name, { "BOTTOMLEFT", parts.health, "TOPLEFT", 0, 2 }, { "BOTTOMRIGHT", parts.health, "TOPRIGHT", 0, 2 })
end

-- A portrait as a square picture: no round mask, the faded rim cropped.
local function Square(skin, portrait)
    Modern.NoMask(skin, portrait)
    if type(portrait.SetTexCoord) == "function" then
        skin:Set(portrait, "SetTexCoord", PORTRAIT_CROP, 1 - PORTRAIT_CROP, PORTRAIT_CROP, 1 - PORTRAIT_CROP)
    end
end

-- Target and focus: a bordered square where the portrait was. A player shows the class icon on a fill and
-- border in the class colour; an NPC shows its portrait inside the border. The high-level skull sits in it.
local function ColourBox(skin, frame, parts, outer, top, size)
    local box = skin:Own(frame, "level box", function() return frame:CreateTexture(nil, "BACKGROUND") end)
    if not box then return end
    box:ClearAllPoints()
    box:SetPoint(parts.right and "TOPRIGHT" or "TOPLEFT", frame, "BOTTOMLEFT", outer, top)
    box:SetSize(size, size)
    local c = parts.icon and parts.colour or Modern.Theme().bg
    box:SetColorTexture(c[1], c[2], c[3], 1)
    box:Show()
    local icon = skin:Own(frame, "class icon", function() return frame:CreateTexture(nil, "ARTWORK") end)
    if icon and parts.icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
        icon:SetTexture(parts.icon[1])
        icon:SetTexCoord(unpack(parts.icon, 2, 5))
        icon:Show()
    elseif icon then
        icon:Hide()
    end
    skin:Border(box, parts.icon and c or nil, box)
    if parts.inside then
        Square(skin, parts.portrait)
        Anchor(skin, parts.portrait, { "TOPLEFT", box, "TOPLEFT", 1, -1 }, { "BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1 })
    end
    if ns.Usable(parts.skull) then Anchor(skin, parts.skull, { "CENTER", box, "CENTER", 0, 0 }) end
    return box
end

-- The player's portrait: square, unmasked and bordered where the box would be; the combat icon sits in
-- its corner.
local function Portrait(skin, frame, parts, outer, top, size)
    local portrait = parts.portrait
    Square(skin, portrait)
    Anchor(skin, portrait, { "TOPLEFT", frame, "BOTTOMLEFT", outer, top },
        { "BOTTOMRIGHT", frame, "BOTTOMLEFT", outer + size, top - size })
    skin:Border(portrait, nil, portrait)
    local combat = parts.combat
    if ns.Usable(combat) and type(combat.SetPoint) == "function" then
        local side = math.floor(size * COMBAT_ICON + 0.5)
        if type(combat.SetSize) == "function" then skin:Set(combat, "SetSize", side, side) end
        Anchor(skin, combat, { "BOTTOMLEFT", portrait, "BOTTOMLEFT", 1, 1 })
    end
    return portrait
end

-- parts: health, mana, portrait (held at alpha 0 unless shown), shown (the player's portrait stays), level,
-- skull, name, combat (the player's attack icon), colour (the box's { r, g, b }), icon ({ file, l, r, t, b } of
-- a player's class icon), inside (an NPC's portrait shows in the box), right (portrait right of bars).
function Modern.UnitLayout(skin, frame, parts)
    local health, mana, portrait = parts.health, parts.mana, parts.portrait
    if not ns.Usable(health) or not ns.Usable(mana) or not ns.Usable(portrait) then return end
    local fl, fb = frame:GetLeft(), frame:GetBottom()
    if not Numbers(fl, fb) then return end
    local hr, mr, pr = Rect(skin, health, fl, fb), Rect(skin, mana, fl, fb), Rect(skin, portrait, fl, fb)
    if not hr or not mr or not pr or hr[3] <= mr[4] then return end
    local top, size = hr[3], hr[3] - mr[4]
    local outer = parts.right and pr[2] or pr[1]
    local level = ns.Usable(parts.level) and type(parts.level.GetPoint) == "function"
    local inset = (level or parts.shown) and size + GAP or 0
    for _, bar in ipairs({ health, mana }) do
        local rect = bar == health and hr or mr
        -- Both bars share the health bar's inner edge: Blizzard's target power bar is a little wider.
        local l, r = hr[1], hr[2]
        if parts.right then r = outer - inset else l = outer + inset end
        Anchor(skin, bar, { "TOPLEFT", frame, "BOTTOMLEFT", l, rect[3] }, { "BOTTOMRIGHT", frame, "BOTTOMLEFT", r, rect[4] })
        Contents(skin, bar, bar == mana and POWER_TEXT or nil)
    end
    local box
    if parts.shown then box = Portrait(skin, frame, parts, outer, top, size)
    elseif level then box = ColourBox(skin, frame, parts, outer, top, size) end
    if level and box then LevelName(skin, parts, box)
    elseif not level and not parts.shown then BarName(skin, parts) end
end
