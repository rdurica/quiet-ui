-- Raid and party frames of the Forever UI source. CompactUnitFrameTemplate: a background texture
-- (raidframe-hp-bg-white), healthBar and powerBar StatusBars (with a background), a name font string coloured
-- through SetVertexColor, and Blizzard's DefaultCompactUnitFrameSetup / CompactUnitFrame_UpdateName that set a frame
-- up and rename it; nameplates use the same template under other names. CompactPartyFrame and CompactRaidGroupN
-- carry a borderFrame. PartyFrame.MemberFrameN (PartyMemberFrameTemplate) is the portrait style.
local h = ...
local L = h.lib("modern")
local R = h.lib("modern-windows-retail")
local U = h.lib("modern-units")

local FILL = 0.141

local function bar(parent)
    local value = CreateFrame("StatusBar", nil, parent)
    local fill = value:CreateTexture(nil, "BORDER")
    fill._atlas = "RaidFrame-Hp-Fill"
    function fill:GetAtlas() return self._atlas end
    value._statusColor = { 0.25, 0.78, 0.92, 1 }
    -- An atlas name goes back as an atlas, a file as a file.
    function value:SetStatusBarTexture(v)
        if tostring(v):find("\\") then fill._atlas = nil; fill:SetTexture(v) else fill._atlas, fill._texture = v, nil end
    end
    function value:GetStatusBarTexture() return fill end
    function value:SetStatusBarColor(...) self._statusColor = { ... } end
    function value:GetStatusBarColor() return unpack(self._statusColor) end
    value.fill = fill
    return value
end

local function member(name, unit, parent)
    local frame = CreateFrame("Button", name, parent or UIParent)
    frame.unit, frame.displayedUnit = unit, unit
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetTexture("raidframe-hp-bg-white")
    frame.healthBar = bar(frame)
    frame.powerBar = bar(frame)
    frame.powerBar.background = frame.powerBar:CreateTexture(nil, "BACKGROUND")
    frame.name = frame:CreateFontString(nil, "ARTWORK")
    frame.name:SetText("Anaxia")
    frame.name._vertex = { 1, 1, 1, 1 }
    frame.roleIcon = frame:CreateTexture(nil, "ARTWORK")
    return frame
end

local function blizzard()
    function DefaultCompactUnitFrameSetup(frame) frame.healthBar:SetStatusBarColor(0.25, 0.78, 0.92) end
    function CompactUnitFrame_UpdateName(frame) frame.name:SetVertexColor(1, 1, 1, 1) end
end

local function party()
    local container = CreateFrame("Frame", "CompactPartyFrame", UIParent)
    container.borderFrame = CreateFrame("Frame", nil, container)
    container.borderFrame.Background = container.borderFrame:CreateTexture(nil, "ARTWORK")
    container.borderFrame.Background:SetTexture("options_frame_child")
    return container, member("CompactPartyFrameMember1", "party1", container)
end

local function health(frame) return frame.healthBar._statusColor end

h.test("Unit frames turns raid-style party frames into dark boxes with a class-coloured name, and restores them", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    UnitIsPlayer = function() return true end
    blizzard()
    local container, first = party()
    local plate = member("NamePlate1UnitFrame", "nameplate1")
    local before = L.snapshot(R.all(UIParent))
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.eq(health(first)[1], FILL, "the health fill is the unit frames' near-black")
    A.eq(first.healthBar.fill._texture, ns.Modern.Theme().bar, "the health fill is flat")
    A.eq(first.background._alpha, 0, "the white health backdrop is held")
    A.eq(container.borderFrame.Background._alpha, 0, "the party border art is held")
    A.eq(first.name._vertex[1], 0.25, "the name takes the mage colour")
    A.eq(first.roleIcon._alpha, 1, "the role icon stays")
    DefaultCompactUnitFrameSetup(first)
    A.eq(health(first)[1], FILL, "Blizzard's class colour on the bar turns dark again")
    UnitIsPlayer = function() return false end
    CompactUnitFrame_UpdateName(first)
    A.eq(first.name._vertex[1], 0.8, "a frame that gets another unit takes its colour")
    UnitIsPlayer = function() return true end
    A.ok(plate.healthBar.fill._atlas == "RaidFrame-Hp-Fill" and plate.background._alpha == 1, "a nameplate is untouched")
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.eq(table.concat(L.diff(before), ","), "", "the party frames restore exactly")
    DefaultCompactUnitFrameSetup(first)
    A.eq(health(first)[1], 0.25, "after restore Blizzard's bar colour stays")
end)

h.test("Unit frames skins a raid frame Blizzard sets up after the area was applied", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    UnitIsPlayer = function() return true end
    blizzard()
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    local late = member("CompactRaidFrame7", "raid7")
    DefaultCompactUnitFrameSetup(late)
    A.eq(health(late)[1], FILL, "the new raid frame has the dark fill")
    A.eq(late.background._alpha, 0, "its backdrop is held")
end)

h.test("Unit frames turns the raid power bar into a thin muted line, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    UnitIsPlayer = function() return true end
    function DefaultCompactUnitFrameSetup(frame)
        frame.healthBar:ClearAllPoints()
        frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 9)
        frame.powerBar:ClearAllPoints()
        frame.powerBar:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, 0)
        frame.powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame.powerBar:SetStatusBarColor(0, 0, 1)
    end
    function CompactUnitFrame_UpdateName(frame) frame.name:SetVertexColor(1, 1, 1, 1) end
    local _, first = party()
    DefaultCompactUnitFrameSetup(first)
    local before = L.snapshot(R.all(UIParent))
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    local function bottomOf(region)
        for i = 1, region:GetNumPoints() do
            local point, _, _, _, y = region:GetPoint(i)
            if point == "BOTTOMRIGHT" then return y end
        end
    end
    A.eq(bottomOf(first.healthBar), 5, "the health fill leaves room for a thin line only")
    A.eq(bottomOf(first.powerBar), 1, "the power line keeps Blizzard's bottom edge")
    local r, _, b = first.powerBar:GetStatusBarColor()
    A.ok(r > 0 and b < 1, "the pure blue is muted")
    DefaultCompactUnitFrameSetup(first)
    A.eq(bottomOf(first.healthBar), 5, "a new setup keeps the thin line")
    A.ok(first.powerBar._statusColor[3] < 1, "and the muted colour")
    CompactUnitFrame_UpdateName(first)
    A.eq(#mock.printed, 0, "nothing reported")
    ns.Modern.Restore()
    A.eq(table.concat(L.diff(before), ","), "", "the raid frame restores exactly")
end)

h.test("Unit frames darkens an offline member's fill so it does not read as full health", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    UnitIsPlayer = function() return true end
    local online = false
    UnitIsConnected = function() return online end
    blizzard()
    local _, first = party()
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.ok(health(first)[1] < FILL, "the offline fill is dark")
    online = true
    DefaultCompactUnitFrameSetup(first)
    A.eq(health(first)[1], FILL, "back online the fill is the health colour again")
end)

h.test("Unit frames shows the raid health percent in the centre, and restores it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    UnitIsPlayer = function() return true end
    local cvars = { raidFramesHealthText = "none" }
    C_CVar = { GetCVar = function(name) return cvars[name] end, SetCVar = function(name, value) cvars[name] = value end }
    blizzard()
    local _, first = party()
    first.statusText = first:CreateFontString(nil, "ARTWORK")
    first.statusText:SetPoint("BOTTOM", first, "BOTTOM", 0, 3)
    local before = L.snapshot(R.all(UIParent))
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.eq(cvars.raidFramesHealthText, "perc", "Blizzard shows the health percent")
    local point, anchor = first.statusText:GetPoint(1)
    A.ok(point == "CENTER" and anchor == first.healthBar and first.statusText:GetNumPoints() == 1, "it sits in the centre")
    CompactUnitFrame_UpdateName(first)
    ns.Modern.Restore()
    A.eq(cvars.raidFramesHealthText, "none", "the player's setting comes back")
    A.eq(table.concat(L.diff(before), ","), "", "the status text goes back to its place")
end)

h.test("Unit frames ignores a classColors false stored before the option was removed", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    UnitIsPlayer = function() return true end
    blizzard()
    local _, first = party()
    QuietUICharDB = { modernize = { enabled = true, classColors = false } }
    ns.Modern.Apply()
    A.ok(first.name._vertex[1] ~= 1, "the name takes its class colour")
end)

h.test("Unit frames gives the portrait party frames the compact box", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.installColours(mock)
    U.frames()
    local partyFrame = CreateFrame("Frame", "PartyFrame", UIParent)
    local memberFrame = CreateFrame("Button", nil, partyFrame)
    partyFrame.MemberFrame1 = memberFrame
    memberFrame.Texture = memberFrame:CreateTexture(nil, "ARTWORK")
    memberFrame.Texture:SetTexture("UI-HUD-UnitFrame-Party-PortraitOn")
    memberFrame.HealthBarContainer = CreateFrame("Frame", nil, memberFrame)
    memberFrame.HealthBarContainer.HealthBar = bar(memberFrame.HealthBarContainer)
    memberFrame.Portrait = memberFrame:CreateTexture(nil, "BACKGROUND")
    QuietUICharDB = { modernize = { enabled = true } }
    ns.Modern.Apply()
    A.eq(memberFrame.Texture._alpha, 0, "the party frame art is held")
    A.eq(memberFrame.Portrait._alpha, 0, "the portrait is held")
    A.eq(memberFrame.HealthBarContainer.HealthBar.fill._texture, ns.Modern.Theme().bar, "the health bar is flat")
    A.eq(#mock.printed, 0, "nothing reported")
end)
