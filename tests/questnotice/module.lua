-- Helpers module (settings.modules.helpers): off means no quest notice, even with Quest updates checked.
local h = ...
local Q = h.lib("questnotice")

-- Boots through the real event frame with the given modules, then accepts a second quest.
local function accept(t, modules)
    local s = Q.fixture(t.mock, t.ns)
    QuietUICharDB = { questNotice = true, modules = modules }
    t.boot()
    s.log[2] = s.quest(2)
    t.mock:fire("QUEST_ACCEPTED", 2)
    for _ = 1, 40 do t.mock:tick(0.05) end
    return s
end

h.test("Helpers on (missing): an accepted quest shows its notice", function(t)
    local s = accept(t, nil)
    s.has("Quest 2")
end)

h.test("Helpers off: an accepted quest shows no notice, with Quest updates checked", function(t)
    local s = accept(t, { helpers = false })
    s.silent()
end)

h.test("Helpers off: progress and completion events show no notice either", function(t)
    local s = accept(t, { helpers = false })
    s.log[1].objectives[1].text = "Wolves 5/8"
    t.mock:fire("QUEST_LOG_UPDATE")
    for _ = 1, 40 do t.mock:tick(0.05) end
    s.silent()
    s.log[1].complete = true
    t.mock:fire("QUEST_LOG_UPDATE")
    for _ = 1, 40 do t.mock:tick(0.05) end
    s.silent()
end)
