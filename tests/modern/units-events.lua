-- UNIT_FACTION and UNIT_CLASSIFICATION_CHANGED fire for every unit; the unit frames only skin again for their own
-- (party members included; raid frames follow Blizzard's own updates).
local h = ...
local U = h.lib("modern-units")

h.test("unit events for other units do no work, events for skinned units skin again", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    U.frames()
    U.installColours(mock)
    local calls = 0
    UnitClassification = function() calls = calls + 1; return "normal" end
    QuietUICharDB = { modules = { modernize = true }, modernize = {} }
    ns.Modern.Apply()
    local applied = calls
    A.ok(applied > 0, "the target health border reads the classification")
    mock:fire("UNIT_CLASSIFICATION_CHANGED", "nameplate3")
    mock:fire("UNIT_FACTION", "raid7")
    A.eq(calls, applied, "other units cause no re-skin")
    mock:fire("UNIT_CLASSIFICATION_CHANGED", "target")
    A.eq(calls, applied + 1, "the target re-skins")
    mock:fire("PLAYER_TARGET_CHANGED")
    A.eq(calls, applied + 2, "a target change re-skins")
end)

h.test("target events update only target/targettarget without re-skinning player, focus, party or raid", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    U.installColours(mock)
    local raid = CreateFrame("Button", "CompactRaidFrame1", UIParent)
    raid.unit = "raid1"
    raid.healthBar = CreateFrame("StatusBar", nil, raid)
    raid.healthBar.SetStatusBarTexture = function() end
    raid.healthBar.SetStatusBarColor = function() end
    raid.healthBar.GetStatusBarTexture = function() return raid.healthBar:CreateTexture() end
    raid.name = raid:CreateFontString(nil, "OVERLAY")
    local raidWrites = 0
    local origRaidColor = raid.healthBar.SetStatusBarColor
    raid.healthBar.SetStatusBarColor = function(s, ...) raidWrites = raidWrites + 1; return origRaidColor(s, ...) end
    local focusWrites = 0
    local focusHealth = U.parts(frames[5]).health
    local origFocusColor = focusHealth.SetStatusBarColor
    focusHealth.SetStatusBarColor = function(s, ...) focusWrites = focusWrites + 1; return origFocusColor(s, ...) end
    local totWrites = 0
    local totHealth = U.parts(frames[4]).health
    local origTotColor = totHealth.SetStatusBarColor
    totHealth.SetStatusBarColor = function(s, ...) totWrites = totWrites + 1; return origTotColor(s, ...) end
    QuietUICharDB = { modules = { modernize = true }, modernize = {} }
    ns.Modern.Apply()
    raidWrites, focusWrites, totWrites = 0, 0, 0
    mock:fire("PLAYER_TARGET_CHANGED")
    A.eq(raidWrites, 0, "target change must not re-skin raid frames")
    A.eq(focusWrites, 0, "target change must not re-skin focus")
    A.ok(totWrites > 0, "target change updates targettarget")
    totWrites = 0
    mock:fire("UNIT_FACTION", "target")
    A.eq(raidWrites, 0, "target faction event must not re-skin raid frames")
    A.eq(focusWrites, 0, "target faction event must not re-skin focus")
    A.eq(totWrites, 0, "target faction event must not re-skin targettarget")
end)
