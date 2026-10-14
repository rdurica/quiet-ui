-- Roster events stop while QuietUI is off, so enabling again rescans the party block.
local h = ...

h.test("Enabling again runs a full party scan without a signature change", function(t)
    local ns = t.ns
    t.boot()
    QuietUIDB.enabled = true
    QuietUICharDB.autoHideParty = true
    ns.World.InGroup = function() return false end
    ns.World.InEditMode = function() return false end
    ns.Glancing = function() return false end
    ns.World.InCombat = function() return false end
    ns.World.InForcedInstance = function() return false end
    ns.Hit = function() return false end
    ns.World.RefreshWorld = function() end
    local container = CompactRaidFrameContainer
    for _ = 1, 5 do CreateFrame("Frame", nil, container) end
    local function scans() return container._calls.GetChildren or 0 end
    ns.FindFaders(true)
    ns.FindFaders(false)
    QuietUIDB.enabled = false
    ns.UpdateParty(0)
    QuietUIDB.enabled = true
    container._calls.GetChildren = 0
    ns.FindFaders(false)
    t.assert.eq(scans(), 1, "Re-enable ran full party scans")
    ns.FindFaders(false)
    t.assert.eq(scans(), 1, "Re-enabled autohide kept scanning")
end)
