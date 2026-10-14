-- Dead or ghost player: pet, auras and personal resource keep their own rules, unsupported
-- alpha isolation and life APIs fail open, disable restores, settings are never rewritten.
local h = ...
local P = h.lib("player")
local unwrap, effective = P.unwrap, P.effective

local function serialize(value)
    if type(value) ~= "table" then return tostring(value) end
    local parts = {}
    for k, v in pairs(value) do parts[#parts + 1] = tostring(k) .. "=" .. serialize(v) end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

for _, inherited in ipairs({ false, true }) do
    h.test((inherited and "Inherited" or "Separate") .. " pet and auras keep their original rules during death", function(t)
        local A = t.assert
        local s = P.env(t, { inherited = inherited })
        local health, power = PersonalResourceDisplayFrame.HealthBarsContainer, s.resourcePower
        QuietUICharDB.alwaysShowDebuffs = false
        for _, life in ipairs({ "dead", "ghost" }) do
            s.life, s.HasTarget = "alive", true; s.tick()
            local pet = effective(PetFrame)
            local buffs, debuffs = unwrap(BuffFrame._alpha), unwrap(DebuffFrame._alpha)
            local resHealth, resPower = unwrap(health._alpha), unwrap(power._alpha)
            s.life = life; s.tick()
            s.portrait(0)
            A.eq(effective(PetFrame), pet, "Pet must not inherit portrait death fade")
            A.ok(unwrap(BuffFrame._alpha) == buffs and unwrap(DebuffFrame._alpha) == debuffs,
                "Grouped auras must remain visible")
            A.ok(unwrap(health._alpha) == resHealth and unwrap(power._alpha) == resPower)
            s.life, s.HasTarget, s.health, s.power = "alive", false, 0.4, 0.4; s.tick()
            local thresholdPet = effective(PetFrame)
            s.life = life; s.tick(); s.portrait(0)
            A.ok(effective(PetFrame) == thresholdPet and unwrap(BuffFrame._alpha) == 1 and unwrap(DebuffFrame._alpha) == 1,
                "Threshold keeps pet and auras visible while dead")
            A.ok(unwrap(health._alpha) == 1 and unwrap(power._alpha) == 1,
                "Low health/power must still reveal the personal resource components")
            s.health, s.power = 1, 1; s.tick()
            A.ok(effective(PetFrame) == 0 and unwrap(BuffFrame._alpha) == 0 and unwrap(DebuffFrame._alpha) == 0)
        end
        s.life, s.HasTarget = "alive", true; s.tick(0); s.portrait(1)
    end)
end

for _, mode in ipairs({ "missing getter", "missing setter", "getter error", "getter secret", "setter error" }) do
    h.test("Inherited pet isolation " .. mode .. " preserves portrait and pet visibility", function(t)
        local A = t.assert
        local s = P.env(t, { inherited = true })
        QuietUICharDB.playerThresholdPercent = false
        s.InCombat, s.allowReports = true, true
        if mode == "missing getter" then PetFrame:SetAbsent("IsIgnoringParentAlpha")
        elseif mode == "missing setter" then PetFrame:SetAbsent("SetIgnoreParentAlpha")
        elseif mode == "getter error" then
            PetFrame.IsIgnoringParentAlpha = function() error("inheritance getter unavailable") end
        elseif mode == "getter secret" then
            PetFrame.IsIgnoringParentAlpha = function() return P.secret(t.mock, false) end
        else PetFrame.SetIgnoreParentAlpha = function() error("inheritance setter unavailable") end end
        s.tick(); s.portrait(1)
        local originalPet = effective(PetFrame)
        for _, life in ipairs({ "dead", "ghost" }) do
            s.life = life
            for _ = 1, 3 do
                s.tick(); s.portrait(1, "Unsupported isolation must preserve the original portrait rule")
                A.eq(effective(PetFrame), originalPet, "Unsupported isolation must preserve inherited pet visibility")
            end
        end
        A.eq(#s.reports, mode == "getter secret" and 0 or 1,
            "Missing/error isolation must report once; secret state is silent")
    end)
end

h.test("Already independent inherited pet retains its original skipped alpha rules", function(t)
    local A = t.assert
    local s = P.env(t, { inherited = true })
    QuietUICharDB.playerThresholdPercent = false
    PetFrame:SetIgnoreParentAlpha(true)
    s.InCombat = true; s.tick(); s.portrait(1)
    A.ok(PetFrame._alpha == 0.6 and effective(PetFrame) == 0.6)
    for _, life in ipairs({ "dead", "ghost" }) do
        s.life = life; s.tick(); s.portrait(0)
        A.ok(PetFrame._alpha == 0.6 and effective(PetFrame) == 0.6,
            "An already independent child was skipped by the original player rule")
    end
    s.life, s.InCombat = "alive", false; s.tick(); s.portrait(0)
    A.ok(PetFrame._alpha == 0.6 and effective(PetFrame) == 0.6)
end)

h.test("Inherited pet preserves initial numeric fade and subsequent normal hide fade", function(t)
    local A = t.assert
    local s = P.env(t, { inherited = true })
    QuietUICharDB.playerThresholdPercent = false
    s.tick(0.15); s.portrait(0.3)
    A.near(effective(PetFrame), 0.18, 1e-6,
        "Initial effective pet alpha must follow the original 0.8 portrait baseline times 0.6 pet alpha")
    s.tick(0.15); s.portrait(0)
    A.eq(effective(PetFrame), 0)
    s.InCombat = true; s.tick(0); s.portrait(1)
    A.eq(effective(PetFrame), 0.6)
    s.InCombat = false; s.tick(0.15); s.portrait(0.5)
    A.near(effective(PetFrame), 0.3, 1e-6, "Normal hide fade must preserve the original rendered pet timing")
    s.tick(0.15); s.portrait(0)
    A.eq(effective(PetFrame), 0)
end)

h.test("Default debuffs stay visible even when death blocks only the portrait", function(t)
    local s = P.env(t)
    for _, life in ipairs({ "dead", "ghost" }) do
        s.life = life; s.tick()
        t.assert.ok(unwrap(DebuffFrame._alpha) == 1 and unwrap(BuffFrame._alpha) == 0)
    end
end)

for _, mode in ipairs({ "missing", "error", "secret" }) do
    h.test("Life API " .. mode .. " preserves existing behaviour and reports errors once", function(t)
        local A = t.assert
        local s = P.env(t)
        s.InCombat, s.allowReports = true, mode == "error"
        if mode == "missing" then UnitIsDeadOrGhost = nil
        elseif mode == "error" then UnitIsDeadOrGhost = function() error("life unavailable") end
        else UnitIsDeadOrGhost = function() return P.secret(t.mock, true) end end
        for _ = 1, 3 do s.tick(); s.portrait(1) end
        A.ok(#s.reports <= 1, "Same life API error must print at most once")
        if mode == "error" then A.eq(#s.reports, 1, "Life API failure must be reported once")
        else A.eq(#s.reports, 0, "Unsupported/secret life state must not produce an error") end
    end)
end

for _, life in ipairs({ "dead", "ghost" }) do
    h.test("Disable while " .. life .. " restores alpha and pet inheritance, then reenable works", function(t)
        local A = t.assert
        local s = P.env(t, { inherited = true })
        local ignoring = PetFrame:IsIgnoringParentAlpha()
        s.life, s.InCombat = life, true; s.tick()
        QuietUIDB.enabled = false
        t.ns.ApplyAll()
        A.ok(PlayerFrame._alpha == 0.8 and PetFrame._alpha == 0.6 and TargetFrame._alpha == 0.7,
            "Disable must restore all original alpha baselines")
        A.eq(PetFrame:IsIgnoringParentAlpha(), ignoring, "Disable must restore the pet inheritance flag")
        for _, name in ipairs(s.names) do
            if name ~= "PlayerFrame" and name ~= "PetFrame" and name ~= "TargetFrame" then
                A.eq(_G[name]._alpha, 1, "Disable must restore " .. name)
            end
        end
        PlayerFrame:SetAlpha(0.9)
        A.eq(PlayerFrame._alpha, 0.9, "Disabled hook must leave Blizzard in control")
        QuietUIDB.enabled, s.life = true, "alive"; s.tick(0); s.portrait(1)
    end)
end

for _, preset in ipairs({ false, true }) do
    h.test((preset and "Existing preset" or "Personal settings") .. " uses death rule without saved-data changes", function(t)
        local s = P.env(t, { preset = preset })
        local before = serialize({ QuietUIDB, QuietUICharDB })
        s.InCombat = true; s.tick()
        for _, life in ipairs({ "dead", "ghost" }) do s.life = life; s.tick(); s.portrait(0) end
        s.Glancing = true; s.tick(0); s.portrait(1)
        s.Glancing, s.life = false, "alive"; s.tick(0); s.portrait(1)
        t.assert.eq(serialize({ QuietUIDB, QuietUICharDB }), before,
            "Death visibility must not write settings or migrate presets")
    end)
end
