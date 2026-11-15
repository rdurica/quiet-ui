-- ns.Dump.Build, State section: features, Modern areas, layout, world, scale and the faded frames; and what the dump never touches.
local h = ...

local FRAMES = { "MainActionBar", "PlayerFrame", "PetFrame", "TargetFrame", "Minimap", "ChatFrame1", "PersonalResourceDisplayFrame",
    "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer", "GamepadMainActionBarFrame" }

local function state(text)
    local body, cur = {}, nil
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local title = line:match("^== (.-) ==%s*$")
        if title then cur = title elseif cur == "State" then body[#body + 1] = line end
    end
    return table.concat(body, "\n")
end

-- The line of the State section that names `name`.
local function lineOf(section, name)
    for line in (section .. "\n"):gmatch("(.-)\n") do
        if line:find(name, 1, true) then return line end
    end
end

h.test("State lists every registered feature with on or off", function(t)
    local ns, A = t.ns, t.assert
    ns.Feature{ name = "probe_on", enabled = function() return true end }
    ns.Feature{ name = "probe_off", enabled = function() return false end }
    local section = state(ns.Dump.Build())
    for _, name in ipairs(ns.Features()) do
        A.ok(lineOf(section, name), "feature " .. name .. " is missing from: " .. section)
    end
    local on, off = lineOf(section, "probe_on"), lineOf(section, "probe_off")
    A.ok(on:lower():find("probe_on[^%w\n]+on"), "probe_on is on: " .. on)
    A.ok(off:lower():find("probe_off[^%w\n]+off"), "probe_off is off: " .. off)
end)

h.test("State lists the Modern areas and the layout status", function(t)
    local ns, A = t.ns, t.assert
    ns.Layout.Status = function() return "LAYOUT-STATUS-MARKER" end
    local section = state(ns.Dump.Build())
    local areas = ns.Modern.Areas()
    A.ok(#areas > 0, "the addon registers Modern areas")
    for _, area in ipairs(areas) do
        A.ok(section:find(area.key, 1, true) or section:find(area.label, 1, true), "area " .. area.key .. " is missing")
    end
    A.ok(section:find("LAYOUT-STATUS-MARKER", 1, true), "layout status in: " .. section)
end)

h.test("State shows the world state, UI scale and screen size", function(t)
    local ns, A = t.ns, t.assert
    t.mock.state.combat = true
    local section = state(ns.Dump.Build()):lower()
    for _, word in ipairs({ "combat", "group", "vehicle", "target", "edit mode", "scale", "1920", "1080" }) do
        A.ok(section:find(word, 1, true), "'" .. word .. "' is missing from: " .. section)
    end
end)

h.test("State lists each faded frame with its alpha", function(t)
    local ns, A = t.ns, t.assert
    _G.MainActionBar._alpha = 0.5
    local section = state(ns.Dump.Build())
    for _, name in ipairs(FRAMES) do A.ok(lineOf(section, name), "frame " .. name .. " is missing from: " .. section) end
    A.ok(lineOf(section, "MainActionBar"):find("0.5", 1, true), "alpha on the line: " .. lineOf(section, "MainActionBar"))
end)

h.test("A missing frame global prints missing", function(t)
    local ns, A = t.ns, t.assert
    _G.EssentialCooldownViewer = nil
    A.eq(_G.GamepadMainActionBarFrame, nil, "the gamepad bar is absent on this client")
    local section = state(ns.Dump.Build())
    A.ok(lineOf(section, "EssentialCooldownViewer"):find("missing", 1, true), "EssentialCooldownViewer: " .. tostring(lineOf(section, "EssentialCooldownViewer")))
    A.ok(lineOf(section, "GamepadMainActionBarFrame"):find("missing", 1, true), "GamepadMainActionBarFrame")
    A.falsy(lineOf(section, "MainActionBar"):find("missing", 1, true), "a present frame is not missing")
end)

h.test("A forbidden frame is skipped without an error", function(t)
    local ns, A = t.ns, t.assert
    local touched = 0
    local frame = _G.PlayerFrame
    frame._forbidden = true
    frame.GetAlpha = function() touched = touched + 1; error("forbidden frame") end
    frame.IsShown = function() touched = touched + 1; error("forbidden frame") end
    local text
    A.noThrow(function() text = ns.Dump.Build() end)
    A.eq(touched, 0, "methods called on the forbidden frame")
    A.falsy(text:find("<error:", 1, true), "an error marker appeared: " .. text)
    A.ok(lineOf(state(text), "MainActionBar"), "other frames are still listed")
end)

h.test("A secret frame alpha is written as <secret> without an error", function(t)
    local ns, A = t.ns, t.assert
    local secret = t.mock:secret(0.5)
    _G.MainActionBar.GetAlpha = function() return secret end
    local text
    A.noThrow(function() text = ns.Dump.Build() end)
    A.falsy(text:find("<error:", 1, true), "an error marker appeared")
    local line = lineOf(state(text), "MainActionBar")
    A.ok(line and line:find("<secret>", 1, true), "secret marker on the line: " .. tostring(line))
end)

h.test("Build changes no alpha, no setting other than lastDump and no CVar", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true, presets = {}, nextPresetId = 2 }
    QuietUICharDB = { chatFade = 10, modules = { fading = false }, groups = { ["1"] = 2 } }
    _G.MainActionBar._alpha, _G.PlayerFrame._alpha, _G.Minimap._alpha = 0.3, 0.6, 0.9
    local alphas = {}
    for i, f in ipairs(t.mock.frames) do alphas[i] = f._alpha end
    local setCalls, cvars = t.mock.calls.SetAlpha or 0, #t.mock.cvarLog
    local dbBefore, charBefore = ns.Copy(QuietUIDB), ns.Copy(QuietUICharDB)
    ns.Dump.Build()
    ns.Dump.IssueURL()
    A.eq(t.mock.calls.SetAlpha or 0, setCalls, "SetAlpha calls")
    A.eq(t.mock.calls.SetAlphaFromBoolean or 0, 0, "SetAlphaFromBoolean calls")
    for i, f in ipairs(t.mock.frames) do A.eq(f._alpha, alphas[i], "alpha of frame " .. i .. " (" .. tostring(f._name) .. ")") end
    A.eq(#t.mock.cvarLog, cvars, "CVar writes")
    A.type(QuietUIDB.lastDump, "string", "lastDump is written")
    QuietUIDB.lastDump = nil
    A.deep(QuietUIDB, dbBefore)
    A.deep(QuietUICharDB, charBefore)
end)

h.test("Build reads no unit health or power", function(t)
    local ns, A = t.ns, t.assert
    local reads = {}
    for _, name in ipairs({ "UnitHealth", "UnitHealthMax", "UnitHealthPercent", "UnitPower", "UnitPowerMax", "UnitPowerPercent",
        "UnitGetTotalAbsorbs", "UnitGetTotalHealAbsorbs" }) do
        _G[name] = function() reads[#reads + 1] = name; return t.mock:secret(1) end
    end
    t.mock:setUnit("player", { name = "Someone" })
    t.mock:setUnit("target", { name = "Other" })
    ns.Dump.Build()
    A.deep(reads, {}, "health or power was read: " .. table.concat(reads, ", "))
end)

h.test("Build works in combat and with QuietUI booted", function(t)
    local ns, A = t.ns, t.assert
    t.boot()
    t.mock.state.combat = true
    local text
    A.noThrow(function() text = ns.Dump.Build() end)
    A.ok(text:find("== Header ==", 1, true) and text:find("== Settings ==", 1, true), "a whole report")
    A.eq(QuietUIDB.lastDump, text)
end)
