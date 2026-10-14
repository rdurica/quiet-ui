-- Notice lifetime, the bounded queue, suppression by other modes, hover dismissal and the
-- Apply / Restore lifecycle.
local h = ...
local Q = h.lib("questnotice")
local function env(t, opts) return Q.fixture(t.mock, t.ns, opts) end

h.test("duplicate events do not extend the five second lifetime", function(t)
    local s = env(t)
    s.change(1); s.pump(3)
    s.event("QUEST_LOG_UPDATE"); s.pump(1.5); s.pump(0.5)
    s.silent()
end)

h.test("a notice holds five seconds, then fades over 0.3 seconds", function(t)
    local s = env(t)
    s.log[1].objectives[1].text = "Wolves 1/8"
    t.ns.QuestNoticeEvent("QUEST_LOG_UPDATE")
    s.tick(0)
    s.pump(4.9); s.has("Wolves 1/8")
    s.pump(0.2)
    local alpha = s.frame():GetAlpha()
    t.assert.ok(s.frame()._shown and alpha > 0 and alpha < 1, "Notice must fade numerically after five seconds")
    s.pump(0.3)
    s.silent()
end)

h.test("multiple changed quests are queued and shown sequentially", function(t)
    local s = env(t)
    s.log[2] = s.quest(2)
    t.ns.RestoreQuestNotice(); t.ns.ApplyQuestNotice(); s.pump()
    for _, q in ipairs(s.log) do q.objectives[1].text = "Wolves 2/8" end
    s.event("QUEST_LOG_UPDATE")
    local first = s.text()
    t.assert.ok(first:find("Quest 1", 1, true) or first:find("Quest 2", 1, true))
    t.assert.falsy(first:find("Quest 1", 1, true) and first:find("Quest 2", 1, true), "Show one quest at a time")
    s.pump(5.4)
    local second = s.text()
    t.assert.ok(second ~= "" and second ~= first, "Other quest must follow")
end)

h.test("the same quest coalesces and refreshes its lifetime", function(t)
    local s = env(t)
    s.change(1); s.pump(3)
    s.change(2); s.pump(2)
    s.has("Wolves 2/8")
    s.pump(4)
    s.silent()
end)

h.test("the queue caps five quests and drops the oldest waiting entry", function(t)
    local s = env(t)
    s.change(1)
    for id = 2, 7 do
        s.log[#s.log + 1] = s.quest(id)
        s.event("QUEST_ACCEPTED", id)
    end
    local observed = {}
    for _ = 1, 8 do observed[#observed + 1] = s.text(); s.pump(5.4) end
    local text = table.concat(observed, "\n")
    t.assert.falsy(text:find("Quest 2", 1, true), "Oldest waiting quest must be dropped")
    t.assert.ok(text:find("Quest 7", 1, true), "Newest queued quest must survive")
    local seen, count = {}, 0
    for _, v in ipairs(observed) do
        local id = v:match("Quest (%d+)")
        if id and not seen[id] then seen[id] = true; count = count + 1 end
    end
    t.assert.ok(count <= 5, "Queue including current must contain at most five different quests")
end)

local SUPPRESS = {
    glance = { on = function(t) t.ns.ToggleGlance() end, off = function(t) t.ns.ToggleGlance() end },
    edit = { on = function(t) EditModeManagerFrame:Show() end, off = function(t) EditModeManagerFrame:Hide() end },
    pinned = { on = function() QuietUICharDB.visible = { quests = true } end, off = function() QuietUICharDB.visible = nil end },
    hoverOnly = { on = function() QuietUICharDB.hoverOnly = { quests = true } end, off = function() QuietUICharDB.hoverOnly = nil end },
}
for _, mode in ipairs({ "glance", "edit", "pinned", "hoverOnly" }) do
    h.test(mode .. " suppresses the notice while time keeps running", function(t)
        local s = env(t)
        SUPPRESS[mode].on(t)
        s.change(1); s.silent()
        s.pump(6)
        SUPPRESS[mode].off(t)
        s.tick(); s.silent()
    end)
end

h.test("hovering the tracker dismisses the visible notice and does not restore it", function(t)
    local s = env(t)
    s.change(1); s.has("Wolves 1/8")
    s.tracker:SetMouseOver(true); s.tick(); s.silent()
    s.tracker:SetMouseOver(false); s.tick(); s.pump(1); s.silent()
end)

h.test("the quest area rectangle dismisses a visible notice on the same update", function(t)
    local s = env(t)
    s.change(1); s.has("Wolves 1/8")
    s.tracker:SetMouseOver(true); s.tick(); s.silent()
    s.tracker:SetMouseOver(false); s.tick(); s.silent()
end)

h.test("hover dismisses only the visible notice and still shows the next queued quest", function(t)
    local s = env(t)
    s.change(1)
    s.log[2] = s.quest(2)
    s.event("QUEST_ACCEPTED", 2)
    s.tracker:SetMouseOver(true); s.tick(); s.silent()
    s.tracker:SetMouseOver(false); s.tick()
    s.has("Quest 2")
    t.assert.falsy(s.text():find("Quest 1", 1, true), "Hovered notice must not return")
end)

h.test("Apply is idempotent, Restore resets, world entry is silent", function(t)
    local s = env(t)
    s.change(1); t.ns.ApplyQuestNotice(); s.tick(); s.has("Wolves 1/8")
    t.ns.RestoreQuestNotice(); s.silent()
    s.log[1].objectives[1].text = "Wolves 2/8"
    t.ns.ApplyQuestNotice(); s.pump(); s.silent()
    s.change(3); s.has("Wolves 3/8")
    s.event("PLAYER_ENTERING_WORLD", false, false); s.silent()
    s.change(4); s.has("Wolves 4/8")
end)

h.test("a quest setting that is off from startup is silent and never reads the quest log", function(t)
    local s = env(t, { disabled = true })
    t.assert.eq(s.reads, 0, "Disabled notices must not create baseline reads")
    s.log[2] = s.quest(2)
    s.event("QUEST_ACCEPTED", 2)
    s.change(2); s.pump(12); s.silent()
    t.assert.eq(s.reads, 0, "Disabled events and idle must not read quest log")
end)

h.test("turning the setting off at runtime clears current and queued notices", function(t)
    local s = env(t)
    s.change(1)
    s.log[2] = s.quest(2)
    s.event("QUEST_ACCEPTED", 2)
    QuietUICharDB.questNotice = false
    s.tick(); s.silent()
    local reads = s.reads
    s.log[1].objectives[1].text = "Wolves 4/8"
    s.event("QUEST_LOG_UPDATE"); s.pump(6)
    t.assert.eq(s.reads, reads, "Off must stop quest reads and retry work")
    QuietUICharDB.questNotice = nil
    s.tick(); s.pump(); s.silent()
    s.pump(6); s.silent()
    s.change(5); s.has("Wolves 5/8")
    t.assert.falsy(s.text():find("Quest 2", 1, true), "Previous queued notices must be discarded")
end)

h.test("turning the setting on through Apply starts a silent fresh baseline", function(t)
    local s = env(t, { disabled = true })
    s.log[2] = s.quest(2)
    s.event("QUEST_ACCEPTED", 2)
    QuietUICharDB.questNotice = nil
    t.ns.ApplyQuestNotice(); s.pump(); s.silent()
    s.change(3); s.has("Wolves 3/8")
    t.assert.falsy(s.text():find("Quest 2", 1, true), "Off-period acceptance must not replay")
end)
