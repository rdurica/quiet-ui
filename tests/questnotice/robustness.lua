-- Hostile or missing client data: failing quest APIs report once, secret values are never
-- consumed, and a missing or forbidden tracker suppresses the notice safely.
local h = ...
local Q = h.lib("questnotice")
local function env(t, opts) return Q.fixture(t.mock, t.ns, opts) end

-- A secret value that errors when read, converted or compared.
local function secret(t, what)
    local box = setmetatable({}, {
        __tostring = function() error("Secret " .. what .. " consumed") end,
        __lt = function() error("Secret " .. what .. " compared") end,
        __le = function() error("Secret " .. what .. " compared") end,
        __add = function() error("Secret " .. what .. " arithmetic") end,
    })
    t.mock.secrets[box] = true
    return box
end

h.test("a missing required classic title reader reports exactly once", function(t)
    local s = env(t, { classic = true })
    GetQuestLogTitle = nil
    t.ns.QuestNotice.Restore(); t.ns.QuestNotice.Apply()
    s.event("QUEST_LOG_UPDATE"); s.pump(12); s.silent()
    s.event("QUEST_LOG_UPDATE"); s.pump(12); s.silent()
    t.assert.eq(s.reports(), 1, "Missing required title reader must report once")
end)

h.test("a throwing quest API reports once across retries and repeated events", function(t)
    local s = env(t)
    C_QuestLog.GetNumQuestLogEntries = function()
        s.reads = s.reads + 1
        error("Quest reader failed")
    end
    s.event("QUEST_LOG_UPDATE"); s.pump(12); s.silent()
    s.event("QUEST_LOG_UPDATE"); s.pump(12); s.silent()
    t.assert.eq(s.reports(), 1, "Throwing quest API must report once")
end)

h.test("missing quest APIs stay quiet and report at most once", function(t)
    local s = env(t)
    C_QuestLog = nil
    s.event("QUEST_LOG_UPDATE"); s.pump(2); s.silent()
    t.assert.ok(s.reports() <= 1, "Missing APIs should report once")
end)

h.test("unavailable log data retries within a finite window", function(t)
    local s = env(t)
    C_QuestLog.GetNumQuestLogEntries = function() s.reads = s.reads + 1; return nil end
    s.event("QUEST_LOG_UPDATE"); s.pump(12); s.silent()
    local reads = s.reads
    s.pump(2)
    t.assert.eq(s.reads, reads, "Unavailable data must stop polling after a bounded retry window")
    t.assert.ok(s.reports() <= 1, "Unavailable API should report once")
end)

h.test("secret objective data does not become a false update", function(t)
    local s = env(t)
    s.log[1].objectives[1].text = secret(t, "text")
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.log[1].objectives[1].text = "Wolves 0/8"
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.change(1)
    s.has("Wolves 1/8")
end)

h.test("a secret quest ID is ignored safely without erasing the previous baseline", function(t)
    local s = env(t)
    s.log[1].id = secret(t, "ID")
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.log[1].id = 1
    s.event("QUEST_LOG_UPDATE"); s.silent()
    s.change(1)
    s.has("Wolves 1/8")
end)

h.test("missing and forbidden trackers safely suppress the notice", function(t)
    local s = env(t)
    ObjectiveTrackerFrame = nil
    s.change(1); s.silent()
    ObjectiveTrackerFrame = s.tracker
    s.tracker._forbidden = true
    s.tick(); s.silent()
end)

h.test("QuestWatchFrame is used when the modern tracker is absent", function(t)
    local s = env(t)
    QuestWatchFrame = s.tracker
    ObjectiveTrackerFrame = nil
    s.change(1)
    s.has("Wolves 1/8")
end)
