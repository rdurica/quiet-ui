-- Dead or ghost player: the portrait fades in 0.3s, secret alphas clear at once, Glance and
-- Edit Mode reveal, revive restores active triggers. Health and power are secret values.
local h = ...
local P = h.lib("player")
local unwrap = P.unwrap

for _, life in ipairs({ "dead", "ghost" }) do
    h.test(life .. " portrait fades in 0.3s despite every ordinary trigger", function(t)
        local s = P.env(t)
        QuietUICharDB.playerThresholdPercent = false
        for _, trigger in ipairs({ "InCombat", "InForcedInstance", "InGroup", "InVehicle", "HasTarget", "hover" }) do
            s.life = "alive"
            if trigger == "hover" then PlayerFrame.hot = true else s[trigger] = true end
            s.tick(0); s.portrait(1)
            s.life = life
            s.tick(0.15); s.portrait(0.5, "Death must start a gradual fade")
            PlayerFrame:SetAlpha(1); s.portrait(0.5, "Blizzard overwrite must keep the fading alpha")
            s.tick(0.15); s.portrait(0)
            if trigger == "hover" then PlayerFrame.hot = false else s[trigger] = false end
        end
    end)
end

h.test("Release to ghost keeps portrait hidden", function(t)
    local s = P.env(t)
    s.InCombat = true; s.tick(0)
    s.life = "dead"; s.tick(); s.portrait(0)
    s.life = "ghost"; s.HasTarget = true; s.tick(); s.portrait(0)
end)

for _, kind in ipairs({ "health", "resource" }) do
    h.test(kind .. " secret threshold hides immediately on death and returns after revive", function(t)
        local s = P.env(t)
        QuietUICharDB.playerThresholdKind = kind
        s.health, s.power = 0, 0.4
        s.tick(); s.portrait(1)
        t.assert.ok(issecretvalue(PlayerFrame._alpha), "Arrange a real secret alpha")
        s.life = "dead"; s.tick(0.15); s.portrait(0, "An unreadable secret alpha must clear immediately on death")
        s.tick(0.15); s.portrait(0)
        s.life = "ghost"; s.tick(); s.portrait(0)
        s.life = "alive"; s.tick(0); s.portrait(1)
        t.assert.eq(#s.reports, 0, "Secret transition must not cause Lua errors")
    end)
    for _, life in ipairs({ "dead", "ghost" }) do
        h.test(kind .. " threshold-hidden portrait stays hidden when " .. life .. " lowers percentages", function(t)
            local s = P.env(t)
            QuietUICharDB.playerThresholdKind = kind
            s.health, s.power = 1, 1
            s.tick(); s.portrait(0)
            t.assert.ok(issecretvalue(PlayerFrame._alpha), "Arrange an already-hidden secret alpha")
            s.life, s.health, s.power = life, 0, 0
            s.tick(0.15); s.portrait(0, "Death must not reveal the previously hidden portrait")
            s.tick(0.15); s.portrait(0)
            t.assert.ok(unwrap(PetFrame._alpha) == 1 and unwrap(BuffFrame._alpha) == 1,
                "The unchanged threshold must still reveal pet and grouped buffs")
        end)
    end
end

for _, life in ipairs({ "dead", "ghost" }) do
    h.test(life .. " Glance immediately reveals and then fades the portrait", function(t)
        local s = P.env(t)
        s.InCombat = true; s.tick()
        s.life = life; s.tick(); s.portrait(0)
        s.Glancing = true; s.tick(0); s.portrait(1)
        s.Glancing = false; s.tick(0.15); s.portrait(0.5)
        s.tick(0.15); s.portrait(0)
    end)
    h.test(life .. " player off ignores Glance but Edit Mode bypasses it", function(t)
        local s = P.env(t)
        QuietUICharDB.player = "resource"
        s.life, s.Glancing = life, true; s.tick(); s.portrait(0)
        s.InEditMode = true; s.tick(0); s.portrait(1)
        s.InEditMode, s.Glancing = false, false
        s.tick(0.15); s.portrait(0.5); s.tick(0.15); s.portrait(0)
    end)
    h.test(life .. " Edit Mode reveals an enabled portrait then fades on exit", function(t)
        local s = P.env(t)
        s.life, s.InCombat = life, true
        s.InEditMode = true; s.tick(0); s.portrait(1)
        s.InEditMode = false; s.tick(0.15); s.portrait(0.5)
        s.tick(0.15); s.portrait(0)
    end)
end

h.test("Glance bypasses the dead-target block, then the block applies again", function(t)
    local A = t.assert
    local s = P.env(t)
    QuietUICharDB.requireLivingTarget = true
    s.targetDead = true
    s.tick(); s.portrait(0)
    A.ok(unwrap(PetFrame._alpha) == 0 and TargetFrame._alpha == 0, "Dead target blocks player, pet and target")
    s.Glancing = true; s.tick(0); s.portrait(1)
    A.eq(unwrap(PetFrame._alpha), 1, "Glance shows the pet")
    A.eq(TargetFrame._alpha, 0.7, "Glance releases the target to its original alpha")
    s.Glancing = false; s.tick(); s.portrait(0)
    A.ok(unwrap(PetFrame._alpha) == 0 and TargetFrame._alpha == 0, "Block applies again after Glance")
end)

h.test("Dead-target threshold exception still overrides only player and pet outside Glance", function(t)
    local A = t.assert
    local s = P.env(t)
    QuietUICharDB.requireLivingTarget = true
    s.targetDead = true
    s.health = 0.4; s.tick(); s.portrait(1)
    A.ok(unwrap(PetFrame._alpha) == 1 and TargetFrame._alpha == 0, "Threshold only overrides player and pet")
    s.Glancing = true; s.tick(0); s.portrait(1)
    A.eq(TargetFrame._alpha, 0.7, "Glance still releases the target")
    s.Glancing = false; s.tick(); s.portrait(1)
    A.ok(unwrap(PetFrame._alpha) == 1 and TargetFrame._alpha == 0,
        "Threshold persists after Glance, target faded again")
end)

h.test("Player frame off keeps the portrait hidden during Glance with a dead target", function(t)
    local s = P.env(t)
    QuietUICharDB.requireLivingTarget = true
    QuietUICharDB.player = "resource"
    s.targetDead, s.Glancing = true, true
    s.tick(); s.portrait(0)
    t.assert.eq(TargetFrame._alpha, 0.7, "Glance releases the target even with the portrait off")
    s.Glancing = false; s.tick(); s.portrait(0)
    t.assert.eq(TargetFrame._alpha, 0, "Block applies again after Glance")
end)

h.test("Revive immediately restores active triggers but remains hidden without them", function(t)
    local s = P.env(t)
    QuietUICharDB.playerThresholdPercent = false
    s.life, s.InCombat = "dead", true; s.tick(); s.portrait(0)
    s.life = "alive"; s.tick(0); s.portrait(1)
    s.life = "ghost"; s.tick(); s.portrait(0)
    s.InCombat, s.life = false, "alive"; s.tick(0); s.portrait(0)
end)
