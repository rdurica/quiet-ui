-- Modern unit frames: visuals compose with the existing Faders ownership and never inspect secrets.
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

local function unit(t, name)
    for _, f in ipairs(U.frames()) do if f:GetName() == name then return f end end
end

h.test("units skin every available unit frame without changing size, layout or fade alpha", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    local before = {}
    for _, f in ipairs(frames) do
        f:SetAlpha(0.37)
        f:SetPoint("CENTER", UIParent, "CENTER", 11, -13)
        before[f] = { f:GetWidth(), f:GetHeight(), f:GetAlpha(), f:GetPoint() }
    end
    enable(ns)
    for _, f in ipairs(frames) do
        A.ok(U.hidden(f), f:GetName() .. " Blizzard art held")
        for _, value in ipairs({ f.HealthBar, f.ManaBar }) do
            A.eq(U.statusTexture(value), ns.Modern.Theme().bar, f:GetName() .. " bar texture")
            A.ok(U.panel(value), f:GetName() .. " bar has themed background")
            A.ok(U.border(value), f:GetName() .. " bar has one-pixel border")
        end
        A.eq(f:GetWidth(), before[f][1], f:GetName() .. " width")
        A.eq(f:GetHeight(), before[f][2], f:GetName() .. " height")
        A.alpha(f, before[f][3], f:GetName() .. " Faders alpha")
        A.eq(f:GetPoint(), before[f][4], f:GetName() .. " point")
    end
end)

h.test("units crop standard portraits, remove supported masks, and restore portrait inputs", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    local before = {}
    for _, f in ipairs(frames) do
        local a, b, c, d = f.Portrait:GetTexCoord()
        before[f] = { a, b, c, d, f.Portrait:GetMaskTexture(1) }
    end
    enable(ns)
    for _, f in ipairs(frames) do
        local a, b, c, d = f.Portrait:GetTexCoord()
        A.deep({ a, b, c, d }, { 0.08, 0.92, 0.08, 0.92 }, f:GetName() .. " square crop")
        A.eq(f.Portrait:GetNumMaskTextures(), 0, f:GetName() .. " supported portrait mask removed")
        A.ok(U.portraitBorder(f), f:GetName() .. " portrait border")
    end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do
        A.deep({ f.Portrait:GetTexCoord() }, { before[f][1], before[f][2], before[f][3], before[f][4] },
            f:GetName() .. " portrait crop restored")
        A.eq(f.Portrait:GetMaskTexture(1), before[f][5], f:GetName() .. " portrait mask restored")
    end
end)

h.test("units restore every owned treatment when their area or Modernize turns off, then reapply", function(t)
    local A, ns = t.assert, t.ns
    local player = unit(t, "PlayerFrame")
    enable(ns)
    A.ok(U.hidden(player), "area applied")
    QuietUICharDB.modernize.units = false
    ns.Modern.Apply()
    A.alpha(player.Border, 0.7, "frame art released when area is off")
    A.eq(U.statusTexture(player.HealthBar), "Interface\\TargetingFrame\\PlayerFrameHealth", "bar texture restored")
    A.deep({ player.Portrait:GetTexCoord() }, { 0, 1, 0, 1 }, "portrait crop restored")
    A.eq(player.Portrait:GetMaskTexture(1):GetTexture(), "Interface\\CharacterFrame\\TempPortraitAlphaMask", "mask restored")
    A.ok(not U.portraitBorder(player), "own portrait border hidden")
    QuietUICharDB.modernize.units = nil
    ns.Modern.Apply()
    A.ok(U.hidden(player), "area reapplied")
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    A.alpha(player.Border, 0.7, "Modernize off restores art")
    QuietUICharDB.modernize.enabled = true
    ns.Modern.Apply()
    A.ok(U.hidden(player), "Modernize on reapplies area")
end)

h.test("units colour health after Blizzard updates: player class, NPC reaction, and disabled class colours", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local target = unit(t, "TargetFrame")
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    C_ClassColor = { GetClassColor = function(token) return RAID_CLASS_COLORS[token] end }
    UnitClass = function(token) if token == "target" then return "Mage", "MAGE" end end
    UnitReaction = function(token) if token == "target" then return 3 end end
    FACTION_BAR_COLORS = { [3] = { r = 1, g = 0.1, b = 0.1 } }
    mock:setUnit("target", { exists = true, player = true })
    enable(ns)
    target.HealthBar:SetStatusBarColor(0.1, 0.1, 0.1, 1)
    A.deep({ U.colour(target.HealthBar) }, { 0.25, 0.78, 0.92, 1 }, "class colour follows Blizzard update")
    mock:setUnit("target", { exists = true, player = false })
    target.HealthBar:SetStatusBarColor(0.2, 0.2, 0.2, 1)
    A.deep({ U.colour(target.HealthBar) }, { 1, 0.1, 0.1, 1 }, "hostile NPC reaction colour")
    QuietUICharDB.modernize.classColors = false
    ns.Modern.Apply()
    target.HealthBar:SetStatusBarColor(0.6, 0.5, 0.4, 1)
    A.deep({ U.colour(target.HealthBar) }, { 0.6, 0.5, 0.4, 1 }, "Blizzard colour remains when class colours are off")
end)

h.test("units refresh target colour on target-change events and select elite, rare and boss portrait borders", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local target = unit(t, "TargetFrame")
    UnitReaction = function() return 5 end
    FACTION_BAR_COLORS = { [5] = { r = 0.2, g = 0.8, b = 0.2 } }
    enable(ns)
    for _, spec in ipairs({
        { "elite", { 0.95, 0.75, 0.25 } },
        { "rare", { 0.85, 0.85, 0.85 } },
        { "rareelite", { 0.85, 0.85, 0.85 } },
        { "worldboss", { 0.9, 0.15, 0.15 } },
    }) do
        mock:setUnit("target", { exists = true, player = false, classification = spec[1] })
        mock:fire("PLAYER_TARGET_CHANGED")
        local c = U.portraitBorderColor(target)
        A.deep({ c[1], c[2], c[3] }, spec[2], spec[1] .. " portrait border")
        A.deep({ U.colour(target.HealthBar) }, { 0.2, 0.8, 0.2, 1 }, spec[1] .. " target event refreshes health colour")
    end
end)

h.test("units never read secret health or power and safely skip missing or forbidden controls", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    local target = unit(t, "TargetFrame")
    UnitHealth = function() error("health was read", 0) end
    UnitHealthMax = function() error("health max was read", 0) end
    UnitPower = function() error("power was read", 0) end
    UnitPowerMax = function() error("power max was read", 0) end
    FocusFrame = nil
    target.ManaBar._forbidden = true
    A.noThrow(function() enable(ns) end)
    A.ok(U.hidden(PlayerFrame), "valid player frame still skins")
    A.eq(U.statusTexture(target.ManaBar), "Interface\\TargetingFrame\\TargetFramePower", "forbidden power bar skipped")
    A.eq(#t.mock.printed, 0, "missing focus and forbidden controls do not break other unit skins")
    ns.Modern.Restore()
    A.alpha(PlayerFrame.Border, 0.7, "restore releases held frame art")
end)
