-- Modern unit frames: a grey health fill, power type colours after Blizzard updates, and names in their class
-- or reaction colour while class colours are on.
local h = ...
local U = h.lib("modern-units")

local GREY = { 0.22, 0.23, 0.25 }

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

local function setup(t)
    local frames = U.frames()
    local tokens = U.installColours(t.mock)
    return frames, tokens
end

local function rgb(text)
    local r, g, b = text:GetTextColor()
    return { r, g, b }
end

h.test("every health fill is the quiet grey, also after Blizzard recolours or retextures it", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    enable(ns)
    for _, f in ipairs(frames) do A.deep({ U.rgb(U.parts(f).health) }, GREY, f:GetName() .. " grey health") end
    local health = U.parts(frames[3]).health
    health:SetStatusBarColor(0, 1, 0)
    A.deep({ U.rgb(health) }, GREY, "grey after Blizzard SetStatusBarColor")
    health:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health")
    A.eq(U.statusTexture(health), ns.Modern.Theme().bar, "theme texture returns after Blizzard retextures")
    A.deep({ U.rgb(health) }, GREY, "grey after Blizzard retextures")
end)

h.test("class colours on: a player target's name takes its class colour, an NPC's its reaction colour", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    local name = frames[3].Name
    name:SetTextColor(1, 0.82, 0)
    mock:setUnit("target", { exists = true, player = true })
    enable(ns)
    A.deep(rgb(name), { 0.25, 0.78, 0.92 }, "class colour")
    mock:setUnit("target", { exists = true, player = false })
    mock:fire("PLAYER_TARGET_CHANGED")
    A.deep(rgb(name), { 0.8, 0.1, 0.1 }, "reaction colour")
    A.alpha(frames[1].Name, 0, "the player's own name stays held")
    QuietUICharDB.modernize.classColors = false
    ns.Modern.Apply()
    A.deep(rgb(name), { 1, 0.82, 0 }, "class colours off: Blizzard's colour")
    QuietUICharDB.modernize.classColors = nil
    ns.Modern.Apply()
    ns.Modern.Restore()
    A.deep(rgb(name), { 1, 0.82, 0 }, "restore: Blizzard's colour")
end)

h.test("health colours stop following Blizzard after the area restores", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    enable(ns)
    local health = U.parts(frames[3]).health
    ns.Modern.Restore()
    A.deep({ U.rgb(health) }, { 0, 1, 0 }, "Blizzard health colour restored")
    health:SetStatusBarColor(0.1, 0.2, 0.3)
    A.deep({ U.rgb(health) }, { 0.1, 0.2, 0.3 }, "colour hook is inert after restore")
end)

h.test("power bars keep the flat texture and the power type colour after UnitFrameManaBar_UpdateType", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames, tokens = setup(t)
    tokens.player, tokens.target = "MANA", "RAGE"
    mock:setUnit("target", { exists = true, player = false })
    enable(ns)
    local mana, rage = U.parts(frames[1]).mana, U.parts(frames[3]).mana
    A.deep({ U.rgb(mana) }, { 0.2, 0.45, 0.9 }, "mana in a softer blue than Blizzard's on apply")
    A.deep({ U.rgb(rage) }, { 1, 0, 0 }, "rage colour on apply")
    UnitFrameManaBar_UpdateType(mana)
    UnitFrameManaBar_UpdateType(rage)
    A.eq(U.statusTexture(mana), ns.Modern.Theme().bar, "player power keeps flat texture")
    A.eq(U.statusTexture(rage), ns.Modern.Theme().bar, "target power keeps flat texture")
    A.deep({ U.rgb(mana) }, { 0.2, 0.45, 0.9 }, "softer mana after update")
    A.deep({ U.rgb(rage) }, { 1, 0, 0 }, "rage colour after update")
    tokens.target = "ENERGY"
    UnitFrameManaBar_UpdateType(rage)
    A.deep({ U.rgb(rage) }, { 1, 1, 0 }, "power type change recolours")
    for _, f in ipairs({ frames[2], frames[4] }) do
        A.eq(U.statusTexture(U.parts(f).mana), ns.Modern.Theme().bar, f:GetName() .. " power texture")
    end
end)

h.test("restoring leaves Blizzard's power texture and colour in charge", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames, tokens = setup(t)
    tokens.target = "RAGE"
    mock:setUnit("target", { exists = true, player = false })
    local mana = U.parts(frames[3]).mana
    local original = U.statusTexture(mana)
    enable(ns)
    ns.Modern.Restore()
    A.eq(U.statusTexture(mana), original, "Blizzard power texture back")
    A.deep({ U.rgb(mana) }, { 1, 1, 1 }, "Blizzard power colour back")
    UnitFrameManaBar_UpdateType(mana)
    A.eq(U.statusTexture(mana), "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana", "update texture is Blizzard's")
    A.deep({ U.rgb(mana) }, { 1, 1, 1 }, "update colour is Blizzard's")
end)
