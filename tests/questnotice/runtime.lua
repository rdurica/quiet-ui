-- Quest notice wiring in the addon runtime: boot, Save, events, ticks and the on/off command.
local h = ...
local Q = h.lib("questnotice")

-- Calls through to the real function and records its arguments.
local function spy(ns, name)
    local calls, real = {}, ns[name]
    ns[name] = function(...) calls[#calls + 1] = { ... }; return real(...) end
    return calls
end

local function booted(t)
    Q.fixture(t.mock, t.ns)
    local calls = {
        apply = spy(t.ns, "ApplyQuestNotice"), restore = spy(t.ns, "RestoreQuestNotice"),
        event = spy(t.ns, "QuestNoticeEvent"), tick = spy(t.ns, "UpdateQuestNotice"),
    }
    t.boot()
    return calls
end

h.test("boot applies the quest notice lifecycle without runtime errors", function(t)
    local calls = booted(t)
    t.assert.ok(#calls.apply > 0, "Boot must apply quest notice")
end)

h.test("ApplyAll reapplies the quest notice", function(t)
    local calls = booted(t)
    local n = #calls.apply
    t.ns.ApplyAll()
    t.assert.ok(#calls.apply > n)
end)

h.test("quest events register independently and forward arguments unchanged", function(t)
    local calls = booted(t)
    for _, name in ipairs({ "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE" }) do
        t.assert.ok(t.mock:eventFrame(name), "Missing registered " .. name)
        local n = #calls.event
        t.mock:fire(name, 11, 22)
        t.assert.eq(#calls.event, n + 1, "Missing forward " .. name)
        local args = calls.event[n + 1]
        t.assert.ok(args[1] == name and args[2] == 11 and args[3] == 22, "Event arguments lost")
    end
end)

h.test("world entry reaches the quest baseline reset", function(t)
    local calls = booted(t)
    local n = #calls.event
    t.mock:fire("PLAYER_ENTERING_WORLD", true, false)
    local found = false
    for i = n + 1, #calls.event do
        if calls.event[i][1] == "PLAYER_ENTERING_WORLD" then found = true end
    end
    t.assert.ok(found, "World entry must reset quest snapshot")
end)

h.test("a stationary active OnUpdate ticks the notice each frame with the elapsed time", function(t)
    local calls = booted(t)
    local n = #calls.tick
    t.mock:tick(0.013); t.mock:tick(0.017)
    t.assert.eq(#calls.tick, n + 2, "Notice timer must update independently of fade rescan")
    t.assert.ok(calls.tick[n + 1][1] == 0.013 and calls.tick[n + 2][1] == 0.017, "Elapsed must be forwarded")
end)

h.test("disable restores, blocks quest events and stops the notice timer; enable resumes", function(t)
    local calls = booted(t)
    local n = #calls.restore
    SlashCmdList.QUIETUI("off")
    t.assert.ok(#calls.restore > n, "Disable must restore quest notice")
    local ev, tick = #calls.event, #calls.tick
    t.mock:fire("QUEST_ACCEPTED", 42); t.mock:tick(0.1)
    t.assert.ok(#calls.event == ev and #calls.tick == tick, "Disabled runtime must not accumulate notices")
    n = #calls.apply
    SlashCmdList.QUIETUI("on")
    t.assert.ok(#calls.apply > n, "Enable must apply")
    n = #calls.tick
    t.mock:tick(0.01)
    t.assert.eq(#calls.tick, n + 1, "Enable must resume update")
end)
