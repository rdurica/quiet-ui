-- A failing RegisterEvent on this client must not break loading; Highlights reports its own events once.
local h = ...

local OTHER = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

local function failing(event)
    return { beforeLoad = function(mock) mock.badEvents[event] = true end }
end

-- Events register at boot, so their failures are reported there.
local function errors(lines)
    local highlights, all = 0, 0
    for _, line in ipairs(lines) do
        if line:find("error (shown once)", 1, true) then all = all + 1 end
        if line:find("highlights events error (shown once)", 1, true) then highlights = highlights + 1 end
    end
    return highlights, all
end

h.test("RegisterEvent failing for PLAYER_SOFT_INTERACT_CHANGED keeps the other events", function(t)
    local forwarded = 0
    t.ns.Highlights.Event = function(name) if name == "NAME_PLATE_UNIT_ADDED" then forwarded = forwarded + 1 end end
    local highlights, all = errors(t.boot(false))
    t.assert.eq(all, highlights, "only highlights events are reported")
    for _, name in ipairs(OTHER) do
        t.assert.ok(t.mock:eventFrame(name), "Missing registered " .. name)
    end
    t.mock:fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    t.assert.eq(forwarded, 1, "Other events must still forward")
end, failing("PLAYER_SOFT_INTERACT_CHANGED"))

for _, name in ipairs({ "PLAYER_SOFT_INTERACT_CHANGED", "NAME_PLATE_UNIT_ADDED" }) do
    h.test("RegisterEvent failing for " .. name .. " is reported once as highlights events", function(t)
        local highlights, all = errors(t.boot(false))
        t.assert.eq(highlights, 1, "highlights events reports")
        t.assert.eq(all, 1, "no other errors")
    end, failing(name))
end

for _, name in ipairs({ "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA", "NAME_PLATE_UNIT_REMOVED" }) do
    h.test("RegisterEvent failing for " .. name .. " stays silent for highlights", function(t)
        local _, all = errors(t.boot(false))
        t.assert.eq(all, 0, "no errors reported")
    end, failing(name))
end
