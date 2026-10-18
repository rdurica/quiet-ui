-- Modernize area registry: validation, apply / restore gating, event routing, /quiet off|on and the
-- contract every registered area (today fakes, later the real ones) has to keep.
local h = ...
local L = h.lib("modern")
local I = h.lib("modern-icons")
local M = h.lib("modern-map-tip")
local U = h.lib("modern-units")
local W = h.lib("modern-windows")

h.test("ns.Modern exposes the registry API", function(t)
    local A = t.assert
    A.type(t.ns.Modern, "table")
    for _, name in ipairs({ "Register", "Areas", "Apply", "Restore", "Themes", "Theme", "Skin",
        "MakeMovable", "ReleaseMovable" }) do
        A.type(t.ns.Modern[name], "function", "ns.Modern." .. name)
    end
end)

h.test("Areas lists registered areas as key and label in registration order", function(t)
    local A, ns = t.assert, t.ns
    local before = #ns.Modern.Areas()
    L.area(t, "zz_a", { label = "Alpha" })
    L.area(t, "zz_b", { label = "Beta" })
    local list = ns.Modern.Areas()
    A.eq(#list, before + 2)
    A.eq(list[before + 1].key, "zz_a"); A.eq(list[before + 1].label, "Alpha")
    A.eq(list[before + 2].key, "zz_b"); A.eq(list[before + 2].label, "Beta")
end)

h.test("Register without apply reports once, skips the entry, other areas still apply", function(t)
    local A, ns = t.assert, t.ns
    local good = L.area(t, "zz_good")
    local ok = pcall(ns.Modern.Register, { key = "zz_bad", label = "Bad" })
    A.ok(ok, "Register must report, not throw")
    A.eq(L.indexOf(ns, "zz_bad"), nil, "bad entry is skipped")
    A.eq(L.errors(t.mock), 1, "exactly one Report message")
    t.boot(false)
    t.mock.printed = {}
    L.enable(); ns.Modern.Apply()
    A.eq(good.apply, 1, "other area still applies")
end)

h.test("Register with a duplicate key reports once and keeps the first entry", function(t)
    local A, ns = t.assert, t.ns
    local first = L.area(t, "zz_dup", { label = "First" })
    local second = L.area(t, "zz_dup", { label = "Second" })
    local other = L.area(t, "zz_other")
    local _, entry = L.indexOf(ns, "zz_dup")
    A.eq(entry.label, "First")
    local count = 0
    for _, a in ipairs(ns.Modern.Areas()) do if a.key == "zz_dup" then count = count + 1 end end
    A.eq(count, 1)
    A.eq(L.errors(t.mock), 1, "exactly one Report message")
    t.boot(false)
    L.enable(); ns.Modern.Apply()
    A.eq(first.apply, 1); A.eq(second.apply, 0); A.eq(other.apply, 1)
end)

h.test("fresh character: Modernize is off and no area applies", function(t)
    local A, ns = t.assert, t.ns
    local a = L.area(t, "zz_a")
    QuietUICharDB = {}
    t.boot()
    ns.Modern.Apply()
    A.eq(a.apply, 0)
    A.ok(not L.zoomed(a.icon), "icon untouched")
    A.alpha(a.art, 0.6, "art alpha untouched")
    A.eq(ns.Settings.Modernize(), false)
end)

h.test("apply runs only when Modernize and the area are on, and only once", function(t)
    local A, ns = t.assert, t.ns
    local a, b = L.area(t, "zz_a"), L.area(t, "zz_b")
    t.boot()
    L.enable({ zz_b = false })
    ns.Modern.Apply(); ns.Modern.Apply()
    A.eq(a.apply, 1, "applied once")
    A.eq(b.apply, 0, "area off is not applied")
    A.ok(L.zoomed(a.icon)); A.ok(not L.zoomed(b.icon))
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    A.ok(not L.zoomed(a.icon), "Modernize off restores the applied area")
end)

h.test("a single area unchecked and applied restores only that area", function(t)
    local A, ns = t.assert, t.ns
    local a, b = L.area(t, "zz_a", { countRestore = true }), L.area(t, "zz_b", { countRestore = true })
    t.boot()
    L.enable(); ns.Modern.Apply()
    A.ok(L.zoomed(a.icon) and L.zoomed(b.icon))
    QuietUICharDB.modernize.zz_a = false
    ns.Modern.Apply()
    A.eq(a.restore, 1); A.eq(b.restore, 0)
    A.ok(not L.zoomed(a.icon), "a restored")
    A.alpha(a.art, 0.6, "a art restored")
    A.ok(L.zoomed(b.icon), "b keeps its skin")
    A.alpha(b.art, 0)
    QuietUICharDB.modernize.zz_a = nil
    ns.Modern.Apply()
    A.eq(a.apply, 2, "re-enabling applies again")
end)

h.test("Restore restores applied areas in reverse registration order", function(t)
    local A, ns = t.assert, t.ns
    local log = {}
    L.area(t, "zz_a", { log = log }); L.area(t, "zz_b", { log = log }); L.area(t, "zz_c", { log = log })
    t.boot()
    L.enable(); ns.Modern.Apply()
    log[#log + 1] = "--"
    ns.Modern.Restore()
    A.deep(log, { "apply:zz_a", "apply:zz_b", "apply:zz_c", "--", "restore:zz_c", "restore:zz_b", "restore:zz_a" })
end)

h.test("a failing area apply reports once, the other areas still apply", function(t)
    local A, ns = t.assert, t.ns
    local a = L.area(t, "zz_a")
    L.area(t, "zz_boom", { apply = function() error("boom") end })
    local c = L.area(t, "zz_c")
    t.boot(false)
    t.mock.printed = {}
    L.enable(); ns.Modern.Apply(); ns.Modern.Apply()
    A.eq(L.errors(t.mock), 1, "one Report message")
    A.eq(a.apply, 1); A.eq(c.apply, 1)
end)

h.test("area events reach onEvent only while the area is applied", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local a = L.area(t, "zz_a", { events = { "ZZ_TEST_EVENT" } })
    t.boot()
    mock:fire("ZZ_TEST_EVENT", 1)
    A.eq(a.event, 0, "not applied yet")
    L.enable(); ns.Modern.Apply()
    mock:fire("ZZ_TEST_EVENT", 7, "x")
    A.eq(a.event, 1)
    A.eq(a.args.event, "ZZ_TEST_EVENT"); A.eq(a.args[1], 7); A.eq(a.args[2], "x")
    A.eq(a.args.skin, a.skin, "onEvent gets the area journal")
    ns.Modern.Restore()
    mock:fire("ZZ_TEST_EVENT", 2)
    A.eq(a.event, 1, "restored area gets no events")
end)

h.test("an event unknown to the client is registered inside pcall and does not break the others", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    mock.badEvents.ZZ_BAD_EVENT = true
    local a = L.area(t, "zz_a", { events = { "ZZ_BAD_EVENT", "ZZ_OK_EVENT" } })
    t.boot(false)
    mock.printed = {}
    L.enable(); ns.Modern.Apply()
    mock:fire("ZZ_OK_EVENT")
    A.eq(a.apply, 1); A.eq(a.event, 1)
end)

h.test("ADDON_LOADED for a listed addon re-runs that area's apply", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local a = L.area(t, "zz_a", { addons = { "Blizzard_Zz" } })
    local b = L.area(t, "zz_b")
    t.boot()
    mock:fire("ADDON_LOADED", "Blizzard_Zz")
    A.eq(a.apply, 0, "Modernize off: nothing runs")
    L.enable(); ns.Modern.Apply()
    A.eq(a.apply, 1)
    mock:fire("ADDON_LOADED", "Blizzard_Other")
    A.eq(a.apply, 1, "other addon is ignored")
    mock:fire("ADDON_LOADED", "Blizzard_Zz")
    A.eq(a.apply, 2, "listed addon re-applies")
    A.eq(b.apply, 1, "other areas are not re-run")
end)

h.test("/quiet off restores every area and releases held alphas, /quiet on reapplies", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local a, b = L.area(t, "zz_a"), L.area(t, "zz_b")
    L.enable()
    t.boot()
    A.eq(a.apply, 1, "boot applies"); A.eq(b.apply, 1)
    A.alpha(a.art, 0)
    a.art:SetAlpha(1)
    A.alpha(a.art, 0, "alpha is held against Blizzard")
    SlashCmdList.QUIETUI("off")
    mock:drain()
    A.ok(not L.zoomed(a.icon) and not L.zoomed(b.icon), "TexCoords restored")
    A.alpha(a.art, 0.6); A.alpha(b.art, 0.6)
    a.art:SetAlpha(1)
    A.alpha(a.art, 1, "hold released")
    SlashCmdList.QUIETUI("on")
    mock:drain()
    A.eq(a.apply, 2, "reapplied with the saved settings"); A.eq(b.apply, 2)
    A.ok(L.zoomed(a.icon) and L.zoomed(b.icon))
    A.alpha(a.art, 0)
end)

h.test("applying and restoring adds no new key to ns and no global", function(t)
    local A, ns = t.assert, t.ns
    L.area(t, "zz_a")
    t.boot()
    local keys = {}
    for k in pairs(ns) do keys[k] = true end
    L.enable(); ns.Modern.Apply(); ns.Modern.Theme(); ns.Modern.Skin("zz_a")
    ns.Modern.Restore()
    local extra = {}
    for k in pairs(ns) do if not keys[k] then extra[#extra + 1] = tostring(k) end end
    A.deep(extra, {}, "new ns keys: " .. table.concat(extra, ", "))
    A.type(ns.Modern, "table")
end)

h.test("only Modern is added to ns by the Modern feature files", function(t)
    local A = t.assert
    local files = {}
    for _, path in ipairs(t.luaFiles({ "Features" })) do
        if path:find("Features/Modern/", 1, true) == 1 then files[#files + 1] = path end
    end
    A.ok(#files >= 4, "Modern feature folder has its files")
    for _, path in ipairs(files) do
        local text = t.readFile(path):gsub("%-%-[^\n]*", "")
        for name in text:gmatch("[^%w_%.]ns%.([%w_]+)%s*=[^=]") do
            A.eq(name, "Modern", path .. " sets ns." .. name)
        end
        for name in text:gmatch("function%s+ns%.([%w_]+)%s*%(") do
            A.eq(name, "Modern", path .. " defines ns." .. name)
        end
    end
end)

-- Builds a real client-shaped fixture for each delivered area. This is deliberately keyed by the
-- runtime registry: adding an area without extending this function fails the shared contract,
-- rather than silently treating that area as covered.
local function Fixture(t, key)
    local ns, mock = t.ns, t.mock
    if key == "bars" then
        local button = I.button(mock, "ActionButton1", MainActionBar)
        local art = I.barArt(MainActionBar, "MainMenuBarTexture0")
        return function(A)
            A.ok(I.zoomed(button.Icon), "bars fixture was skinned")
            A.alpha(art, 0, "bars art was held")
        end
    end
    if key == "auras" then
        local aura = I.aura(mock, "BuffButton1", BuffFrame)
        return function(A) A.ok(I.zoomed(aura.Icon), "aura fixture was skinned") end
    end
    if key == "minimap" then
        local map = M.minimap(mock)
        local oldMask = map:GetMaskTexture()
        GetMinimapShape = nil
        return function(A)
            A.ne(map:GetMaskTexture(), oldMask, "minimap mask was changed")
            A.eq(GetMinimapShape(), "SQUARE", "minimap shape was changed")
        end
    end
    if key == "tooltip" then
        GameTooltip, GameTooltipStatusBar = M.tooltip("GameTooltip", true)
        ItemRefTooltip = M.tooltip("ItemRefTooltip", false)
        ShoppingTooltip1 = M.tooltip("ShoppingTooltip1", false)
        return function(A)
            A.eq(GameTooltipStatusBar:GetAlpha(), 0, "tooltip health bar was hidden")
        end
    end
    if key == "units" then
        local frames = U.fixture()
        return function(A)
            A.ok(U.hidden(frames.player), "unit frame art was held")
            A.eq(U.statusTexture(frames.player.HealthBar), ns.Modern.Theme().bar, "unit health bar was skinned")
        end
    end
    if key == "windows" then
        local character = W.window("CharacterFrame")
        CharacterFrame = character
        return function(A) A.ok(W.isDark(character), "window fixture was skinned") end
    end
    if key == "map" then
        local map = W.window("WorldMapFrame")
        WorldMapFrame = map
        return function(A) A.ok(W.isDark(map), "map fixture was skinned") end
    end
    if key == "status" then
        UnitXP = function() return 0.25 end
        UnitXPMax = function() return 1 end
        GetXPExhaustion = function() return 0.1 end
        GetWatchedFactionInfo = function() return "Faction", 1, 0, 1, 0.7 end
        local before = #mock.frames
        return function(A)
            local xp, reputation
            for i = before + 1, #mock.frames do
                local frame = mock.frames[i]
                if frame._parent == MainStatusTrackingBarContainer and frame._h == 12 then xp = frame end
                if frame._parent == MainStatusTrackingBarContainer and frame._h == 4 then reputation = frame end
            end
            A.type(xp, "table", "status XP bar was created")
            A.type(reputation, "table", "status reputation bar was created")
        end
    end
    error("no real fixture for registered Modern area " .. tostring(key), 0)
end

-- The contract every registered area keeps: it is listed in the runtime order, defaults to on,
-- applies without a Report and restores all observable original state. Fakes keep exercising the
-- journal itself; every non-test area must obtain a concrete fixture above.
h.test("contract: every registered area applies cleanly and restores everything", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    -- One fake that touches every kind of state through the journal helpers.
    local texA, texB = UIParent:CreateTexture(), UIParent:CreateTexture()
    texA:SetTexture("Interface\\Orig-A"); texA:SetTexCoord(0, 1, 0, 1); texA:SetVertexColor(0.2, 0.3, 0.4, 1)
    texB:SetColorTexture(0.5, 0.5, 0.5, 1); texB:SetAlpha(0.8)
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetPoint("CENTER", UIParent, "CENTER", 5, 6)
    frame:SetSize(80, 40)
    L.area(t, "zz_contract", { apply = function(skin)
        skin:Icon(texA)
        skin:Set(texA, "SetTexture", "Interface\\Changed")
        skin:Set(texA, "SetVertexColor", 1, 0, 0, 1)
        skin:Hold(texB)
        skin:Border(frame)
        skin:Panel(frame)
        skin:Set(frame, "SetWidth", 123)
    end })
    local real = {}
    for _, area in ipairs(ns.Modern.Areas()) do
        A.eq(ns.Settings.ModernArea(area.key), false, area.key .. " is gated while Modernize is off")
        if area.key:sub(1, 3) ~= "zz_" then real[area.key] = Fixture(t, area.key) end
    end
    t.boot()
    L.enable()
    for _, area in ipairs(ns.Modern.Areas()) do
        A.eq(ns.Settings.ModernArea(area.key), true, area.key .. " defaults to on")
        A.type(area.label, "string", area.key .. " label")
    end
    local snap = L.snapshot(mock.frames)
    mock.printed = {}
    ns.Modern.Apply()
    A.eq(L.errors(mock), 0, "apply reports nothing")
    A.ok(#L.diff(snap) > 0, "the fake area changed something")
    A.ok(L.zoomed(texA)); A.alpha(texB, 0)
    for key, assertApplied in pairs(real) do assertApplied(A, key) end
    ns.Modern.Restore()
    A.deep(L.diff(snap), {}, "state differs after restore")
    texB:SetAlpha(1)
    A.alpha(texB, 1, "no alpha held after restore")
    A.eq(L.errors(mock), 0, "restore reports nothing")
end)
