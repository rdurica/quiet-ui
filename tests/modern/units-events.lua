-- Unit event dispatch: events skin only the matching unit frames; untracked units do nothing and secret tokens fall back.
local h = ...
local U = h.lib("modern-units")

local function makeStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(91, 11)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    bar._statusColor = { 0, 1, 0, 1 }
    bar.SetStatusBarTexture = function(self, v) fill:SetTexture(v) end
    bar.GetStatusBarTexture = function() return fill end
    bar.SetStatusBarColor = function(self, ...) self._statusColor = { ... } end
    bar.GetStatusBarColor = function(self) return unpack(self._statusColor) end
    return bar
end

local function makePartyFrame(name, parent)
    local frame = CreateFrame("Button", name, parent or UIParent)
    frame.Texture = frame:CreateTexture(nil, "ARTWORK")
    frame.Texture:SetTexture("UI-HUD-UnitFrame-Party-PortraitOn")
    frame.Portrait = frame:CreateTexture(nil, "ARTWORK")
    frame.Portrait:SetTexture("Interface\\Portrait\\Party")
    frame.HealthBar = makeStatusBar(frame)
    frame.ManaBar = makeStatusBar(frame)
    frame.LevelText = frame:CreateFontString(nil, "OVERLAY")
    frame.LevelText:SetText("20")
    frame.LevelText:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    frame.Name = frame:CreateFontString(nil, "OVERLAY")
    frame.Name:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    return frame
end

local function makeRaidFrame(name, unit)
    local raid = CreateFrame("Button", name, UIParent)
    raid.unit = unit
    raid.healthBar = makeStatusBar(raid)
    raid.name = raid:CreateFontString(nil, "OVERLAY")
    return raid
end

local ALL_KEYS = { "player", "pet", "target", "tot", "focus", "party", "raid", "raid7" }

local function setup(mock, opts)
    opts = opts or {}
    local frames = U.frames()
    U.installColours(mock)
    local party
    if opts.retailParty then
        party = makePartyFrame(nil, PartyFrame)
        PartyFrame.MemberFrame1 = party
    else
        party = makePartyFrame("PartyMemberFrame1")
    end
    local raid1 = makeRaidFrame("CompactRaidFrame1", "raid1")
    local raid7 = makeRaidFrame("CompactRaidFrame7", "raid7")

    local writes = {}
    local function watch(key, bar)
        writes[key] = 0
        local orig = bar.SetStatusBarColor
        bar.SetStatusBarColor = function(s, ...)
            writes[key] = writes[key] + 1
            return orig(s, ...)
        end
    end

    watch("player", U.parts(frames[1]).health)
    watch("pet", U.parts(frames[2]).health)
    watch("target", U.parts(frames[3]).health)
    watch("tot", U.parts(frames[4]).health)
    watch("focus", U.parts(frames[5]).health)
    watch("party", party.HealthBar)
    watch("raid", raid1.healthBar)
    watch("raid7", raid7.healthBar)

    local env = {
        frames = frames,
        party = party,
        raid1 = raid1,
        raid7 = raid7,
        writes = writes,
    }

    function env.reset()
        for _, key in ipairs(ALL_KEYS) do writes[key] = 0 end
    end

    function env.assertOnly(A, label, active)
        for _, key in ipairs(ALL_KEYS) do
            if active[key] then
                A.ok(writes[key] > 0, label .. ": " .. key .. " updated")
            else
                A.eq(writes[key], 0, label .. ": " .. key .. " not re-skinned")
            end
        end
    end

    return env
end

local function enable(ns)
    QuietUICharDB = { modules = { modernize = true }, modernize = {} }
    ns.Modern.Apply()
end

h.test("unit events for other units do no work, events for skinned units skin again", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local env = setup(mock)
    local calls = 0
    UnitClassification = function() calls = calls + 1; return "normal" end
    enable(ns)
    local applied = calls
    A.ok(applied > 0, "the target health border reads the classification")
    env.reset()
    for _, event in ipairs({ "UNIT_CLASSIFICATION_CHANGED", "UNIT_FACTION", "UNIT_NAME_UPDATE" }) do
        for _, unit in ipairs({ "nameplate3", "raid7", "partypet1", "party5" }) do
            mock:fire(event, unit)
            env.assertOnly(A, event .. " " .. unit, {})
        end
    end
    A.eq(calls, applied, "other units cause no re-skin")
    mock:fire("UNIT_CLASSIFICATION_CHANGED", "target")
    A.eq(calls, applied + 1, "the target re-skins")
    env.assertOnly(A, "UNIT_CLASSIFICATION_CHANGED target", { target = true })
    env.reset()
    mock:fire("PLAYER_TARGET_CHANGED")
    A.eq(calls, applied + 2, "a target change re-skins")
    env.assertOnly(A, "PLAYER_TARGET_CHANGED", { target = true, tot = true })
end)

h.test("target events update only target/targettarget without re-skinning player, focus, party or raid", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local env = setup(mock)
    enable(ns)
    env.reset()
    mock:fire("PLAYER_TARGET_CHANGED")
    env.assertOnly(A, "PLAYER_TARGET_CHANGED", { target = true, tot = true })
    for _, event in ipairs({ "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED", "UNIT_NAME_UPDATE" }) do
        env.reset()
        mock:fire(event, "target")
        env.assertOnly(A, event .. " target", { target = true })
    end
end)

h.test("focus events update only FocusFrame without re-skinning other frames", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local env = setup(mock)
    enable(ns)
    env.reset()
    mock:fire("PLAYER_FOCUS_CHANGED")
    env.assertOnly(A, "PLAYER_FOCUS_CHANGED", { focus = true })
    for _, event in ipairs({ "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED", "UNIT_NAME_UPDATE" }) do
        env.reset()
        mock:fire(event, "focus")
        env.assertOnly(A, event .. " focus", { focus = true })
    end
end)

local function testRosterAndParty(t, retailParty)
    local A, ns, mock = t.assert, t.ns, t.mock
    local env = setup(mock, { retailParty = retailParty })
    local mode = retailParty and "PartyFrame.MemberFrame1" or "PartyMemberFrame1"
    enable(ns)
    env.reset()
    mock:fire("GROUP_ROSTER_UPDATE")
    env.assertOnly(A, mode .. " GROUP_ROSTER_UPDATE", { party = true, raid = true, raid7 = true })
    for _, event in ipairs({ "UNIT_NAME_UPDATE", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED" }) do
        env.reset()
        mock:fire(event, "party1")
        env.assertOnly(A, mode .. " " .. event .. " party1", { party = true })
    end
end

h.test("roster updates skin party and raid frames only; party1 unit events update only PartyMemberFrame1", function(t)
    testRosterAndParty(t, false)
end)

h.test("roster updates and party1 unit events also target 12.0 PartyFrame.MemberFrame1 only", function(t)
    testRosterAndParty(t, true)
end)

h.test("a secret unit token falls back to a full apply without error", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local env = setup(mock)
    enable(ns)
    local all = {}
    for _, key in ipairs(ALL_KEYS) do all[key] = true end

    env.reset()
    mock:fire("UNIT_FACTION", mock:secret("target"))
    env.assertOnly(A, "table secret unit", all)

    local realSecret = issecretvalue
    issecretvalue = function(v) return v == "secret-target" or realSecret(v) end
    env.reset()
    mock:fire("UNIT_NAME_UPDATE", "secret-target")
    env.assertOnly(A, "string secret unit", all)
    A.eq(#mock.printed, 0, "no error reported")
end)
