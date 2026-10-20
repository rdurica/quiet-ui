-- Modern unit frames on the retail 12.0 frame structure: art, bars, restore, secrets, missing frames.
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

h.test("units hold every Blizzard frame art texture at alpha 0 and release them when the area is off", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    enable(ns)
    for _, f in ipairs(frames) do
        for i, alpha in ipairs(U.artAlpha(f)) do
            A.eq(alpha, 0, f:GetName() .. " art #" .. i .. " held")
        end
    end
    local flash = U.parts(frames[1]).flash
    flash:Show(); flash:SetAlpha(1)
    A.alpha(flash, 0, "Blizzard showing the combat flash cannot undo the hold")
    QuietUICharDB.modernize.units = false
    ns.Modern.Apply()
    for _, f in ipairs(frames) do
        for i, alpha in ipairs(U.artAlpha(f)) do
            A.eq(alpha, 1, f:GetName() .. " art #" .. i .. " released")
        end
    end
    QuietUICharDB.modernize.units = nil
    ns.Modern.Apply()
    A.ok(U.hidden(frames[3]), "area reapplied")
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    A.eq(U.parts(frames[3]).art[1]:GetAlpha(), 1, "Modernize off releases art")
end)

h.test("the boss and elite portrait frame stays hidden when Blizzard shows it on a target change", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    local target = frames[3]
    enable(ns)
    mock:setUnit("target", { exists = true, player = false, classification = "elite" })
    U.blizzardBossFrame(target, "elite")
    mock:fire("PLAYER_TARGET_CHANGED")
    A.alpha(U.parts(target).boss, 0, "elite portrait frame texture")
    A.alpha(U.parts(target).art[4], 0, "reputation colour")
end)

h.test("units skin frames in place without changing size, points or fade alpha", function(t)
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
        A.eq(f:GetWidth(), before[f][1], f:GetName() .. " width")
        A.eq(f:GetHeight(), before[f][2], f:GetName() .. " height")
        A.alpha(f, before[f][3], f:GetName() .. " Faders alpha")
        A.eq(f:GetPoint(), before[f][4], f:GetName() .. " point")
    end
end)

h.test("health and power bars get the theme texture inside one bordered box and carry no border of their own", function(t)
    local A, ns = t.assert, t.ns
    local frames = U.frames()
    local old = {}
    for _, f in ipairs(frames) do
        local p = U.parts(f)
        old[f] = { U.statusTexture(p.health), U.statusTexture(p.mana) }
        A.ok(old[f][1] ~= ns.Modern and old[f][1], f:GetName() .. " fixture has a Blizzard texture")
    end
    enable(ns)
    for _, f in ipairs(frames) do
        local p = U.parts(f)
        for _, value in ipairs({ p.health, p.mana }) do
            A.eq(U.statusTexture(value), ns.Modern.Theme().bar, f:GetName() .. " bar texture")
            A.ok(not U.border(value), f:GetName() .. " bar has no own border")
        end
        A.ok(U.onePixelOn(f, U.barBox(f)), f:GetName() .. " box has a one pixel border")
    end
    ns.Modern.Restore()
    for _, f in ipairs(frames) do
        local p = U.parts(f)
        A.eq(U.statusTexture(p.health), old[f][1], f:GetName() .. " health texture restored")
        A.eq(U.statusTexture(p.mana), old[f][2], f:GetName() .. " power texture restored")
        A.ok(not U.barBox(f), f:GetName() .. " box hidden")
    end
end)

h.test("units restore every treatment when their area or Modernize turns off, then reapply", function(t)
    local A, ns = t.assert, t.ns
    local player = U.frames()[1]
    local p = U.parts(player)
    local original = U.statusTexture(p.health)
    enable(ns)
    A.eq(U.statusTexture(p.health), ns.Modern.Theme().bar, "area applied")
    QuietUICharDB.modernize.units = false
    ns.Modern.Apply()
    A.eq(U.statusTexture(p.health), original, "bar texture restored")
    A.alpha(p.portrait, 1, "portrait released")
    QuietUICharDB.modernize.units = nil
    ns.Modern.Apply()
    A.eq(U.statusTexture(p.health), ns.Modern.Theme().bar, "area reapplied")
    QuietUICharDB.modernize.enabled = nil
    ns.Modern.Apply()
    A.eq(U.statusTexture(p.health), original, "Modernize off restores bars")
end)

h.test("units never read secret health or power values and skip missing or forbidden controls quietly", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = U.frames()
    local secret = U.secrets(mock)
    U.installColours(mock)
    for _, f in ipairs(frames) do
        local p = U.parts(f)
        p.health:SetValue(secret(50)); p.mana:SetValue(secret(5))
        p.health:SetMinMaxValues(secret(0), secret(100))
        p.mana:SetMinMaxValues(secret(0), secret(10))
    end
    mock:setUnit("target", { exists = true, player = true, classification = "elite" })
    FocusFrame = nil
    U.parts(frames[3]).mana._forbidden = true
    A.noThrow(function() enable(ns) end)
    A.noThrow(function()
        mock:fire("PLAYER_TARGET_CHANGED")
        UnitFrameManaBar_UpdateType(U.parts(frames[1]).mana)
        U.parts(frames[1]).health:SetStatusBarColor(0, 1, 0)
    end)
    A.ok(U.hidden(frames[1]), "valid player frame still skins")
    A.eq(U.statusTexture(U.parts(frames[3]).mana), "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana",
        "forbidden power bar skipped")
    A.eq(#mock.printed, 0, "missing focus and forbidden controls print nothing")
    ns.Modern.Restore()
    A.eq(U.parts(frames[1]).art[1]:GetAlpha(), 1, "restore releases held frame art")
    A.eq(#mock.printed, 0, "restore prints nothing")
end)
