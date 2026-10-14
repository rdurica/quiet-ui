-- Static structure check over the sources listed in the .toc, plus proofs that each check
-- fails on a broken synthetic source (checker: tests/lib/structure.lua).
local h = ...
local S = h.lib("structure")

-- Files over the limit that may stay for now. Every entry needs a reason; an entry for a file
-- that is gone or back under the limit fails, so the list can only shrink.
local TEMP = "temporary: flat file until #15 restructure"
local SIZE_ALLOWLIST = {
    ["Layout.lua"] = TEMP,
    ["QuietUI.lua"] = TEMP,
}

local function loadSources(t)
    local sources = {}
    for _, name in ipairs(t.tocFiles()) do
        if name:match("%.lua$") then
            sources[#sources + 1] = { name = name, text = assert(t.readFile(name), "cannot read " .. name) }
        end
    end
    return sources
end

local function report(A, problems, what)
    A.eq(#problems, 0, what .. ":\n  " .. table.concat(problems, "\n  "))
end

local function src(name, text) return { name = name, text = text } end

------------------------------------------------------------------------------
-- The addon as it is
------------------------------------------------------------------------------
h.test("every ns reference is defined somewhere in the loaded files", function(t)
    report(t.assert, S.undefinedRefs(loadSources(t)), "undefined ns references")
end)

h.test("no global is assigned outside the allowed list", function(t)
    report(t.assert, S.globalAssignments(loadSources(t)), "stray globals")
end)

h.test("every .lua under the module folders is in the .toc and every .toc line exists", function(t)
    report(t.assert, S.tocProblems(t.tocFiles(), t.luaFiles(S.CHECKED_DIRS), t.fileExists), ".toc coverage")
end)

h.test("no file is over the line limit unless allowlisted with a reason", function(t)
    report(t.assert, S.sizeProblems(loadSources(t), S.MAX_LINES, SIZE_ALLOWLIST), "file size")
end)

h.test("no file captures a function of another file in a local at load", function(t)
    report(t.assert, S.captures(loadSources(t)), "captured functions")
end)

------------------------------------------------------------------------------
-- The checks fail on broken sources
------------------------------------------------------------------------------
h.test("an undefined ns.Chat.Foo call fails naming file and line", function(t)
    local A = t.assert
    local problems = S.undefinedRefs({
        src("Features/Chat/Update.lua", "local _, ns = ...\nns.Chat = {}\nfunction ns.Chat.Update() end\n"),
        src("Features/Menu/Bags.lua", "local _, ns = ...\n\nns.Chat.Foo()\n"),
    })
    A.eq(#problems, 1, table.concat(problems, "\n"))
    A.ok(problems[1]:find("Features/Menu/Bags.lua:3:", 1, true), problems[1])
    A.ok(problems[1]:find("ns.Chat.Foo", 1, true), problems[1])
end)

h.test("defined names pass: functions, fields, constructors and aliases", function(t)
    local problems = S.undefinedRefs({
        src("Core/Base.lua", "local _, ns = ...\nfunction ns.Report() end\nns.Run = function() end\n"),
        src("Features/Chat/A.lua", "local _, ns = ...\nns.Chat = ns.Chat or {}\nlocal Chat = ns.Chat\n"
            .. "function Chat.Update() end\nChat.Restore = function() end\n"),
        src("Features/Menu/B.lua", "local _, ns = ...\nlocal Menu = {\n  Reset = function() end,\n  Fade = nil,\n}\nns.Menu = Menu\n"),
        src("QuietUI.lua", "local _, ns = ...\nns.Report('x')\nns.Chat.Update()\nns.Chat.Restore()\nns.Menu.Reset()\n"
            .. "-- ns.Nope.Thing() in a comment\nlocal s = 'ns.Nope.Thing()'\n"),
    })
    t.assert.eq(#problems, 0, table.concat(problems, "\n"))
end)

h.test("an undefined plain ns.Name read fails", function(t)
    local problems = S.undefinedRefs({ src("A.lua", "local _, ns = ...\nif ns.Missing then end\n") })
    t.assert.eq(#problems, 1)
    t.assert.ok(problems[1]:find("A.lua:2:", 1, true) and problems[1]:find("ns.Missing", 1, true), problems[1])
end)

h.test("a new global assignment fails; the allowed globals pass", function(t)
    local A = t.assert
    local problems = S.globalAssignments({
        src("Features/Glance/Glance.lua", "local _, ns = ...\nlocal x = 1\nMyLeak = 5\nfunction LeakyFn() end\n"),
    })
    A.eq(#problems, 2, table.concat(problems, "\n"))
    A.ok(problems[1]:find("Features/Glance/Glance.lua:3:", 1, true) and problems[1]:find("MyLeak", 1, true), problems[1])
    A.ok(problems[2]:find(":4:", 1, true) and problems[2]:find("LeakyFn", 1, true), problems[2])

    local ok = S.globalAssignments({ src("QuietUI.lua", table.concat({
        "local _, ns = ...",
        "QuietUIDB = QuietUIDB or {}",
        "QuietUICharDB = QuietUICharDB or {}",
        "BINDING_CATEGORY_QUIETUI = 'QuietUI'",
        "BINDING_NAME_QUIETUI_GLANCE = 'Glance'",
        "function QuietUIGlance(keystate) end",
        "QuietUISetup = frame",
        "SLASH_QUIETUI1 = '/quiet'",
        "SLASH_QUIETUI2 = '/quietui'",
        "SlashCmdList[\"QUIETUI\"] = function(msg) end",
        "local t = { Field = 1 }",
        "for i = 1, 3 do local y = i end",
        "local a, b",
        "a, b = 1, 2",
    }, "\n") .. "\n") })
    A.eq(#ok, 0, table.concat(ok, "\n"))
end)

h.test("a foreign slash command or _G write fails", function(t)
    local problems = S.globalAssignments({ src("X.lua", "SlashCmdList[\"OTHER\"] = function() end\n_G.Leak = 1\n") })
    t.assert.eq(#problems, 2, table.concat(problems, "\n"))
end)

h.test("a .lua under Features/ missing from the .toc fails", function(t)
    local problems = S.tocProblems(
        { "Core/Base.lua", "Features/Chat/Update.lua", "QuietUI.lua" },
        { "Core/Base.lua", "Features/Chat/Update.lua", "Features/Chat/Forgotten.lua" },
        function() return true end)
    t.assert.eq(#problems, 1, table.concat(problems, "\n"))
    t.assert.ok(problems[1]:find("Features/Chat/Forgotten.lua", 1, true), problems[1])
end)

h.test("a .toc line without a file fails", function(t)
    local problems = S.tocProblems({ "Core/Base.lua", "Core/Gone.lua" }, { "Core/Base.lua" },
        function(name) return name == "Core/Base.lua" end)
    t.assert.eq(#problems, 1)
    t.assert.ok(problems[1]:find("Core/Gone.lua", 1, true), problems[1])
end)

h.test("a file over the limit fails unless allowlisted with a reason", function(t)
    local A = t.assert
    local long = string.rep("local x = 1\n", S.MAX_LINES + 1)
    local short = string.rep("local x = 1\n", S.MAX_LINES)
    local problems = S.sizeProblems({ src("Features/Big.lua", long), src("Features/Ok.lua", short) }, S.MAX_LINES, {})
    A.eq(#problems, 1, table.concat(problems, "\n"))
    A.ok(problems[1]:find("Features/Big.lua", 1, true), problems[1])
    A.eq(#S.sizeProblems({ src("Features/Big.lua", long) }, S.MAX_LINES, { ["Features/Big.lua"] = "legacy" }), 0)
    A.eq(#S.sizeProblems({ src("Features/Big.lua", long) }, S.MAX_LINES, { ["Features/Big.lua"] = "" }), 1,
        "an allowlist entry needs a reason")
    A.eq(#S.sizeProblems({ src("Features/Ok.lua", short) }, S.MAX_LINES, { ["Features/Ok.lua"] = "stale" }), 1,
        "a stale allowlist entry fails")
end)

h.test("capturing a function of another file in a local fails; a table capture passes", function(t)
    local A = t.assert
    local files = {
        src("Core/Base.lua", "local _, ns = ...\nfunction ns.Report() end\nns.Chat = {}\n"),
        src("Features/Chat/A.lua", "local _, ns = ...\nlocal Report = ns.Report\nlocal Chat = ns.Chat\n"
            .. "local function f()\n    local R = ns.Report\nend\n"),
    }
    local problems = S.captures(files)
    A.eq(#problems, 1, table.concat(problems, "\n"))
    A.ok(problems[1]:find("Features/Chat/A.lua:2:", 1, true) and problems[1]:find("ns.Report", 1, true), problems[1])
end)
