-- Debuffs stay visible alone; the opt-out brings back aura fading and the power alpha curve.
-- Driven through ns.UpdateSmooth and the alpha of BuffFrame / DebuffFrame.
local h = ...

local function frame(parent) return CreateFrame("Frame", nil, parent) end

h.test("Debuffs stay visible alone and opt-out restores aura fading and alpha", function(t)
    local ns, A = t.ns, t.assert
    BuffFrame, DebuffFrame, TemporaryEnchantFrame = frame(UIParent), frame(UIParent), frame(UIParent)
    DebuffFrame._alpha = 0.8
    ns.PlayerStyle = function() return "resource" end
    ns.GroupAuras = function() return false end
    ns.FindFaders(false)
    ns.UpdateSmooth(1)
    A.eq(DebuffFrame._alpha, 1, "Default did not show debuffs with player frame off")
    A.ok(BuffFrame._alpha == 0 and TemporaryEnchantFrame._alpha == 0, "Debuffs revealed buffs")
    DebuffFrame:SetAlpha(0)
    A.eq(DebuffFrame._alpha, 1, "Blizzard alpha overwrite was not held")
    QuietUICharDB.alwaysShowDebuffs = false
    ns.UpdateSmooth(0.15)
    A.ok(DebuffFrame._alpha > 0 and DebuffFrame._alpha < 1, "Opt-out did not fade smoothly")
    ns.UpdateSmooth(1)
    A.eq(DebuffFrame._alpha, 0)
    ns.InCombat = function() return true end
    ns.UpdateSmooth(1)
    A.ok(DebuffFrame._alpha == 1 and BuffFrame._alpha == 1, "Opt-out broke normal combat visibility")
    QuietUICharDB.alwaysShowDebuffs = nil
    ns.RestoreAlpha()
    QuietUIDB.enabled = false
    A.eq(DebuffFrame._alpha, 0.8, "Disable did not restore original alpha")
    DebuffFrame:SetAlpha(0.4)
    A.eq(DebuffFrame._alpha, 0.4, "Disabled addon still held debuff alpha")
end)

h.test("Always visible debuffs override the shared power alpha curve", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    -- Full health with the default 70% threshold: the shared curve gives the faded group its
    -- current fade weight. Reveal the group once, then fade it a quarter of the way back.
    mock:setUnit("player", { health = 100, healthMax = 100, power = 100, powerMax = 100 })
    BuffFrame, DebuffFrame = frame(UIParent), frame(UIParent)
    ns.FindFaders(false)
    ns.InCombat = function() return true end
    ns.UpdateSmooth(1)
    ns.InCombat = function() return false end
    ns.UpdateSmooth(0.225)
    A.near(BuffFrame._alpha, 0.25, 1e-9, "Buffs did not follow the shared curve")
    A.eq(DebuffFrame._alpha, 1)
    QuietUICharDB.alwaysShowDebuffs = false
    ns.UpdateSmooth(0)
    A.near(DebuffFrame._alpha, 0.25, 1e-9, "Opt-out did not rejoin the power curve")
end)
