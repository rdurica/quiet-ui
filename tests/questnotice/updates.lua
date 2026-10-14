-- Which quest changes produce a notice: acceptance, progress and completion, on the modern
-- and the classic quest log, and which reads stay silent (baseline, duplicates, reorders).
local h = ...
local Q = h.lib("questnotice")
local function env(t, opts) return Q.fixture(t.mock, t.ns, opts) end

h.test("startup and duplicate events are silent; idle updates do not scan the log", function(t)
    local s = env(t)
    s.silent()
    s.event("QUEST_LOG_UPDATE")
    s.silent()
    local reads = s.reads
    s.pump(3)
    t.assert.eq(s.reads, reads, "Idle must not read quest log")
end)

for _, classic in ipairs({ false, true }) do
    local kind = classic and "classic" or "modern"
    h.test(kind .. " acceptance displays only the accepted quest with its objectives", function(t)
        local s = env(t, { classic = classic })
        s.log[2] = s.quest(2)
        if classic then s.event("QUEST_ACCEPTED", 2, 2) else s.event("QUEST_ACCEPTED", 2) end
        s.has("Quest 2"); s.has("Wolves 0/8"); s.has("Find the relic")
        t.assert.falsy(s.text():find("Quest 1", 1, true), "Must not show unchanged quests")
    end)
    h.test(kind .. " progress shows only changed objectives and completion needs no dialog", function(t)
        local s = env(t, { classic = classic })
        s.change(3)
        s.has("Quest 1"); s.has("Wolves 3/8")
        t.assert.falsy(s.text():find("Find the relic", 1, true), "Unchanged objective must not appear")
        s.log[1].complete = true
        s.event("QUEST_LOG_UPDATE")
        s.has("Complete")
    end)
end

h.test("an accepted quest waits for delayed log data", function(t)
    local s = env(t)
    s.event("QUEST_ACCEPTED", 2)
    s.silent()
    s.log[2] = s.quest(2)
    s.event("QUEST_LOG_UPDATE")
    s.has("Quest 2")
end)

h.test("acceptance before the first world-entry scan announces the new quest only", function(t)
    local s = env(t)
    t.ns.QuestNotice.Event("PLAYER_ENTERING_WORLD", false, false)
    s.log[2] = s.quest(2)
    t.ns.QuestNotice.Event("QUEST_ACCEPTED", 2)
    s.tick(0)
    s.has("Quest 2"); s.has("Wolves 0/8")
    t.assert.falsy(s.text():find("Quest 1", 1, true), "Existing baseline quests must remain silent")
end)

h.test("modern stable objective text detects numeric progress and displays the count", function(t)
    local s = env(t)
    t.ns.QuestNotice.Restore()
    s.log[1].objectives[1] = { text = "Wolves slain", finished = false, type = "monster", numFulfilled = 0, numRequired = 8 }
    t.ns.QuestNotice.Apply(); s.pump(); s.silent()
    s.log[1].objectives[1].numFulfilled = 3
    s.event("QUEST_LOG_UPDATE")
    s.has("Quest 1"); s.has("Wolves slain"); s.has("3/8")
    t.assert.falsy(s.text():find("Find the relic", 1, true), "Unchanged objective must not appear")
end)

h.test("classic nil unfinished completion is valid without IsQuestComplete", function(t)
    local s = env(t, { classic = true })
    -- Explicit nil is the classic unfinished marker, not missing quest data.
    GetQuestLogTitle = function(index)
        local q = s.log[index]
        if q then return q.title, 10, 0, false, false, q.complete and 1 or nil, 1, q.id end
    end
    IsQuestComplete = nil
    t.ns.QuestNotice.Restore(); t.ns.QuestNotice.Apply(); s.pump(); s.silent()
    s.change(3)
    s.has("Quest 1"); s.has("Wolves 3/8")
end)

h.test("transient empty modern objectives preserve a nonempty unfinished baseline", function(t)
    local s = env(t)
    local previous = s.log[1].objectives
    s.log[1].objectives = {}
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.log[1].objectives = previous
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.change(3)
    s.has("Quest 1"); s.has("Wolves 3/8")
    t.assert.falsy(s.text():find("Find the relic", 1, true), "Unchanged objective must not appear after incomplete read")
end)

h.test("transient empty objectives preserve an already complete quest baseline", function(t)
    local s = env(t)
    s.log[1].complete = true
    s.event("QUEST_LOG_UPDATE"); s.has("Complete")
    s.pump(6); s.silent()
    local previous = s.log[1].objectives
    s.log[1].objectives = {}
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.log[1].objectives = previous
    s.event("QUEST_LOG_UPDATE"); s.silent()
end)

h.test("a completion transition is announced even when objectives are temporarily empty", function(t)
    local s = env(t)
    s.log[1].complete = true
    s.log[1].objectives = {}
    s.event("QUEST_LOG_UPDATE")
    s.has("Quest 1"); s.has("Complete")
end)

h.test("temporarily incomplete objectives preserve the previous snapshot", function(t)
    local s = env(t)
    local old = s.log[1].objectives
    s.log[1].objectives = nil
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.log[1].objectives = old
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.change(2)
    s.has("Wolves 2/8")
end)

h.test("QUEST_COMPLETE dialog, quest removal and turn-in create no notices", function(t)
    local s = env(t)
    s.event("QUEST_COMPLETE"); s.silent()
    s.log = {}
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.event("QUEST_TURNED_IN", 1); s.silent()
end)

h.test("a classic index reorder is silent", function(t)
    local s = env(t, { classic = true })
    s.log[2] = s.quest(2)
    t.ns.QuestNotice.Restore(); t.ns.QuestNotice.Apply(); s.pump()
    s.log[1], s.log[2] = s.log[2], s.log[1]
    s.event("QUEST_LOG_UPDATE"); s.silent()
end)

h.test("a temporarily missing title preserves the snapshot without a false notice", function(t)
    local s = env(t)
    s.log[1].title = nil
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.log[1].title = "Quest 1"
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.change(1)
    s.has("Wolves 1/8")
end)
