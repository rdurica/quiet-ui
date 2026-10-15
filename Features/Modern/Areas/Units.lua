local _, ns = ...

-- Unit frames (retail 12.0 structure, with the older flat names as fallbacks). Frame art is held,
-- bars get the theme texture, a background and a border, and Blizzard's own bar updates are
-- followed by a repaint of the colour. Hooks only act on bars that are tracked, so they are
-- inert while the area is off. Health and power values are never read.

local Modern = ns.Modern

local FRAMES = {
    { "PlayerFrame", "player" }, { "PetFrame", "pet" }, { "TargetFrame", "target" },
    { "TargetFrameToT", "targettarget" }, { "FocusFrame", "focus" },
}

-- Places a part can live, relative to the unit frame.
local ART_ROOTS = { "", "PlayerFrameContainer", "TargetFrameContainer",
    "PlayerFrameContent.PlayerFrameContentMain", "TargetFrameContent.TargetFrameContentMain" }
local ART_NAMES = { "FrameTexture", "AlternatePowerFrameTexture", "VehicleFrameTexture", "FrameFlash", "Flash",
    "BossPortraitFrameTexture", "ReputationColor", "Border", "EliteTexture", "PortraitFrame" }
local ART_GLOBALS = { "Texture", "Flash" }
local HEALTH_PATHS = { "healthbar", "HealthBar", "healthBar",
    "PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar",
    "TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar" }
local POWER_PATHS = { "manabar", "ManaBar", "manaBar", "PowerBar", "powerBar",
    "PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar",
    "TargetFrameContent.TargetFrameContentMain.ManaBar" }
local PORTRAIT_PATHS = { "portrait", "Portrait", "PlayerFrameContainer.PlayerPortrait", "TargetFrameContainer.Portrait" }

local GREEN = { 0.2, 0.8, 0.2 }
local RARE = { 0.85, 0.85, 0.85, 1 }
local BOSS = { 0.9, 0.15, 0.15, 1 }

local tracked = setmetatable({}, { __mode = "k" }) -- bar -> { unit, kind, texture, busy } while applied
local hooked = setmetatable({}, { __mode = "k" })
local hookedUpdate

local function Dig(root, path)
    local node = root
    for key in path:gmatch("[^.]+") do
        if not ns.Usable(node) then return end
        node = node[key]
    end
    return node
end

local function Find(frame, paths, globalName)
    for _, path in ipairs(paths) do
        local node = Dig(frame, path)
        if ns.Usable(node) then return node end
    end
    local node = globalName and _G[globalName]
    if ns.Usable(node) then return node end
end

local function Colours(color)
    if type(color) ~= "table" then return end
    return color.r or color[1], color.g or color[2], color.b or color[3]
end

local function HealthColour(unit)
    if not ns.Settings.ModernClassColors() then return unpack(GREEN) end
    local r, g, b
    if type(UnitIsPlayer) == "function" and UnitIsPlayer(unit) then
        local token
        if type(UnitClass) == "function" then token = select(2, UnitClass(unit)) end
        local c = type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function"
            and C_ClassColor.GetClassColor(token)
        r, g, b = Colours(c or (type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[token]))
    elseif type(UnitReaction) == "function" and type(FACTION_BAR_COLORS) == "table" then
        local reaction = UnitReaction(unit, "player") or UnitReaction(unit)
        r, g, b = Colours(FACTION_BAR_COLORS[reaction])
    end
    if r and g and b then return r, g, b end
    return unpack(GREEN)
end

local function PowerColour(unit)
    if type(UnitPowerType) ~= "function" or type(PowerBarColor) ~= "table" then return end
    local kind, token = UnitPowerType(unit)
    return Colours(PowerBarColor[token] or PowerBarColor[kind])
end

-- Puts the theme texture (after Blizzard changed it) and the wanted colour back on a tracked bar.
local function Paint(bar, retexture)
    local info = tracked[bar]
    if not info or info.busy then return end
    info.busy = true
    ns.Run("modern units", function()
        if retexture then bar:SetStatusBarTexture(info.texture) end
        local r, g, b
        if info.kind == "health" then r, g, b = HealthColour(info.unit) else r, g, b = PowerColour(info.unit) end
        if r and g and b then bar:SetStatusBarColor(r, g, b, 1) end
    end)
    info.busy = nil
end

local function CurrentTexture(bar)
    local fill = bar:GetStatusBarTexture()
    if not ns.Usable(fill) then return end
    local atlas = type(fill.GetAtlas) == "function" and fill:GetAtlas()
    if type(atlas) == "string" and atlas ~= "" then return atlas end
    if type(fill.GetTexture) == "function" then return fill:GetTexture() end
end

local function Hook(bar)
    if hooked[bar] or type(hooksecurefunc) ~= "function" then return end
    hooked[bar] = true
    pcall(hooksecurefunc, bar, "SetStatusBarColor", function() Paint(bar, false) end)
    pcall(hooksecurefunc, bar, "SetStatusBarTexture", function(_, texture)
        local info = tracked[bar]
        if info and texture ~= info.texture then Paint(bar, true) end
    end)
end

-- Blizzard re-types the power bar (texture and colour) when the power type changes.
local function HookUpdate()
    local update = _G.UnitFrameManaBar_UpdateType
    if type(update) ~= "function" or update == hookedUpdate then return end
    if pcall(hooksecurefunc, "UnitFrameManaBar_UpdateType", function(bar) Paint(bar, true) end) then
        hookedUpdate = _G.UnitFrameManaBar_UpdateType
    end
end

local function Bar(skin, bar, unit, kind)
    if not ns.Usable(bar) or type(bar.SetStatusBarTexture) ~= "function" or type(bar.GetStatusBarTexture) ~= "function"
        or type(bar.SetStatusBarColor) ~= "function" then return end
    if type(bar.GetStatusBarColor) == "function" then
        local r, g, b, a = bar:GetStatusBarColor()
        skin:Remember(bar, "status colour", function() pcall(bar.SetStatusBarColor, bar, r, g, b, a) end)
    end
    local old = CurrentTexture(bar)
    if old then skin:Remember(bar, "status texture", function() pcall(bar.SetStatusBarTexture, bar, old) end) end
    tracked[bar] = { unit = unit, kind = kind, texture = Modern.Theme().bar }
    skin:Panel(bar)
    skin:Border(bar)
    Hook(bar)
    Paint(bar, true)
end

local function Art(skin, frame, name)
    for _, rootPath in ipairs(ART_ROOTS) do
        local root = rootPath == "" and frame or Dig(frame, rootPath)
        if ns.Usable(root) then
            for _, key in ipairs(ART_NAMES) do
                local art = root[key]
                if ns.Usable(art) and type(art.SetAlpha) == "function" then skin:Hold(art) end
            end
        end
    end
    for _, suffix in ipairs(ART_GLOBALS) do
        local art = _G[name .. suffix]
        if ns.Usable(art) and type(art.SetAlpha) == "function" then skin:Hold(art) end
    end
end

local function Portrait(skin, frame, unit, name)
    local portrait = Find(frame, PORTRAIT_PATHS, name == "PetFrame" and "PetPortrait" or nil)
    if not portrait then return end
    skin:Icon(portrait)
    if type(portrait.GetNumMaskTextures) == "function" and type(portrait.GetMaskTexture) == "function"
        and type(portrait.RemoveMaskTexture) == "function" and type(portrait.AddMaskTexture) == "function" then
        local masks = {}
        for i = 1, portrait:GetNumMaskTextures() do masks[#masks + 1] = portrait:GetMaskTexture(i) end
        if skin:Remember(portrait, "masks", function()
            for i = 1, #masks do pcall(portrait.AddMaskTexture, portrait, masks[i]) end
        end) then
            for _, mask in ipairs(masks) do pcall(portrait.RemoveMaskTexture, portrait, mask) end
        end
    end
    local color = Modern.Theme().border
    if unit == "target" and type(UnitClassification) == "function" then
        local kind = UnitClassification(unit)
        if kind == "elite" then color = Modern.Theme().accent
        elseif kind == "rare" or kind == "rareelite" then color = RARE
        elseif kind == "worldboss" or kind == "boss" then color = BOSS end
    end
    skin:Border(portrait, color, portrait)
end

local function Unit(skin, spec)
    local name, unit = spec[1], spec[2]
    local frame = _G[name]
    if not ns.Usable(frame) then return end
    Art(skin, frame, name)
    Bar(skin, Find(frame, HEALTH_PATHS, name .. "HealthBar"), unit, "health")
    Bar(skin, Find(frame, POWER_PATHS, name .. "ManaBar"), unit, "power")
    Portrait(skin, frame, unit, name)
end

local function Apply(skin)
    HookUpdate()
    for _, spec in ipairs(FRAMES) do Unit(skin, spec) end
end

Modern.Register{
    key = "units", label = "Unit frames",
    events = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED" },
    apply = Apply, onEvent = function(skin) Apply(skin) end,
    -- Untrack first: the journal's undo then restores texture and colour without the hooks answering.
    restore = function() for bar in pairs(tracked) do tracked[bar] = nil end end,
}
