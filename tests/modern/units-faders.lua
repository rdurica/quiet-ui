-- Unit skins must not change the player / pet / target fade rules (docs/features/player.md).
local h = ...
local P = h.lib("player")
local U = h.lib("modern-units")
local unwrap = P.unwrap

local function skinned(t)
    U.frames()
    U.installColours(t.mock)
    local s = P.env(t)
    QuietUICharDB.modernize = { enabled = true }
    t.ns.Modern.Apply()
    s.reports = t.mock.printed
    t.assert.ok(U.hidden(PlayerFrame), "unit skins are applied")
    return s
end

h.test("skinned frames: a dead target blocks player, pet and target, and Glance releases them", function(t)
    local A = t.assert
    local s = skinned(t)
    QuietUICharDB.requireLivingTarget = true
    s.targetDead = true
    s.tick(); s.portrait(0)
    A.ok(unwrap(PetFrame._alpha) == 0 and TargetFrame._alpha == 0, "Dead target blocks player, pet and target")
    s.Glancing = true; s.tick(0); s.portrait(1)
    A.eq(unwrap(PetFrame._alpha), 1, "Glance shows the pet")
    A.eq(TargetFrame._alpha, 0.7, "Glance releases the target to its original alpha")
    s.Glancing = false; s.tick(); s.portrait(0)
    A.ok(unwrap(PetFrame._alpha) == 0 and TargetFrame._alpha == 0, "Block applies again after Glance")
    A.ok(U.hidden(PlayerFrame), "frame art stays held through fades")
end)

h.test("skinned frames: the threshold overrides the dead-target block for player and pet only", function(t)
    local A = t.assert
    local s = skinned(t)
    QuietUICharDB.requireLivingTarget = true
    s.targetDead = true
    s.health = 0.4; s.tick(); s.portrait(1)
    A.ok(unwrap(PetFrame._alpha) == 1 and TargetFrame._alpha == 0, "Threshold only overrides player and pet")
    s.Glancing = true; s.tick(0); s.portrait(1)
    A.eq(TargetFrame._alpha, 0.7, "Glance still releases the target")
end)

h.test("skinned frames: the portrait fades in 0.3s on death and the skin does not re-show it", function(t)
    local s = skinned(t)
    s.InCombat = true; s.tick(0); s.portrait(1)
    s.life = "dead"
    s.tick(0.15); s.portrait(0.5, "Death must start a gradual fade")
    PlayerFrame:SetAlpha(1); s.portrait(0.5, "Blizzard overwrite must keep the fading alpha")
    s.tick(0.15); s.portrait(0)
    s.life = "alive"; s.tick(0); s.portrait(1)
end)
