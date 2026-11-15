-- ns.Report: prints once per name and records every call into QuietUIDB.errors (newest 20, with count, version, time).
local h = ...

local HINT = "Type /quiet dump to report it."

-- The addon version the client reports for QuietUI.
local function version(mock)
    local function meta(name, field)
        if name == "QuietUI" and field == "Version" then return "9.8.7" end
        return "0.0.0"
    end
    _G.C_AddOns.GetAddOnMetadata = meta
    _G.GetAddOnMetadata = meta
end

local function lastLine(line, suffix)
    return line:sub(-#suffix) == suffix
end

h.test("Report twice prints one chat line ending with the dump hint and records one entry with count 2", function(t)
    local ns, A = t.ns, t.assert
    local out = A.capture(t.mock, function()
        ns.Report("chat", "boom")
        ns.Report("chat", "boom")
    end)
    A.eq(#out, 1, "chat lines")
    A.ok(out[1]:find("chat", 1, true) and out[1]:find("boom", 1, true), "line names the feature and the error: " .. out[1])
    A.ok(lastLine(out[1], HINT), "line ends with the hint: " .. out[1])
    local errors = QuietUIDB.errors
    A.type(errors, "table", "QuietUIDB.errors")
    A.eq(#errors, 1, "one entry for chat")
    A.eq(errors[1].name, "chat")
    A.eq(errors[1].count, 2)
    A.ok(tostring(errors[1].message):find("boom", 1, true), "message holds the error text")
    A.ok(tostring(errors[1].time):match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$"), "time is YYYY-MM-DD HH:MM:SS, got " .. tostring(errors[1].time))
end)

h.test("Report records the addon version with the entry", function(t)
    local ns, A = t.ns, t.assert
    ns.Report("chat", "boom")
    A.eq(QuietUIDB.errors[1].version, "9.8.7")
end, { beforeLoad = function(mock) version(mock) end })

h.test("Report keeps the debugstack when the client has one", function(t)
    local ns, A = t.ns, t.assert
    ns.Report("chat", "boom")
    A.ok(tostring(QuietUIDB.errors[1].stack):find("STACK-TEXT", 1, true), "stack: " .. tostring(QuietUIDB.errors[1].stack))
end, { beforeLoad = function() _G.debugstack = function() return "STACK-TEXT" end end })

h.test("Report survives a missing or failing debugstack", function(t)
    local ns, A = t.ns, t.assert
    _G.debugstack = nil
    A.noThrow(ns.Report, "a", "one")
    _G.debugstack = function() error("no stack for you") end
    A.noThrow(ns.Report, "b", "two")
    A.eq(#QuietUIDB.errors, 2, "both errors are recorded")
    A.eq(QuietUIDB.errors[2].name, "b")
end)

h.test("25 distinct errors leave the newest 20 in order", function(t)
    local ns, A = t.ns, t.assert
    for i = 1, 25 do ns.Report("e" .. i, "message " .. i) end
    local errors = QuietUIDB.errors
    A.eq(#errors, 20, "entries")
    for i = 1, 20 do
        A.eq(errors[i].name, "e" .. (i + 5), "entry " .. i)
        A.ok(tostring(errors[i].message):find("message " .. (i + 5), 1, true), "message " .. i)
    end
end)

h.test("Repeats of an old name keep counting and keep the order of first occurrence", function(t)
    local ns, A = t.ns, t.assert
    ns.Report("a", "x"); ns.Report("b", "y"); ns.Report("a", "x"); ns.Report("a", "x")
    local errors = QuietUIDB.errors
    A.eq(#errors, 2)
    A.eq(errors[1].name, "a"); A.eq(errors[1].count, 3)
    A.eq(errors[2].name, "b"); A.eq(errors[2].count, 1)
end)

h.test("A first report of a name recorded in an earlier session appends a new entry", function(t)
    local ns, A = t.ns, t.assert
    ns.Report("chat", "fresh")
    local errors = QuietUIDB.errors
    A.eq(#errors, 2, "the old entry stays, the new one is added")
    A.eq(errors[1].message, "old boom")
    A.eq(errors[1].count, 4)
    A.eq(errors[2].name, "chat")
    A.eq(errors[2].count, 1)
end, { beforeLoad = function()
    _G.QuietUIDB = { enabled = true, errors = { { name = "chat", message = "old boom", stack = "", time = "2026-01-01 00:00:00",
        version = "0.0.1", count = 4 } } }
end })

h.test("Report never throws: odd error values and a damaged errors list", function(t)
    local ns, A = t.ns, t.assert
    A.noThrow(ns.Report, "nil err", nil)
    A.noThrow(ns.Report, "table err", { 1, 2 })
    QuietUIDB.errors = "damaged"
    A.noThrow(ns.Report, "after damage", "boom")
    A.type(QuietUIDB.errors, "table", "errors list is rebuilt")
    A.eq(QuietUIDB.errors[#QuietUIDB.errors].name, "after damage")
    A.type(QuietUIDB.errors[#QuietUIDB.errors].message, "string", "message is text")
end)

h.test("A failing ns.Run is recorded with its label and message", function(t)
    local ns, A = t.ns, t.assert
    ns.Run("some feature", error, "run boom", 0)
    A.eq(#QuietUIDB.errors, 1)
    A.eq(QuietUIDB.errors[1].name, "some feature")
    A.ok(tostring(QuietUIDB.errors[1].message):find("run boom", 1, true))
end)

h.test("Reporting never changes alpha or settings other than errors", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB.chatFade = 5
    local calls = t.mock.calls.SetAlpha or 0
    ns.Report("chat", "boom")
    A.eq(t.mock.calls.SetAlpha or 0, calls, "SetAlpha calls")
    A.eq(QuietUICharDB.chatFade, 5)
    A.deep(QuietUICharDB, { chatFade = 5 })
end)

h.test("The recorded stack starts at the reporting caller", function(t)
    local ns, A = t.ns, t.assert
    -- Like the client: level 1 is the function calling debugstack, then its callers outward.
    local calls = { "closure", "ns.Report", "CALLER", "outer" }
    _G.debugstack = function(level)
        local out = {}
        for i = level, #calls do out[#out + 1] = calls[i] end
        return table.concat(out, "\n")
    end
    local function caller() ns.Report("where", "boom") end
    caller()
    A.ok(tostring(QuietUIDB.errors[1].stack):find("^CALLER"), "stack: " .. tostring(QuietUIDB.errors[1].stack))
end)
