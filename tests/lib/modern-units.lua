-- Unit-frame fixtures shaped like the retail 12.0 (Midnight) Blizzard_UnitFrame XML and Lua:
--   PlayerFrame.PlayerFrameContainer.{FrameTexture, AlternatePowerFrameTexture, VehicleFrameTexture,
--     PlayerPortrait, PlayerPortraitMask, FrameFlash}; PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
--     .{StatusTexture, PlayerLevelText, HealthBarsContainer.HealthBar, ManaBarArea.ManaBar}
--   TargetFrame / FocusFrame .TargetFrameContainer.{FrameTexture, Portrait, PortraitMask, Flash,
--     BossPortraitFrameTexture}; .TargetFrameContent.TargetFrameContentMain.{HealthBarsContainer.HealthBar,
--     ManaBar, ReputationColor, LevelText}
-- The level text sits in a ring texture anchored to it (WoW Forever art, name unknown).
-- The player's combat swords: PlayerFrameContent.PlayerFrameContentContextual.AttackIcon.
--   TargetFrameToT: Portrait, PortraitMask, FrameTexture, HealthBar, ManaBar directly on the frame
--   PetFrame: Portrait / PortraitMask keys; PetFrameTexture, PetFrameFlash, PetFrameHealthBar,
--     PetFrameManaBar as named globals
-- UnitFrame_Initialize adds the lowercase aliases frame.portrait / healthbar / manabar and bar.unitFrame.
-- Blizzard's SetStatusBarTexture is modelled as dropping the bar colour to white (a new texture starts
-- with a white vertex colour), which is the reported "flat texture turns white" failure.
local U = {}

local ATLAS = "UI-HUD-UnitFrame-"

local function texture(parent, atlas, hidden)
    local art = parent:CreateTexture(nil, "ARTWORK")
    art:SetTexture(atlas)
    art:SetAlpha(1)
    if hidden then art:Hide() end
    return art
end

-- Gives a texture one mask with the client's mask API; returns the mask.
local function masked(tex, parent, file)
    local mask = parent:CreateTexture(nil, "ARTWORK")
    mask._kind = "MaskTexture"
    mask:SetTexture(file)
    local masks = { mask }
    function tex:GetNumMaskTextures() return #masks end
    function tex:GetMaskTexture(index) return masks[index] end
    function tex:AddMaskTexture(m) masks[#masks + 1] = m end
    function tex:RemoveMaskTexture(m)
        for i, current in ipairs(masks) do
            if current == m then table.remove(masks, i); return end
        end
    end
    return mask
end

-- 12.0 bars: the fill is clipped by a fixed-size mask (HealthBarMask / ManaBarMask), and the value
-- texts (TextString, LeftText, RightText) belong to the bar's container, anchored to it, not to the bar.
local function bar(parent, atlas, colour)
    local value = CreateFrame("StatusBar", nil, parent)
    value:SetSize(91, 11)
    local fill = value:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(atlas)
    masked(fill, value, atlas .. "-Mask")
    for _, spec in ipairs({ { "TextString", "CENTER" }, { "LeftText", "LEFT" }, { "RightText", "RIGHT" } }) do
        local text = parent:CreateFontString(nil, "OVERLAY")
        text:SetPoint(spec[2], parent, spec[2], 0, 0)
        text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        value[spec[1]] = text
    end
    value._statusColor = colour
    function value:SetStatusBarTexture(v) fill:SetTexture(v); self._statusColor = { 1, 1, 1, 1 } end
    function value:GetStatusBarTexture() return fill end
    function value:SetStatusBarColor(...) self._statusColor = { ... } end
    function value:GetStatusBarColor() return unpack(self._statusColor) end
    return value
end

local function portrait(parent, name)
    local icon = texture(parent, "Interface\\Portrait\\" .. name)
    icon.CreateTexture = nil -- a texture cannot own regions
    return icon, masked(icon, parent, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
end

local function sub(parent) return CreateFrame("Frame", nil, parent) end

local function level(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetText(text)
    label:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    label:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 4, 4)
    local ring = parent:CreateTexture(nil, "BORDER")
    ring:SetTexture("Interface\\LevelRing")
    ring:SetPoint("CENTER", label, "CENTER", 0, 0)
    return label, ring
end

-- Registry of the pieces of each fixture frame, for assertions only.
local parts = setmetatable({}, { __mode = "k" })

local function finish(f, unit, kind, p)
    f.unit, f.frameType = unit, kind
    f.portrait, f.healthbar, f.manabar = p.portrait, p.health, p.mana
    p.health.unitFrame, p.mana.unitFrame = f, f
    p.health.unit, p.mana.unit = unit, unit
    f.Name = f:CreateFontString(nil, "OVERLAY")
    f.Name:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    f:SetSize(232, 100)
    parts[f] = p
    _G[f:GetName()] = f
    return f
end

local function player()
    local f = CreateFrame("Button", "PlayerFrame", UIParent)
    local c = sub(f); f.PlayerFrameContainer = c
    local icon, mask = portrait(c, "Player")
    c.PlayerPortrait, c.PlayerPortraitMask = icon, mask
    c.VehicleFrameTexture = texture(c, ATLAS .. "Player-PortraitOn-Vehicle", true)
    c.FrameTexture = texture(c, ATLAS .. "Player-PortraitOn")
    c.AlternatePowerFrameTexture = texture(c, ATLAS .. "Player-PortraitOn-ClassResource", true)
    c.FrameFlash = texture(c, ATLAS .. "Player-PortraitOn-InCombat", true)
    local content = sub(f); f.PlayerFrameContent = content
    local main = sub(content); content.PlayerFrameContentMain = main
    main.StatusTexture = texture(main, ATLAS .. "Player-PortraitOn-Status")
    local lvl, ring = level(main, "20"); main.PlayerLevelText = lvl
    local contextual = sub(content); content.PlayerFrameContentContextual = contextual
    contextual.AttackIcon = texture(contextual, ATLAS .. "Player-CombatIcon", true)
    contextual.AttackIcon:SetSize(24, 24)
    contextual.AttackIcon:SetPoint("TOPLEFT", lvl, "BOTTOMLEFT", 0, -2)
    local hb = sub(main); main.HealthBarsContainer = hb
    hb.HealthBar = bar(hb, ATLAS .. "Player-PortraitOn-Bar-Health", { 0, 1, 0, 1 })
    hb.HealthBar:SetPoint("TOPLEFT", hb, "TOPLEFT", 85, -26)
    local area = sub(main); main.ManaBarArea = area
    area.ManaBar = bar(area, ATLAS .. "Player-PortraitOn-Bar-Mana", { 1, 1, 1, 1 })
    area.ManaBar:SetPoint("TOPLEFT", area, "TOPLEFT", 85, -47)
    return finish(f, "player", "Player", { portrait = icon, mask = mask, health = hb.HealthBar, mana = area.ManaBar,
        art = { c.FrameTexture, c.AlternatePowerFrameTexture, c.VehicleFrameTexture, c.FrameFlash, main.StatusTexture },
        flash = c.FrameFlash, status = main.StatusTexture, level = lvl, ring = ring,
        combat = contextual.AttackIcon })
end

local function target(name, unit)
    local f = CreateFrame("Button", name, UIParent)
    local c = sub(f); f.TargetFrameContainer = c
    local icon, mask = portrait(c, "Target")
    c.Portrait, c.PortraitMask = icon, mask
    c.FrameTexture = texture(c, ATLAS .. "Target-PortraitOn")
    c.Flash = texture(c, ATLAS .. "Target-PortraitOn-InCombat", true)
    c.BossPortraitFrameTexture = texture(c, ATLAS .. "Target-PortraitOn-Boss-Gold", true)
    local content = sub(f); f.TargetFrameContent = content
    local main = sub(content); content.TargetFrameContentMain = main
    main.ReputationColor = texture(main, ATLAS .. "Target-PortraitOn-Type")
    local lvl, ring = level(main, "21"); main.LevelText = lvl
    local hb = sub(main); main.HealthBarsContainer = hb
    hb.HealthBar = bar(hb, ATLAS .. "Target-PortraitOn-Bar-Health", { 0, 1, 0, 1 })
    main.ManaBar = bar(main, ATLAS .. "Target-PortraitOn-Bar-Mana", { 1, 1, 1, 1 })
    return finish(f, unit, "Target", { portrait = icon, mask = mask, health = hb.HealthBar, mana = main.ManaBar,
        art = { c.FrameTexture, c.Flash, c.BossPortraitFrameTexture, main.ReputationColor },
        flash = c.Flash, boss = c.BossPortraitFrameTexture, level = lvl, ring = ring })
end

local function tot()
    local f = CreateFrame("Button", "TargetFrameToT", UIParent)
    f.Portrait, f.PortraitMask = portrait(f, "ToT")
    f.FrameTexture = texture(f, ATLAS .. "TargetofTarget-PortraitOn")
    f.HealthBar = bar(f, ATLAS .. "Party-PortraitOn-Bar-Health", { 0, 1, 0, 1 })
    f.ManaBar = bar(f, ATLAS .. "Party-PortraitOn-Bar-Mana", { 1, 1, 1, 1 })
    return finish(f, "targettarget", "TargetofTarget", { portrait = f.Portrait, mask = f.PortraitMask,
        health = f.HealthBar, mana = f.ManaBar, art = { f.FrameTexture } })
end

local function pet()
    local f = CreateFrame("Button", "PetFrame", UIParent)
    f.Portrait, f.PortraitMask = portrait(f, "Pet")
    PetPortrait = f.Portrait
    PetFrameTexture = texture(f, ATLAS .. "TargetofTarget-PortraitOn")
    PetFrameFlash = texture(f, ATLAS .. "TargetofTarget-PortraitOn-InCombat", true)
    PetFrameHealthBar = bar(f, ATLAS .. "Party-PortraitOn-Bar-Health", { 0, 1, 0, 1 })
    PetFrameManaBar = bar(f, ATLAS .. "Party-PortraitOn-Bar-Mana", { 1, 1, 1, 1 })
    return finish(f, "pet", "TargetofTarget", { portrait = f.Portrait, mask = f.PortraitMask,
        health = PetFrameHealthBar, mana = PetFrameManaBar, art = { PetFrameTexture, PetFrameFlash },
        flash = PetFrameFlash })
end

-- Blizzard's UnitFrameManaBar_UpdateType (global): atlas texture and a white bar colour.
local function installBlizzard()
    function UnitFrameManaBar_UpdateType(mana)
        mana:SetStatusBarTexture(ATLAS .. "Target-PortraitOn-Bar-Mana")
        mana:SetStatusBarColor(1, 1, 1)
    end
end

function U.frames()
    installBlizzard()
    return { player(), pet(), target("TargetFrame", "target"), tot(), target("FocusFrame", "focus") }
end

function U.parts(frame) return parts[frame._frame or frame] end

-- Public fixture surface for the generic registry contract. The registry reads player.HealthBar and
-- calls U.hidden / U.statusTexture; a shim exposes that one key without adding it to the real frame.
function U.fixture()
    local frames = U.frames()
    local function shim(f) return { _frame = f, HealthBar = parts[f].health } end
    return { frames = frames, player = shim(frames[1]), pet = frames[2], target = frames[3],
        targetTarget = frames[4], focus = frames[5] }
end

-- Blizzard shows a boss / elite dragon around the portrait when the target changes.
function U.blizzardBossFrame(frame, kind)
    local art = U.parts(frame).boss
    if kind == "elite" or kind == "rareelite" or kind == "worldboss" then art:Show() else art:Hide() end
end

function U.hidden(frame)
    for _, art in ipairs(U.parts(frame).art) do
        if art:GetAlpha() ~= 0 then return false end
    end
    return true
end

function U.artAlpha(frame)
    local list = {}
    for _, art in ipairs(U.parts(frame).art) do list[#list + 1] = art:GetAlpha() end
    return list
end

local function walk(node, fn)
    fn(node)
    for _, r in ipairs(node._regions or {}) do fn(r) end
    for _, child in ipairs(node._children or {}) do walk(child, fn) end
end

local function edges(owner, anchor)
    local list = {}
    walk(owner, function(r)
        if (r._layer == "BORDER" or r._layer == "OVERLAY") and r._shown then
            for _, point in ipairs(r._points) do
                if anchor == nil or point[2] == anchor then list[#list + 1] = r; break end
            end
        end
    end)
    return list
end

-- The square QuietUI draws where a target or focus portrait was: a shown square background fill on the frame.
function U.levelBox(frame)
    for _, r in ipairs(frame._regions or {}) do
        if r._layer == "BACKGROUND" and r._shown and r._color and r._w == r._h then return r end
    end
end

-- The class icon QuietUI shows in that square for a player unit.
function U.classIcon(frame)
    for _, r in ipairs(frame._regions or {}) do
        if r._layer == "ARTWORK" and r._shown and type(r._texture) == "string" and r._texture:find("CLASSES") then
            return r
        end
    end
end

function U.border(bar) return #edges(bar, bar) >= 4 end

function U.onePixel(bar)
    local list = edges(bar, bar)
    for _, r in ipairs(list) do
        if r._w ~= 1 and r._h ~= 1 then return false end
    end
    return #list >= 4
end

-- Colour of the border drawn on a bar's edges.
function U.borderColor(bar)
    for _, r in ipairs(edges(bar, bar)) do
        if r._color then return r._color end
    end
end

-- A copy of a region's anchor list, for comparing before and after.
function U.points(region)
    local list = {}
    for i = 1, region:GetNumPoints() do list[i] = { region:GetPoint(i) } end
    return list
end

function U.panel(bar)
    for _, region in ipairs(bar._regions) do
        if region._layer == "BACKGROUND" and region._shown and region._color then return true end
    end
    return false
end

function U.rgb(bar)
    return bar._statusColor[1], bar._statusColor[2], bar._statusColor[3]
end

function U.colour(bar)
    return bar._statusColor[1], bar._statusColor[2], bar._statusColor[3], bar._statusColor[4]
end

function U.statusTexture(bar)
    local tex = bar:GetStatusBarTexture()
    return tex and tex:GetTexture()
end

-- Retail unit API shapes used by the colour tests.
function U.installColours(mock, powerTokens)
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    C_ClassColor = { GetClassColor = function(token) return RAID_CLASS_COLORS[token] end }
    UnitClass = function() return "Mage", "MAGE", 8 end
    -- UnitReaction needs two units on the real client; one argument gives nil.
    UnitReaction = function(a, b) if a and b then return 2 end end
    FACTION_BAR_COLORS = { [2] = { r = 0.8, g = 0.1, b = 0.1 }, [5] = { r = 0.2, g = 0.8, b = 0.2 } }
    PowerBarColor = { MANA = { r = 0, g = 0, b = 1 }, RAGE = { r = 1, g = 0, b = 0 },
        ENERGY = { r = 1, g = 1, b = 0 } }
    powerTokens = powerTokens or {}
    UnitPowerType = function(unit) local token = powerTokens[unit] or "MANA"; return 0, token end
    return powerTokens
end

-- Health and power are secret: any comparison or arithmetic raises.
function U.secrets(mock)
    local function boom() error("secret value was inspected", 2) end
    local strict = { __lt = boom, __le = boom, __add = boom, __sub = boom, __mul = boom,
        __div = boom, __unm = boom, __concat = boom, __len = boom }
    local function secret(v)
        local box = setmetatable({ value = v }, strict)
        mock.secrets[box] = true
        return box
    end
    UnitHealth, UnitHealthMax = function() return secret(50) end, function() return secret(100) end
    UnitPower, UnitPowerMax = function() return secret(5) end, function() return secret(10) end
    UnitHealthPercent = function() return secret(0.5) end
    UnitPowerPercent = function() return secret(0.5) end
    return secret
end

return U
