-- Party and raid block: the container signature keeps idle ticks from rescanning it.
local h = ...

-- A booted addon with a raid container of five members, autohide on, outside a group.
local function setup(t)
    local ns, mock = t.ns, t.mock
    t.boot()
    QuietUIDB.enabled = true
    QuietUICharDB.autoHideParty = true
    local ctx = { ns = ns, mock = mock, grouped = false }
    ns.World.InGroup = function() return ctx.grouped end
    ns.World.InEditMode = function() return false end
    ns.Glancing = function() return false end
    ns.World.InCombat = function() return false end
    ns.World.InForcedInstance = function() return false end
    ns.Hit = function() return false end
    ns.World.RefreshWorld = function() end
    local container = CompactRaidFrameContainer
    for _ = 1, 5 do CreateFrame("Frame", nil, container) end
    ctx.container = container
    -- A full party scan enumerates every root once; the signature only reads counts.
    ctx.scans = function() return container._calls.GetChildren or 0 end
    ctx.reset = function() container._calls.GetChildren = 0 end
    ctx.ticks = function(count)
        for _ = 1, count do ns.Faders.Find(false) end
    end
    ctx.fire = function(event)
        mock:fire(event)
        mock:drain()
    end
    return ctx
end

h.test("Ten idle 1 s ticks skip the full party scan", function(t)
    local c = setup(t)
    c.ns.Faders.Find(true)
    c.reset()
    c.ticks(10)
    t.assert.eq(c.scans(), 0, "Unchanged party containers were fully scanned")
end)

h.test("A new raid container child triggers exactly one full scan", function(t)
    local c = setup(t)
    c.ns.Faders.Find(true)
    c.ticks(1)
    local added = CreateFrame("Frame", nil, c.container)
    function added:IsIgnoringParentAlpha() return true end
    c.reset()
    c.ticks(1)
    t.assert.eq(c.scans(), 1, "Child count change ran full scans on the next tick")
    c.ticks(1)
    t.assert.eq(c.scans(), 1, "The settled signature scanned again")
    c.grouped = true
    c.ns.Faders.UpdateParty(0.3)
    c.grouped = false
    t.assert.eq(added._alpha, 0, "The new independent child was not collected by the scan")
end)

h.test("GROUP_ROSTER_UPDATE scans only while autohide is on", function(t)
    local c = setup(t)
    c.ns.Faders.Find(true)
    c.ticks(1)
    c.reset()
    c.fire("GROUP_ROSTER_UPDATE")
    t.assert.eq(c.scans(), 1, "Roster update with autohide ran full scans")
    QuietUICharDB.autoHideParty = false
    c.reset()
    c.fire("GROUP_ROSTER_UPDATE")
    t.assert.eq(c.scans(), 0, "Roster update without autohide ran full scans")
end)

h.test("Turning autohide on scans at the next tick without a signature change", function(t)
    local c = setup(t)
    c.ns.Faders.Find(true)
    c.ticks(2)
    QuietUICharDB.autoHideParty = false
    c.ticks(1)
    QuietUICharDB.autoHideParty = true
    c.reset()
    c.ticks(1)
    t.assert.eq(c.scans(), 1, "Enabling autohide ran full scans")
    c.ticks(1)
    t.assert.eq(c.scans(), 1, "Enabled autohide kept scanning")
end)
