-- Range indicator rules: always-visible bars do not block it, forced visibility and Glance
-- suppress it without reading distance, and an invisible gradient detaches from the plate.
local h = ...

h.test("Range ignores always-visible groups, keeps forced suppression and detaches", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    ns.Settings.Range = function() return "spell", "hostile", "Test" end
    mock:setUnit("target", { exists = true, dead = false })
    local distanceReads = 0
    C_Spell = { IsSpellInRange = function() distanceReads = distanceReads + 1; return true end }
    ns.Settings.AnyBarsAlwaysVisible = function() return true end
    local plate = CreateFrame("Frame", nil, UIParent)
    local health = CreateFrame("Frame", nil, nil)
    health:SetSize(100, 10)
    plate.UnitFrame = { healthBar = health, IsShown = function() return true end }
    mock.nameplates.target = plate
    local mark
    local create = CreateFrame
    CreateFrame = function(...) mark = create(...); return mark end
    ns.Faders.UpdateRange(0.1)
    A.ok(mark and mark._shown and mark._parent == health and mark._alpha == 1,
        "Always-visible bars must not block the range indicator")
    local reads = distanceReads
    ns.World.ShowAll = function() return true end
    ns.Faders.UpdateRange(0.3)
    A.ok(not mark._shown and distanceReads == reads, "Forced visibility must hide range without reading distance")
    ns.World.ShowAll = function() return false end
    ns.Faders.UpdateRange(0.1)
    A.ok(mark._shown, "Range did not return after forced visibility ended")
    ns.Glance.Active = function() return true end
    reads = distanceReads
    ns.Faders.UpdateRange(0.3)
    A.ok(not mark._shown and distanceReads == reads, "Glance must hide range without reading distance")
    ns.Glance.Active = function() return false end
    ns.Faders.UpdateRange(0.1)
    A.ok(mark._shown, "Range did not return after Glance ended")
    ns.Settings.Range = function() end
    ns.Faders.UpdateRange(0.3)
    A.ok(not mark._shown and mark._parent == UIParent, "Invisible gradient stayed on nameplate")
    local before = mock.calls.GetNamePlateForUnit
    for _ = 1, 60 do ns.Faders.UpdateRange(1 / 60) end
    A.eq(mock.calls.GetNamePlateForUnit, before, "Hidden gradient still scanned nameplate")
end)
