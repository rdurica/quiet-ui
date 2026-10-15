-- Modern XP and reputation bars against retail 12.0: C_Reputation.GetWatchedFactionData() (no
-- GetWatchedFactionInfo), rested drawn behind the XP fill as xp..xp+exhaustion, Blizzard's bar art
-- (StatusTrackingBar > StatusBar Background / Underlay / Overlay) held, own bars parented under
-- MainStatusTrackingBarContainer so its alpha fade applies.
local h = ...
local L = h.lib("modern")

local function enable() QuietUICharDB = { modernize = { enabled = true } } end

local function data(mock)
    mock.xp, mock.rested = 0.25, 0.1
    mock.faction = { factionID = 72, reaction = 5, currentReactionThreshold = 3000,
        nextReactionThreshold = 6000, currentStanding = 4500 }
    GetWatchedFactionInfo = nil
    C_Reputation = { GetWatchedFactionData = function() return mock.faction end }
    UnitXP = function() return mock.xp end
    UnitXPMax = function() return 1 end
    GetXPExhaustion = function() return mock.rested end
end

local function direct(mock, height)
    for _, f in ipairs(mock.frames) do
        if f._parent == MainStatusTrackingBarContainer and f._h == height and f._kind == "StatusBar" then return f end
    end
end

local function restedBar(xp)
    local function walk(frame)
        for _, child in ipairs(frame._children) do
            if child ~= xp and child._kind == "StatusBar" and child._h == 6 then return child end
            local found = walk(child)
            if found then return found end
        end
    end
    return walk(MainStatusTrackingBarContainer)
end

local function blizzardBar()
    local bar = CreateFrame("Frame", nil, MainStatusTrackingBarContainer)
    bar:EnableMouse(true)
    bar.StatusBar = CreateFrame("StatusBar", nil, bar)
    local function art(key, alpha)
        local t = bar.StatusBar:CreateTexture(nil, "BACKGROUND")
        t:SetTexture("Interface\\Blizzard\\" .. key); t:SetAlpha(alpha or 1)
        bar.StatusBar[key] = t
        return t
    end
    art("Background"); art("Underlay", 0.8); art("Overlay", 0.7)
    local fill = bar.StatusBar:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Blizzard\\Fill")
    bar.StatusBar.GetStatusBarTexture = function() return fill end
    bar.Fill = fill
    bar.OverlayFrame = CreateFrame("Frame", nil, bar)
    bar.OverlayFrame.Text = bar.OverlayFrame:CreateFontString(nil, "OVERLAY")
    bar.OverlayFrame.Text:SetText("12 / 100")
    return bar
end

h.test("12.0 reputation reads C_Reputation.GetWatchedFactionData thresholds and standing", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    enable(); ns.Modern.Apply()
    local rep = direct(mock, 4)
    A.type(rep, "table", "a 4 px reputation bar")
    A.eq(rep._min, 3000, "min is currentReactionThreshold")
    A.eq(rep._max, 6000, "max is nextReactionThreshold")
    A.eq(rep:GetValue(), 4500, "value is currentStanding")
    A.ok(rep:IsShown(), "shown while a faction is watched")
    mock.faction.currentStanding = 5000
    mock:fire("UPDATE_FACTION")
    A.eq(rep:GetValue(), 5000, "UPDATE_FACTION refreshes the standing")
    A.eq(L.errors(mock), 0, "no Report on a client without GetWatchedFactionInfo")
end)

h.test("12.0 no watched faction hides the reputation bar and a new watch shows it again", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    mock.faction = nil
    enable(); ns.Modern.Apply()
    local rep = direct(mock, 4)
    A.type(rep, "table", "the reputation bar exists")
    A.falsy(rep:IsShown(), "nothing watched: hidden")
    mock.faction = { factionID = 0 } -- Blizzard treats factionID 0 as not watching
    mock:fire("UPDATE_FACTION")
    A.falsy(rep:IsShown(), "factionID 0 is not watching")
    mock.faction = { factionID = 72, reaction = 5, currentReactionThreshold = 0,
        nextReactionThreshold = 1000, currentStanding = 400 }
    mock:fire("UPDATE_FACTION")
    A.ok(rep:IsShown(), "watching again shows it")
    A.eq(rep:GetValue(), 400)
    mock.faction = nil
    mock:fire("UPDATE_FACTION")
    A.falsy(rep:IsShown(), "unwatching hides it again")
end)

h.test("12.0 rested is a lighter bar behind the XP fill covering xp to xp plus exhaustion, capped at the maximum", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    enable(); ns.Modern.Apply()
    local xp = direct(mock, 6)
    local rested = restedBar(xp)
    A.type(rested, "table", "a rested bar")
    A.near(rested:GetValue(), 0.35, 1e-6, "xp 0.25 + rested 0.1")
    A.eq(xp:GetValue(), 0.25, "the XP fill is the real value, not hidden by the rested bar")
    A.ok(rested:GetFrameLevel() < xp:GetFrameLevel(), "rested is drawn behind the XP fill")
    mock.rested = 0.9
    mock:fire("UPDATE_EXHAUSTION")
    A.eq(rested:GetValue(), 1, "capped at the maximum")
    mock.rested = nil
    mock:fire("UPDATE_EXHAUSTION")
    A.ok(not rested:IsShown() or rested:GetValue() <= xp:GetValue(), "no rested XP: nothing beyond the fill")
    A.eq(xp:GetValue(), 0.25)
end)

h.test("12.0 a gain moves rested with the XP value and a level up sets the bar directly", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    enable(); ns.Modern.Apply()
    local xp = direct(mock, 6)
    mock.xp = 0.5; mock:fire("PLAYER_XP_UPDATE", "player")
    mock:tick(0.4); mock:tick(0.1)
    A.eq(xp:GetValue(), 0.5, "animation ended on the new value")
    A.near(restedBar(xp):GetValue(), 0.6, 1e-6, "rested follows xp + exhaustion")
    A.falsy(xp:GetScript("OnUpdate"), "no OnUpdate after the animation")
    mock.xp = 0.05; mock:fire("PLAYER_LEVEL_UP", 2); mock:fire("PLAYER_XP_UPDATE", "player")
    A.eq(xp:GetValue(), 0.05, "a lower value after a level up is set directly")
    A.falsy(xp:GetScript("OnUpdate"), "no animation for a level up")
end)

h.test("12.0 the spark texture exists and the glow uses it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    A.ok(t.fileExists("Media/spark.tga"), "Media/spark.tga is shipped")
    enable(); ns.Modern.Apply()
    local found
    for _, f in ipairs(mock.frames) do
        if f._kind == "Texture" and f._texture == "Interface\\AddOns\\QuietUI\\Media\\spark.tga" then found = true end
    end
    A.ok(found, "a status texture uses the spark path")
end)

h.test("12.0 own bars sit under the container so its fade applies and they never set their own alpha", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    MainStatusTrackingBarContainer:SetAlpha(0.3)
    enable(); ns.Modern.Apply()
    local xp, rep = direct(mock, 6), direct(mock, 4)
    for _, bar in ipairs({ xp, rep, restedBar(xp) }) do
        A.eq(bar:GetEffectiveAlpha(), 0.3, "the container fade reaches the bar")
        A.eq(bar._alpha, 1, "the bar keeps alpha 1 so the fade is the only owner")
    end
    MainStatusTrackingBarContainer:SetAlpha(1)
    A.eq(xp:GetEffectiveAlpha(), 1)
    A.alpha(MainStatusTrackingBarContainer, 1, "the area does not own the container alpha")
end)

h.test("12.0 Blizzard bar art is held hidden, mouse and text stay, and restore releases everything", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    local frameArt = MainStatusTrackingBarContainer:CreateTexture(nil, "OVERLAY")
    frameArt:SetTexture("Interface\\Blizzard\\BarFrame"); frameArt:SetAlpha(0.9)
    MainStatusTrackingBarContainer.BarFrameTexture = frameArt
    local blizz = blizzardBar()
    enable(); ns.Modern.Apply()
    local sb = blizz.StatusBar
    for _, region in ipairs({ frameArt, sb.Background, sb.Underlay, sb.Overlay, blizz.Fill }) do
        A.alpha(region, 0, "Blizzard art is held")
    end
    A.ok(blizz:IsMouseEnabled(), "Blizzard mouse behaviour stays (tooltip)")
    A.eq(blizz.OverlayFrame.Text:GetText(), "12 / 100", "Blizzard text stays")
    sb.Overlay:SetAlpha(1) -- Blizzard's gain animation tries to show it
    A.alpha(sb.Overlay, 0, "Blizzard cannot bring the art back while applied")

    QuietUICharDB.modernize.status = false
    ns.Modern.Apply()
    A.alpha(frameArt, 0.9, "frame art released")
    A.alpha(sb.Background, 1, "background released")
    A.alpha(sb.Underlay, 0.8, "underlay released")
    A.alpha(blizz.Fill, 1, "fill released")
    for _, f in ipairs({ direct(mock, 6), direct(mock, 4) }) do A.falsy(f:IsShown(), "own bar hidden after restore") end
    A.falsy(direct(mock, 6):GetScript("OnUpdate"), "no OnUpdate left behind")
end)

h.test("12.0 restore in the middle of a gain stops the animation", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    data(mock)
    enable(); ns.Modern.Apply()
    local xp = direct(mock, 6)
    mock.xp = 0.75; mock:fire("PLAYER_XP_UPDATE", "player")
    A.ok(xp:GetScript("OnUpdate"), "animation running")
    QuietUICharDB.modernize.status = false
    ns.Modern.Apply()
    A.falsy(xp:GetScript("OnUpdate"), "restore stops it")
    A.eq(L.errors(mock), 0)
end)
