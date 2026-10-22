-- The Status area owns only its thin visual bars. Blizzard keeps the container, text and mouse
-- behaviour so the existing XP fader still controls the complete result.
local h = ...
local L = h.lib("modern")

local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION" }

local function enable()
    QuietUICharDB = { modernize = { enabled = true } }
end

local function area(ns)
    for _, item in ipairs(ns.Modern.Areas()) do
        if item.key == "status" then return item end
    end
end

local function bars(mock, first)
    local found = {}
    for i = first + 1, #mock.frames do
        local frame = mock.frames[i]
        if frame._parent == MainStatusTrackingBarContainer and (frame._h == 12 or frame._h == 4) then
            found[#found + 1] = frame
        end
    end
    return found
end

local function byHeight(list, height)
    for _, frame in ipairs(list) do if frame._h == height then return frame end end
end

local function descendant(frame, root)
    for _ = 1, 30 do
        if frame == root then return true end
        frame = frame and frame._parent
    end
    return false
end

local function playedGlow(mock, xp)
    for _, frame in ipairs(mock.frames) do
        if frame._kind == "AnimationGroup" and frame._plays and frame._plays > 0
            and descendant(frame._owner, xp) then
            return frame
        end
    end
end

-- The rested bar is any other 12 px StatusBar below the container (child of the XP bar or a sibling).
local function restedBar(xp)
    local function walk(frame)
        for _, child in ipairs(frame._children) do
            if child ~= xp and child._kind == "StatusBar" and child._h == 12 then return child end
            local found = walk(child)
            if found then return found end
        end
    end
    return walk(MainStatusTrackingBarContainer)
end

local function installStatusData(mock)
    mock.xp, mock.rested = 0.25, 0.1
    mock.reputation = 0.7
    UnitXP = function() return mock.xp end
    UnitXPMax = function() return 1 end
    GetXPExhaustion = function() return mock.rested end
    GetWatchedFactionInfo = function() return "Faction", 1, 0, 1, mock.reputation end
end

h.test("Status registers XP and reputation in the Modern area list", function(t)
    local A, ns = t.assert, t.ns
    local entry = area(ns)
    A.type(entry, "table", "the status area is registered")
    A.eq(entry.label, "Modern XP bar")
    A.eq(ns.Settings.ModernArea("status"), false, "it follows the Modernize gate")
end)

h.test("Status creates thin XP and watched-reputation bars under Blizzard's container without changing its alpha, mouse or text", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    installStatusData(mock)
    MainStatusTrackingBarContainer:SetAlpha(0.37)
    MainStatusTrackingBarContainer:EnableMouse(true)
    local text = MainStatusTrackingBarContainer:CreateFontString()
    text:SetText("Blizzard XP")
    local before = #mock.frames
    enable(); ns.Modern.Apply()
    local own = bars(mock, before)
    local xp, reputation = byHeight(own, 12), byHeight(own, 4)
    A.type(xp, "table", "a 12 px XP bar")
    A.type(reputation, "table", "a 4 px watched reputation bar")
    A.eq(xp._parent, MainStatusTrackingBarContainer)
    A.eq(reputation._parent, MainStatusTrackingBarContainer)
    local point, relative, relativePoint, x, y = reputation:GetPoint(1)
    A.eq(point, "BOTTOM", "reputation is above XP")
    A.eq(relative, xp, "reputation is anchored to XP")
    A.eq(relativePoint, "TOP", "reputation is above XP")
    A.eq(x, 0)
    A.eq(y, 2, "the bars have a 2 px gap")
    A.alpha(MainStatusTrackingBarContainer, 0.37, "the fader still owns the container alpha")
    A.ok(MainStatusTrackingBarContainer:IsMouseEnabled(), "Blizzard mouse behaviour remains")
    A.eq(text:GetText(), "Blizzard XP", "Blizzard text remains")
    local rested = restedBar(xp)
    A.type(rested, "table", "a rested bar follows the XP bar")
    A.near(rested:GetValue(), 0.35, 1e-6, "rested fill covers xp..xp+exhaustion (0.25 + 0.1)")
end)

h.test("Status updates on every XP and faction event and animates a normal XP gain for 0.4 seconds", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    installStatusData(mock)
    enable(); ns.Modern.Apply()
    for _, name in ipairs(EVENTS) do
        A.ok(mock:eventFrame(name), "missing registered " .. name)
    end
    local before = #mock.frames
    mock.xp = 0.25; mock:fire("PLAYER_XP_UPDATE", "player")
    local xp = byHeight(bars(mock, before), 12) or byHeight(bars(mock, 0), 12)
    A.type(xp, "table", "the XP visual bar")
    mock.xp = 0.75; mock:fire("PLAYER_XP_UPDATE", "player")
    A.ok(xp:GetScript("OnUpdate"), "gain starts the only per-frame animation")
    mock:tick(0.2)
    A.ok(xp:GetValue() > 0.25 and xp:GetValue() < 0.75, "fill interpolates during the gain")
    mock:tick(0.2)
    A.eq(xp:GetValue(), 0.75, "fill reaches the new value at 0.4 seconds")
    A.falsy(xp:GetScript("OnUpdate"), "no per-frame work remains when idle")
    local glow = playedGlow(mock, xp)
    A.type(glow, "table", "end glow plays after the gain")
    mock.rested = 0.2; mock:fire("UPDATE_EXHAUSTION")
    mock:fire("PLAYER_LEVEL_UP", 2)
    mock.reputation = 0.3; mock:fire("UPDATE_FACTION")
    A.eq(xp:GetValue(), 0.75, "non-gain events refresh without resetting XP")
    local reputation = byHeight(bars(mock, 0), 4)
    A.eq(reputation:GetValue(), 0.3, "UPDATE_FACTION refreshes watched reputation")
end)

h.test("Status passes secret XP straight to its widget without arithmetic, comparison or animation", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    installStatusData(mock)
    local secret = setmetatable({}, {
        __add = function() error("secret XP was added") end,
        __sub = function() error("secret XP was subtracted") end,
        __mul = function() error("secret XP was multiplied") end,
        __div = function() error("secret XP was divided") end,
        __lt = function() error("secret XP was compared") end,
        __le = function() error("secret XP was compared") end,
    })
    mock.secrets[secret] = true
    mock.xp = secret
    enable(); ns.Modern.Apply()
    local xp = byHeight(bars(mock, 0), 12)
    A.type(xp, "table", "the XP visual bar")
    A.eq(xp:GetValue(), secret, "the widget receives the secret value itself")
    A.falsy(xp:GetScript("OnUpdate"), "secret values never animate")
end)

h.test("Status never does arithmetic or comparison on a secret rested value", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    installStatusData(mock)
    local secret = setmetatable({}, {
        __add = function() error("secret rested XP was added") end,
        __sub = function() error("secret rested XP was subtracted") end,
        __lt = function() error("secret rested XP was compared") end,
        __le = function() error("secret rested XP was compared") end,
    })
    mock.secrets[secret] = true
    mock.rested = secret
    enable(); ns.Modern.Apply()
    local xp = byHeight(bars(mock, 0), 12)
    A.type(xp, "table", "the XP visual bar")
    A.eq(L.errors(mock), 0, "a secret rested value is never added to or compared with the XP value")
    A.eq(xp:GetValue(), 0.25, "the XP fill is unaffected by a secret rested value")
end)

h.test("Status restores original art and reuses its own bars across Modernize and addon off/on", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    installStatusData(mock)
    A.type(area(ns), "table", "the status area is registered")
    local original = MainStatusTrackingBarContainer:CreateTexture()
    original:SetTexture("Interface\\OriginalStatus")
    original:SetAlpha(0.63)
    MainStatusTrackingBarContainer:SetPoint("TOP", UIParent, "TOP", 3, -4)
    local before = #mock.frames
    enable(); ns.Modern.Apply()
    local created = #mock.frames - before
    A.ok(created > 0, "Status creates its visual regions")
    QuietUICharDB.modernize.status = false; ns.Modern.Apply()
    A.eq(original:GetTexture(), "Interface\\OriginalStatus")
    A.alpha(original, 0.63)
    local _, _, _, x = MainStatusTrackingBarContainer:GetPoint()
    A.eq(x, 3)
    QuietUICharDB.modernize.status = nil; ns.Modern.Apply()
    A.eq(#mock.frames - before, created, "own visual regions are reused")
    SlashCmdList.QUIETUI("off"); mock:drain()
    A.eq(original:GetTexture(), "Interface\\OriginalStatus", "off restores immediately")
    SlashCmdList.QUIETUI("on"); mock:drain()
    A.eq(#mock.frames - before, created, "on reuses the same visual regions")
end)

h.test("Status skips missing or forbidden pieces without stopping the rest of Modernize", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    installStatusData(mock)
    A.type(area(ns), "table", "the status area is registered")
    MainStatusTrackingBarContainer._forbidden = true
    local other = L.area(t, "zz_status_neighbour")
    enable()
    A.noThrow(ns.Modern.Apply)
    A.eq(other.apply, 1, "another area still applies")
    A.eq(#bars(mock, 0), 0, "no visual child is attached to a forbidden container")
end)
