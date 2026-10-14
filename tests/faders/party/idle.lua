-- Party autohide idles while solo, joins and leaves with the normal fade, settled indicators cost
-- nothing, and Edit Mode, Glance and forced visibility reveal or restore.
local h = ...

-- A party block with 100 independent indicators; counts the frame reads the addon makes.
local function setup(t)
    local ns, mock = t.ns, t.mock
    local s = { reads = 0, indicatorChecks = 0, grouped = false }
    local function instrument(f)
        for _, name in ipairs({ "IsShown", "GetFrameLevel", "GetFrameStrata" }) do
            local original = f[name]
            f[name] = function(self, ...) s.reads = s.reads + 1; return original(self, ...) end
        end
        return f
    end
    local create = CreateFrame
    CreateFrame = function(...) return instrument(create(...)) end
    -- Only the party block under test: the mock also provides the compact raid roots.
    CompactRaidFrameContainer, CompactPartyFrame = nil, nil
    PartyFrame = instrument(create("Frame", nil, UIParent))
    s.children = {}
    for i = 1, 100 do
        local child = instrument(create("Frame", nil, PartyFrame))
        child:SetIgnoreParentAlpha(true)
        local forbidden = child.IsForbidden
        child.IsForbidden = function(self) s.indicatorChecks = s.indicatorChecks + 1; return forbidden(self) end
        s.children[i] = child
    end
    QuietUICharDB.autoHideParty = true
    ns.World.InGroup = function() return s.grouped end
    ns.World.InEditMode = function() return s.editing == true end
    ns.Glancing = function() return s.glance == true end
    ns.World.InCombat = function() return s.combat == true end
    ns.World.InForcedInstance = function() return s.instance == true end
    ns.Hit = function() return false end
    ns.Faders.Find(false)
    function s.writes() return mock.calls.SetAlpha or 0 end
    function s.reset() s.reads, s.indicatorChecks, s.base = 0, 0, s.writes() end
    function s.update(elapsed) ns.Faders.UpdateParty(elapsed) end
    s.reset()
    return s
end

h.test("Solo autohide leaves empty party containers idle", function(t)
    local s = setup(t)
    local created = #t.mock.createLog
    for _ = 1, 60 do s.update(1 / 60) end
    t.assert.eq(s.reads, 0, "Solo autohide must not read party frames")
    t.assert.eq(s.writes() - s.base, 0, "Solo autohide must not write alpha")
    t.assert.eq(#t.mock.createLog - created, 0, "Solo autohide must not create catchers")
end)

h.test("Joining fades at once, independent indicators fade with the group and settle for free", function(t)
    local A = t.assert
    local s = setup(t)
    s.grouped = true
    s.update(0.1)
    A.ok(PartyFrame._alpha > 0 and PartyFrame._alpha < 1, "Joining must immediately start the normal fade")
    s.update(0.3)
    A.ok(PartyFrame._alpha == 0 and s.children[100]._alpha == 0, "Independent indicators must fade with the group")
    s.reset()
    for _ = 1, 60 do s.update(1 / 60) end
    A.ok(s.reads <= 300, "A settled block must check its root once rather than once per indicator")
    A.ok(s.indicatorChecks == 0 and s.writes() - s.base == 0,
        "Settled indicators must not repeat frame checks or alpha writes")
end)

h.test("Leaving the group stops indicator updates", function(t)
    local s = setup(t)
    s.grouped = true
    s.update(0.1); s.update(0.3)
    s.grouped = false
    s.reset()
    s.update(1 / 60)
    t.assert.eq(s.writes() - s.base, 0, "Leaving the group must stop indicator updates")
end)

h.test("Solo Edit Mode reveals previews", function(t)
    local s = setup(t)
    s.grouped = true
    s.update(0.1); s.update(0.3)
    s.grouped, s.editing = false, true
    s.update(0)
    t.assert.ok(PartyFrame._alpha == 1 and s.children[100]._alpha == 1, "Solo Edit Mode must reveal previews")
end)

h.test("Glance still reveals shown party frames", function(t)
    local s = setup(t)
    s.grouped = true
    s.update(0.3)
    s.grouped, s.glance = false, true
    s.update(0)
    t.assert.eq(PartyFrame._alpha, 1, "Glance must still reveal shown party frames")
end)

for _, trigger in ipairs({ "combat", "instance" }) do
    h.test("Solo forced visibility (" .. trigger .. ") still reveals shown party frames", function(t)
        local s = setup(t)
        s.grouped = true
        s.update(0.3)
        s.grouped = false
        s[trigger] = true
        s.update(0)
        t.assert.eq(PartyFrame._alpha, 1, "Solo forced visibility must still reveal shown party frames")
    end)
end

h.test("Disabling autohide while solo restores independent indicators", function(t)
    local A = t.assert
    local s = setup(t)
    s.grouped = true
    s.update(0.3)
    s.grouped = false
    QuietUICharDB.autoHideParty = nil
    s.update(0)
    A.eq(PartyFrame._alpha, 1)
    A.eq(s.children[100]._alpha, 1, "Disabling autohide while solo must restore independent indicators")
end)
