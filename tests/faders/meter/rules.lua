-- The damage meter follows combat, instance, group, edit mode and grace only.
local h = ...

h.test("Damage meter follows combat, instance, group, edit mode and grace only", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    DamageMeter = CreateFrame("Frame", nil, UIParent)
    ns.FindFaders(false)
    ns.Hit = function() return true end
    ns.NextFadeTick()
    ns.ShowAll = function() return true end -- flyout or cursor item
    ns.UpdateFaders(1)
    A.eq(DamageMeter._alpha, 0, "Hover or bar showAll revealed meter")
    ns.InGroup = function() return true end
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    A.eq(DamageMeter._alpha, 1, "Group did not reveal meter")
    ns.InGroup = function() return false end
    ns.MarkCombatEnd()
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    A.eq(DamageMeter._alpha, 1, "Post-combat grace missing")
    mock.now = mock.now + 11
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    A.eq(DamageMeter._alpha, 0, "Post-combat grace did not expire")
end)
