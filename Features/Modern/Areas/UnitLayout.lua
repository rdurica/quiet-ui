local _, ns = ...

-- Unit frames without portraits: health and power bars take the portrait's space, and the level sits in
-- a small square box at the outer edge, as tall as the bars. Edges are layout numbers, never unit values.
-- Each bar's rect is read once per apply cycle, before anything moves: Blizzard re-anchors target bars
-- on every classification check, and its SetPoint is answered by putting the layout back.

local Modern = ns.Modern

local GAP = 2
local TEXT_POINTS = { TextString = { "CENTER", 0 }, LeftText = { "LEFT", 2 }, RightText = { "RIGHT", -2 } }

local rects = setmetatable({}, { __mode = "k" })  -- bar -> Blizzard rect relative to the frame, this cycle
local laid = setmetatable({}, { __mode = "k" })   -- region -> points held while applied
local hooked = setmetatable({}, { __mode = "k" })
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

local function LevelBox(skin, frame, parts, outer, top, size)
    local box = skin:Own(frame, "level box", function() return frame:CreateTexture(nil, "BACKGROUND") end)
    if not box then return end
    box:ClearAllPoints()
    box:SetPoint(parts.right and "TOPRIGHT" or "TOPLEFT", frame, "BOTTOMLEFT", outer, top)
    box:SetSize(size, size)
    box:SetColorTexture(unpack(Modern.Theme().bg))
    box:Show()
    skin:Border(box, nil, box)
    Ring(skin, parts.level, box)
    Anchor(skin, parts.level, { "CENTER", box, "CENTER", 0, 0 })
    if ns.Usable(parts.skull) then Anchor(skin, parts.skull, { "CENTER", box, "CENTER", 0, 0 }) end
end

-- Target's name overlaps the widened bar where Blizzard put it; every boxed frame gets the same spot.
local function Name(skin, name, health)
    if not ns.Usable(name) or type(name.SetPoint) ~= "function" then return end
    if type(name.SetJustifyH) == "function" then skin:Set(name, "SetJustifyH", "LEFT") end
    Anchor(skin, name, { "BOTTOMLEFT", health, "TOPLEFT", 0, 2 })
end

-- The fill's mask has the old bar size and would clip the widened fill; the texts follow the bar.
local function Contents(skin, bar)
    local fill = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
    if ns.Usable(fill) then Modern.NoMask(skin, fill) end
    for key, spec in pairs(TEXT_POINTS) do
        local text = bar[key]
        if ns.Usable(text) and type(text.SetPoint) == "function" then
            Anchor(skin, text, { spec[1], bar, spec[1], spec[2], 0 })
        end
    end
end

-- parts: health, mana, portrait (still laid out, held at alpha 0), level, skull, name, right (portrait right of bars).
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
    local inset = level and size + GAP or 0
    for _, bar in ipairs({ health, mana }) do
        local rect = bar == health and hr or mr
        local l, r = rect[1], rect[2]
        if parts.right then r = outer - inset else l = outer + inset end
        Anchor(skin, bar, { "TOPLEFT", frame, "BOTTOMLEFT", l, rect[3] }, { "BOTTOMRIGHT", frame, "BOTTOMLEFT", r, rect[4] })
        Contents(skin, bar)
    end
    if not level then return end
    LevelBox(skin, frame, parts, outer, top, size)
    Name(skin, parts.name, health)
end
