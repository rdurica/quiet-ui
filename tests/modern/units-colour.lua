-- Modern unit frames: health colours (class, reaction, flat green) and power colours after Blizzard updates.
local h = ...
local U = h.lib("modern-units")

local function enable(ns, extra)
    extra = extra or {}
    extra.enabled = true
    QuietUICharDB = { modernize = extra }
    ns.Modern.Apply()
end

-- Fills are drawn at 80 % of the unit's colour, so the white value text stands out.
local function dim(c) return { c[1] * 0.8, c[2] * 0.8, c[3] * 0.8 } end

local function setup(t)
    local frames = U.frames()
    local tokens = U.installColours(t.mock)
    return frames, tokens
end

h.test("class colours off give the flat health texture a green colour instead of white", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    enable(ns, { classColors = false })
    for _, f in ipairs(frames) do
        local r, g, b = U.rgb(U.parts(f).health)
        A.ok(g > r and g > b, f:GetName() .. " health is green, got " .. r .. "," .. g .. "," .. b)
    end
    local health = U.parts(frames[3]).health
    health:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health")
    local r, g, b = U.rgb(health)
    A.eq(U.statusTexture(health), ns.Modern.Theme().bar, "theme texture returns after Blizzard retextures")
    A.ok(g > r and g > b, "green again after Blizzard retextures the bar")
end)

h.test("class colours on: player target gets its class colour, re-applied after Blizzard updates", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = true })
    mock:setUnit("player", { exists = true, player = true })
    enable(ns)
    local mage = dim({ 0.25, 0.78, 0.92 })
    local health = U.parts(frames[3]).health
    A.deep({ U.rgb(health) }, mage, "class colour on apply")
    A.deep({ U.rgb(U.parts(frames[1]).health) }, mage, "player frame class colour")
    health:SetStatusBarColor(0, 1, 0)
    A.deep({ U.rgb(health) }, mage, "class colour follows Blizzard SetStatusBarColor")
    health:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health")
    A.eq(U.statusTexture(health), ns.Modern.Theme().bar, "theme texture follows Blizzard SetStatusBarTexture")
    A.deep({ U.rgb(health) }, mage, "class colour follows Blizzard SetStatusBarTexture")
end)

h.test("class colours on: hostile NPC target gets its reaction colour after Blizzard updates", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    local frames = setup(t)
    mock:setUnit("target", { exists = true, player = false })
    enable(ns)
    local health = U.parts(frames[3]).health
    A.deep({ U.rgb(health) }, dim({ 0.8, 0.1, 0.1 }), "reaction colour on apply")
    health:SetStatusBarColor(0, 1, 0)
    A.deep({ U.rgb(health) }, dim({ 0.8, 0.1, 0.1 }), "reaction colour follows Blizzard update")
    health:SetStatusBarTexture("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health")
    A.deep({ U.rgb(health) }, dim({ 0.8, 0.1, 0.1 }), "reaction colour follows retexture")
    QuietUICharDB.modernize.classColors = false
    ns.Modern.Apply()
    health:SetStatusBarColor(0, 1, 0)
    local r, g, b = U.rgb(health)
    A.ok(g > r and g > b, "class colours turned off live go flat green")
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
    A.deep({ U.rgb(mana) }, dim({ 0.2, 0.45, 0.9 }), "mana in a softer blue than Blizzard's on apply")
    A.deep({ U.rgb(rage) }, dim({ 1, 0, 0 }), "rage colour on apply")
    UnitFrameManaBar_UpdateType(mana)
    UnitFrameManaBar_UpdateType(rage)
    A.eq(U.statusTexture(mana), ns.Modern.Theme().bar, "player power keeps flat texture")
    A.eq(U.statusTexture(rage), ns.Modern.Theme().bar, "target power keeps flat texture")
    A.deep({ U.rgb(mana) }, dim({ 0.2, 0.45, 0.9 }), "softer mana after update")
    A.deep({ U.rgb(rage) }, dim({ 1, 0, 0 }), "rage colour after update")
    tokens.target = "ENERGY"
    UnitFrameManaBar_UpdateType(rage)
    A.deep({ U.rgb(rage) }, dim({ 1, 1, 0 }), "power type change recolours")
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
