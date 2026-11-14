local h = ...

h.test("Window refresh jobs use the latest arguments and preserve nil arguments", function(t)
    local ns, A = t.ns, t.assert
    local skin, owner = ns.Modern.Skin("refresh-test"), CreateFrame("Frame")
    local calls, seen = 0, nil
    local function paint(...)
        calls = calls + 1
        seen = { n = select("#", ...), ... }
    end
    for i = 1, 100 do ns.Modern.Refresh.Queue(skin, owner, "rows", "test rows", paint, i, nil, "last") end
    A.eq(calls, 0)
    t.mock:tick(0)
    A.eq(calls, 1)
    A.deep(seen, { n = 3, 100, nil, "last" })
    t.mock:tick(0)
    A.eq(calls, 1, "idle frames do no work")
end)

h.test("Restoring a journal cancels only its own window refresh jobs", function(t)
    local ns, A = t.ns, t.assert
    local first, second = ns.Modern.Skin("refresh-first"), ns.Modern.Skin("refresh-second")
    local owner, calls = CreateFrame("Frame"), {}
    ns.Modern.Refresh.Queue(first, owner, "rows", "first", function() calls[#calls + 1] = "stale" end)
    ns.Modern.Refresh.Queue(second, owner, "rows", "second", function() calls[#calls + 1] = "other" end)
    first:Undo()
    ns.Modern.Refresh.Queue(first, owner, "rows", "first", function() calls[#calls + 1] = "new" end)
    t.mock:tick(0)
    table.sort(calls)
    A.deep(calls, { "new", "other" }, "a re-enabled journal must not run its previous job")
end)

h.test("A window refresh can queue work for the next frame and errors do not strand other jobs", function(t)
    local ns, A = t.ns, t.assert
    local skin, owner = ns.Modern.Skin("refresh-test"), CreateFrame("Frame")
    local calls = 0
    local function later() calls = calls + 1 end
    ns.Modern.Refresh.Queue(skin, owner, "again", "test again", function()
        calls = calls + 1
        ns.Modern.Refresh.Queue(skin, owner, "again", "test again", later)
    end)
    ns.Modern.Refresh.Queue(skin, owner, "error", "test error", function() error("refresh failure") end)
    t.mock:tick(0)
    A.eq(calls, 1)
    A.ok(table.concat(t.mock.printed, "\n"):find("refresh failure", 1, true), "the failed job is reported")
    t.mock:tick(0)
    A.eq(calls, 2)
    t.mock:tick(0)
    A.eq(calls, 2)
end)


h.test("Undo callbacks cannot queue a refresh that reapplies restored styling", function(t)
    local ns, A = t.ns, t.assert
    local skin, owner = ns.Modern.Skin("refresh-test"), CreateFrame("Frame")
    local calls = 0
    local function paint() calls = calls + 1 end
    skin:Remember(owner, "restore hook", function()
        ns.Modern.Refresh.Queue(skin, owner, "rows", "test rows", paint)
    end)
    ns.Modern.Refresh.Queue(skin, owner, "rows", "test rows", paint)
    skin:Undo()
    t.mock:tick(0)
    A.eq(calls, 0, "restore-triggered hooks must not leave work behind")
    ns.Modern.Refresh.Queue(skin, owner, "rows", "test rows", paint)
    t.mock:tick(0)
    A.eq(calls, 1, "a later apply can queue work again")
end)
