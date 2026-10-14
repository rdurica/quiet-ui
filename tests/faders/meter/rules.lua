-- The damage meter follows combat, instance, group, edit mode and grace only.
local h = ...

h.test("Damage meter follows combat, instance, group, edit mode and grace only", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    DamageMeter = CreateFrame("Frame", nil, UIParent)
    ns.Faders.Find(false)
    ns.Hit = function() return true end
    ns.NextFadeTick()
    ns.World.ShowAll = function() return true end -- flyout or cursor item
    ns.Faders.Update(1)
    A.eq(DamageMeter._alpha, 0, "Hover or bar showAll revealed meter")
    ns.World.InGroup = function() return true end
    ns.NextFadeTick()
    ns.Faders.Update(1)
    A.eq(DamageMeter._alpha, 1, "Group did not reveal meter")
    ns.World.InGroup = function() return false end
    ns.Faders.MarkCombatEnd()
    ns.NextFadeTick()
    ns.Faders.Update(1)
    A.eq(DamageMeter._alpha, 1, "Post-combat grace missing")
    mock.now = mock.now + 11
    ns.NextFadeTick()
    ns.Faders.Update(1)
    A.eq(DamageMeter._alpha, 0, "Post-combat grace did not expire")
end)
