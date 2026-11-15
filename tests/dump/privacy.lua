-- The Settings section never carries sent chat lines: chatHistory is written as "<N lines>" and no line text is in the report (R2).
local h = ...

local function sections(text)
    local out, cur = {}, nil
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local title = line:match("^== (.-) ==%s*$")
        if title then cur = title; out[cur] = {}
        elseif cur then out[cur][#out[cur] + 1] = line end
    end
    for k, v in pairs(out) do out[k] = table.concat(v, "\n") end
    return out
end

local function run(text, env)
    local fn, err
    if setfenv then
        fn, err = loadstring(text)
        if fn then setfenv(fn, env) end
    else
        fn, err = load(text, "settings", "t", env)
    end
    if not fn then error("the Settings section does not load: " .. tostring(err) .. "\n" .. text, 0) end
    return fn()
end

h.test("The report holds no chat history line and the Settings section says how many lines there are", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB.chatHistory = { "/w Friend secret one", "hello guild" }
    local text = ns.Dump.Build()
    A.falsy(text:find("secret one", 1, true), "whisper text in the report")
    A.falsy(text:find("hello guild", 1, true), "guild text in the report")
    A.falsy(text:find("/w Friend", 1, true), "whisper command in the report")
    A.ok(sections(text).Settings:find('chatHistory = "<2 lines>"', 1, true), "line count missing in: " .. sections(text).Settings)
    A.falsy(QuietUIDB.lastDump:find("secret one", 1, true), "the saved copy holds the text")
end)

h.test("The QuietUICharDB literal loads back equal apart from chatHistory, which is the line count", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = { chatFade = 20, modules = { fading = false }, visible = { xp = true }, list = { 3, 2, 1 },
        chatHistory = { "/w Friend secret one", "hello guild" } }
    local expected = ns.Copy(QuietUICharDB)
    expected.chatHistory = "<2 lines>"
    local env = {}
    run(sections(ns.Dump.Build()).Settings, env)
    A.type(env.QuietUICharDB, "table", "QuietUICharDB literal")
    A.deep(env.QuietUICharDB, expected)
    A.eq(#QuietUICharDB.chatHistory, 2, "the dump leaves the real history alone")
    A.eq(QuietUICharDB.chatHistory[1], "/w Friend secret one", "the dump changed the real history")
end)

h.test("An empty history is written as <0 lines>", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB.chatHistory = {}
    local settings = sections(ns.Dump.Build()).Settings
    A.ok(settings:find('chatHistory = "<0 lines>"', 1, true), "count missing in: " .. settings)
end)

h.test("A missing history stays missing", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB.chatFade = 7
    local settings = sections(ns.Dump.Build()).Settings
    A.falsy(settings:find("chatHistory", 1, true), "chatHistory appears: " .. settings)
    local env = {}
    run(settings, env)
    A.eq(env.QuietUICharDB.chatHistory, nil)
    A.eq(env.QuietUICharDB.chatFade, 7)
end)
