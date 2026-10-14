-- A failing RegisterEvent for UNIT_QUEST_LOG_CHANGED must not break loading or the other events.
local h = ...

h.test("RegisterEvent failing for UNIT_QUEST_LOG_CHANGED keeps loading and the other events", function(t)
    for _, name in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE",
        "PLAYER_ENTERING_WORLD" }) do
        t.assert.ok(t.mock:eventFrame(name), "Missing registered " .. name)
    end
    local forwarded = 0
    t.ns.QuestMobsEvent = function(name) if name == "QUEST_LOG_UPDATE" then forwarded = forwarded + 1 end end
    t.boot()
    t.mock:fire("QUEST_LOG_UPDATE")
    t.assert.eq(forwarded, 1, "Other events must still forward")
end, { beforeLoad = function(mock) mock.badEvents.UNIT_QUEST_LOG_CHANGED = true end })
