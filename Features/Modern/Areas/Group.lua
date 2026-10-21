local _, ns = ...

-- Raid frames and raid-style party frames (CompactUnitFrameTemplate, Forever UI source): each member becomes a flat
-- rectangle (its Edit Mode size, sharp corners) with a thin black edge, a grey health fill over a dark track and a
-- flat power line in Blizzard's power colour; the name takes its class colour when Class colours is on. The group and party border art is held. Role,
-- ready check, aura, dispel, aggro and selection marks stay Blizzard's. Members are created as the group grows, so
-- every frame Blizzard sets up is skinned then; nameplates share the template and are never touched. Health and
-- unit values are never read; the fill colour is a constant.

local Modern = ns.Modern
local Group = {}
Modern.Group = Group

local FILL = { 0.34, 0.35, 0.37 }        -- health: a quiet grey, the class lives in the name
local TRACK = { 0.06, 0.065, 0.07, 0.92 } -- the missing health shows as this dark track
local EDGE = { 0, 0, 0, 1 }
-- Compact frames by name; anything else built from the template (nameplates, arena) is left alone.
local PREFIXES = { "CompactPartyFrameMember", "CompactPartyFramePet", "CompactRaidFrame", "CompactRaidGroup" }
local MEMBERS, RAID, GROUPS = 5, 40, 8

local tracked = setmetatable({}, { __mode = "k" }) -- member frame -> journal while applied
local bars = setmetatable({}, { __mode = "k" })    -- health bar -> member frame while applied
local names = setmetatable({}, { __mode = "k" })   -- name -> Blizzard's last colour while applied
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

local function Grey(bar)
    if busy or not bars[bar] then return end
    busy = true
    pcall(bar.SetStatusBarColor, bar, FILL[1], FILL[2], FILL[3], 1)
    busy = false
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

-- With Class colours on the name takes its class or reaction colour; Blizzard's last colour is what comes back.
local function Name(frame)
    local label = tracked[frame] and frame.name
    if not ns.Usable(label) or type(label.SetVertexColor) ~= "function" or busy then return end
    local unit = frame.displayedUnit or frame.unit
    if type(unit) ~= "string" or ns.IsSecret(unit) or not ns.Settings.ModernClassColors() then return end
    local r, g, b = Modern.UnitColour(unit)
    if not r then return end
    if type(label.GetVertexColor) == "function" then names[label] = { label:GetVertexColor() } end
    busy = true
    pcall(label.SetVertexColor, label, r, g, b)
    busy = false
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
        end
        if not hooked[frame.healthBar] then
            hooked[frame.healthBar] = true
            pcall(hooksecurefunc, frame.healthBar, "SetStatusBarColor", Grey)
        end
    end
    Grey(frame.healthBar)
    Name(frame)
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
    HookGlobal("CompactUnitFrame_UpdateName", function(frame) ns.Profiler.Run("modern group", Name, frame) end)
end

function Group.Apply(skin)
    Watch(skin)
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
    for key in pairs(tracked) do tracked[key] = nil end
end
