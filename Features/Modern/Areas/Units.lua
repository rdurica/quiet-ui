local _, ns = ...

-- Unit frames (retail 12.0 structure, with the older flat names as fallbacks): player, pet, target, target of target,
-- focus and the portrait party frames (PartyFrame.MemberFrameN); raid frames are Group's. Frame art is held,
-- bars get the theme texture inside one dark box, and Blizzard's own bar updates are followed by a
-- repaint of the colour. Hooks only act on bars that are tracked, so they are
-- inert while the area is off. Health and power values are never read.

local Modern = ns.Modern

-- The third field: Blizzard draws the portrait right of the bars; the fourth: the player's own frame.
local FRAMES = {
    { "PlayerFrame", "player", false, true }, { "PetFrame", "pet" }, { "TargetFrame", "target", true },
    { "TargetFrameToT", "targettarget" }, { "FocusFrame", "focus", true },
    -- BossTargetFrameTemplate is the target frame's.
    { "Boss1TargetFrame", "boss1", true }, { "Boss2TargetFrame", "boss2", true }, { "Boss3TargetFrame", "boss3", true },
    { "Boss4TargetFrame", "boss4", true }, { "Boss5TargetFrame", "boss5", true },
}

-- Places a part can live, relative to the unit frame.
local ART_ROOTS = { "", "PlayerFrameContainer", "TargetFrameContainer",
    "PlayerFrameContent.PlayerFrameContentMain", "TargetFrameContent.TargetFrameContentMain" }
local ART_NAMES = { "FrameTexture", "AlternatePowerFrameTexture", "VehicleFrameTexture", "FrameFlash", "Flash",
    "BossPortraitFrameTexture", "ReputationColor", "Border", "EliteTexture", "PortraitFrame", "StatusTexture",
    -- PartyMemberFrameTemplate keeps its frame art as Texture and VehicleTexture.
    "Texture", "VehicleTexture" }
local PARTY = 4
local ART_GLOBALS = { "Texture", "Flash" }
local HEALTH_PATHS = { "healthbar", "HealthBar", "healthBar", "HealthBarContainer.HealthBar",
    "PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar",
    "TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar" }
local POWER_PATHS = { "manabar", "ManaBar", "manaBar", "PowerBar", "powerBar",
    "PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar",
    "TargetFrameContent.TargetFrameContentMain.ManaBar" }
local PORTRAIT_PATHS = { "portrait", "Portrait", "PlayerFrameContainer.PlayerPortrait", "TargetFrameContainer.Portrait" }
local LEVEL_PATHS = { "PlayerFrameContent.PlayerFrameContentMain.PlayerLevelText",
    "TargetFrameContent.TargetFrameContentMain.LevelText", "levelText", "LevelText" }
local NAME_PATHS = { "name", "Name", "TargetFrameContent.TargetFrameContentMain.Name" }
local COMBAT_PATHS = { "PlayerFrameContent.PlayerFrameContentContextual.AttackIcon" }
local SKULL_PATHS = { "TargetFrameContent.TargetFrameContentMain.HighLevelTexture", "highLevelTexture" }
-- The player's resting "zzz" and its glow.
local REST_PATHS = { "PlayerFrameContent.PlayerFrameContentContextual.PlayerRestLoop" }
local REST_GLOBALS = { "PlayerRestLoop", "PlayerRestIcon", "PlayerRestGlow" }

local HEALTH = { 0.14, 0.15, 0.16 } -- a quiet near-black fill; the white value text reads on it
local EDGE = { 0, 0, 0, 1 }          -- the box border sinks into the box instead of outlining it
local MANA = { 0.2, 0.45, 0.9 } -- Blizzard's pure blue is the loudest colour on the frame
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

-- The name's class or reaction colour. Identity can be secret on 12.0: it is never a branch or a table
-- key, and the name then keeps Blizzard's colour (nil).
function Modern.UnitColour(unit)
    local r, g, b
    local player = type(UnitIsPlayer) == "function" and UnitIsPlayer(unit)
    if ns.IsSecret(player) then return end
    if player then
        local token
        if type(UnitClass) == "function" then token = select(2, UnitClass(unit)) end
        if ns.IsSecret(token) then return end
        local c = type(C_ClassColor) == "table" and type(C_ClassColor.GetClassColor) == "function"
            and C_ClassColor.GetClassColor(token)
        r, g, b = Colours(c or (type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[token]))
    elseif type(UnitReaction) == "function" and type(FACTION_BAR_COLORS) == "table" then
        local reaction = UnitReaction(unit, "player")
        if ns.IsSecret(reaction) then return end
        r, g, b = Colours(FACTION_BAR_COLORS[reaction])
    end
    if r and g and b then return r, g, b end
end

local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local ICON_INSET = 0.02 -- of the sheet, trims the icon's rounded corners

-- A player's class icon from Blizzard's class sheet; nil for NPCs, a secret identity or a missing sheet.
local function ClassIcon(unit)
    if type(UnitIsPlayer) ~= "function" or type(UnitClass) ~= "function" or type(CLASS_ICON_TCOORDS) ~= "table" then return end
    local player = UnitIsPlayer(unit)
    if ns.IsSecret(player) or not player then return end
    local token = select(2, UnitClass(unit))
    if type(token) ~= "string" or ns.IsSecret(token) then return end
    local c = CLASS_ICON_TCOORDS[token]
    if type(c) ~= "table" then return end
    return { CLASS_ICONS, c[1] + ICON_INSET, c[2] - ICON_INSET, c[3] + ICON_INSET, c[4] - ICON_INSET }
end

local function PowerColour(unit)
    if type(UnitPowerType) ~= "function" or type(PowerBarColor) ~= "table" then return end
    local kind, token = UnitPowerType(unit)
    if not ns.IsSecret(token) and token == "MANA" then return unpack(MANA) end
    return Colours(PowerBarColor[token] or PowerBarColor[kind])
end

-- Puts the theme texture (after Blizzard changed it) and the wanted colour back on a tracked bar.
local function Paint(bar, retexture)
    local info = tracked[bar]
    if not info or info.busy then return end
    info.busy = true
    ns.Profiler.Run("modern units", function()
        if retexture then bar:SetStatusBarTexture(info.texture) end
        local r, g, b
        if info.kind == "health" then r, g, b = unpack(HEALTH) else r, g, b = PowerColour(info.unit) end
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

-- The portrait is gone, so the target's rarity moves to the border of its bar box.
local function RarityColour(unit)
    local color = EDGE
    if unit == "target" and type(UnitClassification) == "function" then
        local kind = UnitClassification(unit)
        if ns.IsSecret(kind) then kind = nil end
        if kind == "elite" then color = Modern.Theme().accent
        elseif kind == "rare" or kind == "rareelite" then color = RARE
        elseif kind == "worldboss" or kind == "boss" then color = BOSS end
    end
    return color
end

-- With class colours on, the name takes its class or reaction colour; otherwise, or for a secret identity,
-- Blizzard's colour, read once per apply cycle.
local base = setmetatable({}, { __mode = "k" })
local function Name(skin, label, unit)
    if not ns.Usable(label) or type(label.SetTextColor) ~= "function" or type(label.GetTextColor) ~= "function" then return end
    if not base[label] then
        base[label] = { label:GetTextColor() }
        skin:Remember(label, "name colour", function()
            pcall(label.SetTextColor, label, unpack(base[label]))
            base[label] = nil
        end)
    end
    local r, g, b
    if ns.Settings.ModernClassColors() then r, g, b = Modern.UnitColour(unit) end
    if r and g and b then label:SetTextColor(r, g, b) else label:SetTextColor(unpack(base[label])) end
end

local function Rest(skin, frame)
    local list = { Find(frame, REST_PATHS) }
    for _, key in ipairs(REST_GLOBALS) do list[#list + 1] = _G[key] end
    for _, art in pairs(list) do
        if ns.Usable(art) and type(art.SetAlpha) == "function" then skin:Hold(art) end
    end
end

local function Unit(skin, spec)
    local name, unit = spec[1], spec[2]
    local frame = spec.frame or _G[name]
    if not ns.Usable(frame) then return end
    Art(skin, frame, name)
    local health, mana = Find(frame, HEALTH_PATHS, name .. "HealthBar"), Find(frame, POWER_PATHS, name .. "ManaBar")
    Bar(skin, health, unit, "health")
    Bar(skin, mana, unit, "power")
    local label = Find(frame, NAME_PATHS, name == "PlayerFrame" and "PlayerName" or name .. "TextureFrameName")
    if not spec[4] then Name(skin, label, unit) end
    if spec[4] then Rest(skin, frame) end
    -- The portrait is held at alpha 0 in place; the bars take its space.
    local portrait = Find(frame, PORTRAIT_PATHS, name == "PetFrame" and "PetPortrait" or nil)
    if not portrait then return end
    skin:Hold(portrait)
    Modern.UnitLayout(skin, frame, { health = health, mana = mana, portrait = portrait, right = spec[3],
        player = spec[4], border = RarityColour(unit), icon = spec[3] and ClassIcon(unit) or nil,
        combat = spec[4] and Find(frame, COMBAT_PATHS, "PlayerAttackIcon") or nil,
        level = Find(frame, LEVEL_PATHS, name == "PlayerFrame" and "PlayerLevelText" or name .. "TextureFrameLevelText"),
        skull = Find(frame, SKULL_PATHS, name .. "TextureFrameHighLevelTexture"),
        name = label })
end

-- The 12.0 party frame pools its members under PartyFrame; Forever's classic globals are the fallback.
local function Party(skin)
    local party = _G.PartyFrame
    for index = 1, PARTY do
        local name = "PartyMemberFrame" .. index
        local frame = ns.Usable(party) and party["MemberFrame" .. index] or _G[name]
        if ns.Usable(frame) then Unit(skin, { name, "party" .. index, frame = frame }) end
    end
end

-- Blizzard shows the health value only on hover by default; on the near-black fill it is the only
-- sign of health, so it stays on while the area is applied.
local STATUS_TEXT = {} -- the journal key for the CVar
local function StatusText(skin)
    if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" or type(C_CVar.SetCVar) ~= "function" then return end
    local ok, old = pcall(C_CVar.GetCVar, "statusText")
    if not ok or old == nil or ns.IsSecret(old) or tostring(old) == "1" then return end
    if not skin:Remember(STATUS_TEXT, "statusText", function() pcall(C_CVar.SetCVar, "statusText", old) end) then return end
    local set, err = pcall(C_CVar.SetCVar, "statusText", "1")
    if not set then ns.Report("modern units", err) end
end

local function Apply(skin)
    HookUpdate()
    StatusText(skin)
    for _, spec in ipairs(FRAMES) do Unit(skin, spec) end
    Party(skin)
    Modern.Group.Apply(skin)
end

-- UNIT_FACTION and UNIT_CLASSIFICATION_CHANGED fire for every unit (nameplates, party): only the skinned
-- ones matter. A secret token cannot be told apart, so it skins to be safe.
local function OnEvent(skin, _, unit)
    if type(unit) == "string" and not ns.IsSecret(unit) then
        local tracked = unit:sub(1, 5) == "party"
        for _, spec in ipairs(FRAMES) do tracked = tracked or spec[2] == unit end
        if not tracked then return end
    end
    Apply(skin)
end

Modern.Register{
    key = "units", label = "Unit frames",
    -- Combat end and vehicle changes lay the bars out again (Blizzard re-anchors them for vehicles).
    events = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED",
        "PLAYER_REGEN_ENABLED", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "GROUP_ROSTER_UPDATE" },
    apply = Apply, onEvent = OnEvent,
    -- Untrack first: the journal's undo then restores texture and colour without the hooks answering.
    restore = function()
        for bar in pairs(tracked) do tracked[bar] = nil end
        Modern.Group.Release()
    end,
}
