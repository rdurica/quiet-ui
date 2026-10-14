-- A failing RegisterEvent on this client must not break loading; Highlights reports its own events once.
local h = ...

local OTHER = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

local function failing(event)
    return { beforeLoad = function(mock) mock.badEvents[event] = true end }
end

local function reports(t)
    local n = 0
    for _, line in ipairs(t.mock.printed) do
        if line:find("highlights events error (shown once)", 1, true) then n = n + 1 end
    end
    return n
end

h.test("RegisterEvent failing for PLAYER_SOFT_INTERACT_CHANGED keeps the other events", function(t)
    local forwarded = 0
    t.ns.Highlights.Event = function(name) if name == "NAME_PLATE_UNIT_ADDED" then forwarded = forwarded + 1 end end
    for _, name in ipairs(OTHER) do
        t.assert.ok(t.mock:eventFrame(name), "Missing registered " .. name)
    end
    for _, line in ipairs(t.mock.printed) do
        t.assert.ok(line:find("highlights events", 1, true), "unexpected output: " .. line)
    end
    t.boot(false)
    t.mock:fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    t.assert.eq(forwarded, 1, "Other events must still forward")
end, failing("PLAYER_SOFT_INTERACT_CHANGED"))

for _, name in ipairs({ "PLAYER_SOFT_INTERACT_CHANGED", "NAME_PLATE_UNIT_ADDED" }) do
    h.test("RegisterEvent failing for " .. name .. " is reported once as highlights events", function(t)
        t.assert.eq(reports(t), 1, "highlights events reports")
        t.assert.eq(#t.mock.printed, 1, "Unexpected output: " .. table.concat(t.mock.printed, " | "))
    end, failing(name))
end

for _, name in ipairs({ "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA", "NAME_PLATE_UNIT_REMOVED" }) do
    h.test("RegisterEvent failing for " .. name .. " stays silent for highlights", function(t)
        t.assert.eq(#t.mock.printed, 0, "Unexpected output: " .. table.concat(t.mock.printed, " | "))
    end, failing(name))
end
