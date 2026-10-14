-- Range indicator cost: the bar-1 slot and the target nameplate are cached, events and a
-- five second fallback invalidate them. Counted through mock frame and API calls.
local h = ...

local function setup(t, rangeSettings)
    local ns, mock = t.ns, t.mock
    local ctx = { ns = ns, mock = mock }
    QuietUIDB.enabled = true
    QuietUICharDB.range = rangeSettings or { yards = "spell", kind = "hostile", spell = "Fireball" }
    mock:setUnit("target", { exists = true, dead = false })
    CheckInteractDistance = function() return true end
    IsActionInRange = function() return true end
    GetActionInfo = function(slot)
        mock.calls.GetActionInfo = (mock.calls.GetActionInfo or 0) + 1
        if slot == 1 then return "spell", 133 end
    end
    C_Spell = {
        GetSpellInfo = function() return { name = "Fireball", maxRange = 35 } end,
        IsSpellHarmful = function() return true end,
        IsSpellHelpful = function() return false end,
        IsSpellInRange = function() return true end,
    }
    ns.World.ShowAll = function() return false end
    ns.Glancing = function() return false end
    ns.Report = function(name, err) error(name .. ": " .. tostring(err)) end
    mock.calls.GetActionInfo = 0

    ctx.makePlate = function()
        local plate = CreateFrame("Frame", nil, UIParent)
        plate:SetSize(120, 60)
        local unit = CreateFrame("Frame", nil, plate)
        unit:SetSize(120, 60)
        local bar = CreateFrame("Frame", nil, unit)
        bar:SetSize(100, 10)
        plate.UnitFrame = unit
        ctx.unit, ctx.bar = unit, bar
        mock.nameplates.target = plate
        return plate
    end
    -- Times the full bar search of the current plate: the plate unit frame lists its children.
    ctx.walks = function() return ctx.unit._calls.GetChildren or 0 end
    ctx.resetWalks = function() ctx.unit._calls.GetChildren = 0 end
    ctx.reads = function() return mock.calls.GetActionInfo end
    ctx.resetReads = function() mock.calls.GetActionInfo = 0 end
    ctx.frames = function(count)
        for _ = 1, count do
            mock.now = mock.now + 1 / 60
            ns.UpdateRange(1 / 60)
        end
    end
    return ctx
end

h.test("Same target plate looks up its health bar at most once in 60 frames", function(t)
    local c = setup(t)
    c.makePlate()
    c.resetWalks()
    c.frames(60)
    local placed = false
    for _, f in ipairs(t.mock.frames) do placed = placed or (f._parent == c.bar and f._shown) end
    t.assert.ok(placed, "The range gradient was not shown on the health bar")
    t.assert.ok(c.walks() >= 1, "The health bar was never searched")
    t.assert.ok(c.walks() <= 1, "The same plate was walked " .. c.walks() .. " times in 60 frames")
end)

h.test("Target change and plate removal events make the next frame search the plate again", function(t)
    local c = setup(t)
    t.boot()
    c.makePlate()
    c.frames(2)
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_REMOVED" }) do
        t.assert.ok(t.mock:eventFrame(event), event .. " is not registered")
        c.frames(2)
        c.resetWalks()
        t.mock:fire(event, "nameplate1")
        c.frames(1)
        t.assert.eq(c.walks(), 1, "After " .. event .. " the bar was searched " .. c.walks() .. " times")
    end
end)

h.test("A different plate is searched without an event", function(t)
    local c = setup(t)
    c.makePlate()
    c.frames(2)
    c.makePlate()
    c.resetWalks()
    c.frames(2)
    t.assert.eq(c.walks(), 1, "A new plate was searched " .. c.walks() .. " times")
end)

h.test("Empty Spell field rescans bar 1 only on the five second fallback", function(t)
    local c = setup(t, { yards = "spell", kind = "hostile" })
    c.makePlate()
    c.frames(1)
    c.resetReads()
    c.frames(600)
    local scans = c.reads() / 12
    t.assert.ok(scans >= 1, "Bar 1 was never scanned")
    t.assert.ok(scans <= 2, "Bar 1 was scanned " .. scans .. " times in 10 s without events")
end)

h.test("Action bar and spell events make the next frame rescan bar 1", function(t)
    local c = setup(t, { yards = "spell", kind = "hostile" })
    t.boot()
    c.makePlate()
    for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED" }) do
        t.assert.ok(t.mock:eventFrame(event), event .. " is not registered")
        c.frames(1)
        c.resetReads()
        t.mock:fire(event, 1)
        c.frames(1)
        t.assert.eq(c.reads(), 12, "After " .. event .. " bar 1 was read " .. c.reads() .. " times")
    end
end)

h.test("ForgetRangePlate makes the next frame search the plate again", function(t)
    local c = setup(t)
    c.makePlate()
    t.assert.type(c.ns.ForgetRangePlate, "function", "ns.ForgetRangePlate is missing")
    c.frames(60)
    c.frames(2)
    c.resetWalks()
    c.ns.ForgetRangePlate()
    c.frames(1)
    t.assert.eq(c.walks(), 1, "After ForgetRangePlate the bar was searched " .. c.walks() .. " times")
end)

h.test("ForgetRangeSlot rescans bar 1 on the next frame", function(t)
    local c = setup(t, { yards = "spell", kind = "hostile" })
    c.makePlate()
    t.assert.type(c.ns.ForgetRangeSlot, "function", "ns.ForgetRangeSlot is missing")
    c.frames(1)
    c.resetReads()
    c.ns.ForgetRangeSlot()
    c.frames(1)
    t.assert.eq(c.reads(), 12, "After ForgetRangeSlot bar 1 was read " .. c.reads() .. " times")
end)
