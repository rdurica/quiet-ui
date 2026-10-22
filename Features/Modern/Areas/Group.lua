local _, ns = ...

-- Raid frames and raid-style party frames (CompactUnitFrameTemplate, Forever UI source): each member becomes a flat
-- rectangle (its Edit Mode size, sharp corners) with a thin black edge, the unit frames' near-black health fill over a
-- darker track, a thin flat power line in a muted power colour, the class in the name and Blizzard's health percent
-- in the centre. The group and party border art is held. Role,
-- ready check, aura, dispel, aggro and selection marks stay Blizzard's. Members are created as the group grows, so
-- every frame Blizzard sets up is skinned then; nameplates share the template and are never touched. Health and
-- unit values are never read; the fill colour is a constant, as dark as the track for an offline member.

local Modern = ns.Modern
local Group = {}
Modern.Group = Group

local FILL = { 0.141, 0.149, 0.161 }     -- the unit frames' health colour
local TRACK = { 0.06, 0.065, 0.07, 0.92 } -- the missing health shows as this darker track
local OFFLINE = TRACK                     -- an offline member keeps a full bar; it must not read as full health
local EDGE = { 0, 0, 0, 1 }
local POWER_HEIGHT = 3 -- Blizzard's power bar is as loud as the health fill
local POWER_GAP = 1    -- the dark track shows as a line between health and power
local MUTE = 0.4       -- share of grey mixed into Blizzard's power colour
local GREY = 0.35
-- Compact frames by name; anything else built from the template (nameplates, arena) is left alone.
local PREFIXES = { "CompactPartyFrameMember", "CompactPartyFramePet", "CompactRaidFrame", "CompactRaidGroup" }
local MEMBERS, RAID, GROUPS = 5, 40, 8

local tracked = setmetatable({}, { __mode = "k" }) -- member frame -> journal while applied
local names = setmetatable({}, { __mode = "k" })   -- name -> Blizzard's last colour while applied
local bars = setmetatable({}, { __mode = "k" })    -- health bar -> member frame while applied
local powers = setmetatable({}, { __mode = "k" })  -- power bar -> member frame while applied
local hooked = setmetatable({}, { __mode = "k" })
local hookedGlobal = {}
local current = nil -- the journal while applied
local busy = false

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, texture)
    if IsTexture(texture) then skin:Hold(texture) end
end

local function IsMember(frame)
    local name = ns.Usable(frame) and type(frame.GetName) == "function" and frame:GetName()
    if type(name) ~= "string" or not ns.Usable(frame.healthBar) then return false end
    for _, prefix in ipairs(PREFIXES) do
        if name:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function Offline(frame)
    local unit = frame.displayedUnit or frame.unit
    if type(unit) ~= "string" or ns.IsSecret(unit) or type(UnitIsConnected) ~= "function" then return false end
    local connected = UnitIsConnected(unit)
    return not ns.IsSecret(connected) and not connected
end

-- Blizzard re-colours the bar when the member goes offline or comes back, so the hook sees both.
local function Fill(bar)
    local frame = bars[bar]
    if busy or not frame then return end
    local color = Offline(frame) and OFFLINE or FILL
    busy = true
    pcall(bar.SetStatusBarColor, bar, color[1], color[2], color[3], 1)
    busy = false
end

-- The name takes its class or reaction colour; Blizzard's last colour is what comes back.
local function Class(frame)
    if busy or not tracked[frame] then return end
    local unit = frame.displayedUnit or frame.unit
    local r, g, b
    if type(unit) == "string" and not ns.IsSecret(unit) then r, g, b = Modern.UnitColour(unit) end
    local label = frame.name
    if not r or not ns.Usable(label) or type(label.SetVertexColor) ~= "function" then return end
    if type(label.GetVertexColor) == "function" then names[label] = { label:GetVertexColor() } end
    busy = true
    pcall(label.SetVertexColor, label, r, g, b)
    busy = false
end


local function Mix(c)
    return c * (1 - MUTE) + GREY * MUTE
end

-- Blizzard re-colours the power bar by power type; the colour stays, only quieter.
local function Mute(bar, r, g, b)
    if busy or not powers[bar] or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number"
        or ns.IsSecret(r) or ns.IsSecret(g) or ns.IsSecret(b) then return end
    busy = true
    pcall(bar.SetStatusBarColor, bar, Mix(r), Mix(g), Mix(b), 1)
    busy = false
end

local function BottomRight(points)
    for _, p in ipairs(points) do
        if p[1] == "BOTTOMRIGHT" and type(p[4]) == "number" and type(p[5]) == "number" then return p end
    end
end

-- The power line shrinks to a thin strip on the frame's bottom edge and the health fill takes the rest. Blizzard
-- lays both out in its setup, so this runs after every setup while the power bar is shown, and only out of combat.
local function Thin(skin, frame)
    local health, power = frame.healthBar, frame.powerBar
    if (InCombatLockdown and InCombatLockdown()) or type(power.IsShown) ~= "function" or not power:IsShown() then return end
    local healthPoints, powerPoints = Modern.Points(health), Modern.Points(power)
    local bottom = powerPoints and healthPoints and BottomRight(powerPoints)
    if not bottom or bottom[2] ~= frame then return end
    local x, y = bottom[4], bottom[5]
    skin:Remember(health, "group bar points", function() pcall(Modern.SetPoints, health, healthPoints) end)
    skin:Remember(power, "group bar points", function() pcall(Modern.SetPoints, power, powerPoints) end)
    local kept = {}
    for _, p in ipairs(healthPoints) do
        if p[1]:sub(1, 3) == "TOP" then kept[#kept + 1] = p end
    end
    kept[#kept + 1] = { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", x, y + POWER_HEIGHT + POWER_GAP, n = 5 }
    pcall(Modern.SetPoints, health, kept)
    pcall(Modern.SetPoints, power, {
        { "TOPLEFT", health, "BOTTOMLEFT", 0, -POWER_GAP, n = 5 },
        { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", x, y, n = 5 },
    })
end

-- The bar keeps its fill object; the journal remembers Blizzard's texture and colour.
local function Flat(skin, bar)
    if not ns.Usable(bar) or type(bar.SetStatusBarTexture) ~= "function" then return end
    local fill = type(bar.GetStatusBarTexture) == "function" and bar:GetStatusBarTexture()
    local atlas = ns.Usable(fill) and type(fill.GetAtlas) == "function" and fill:GetAtlas()
    local file = ns.Usable(fill) and type(fill.GetTexture) == "function" and fill:GetTexture()
    local old = type(atlas) == "string" and atlas ~= "" and atlas or file
    if old then skin:Remember(bar, "group bar texture", function() pcall(bar.SetStatusBarTexture, bar, old) end) end
    if type(bar.GetStatusBarColor) == "function" then
        local r, g, b, a = bar:GetStatusBarColor()
        skin:Remember(bar, "group bar colour", function() pcall(bar.SetStatusBarColor, bar, r, g, b, a) end)
    end
    bar:SetStatusBarTexture(Modern.Theme().bar)
end

-- Blizzard anchors the status text (health percent, Dead, Offline) low in the frame; it sits in the centre of the
-- health fill, and only out of combat since the member is a secure button.
local function Centre(skin, frame)
    local text = frame.statusText
    if not ns.Usable(text) or type(text.SetPoint) ~= "function" or (InCombatLockdown and InCombatLockdown()) then return end
    local points = Modern.Points(text)
    if not points then return end
    skin:Remember(text, "group status points", function() pcall(Modern.SetPoints, text, points) end)
    pcall(Modern.SetPoints, text, { { "CENTER", frame.healthBar, "CENTER", 0, 0, n = 5 } })
end

-- Blizzard's raid frames show the health percent only when asked; the values stay secret and Blizzard's to write.
local HEALTH_TEXT = {} -- the journal key for the CVar
local function HealthText(skin)
    if type(C_CVar) ~= "table" or type(C_CVar.GetCVar) ~= "function" or type(C_CVar.SetCVar) ~= "function" then return end
    local ok, old = pcall(C_CVar.GetCVar, "raidFramesHealthText")
    if not ok or old == nil or ns.IsSecret(old) or tostring(old) == "perc" then return end
    if not skin:Remember(HEALTH_TEXT, "raidFramesHealthText", function()
        pcall(C_CVar.SetCVar, "raidFramesHealthText", old)
    end) then return end
    local set, err = pcall(C_CVar.SetCVar, "raidFramesHealthText", "perc")
    if not set then ns.Report("modern group", err) end
end

local function Member(skin, frame)
    if not IsMember(frame) then return end
    if not tracked[frame] then
        tracked[frame] = skin
        Hold(skin, frame.background)
        skin:Panel(frame, TRACK)
        skin:Border(frame, EDGE)
        Flat(skin, frame.healthBar)
        bars[frame.healthBar] = frame
        local power = frame.powerBar
        if ns.Usable(power) then
            Flat(skin, power)
            Hold(skin, power.background)
            powers[power] = frame
            if not hooked[power] then
                hooked[power] = true
                pcall(hooksecurefunc, power, "SetStatusBarColor", Mute)
            end
            if type(power.GetStatusBarColor) == "function" then Mute(power, power:GetStatusBarColor()) end
        end
        if not hooked[frame.healthBar] then
            hooked[frame.healthBar] = true
            pcall(hooksecurefunc, frame.healthBar, "SetStatusBarColor", Fill)
        end
    end
    Fill(frame.healthBar)
    if ns.Usable(frame.powerBar) and powers[frame.powerBar] then Thin(skin, frame) end
    Centre(skin, frame)
    Class(frame)
end

local function Borders(skin, frame)
    if ns.Usable(frame) then Modern.Character.HoldArt(skin, frame.borderFrame or frame.BorderFrame) end
end

local function HookGlobal(name, fn)
    if hookedGlobal[name] or type(_G[name]) ~= "function" then return end
    hookedGlobal[name] = pcall(hooksecurefunc, name, fn)
end

local function Watch(skin)
    current = skin
    HookGlobal("DefaultCompactUnitFrameSetup", function(frame)
        if current then ns.Profiler.Run("modern group", Member, current, frame) end
    end)
    HookGlobal("CompactUnitFrame_UpdateName", function(frame) ns.Profiler.Run("modern group", Class, frame) end)
end

function Group.Apply(skin)
    Watch(skin)
    HealthText(skin)
    for index = 1, MEMBERS do
        Member(skin, _G["CompactPartyFrameMember" .. index])
        Member(skin, _G["CompactPartyFramePet" .. index])
    end
    for index = 1, RAID do Member(skin, _G["CompactRaidFrame" .. index]) end
    Borders(skin, _G.CompactPartyFrame)
    for group = 1, GROUPS do
        Borders(skin, _G["CompactRaidGroup" .. group])
        for index = 1, MEMBERS do Member(skin, _G["CompactRaidGroup" .. group .. "Member" .. index]) end
    end
    Borders(skin, _G.CompactRaidFrameContainer)
end

-- Before the journal is undone: the hooks stop answering and the names get Blizzard's colour back.
function Group.Release()
    current = nil
    for label, color in pairs(names) do pcall(label.SetVertexColor, label, unpack(color, 1, 4)) end
    for key in pairs(names) do names[key] = nil end
    for key in pairs(bars) do bars[key] = nil end
    for key in pairs(powers) do powers[key] = nil end
    for key in pairs(tracked) do tracked[key] = nil end
end
