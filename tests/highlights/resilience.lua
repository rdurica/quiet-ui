-- Missing or hostile client pieces: no error, one report where the glow cannot work.
local h = ...
local H = h.lib("highlights")
local case = function(name, fn) H.case(h, name, fn) end

case("Missing C_CVar: no error, reported, nothing written", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    C_CVar = nil
    w.apply()
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    w.restore()
    A.ok(w.reported(), "missing C_CVar was not reported")
    A.eq(w.writes(), 0, "a CVar was written without C_CVar")
    return w
end)

case("Missing C_NamePlate: no error, reported, nothing shown", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    C_NamePlate = nil
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    w.event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    A.printed(t.mock, "highlights nameplates error", 1)
    A.ok(w.nothingShown(), "something was shown without C_NamePlate")
    return w
end)

case("Missing SoftTargetFrame: no error, reported, nothing shown", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE, { noSoftTarget = true })
    w.target("GameObject-A")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    A.printed(t.mock, "highlights soft target error", 1)
    A.ok(w.nothingShown(), "something was shown without SoftTargetFrame")
    return w
end)

case("Missing CreateAnimationGroup: no error, reported", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    local create = CreateFrame
    CreateFrame = function(...)
        local frame = create(...)
        local createTexture = frame.CreateTexture
        frame.CreateTexture = function(self, ...)
            local texture = createTexture(self, ...)
            texture:SetAbsent("CreateAnimationGroup")
            return texture
        end
        return frame
    end
    w.apply()
    w.addPlate("nameplate1", "GameObject-A", H.MINE)
    w.target("GameObject-A")
    w.target(nil, "GameObject-A")
    w.target("GameObject-A")
    A.printed(t.mock, "highlights animations error", 1)
    return w
end)

case("Forbidden plate is skipped without calling its methods", function(t, A)
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local calls = 0
    local proxy = setmetatable({}, { __index = function(_, key)
        if key == "IsForbidden" then return function() return true end end
        return function() calls = calls + 1 end
    end })
    t.mock.nameplates.nameplate1 = proxy
    t.mock.units.nameplate1 = { exists = true, guid = "GameObject-A" }
    w.target("GameObject-A")
    w.event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    w.event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    A.eq(calls, 0, "a forbidden plate had method calls")
    A.ok(w.nothingShown(), "something was shown on a forbidden plate")
    return w
end)

case("Unknown event is ignored without error", function(t)
    local w = H.oreShown(t)
    w.event("SOME_UNKNOWN_EVENT", "x")
    w.assertNoErrors()
    return w
end)
