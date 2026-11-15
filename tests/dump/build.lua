-- ns.Dump.Build and ns.Dump.IssueURL: the report text, its sections, its saved copy and the issue link.
-- Fixture: a client whose build, QuietUI version and addon list are known.
local h = ...

local ADDONS = {
    { name = "QuietUI", title = "QuietUI", version = "9.8.7", enabled = true },
    { name = "Details", title = "Details! Damage Meter", version = "1.2.3", enabled = true },
    { name = "SleepyAddon", title = "Sleepy Addon Title", version = "4.5.6", enabled = false },
}

local function addonAt(id)
    if type(id) == "number" then return ADDONS[id] end
    for _, a in ipairs(ADDONS) do if a.name == id then return a end end
end

local function client()
    local C = _G.C_AddOns
    local function info(id)
        local a = addonAt(id)
        if not a then return nil end
        return a.name, a.title, "notes", a.enabled, a.enabled and nil or "DISABLED", "INSECURE"
    end
    local function meta(id, field)
        local a = addonAt(id)
        if not a then return nil end
        if field == "Version" then return a.version end
        if field == "Title" then return a.title end
    end
    local function state(...)
        for i = 1, select("#", ...) do
            local a = addonAt((select(i, ...)))
            if a then return a.enabled and 2 or 0 end
        end
        return 0
    end
    local function loaded(id) local a = addonAt(id); return a ~= nil and a.enabled end
    local function count() return #ADDONS end
    C.GetNumAddOns, C.GetAddOnInfo, C.GetAddOnMetadata, C.GetAddOnEnableState, C.IsAddOnLoaded = count, info, meta, state, loaded
    _G.GetNumAddOns, _G.GetAddOnInfo, _G.GetAddOnMetadata, _G.GetAddOnEnableState, _G.IsAddOnLoaded = count, info, meta, state, loaded
    _G.GetBuildInfo = function() return "12.0.1", "54321", "Nov 1 2026", 120001 end
    _G.GetLocale = function() return "deDE" end
end

-- The text of each "== Title ==" section, and the titles in order.
local function sections(text)
    local out, order, cur = {}, {}, nil
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local title = line:match("^== (.-) ==%s*$")
        if title then
            cur = title
            out[cur] = {}
            order[#order + 1] = title
        elseif cur then
            out[cur][#out[cur] + 1] = line
        end
    end
    for k, v in pairs(out) do out[k] = table.concat(v, "\n") end
    return out, order
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

local function build(ns) return ns.Dump.Build() end

local function withClient(mock) client() end

h.test("The report has the sections in order and no Last profile without a saved profile", function(t)
    local ns, A = t.ns, t.assert
    local _, order = sections(build(ns))
    A.deep(order, { "Header", "Errors", "State", "Addons", "Settings" })
end, { beforeLoad = withClient })

h.test("Last profile appears between State and Addons when a profile was saved", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB.lastProfile = { "CPU timing: 10.0 seconds, PROFILE-ONE.", "lap / PROFILE-TWO" }
    local secs, order = sections(build(ns))
    A.deep(order, { "Header", "Errors", "State", "Last profile", "Addons", "Settings" })
    A.ok(secs["Last profile"]:find("PROFILE-ONE", 1, true), "first profile line")
    A.ok(secs["Last profile"]:find("PROFILE-TWO", 1, true), "second profile line")
end, { beforeLoad = withClient })

h.test("Header holds the QuietUI version, client build, class, level, locale and no preset", function(t)
    local ns, A = t.ns, t.assert
    t.mock:setUnit("player", { level = 70 })
    local header = sections(build(ns)).Header
    A.ok(header:find("9.8.7", 1, true), "QuietUI version in: " .. header)
    A.ok(header:find("54321", 1, true), "client build")
    A.ok(header:find("12.0.1", 1, true), "client version")
    A.ok(header:lower():find("warrior", 1, true), "class")
    A.ok(header:find("70", 1, true), "level")
    A.ok(header:find("deDE", 1, true), "locale")
    A.ok(header:find("<no preset>", 1, true), "no preset marker")
end, { beforeLoad = withClient })

h.test("Header shows the active preset name", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB.presets = { ["1"] = { name = "Healer Deluxe", layout = {}, settings = {}, interfaceStyle = 0 } }
    QuietUICharDB.presetId = "1"
    local header = sections(build(ns)).Header
    A.ok(header:find("Healer Deluxe", 1, true), "preset name in: " .. header)
    A.falsy(header:find("<no preset>", 1, true), "no preset marker")
end, { beforeLoad = withClient })

h.test("Header shows each module on or off", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB.modules = { fading = false, modernize = true }
    local header = sections(build(ns)).Header:lower()
    A.ok(header:find("fading[^%w\n]+off"), "fading off in: " .. header)
    A.ok(header:find("modernize[^%w\n]+on"), "modernize on")
    A.ok(header:find("chat[^%w\n]+on"), "chat on (the default)")
    A.ok(header:find("helpers[^%w\n]+on"), "helpers on")
    A.ok(header:find("layout[^%w\n]+on"), "layout on")
end, { beforeLoad = withClient })

h.test("The report holds no character or realm name", function(t)
    local ns, A = t.ns, t.assert
    t.mock:setUnit("player", { name = "Zzcharname", level = 12 })
    _G.GetRealmName = function() return "Zzrealmname" end
    _G.UnitFullName = function() return "Zzcharname", "Zzrealmname" end
    local text = build(ns)
    A.falsy(text:find("Zzcharname", 1, true), "character name leaked")
    A.falsy(text:find("Zzrealmname", 1, true), "realm name leaked")
end, { beforeLoad = withClient })

h.test("Errors present in QuietUIDB.errors at load show up in the report", function(t)
    local ns, A = t.ns, t.assert
    local errors = sections(build(ns)).Errors
    A.ok(errors:find("chat", 1, true), "name in: " .. errors)
    A.ok(errors:find("EARLIER-BOOM", 1, true), "message")
    A.ok(errors:find("STACK-LINE-1", 1, true), "stack")
    A.ok(errors:find("2026-11-14 10:00:00", 1, true), "time")
    A.ok(errors:find("0.1.2", 1, true), "version")
    A.ok(errors:find("7", 1, true), "count")
    A.falsy(errors:find("none", 1, true), "an empty marker beside real entries")
end, { beforeLoad = function(mock)
    client()
    _G.QuietUIDB = { enabled = true, errors = { { name = "chat", message = "EARLIER-BOOM", stack = "STACK-LINE-1\nSTACK-LINE-2",
        time = "2026-11-14 10:00:00", version = "0.1.2", count = 7 } } }
end })

h.test("Errors says none when nothing was reported", function(t)
    local ns, A = t.ns, t.assert
    A.ok(sections(build(ns)).Errors:find("none", 1, true), "none marker")
end, { beforeLoad = withClient })

h.test("An error reported in this session shows up in the next report", function(t)
    local ns, A = t.ns, t.assert
    ns.Report("bars", "FRESH-BOOM")
    ns.Report("bars", "FRESH-BOOM")
    local errors = sections(build(ns)).Errors
    A.ok(errors:find("bars", 1, true) and errors:find("FRESH-BOOM", 1, true), "entry in: " .. errors)
    A.falsy(errors:find("none", 1, true), "none marker")
end, { beforeLoad = withClient })

h.test("A damaged errors list does not break the report", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB.errors = "damaged"
    local text
    A.noThrow(function() text = build(ns) end)
    local _, order = sections(text)
    A.deep(order, { "Header", "Errors", "State", "Addons", "Settings" })
end, { beforeLoad = withClient })

h.test("Addons lists another enabled addon with title and version, not QuietUI, not a disabled addon", function(t)
    local ns, A = t.ns, t.assert
    local addons = sections(build(ns)).Addons
    A.ok(addons:find("Details! Damage Meter", 1, true), "title in: " .. addons)
    A.ok(addons:find("1.2.3", 1, true), "version")
    A.falsy(addons:find("QuietUI", 1, true), "QuietUI listed itself")
    A.falsy(addons:find("Sleepy", 1, true), "a disabled addon is listed")
end, { beforeLoad = withClient })

h.test("Addons falls back to the classic globals when C_AddOns has no list functions", function(t)
    local ns, A = t.ns, t.assert
    _G.C_AddOns.GetNumAddOns, _G.C_AddOns.GetAddOnInfo, _G.C_AddOns.GetAddOnEnableState = nil, nil, nil
    local addons
    A.noThrow(function() addons = sections(build(ns)).Addons end)
    A.ok(addons:find("Details! Damage Meter", 1, true), "title in: " .. tostring(addons))
end, { beforeLoad = withClient })

h.test("Addons survives a client without any addon list", function(t)
    local ns, A = t.ns, t.assert
    _G.C_AddOns, _G.GetNumAddOns, _G.GetAddOnInfo = nil, nil, nil
    local _, order
    A.noThrow(function() _, order = sections(build(ns)) end)
    A.deep(order, { "Header", "Errors", "State", "Addons", "Settings" })
end, { beforeLoad = withClient })

h.test("Build returns the text and saves the same text in QuietUIDB.lastDump", function(t)
    local ns, A = t.ns, t.assert
    local text = build(ns)
    A.type(text, "string", "Build result")
    A.ok(#text > 0, "report is not empty")
    A.eq(QuietUIDB.lastDump, text)
    ns.Report("bars", "ANOTHER")
    local second = build(ns)
    A.ne(second, text, "the second report sees the new error")
    A.eq(QuietUIDB.lastDump, second, "lastDump is replaced")
end, { beforeLoad = withClient })

h.test("Settings literals load back: CharDB equal, QuietUIDB without lastDump and errors", function(t)
    local ns, A = t.ns, t.assert
    QuietUICharDB = { chatFade = 20, modules = { fading = false }, visible = { xp = true }, groups = { ["1"] = 2 },
        note = "quote \" and \n newline", list = { 3, 2, 1 } }
    QuietUIDB = { enabled = true, presets = {}, nextPresetId = 4, lastDump = "OLD-DUMP-MARKER",
        errors = { { name = "chat", message = "ERR-MARKER", stack = "", time = "t", version = "v", count = 1 } },
        presetsOpen = { a = 1 } }
    local charBefore = ns.Copy(QuietUICharDB)
    local dbBefore = ns.Copy(QuietUIDB)
    dbBefore.lastDump, dbBefore.errors = nil, nil
    local settings = sections(build(ns)).Settings
    local env = {}
    run(settings, env)
    A.type(env.QuietUICharDB, "table", "QuietUICharDB literal")
    A.type(env.QuietUIDB, "table", "QuietUIDB literal")
    A.deep(env.QuietUICharDB, charBefore)
    A.eq(env.QuietUIDB.lastDump, nil, "lastDump left out")
    A.eq(env.QuietUIDB.errors, nil, "errors left out")
    A.deep(env.QuietUIDB, dbBefore)
    A.falsy(settings:find("OLD-DUMP-MARKER", 1, true), "old dump text in the Settings section")
    A.falsy(settings:find("ERR-MARKER", 1, true), "errors in the Settings section")
end, { beforeLoad = withClient })

h.test("Settings writes <secret> for a secret value and <cycle> for a self-reference, without an error", function(t)
    local ns, A = t.ns, t.assert
    local loop = { name = "loop" }
    loop.me = loop
    QuietUICharDB.hidden = t.mock:secret(42)
    QuietUICharDB.loop = loop
    local text
    A.noThrow(function() text = build(ns) end)
    local settings = sections(text).Settings
    A.ok(settings:find("<secret>", 1, true), "secret marker in: " .. settings)
    A.ok(settings:find("<cycle>", 1, true), "cycle marker")
    A.ok(sections(text).Header, "the report is whole")
end, { beforeLoad = withClient })

h.test("A section whose builder throws shows <error: ...> and the others still appear", function(t)
    local ns, A = t.ns, t.assert
    ns.Settings.ActivePreset = function() error("boom-preset") end
    ns.Layout.Status = function() error("boom-layout") end
    ns.Modern.Areas = function() error("boom-areas") end
    local text
    A.noThrow(function() text = build(ns) end)
    A.ok(text:find("<error:", 1, true), "no <error: ...> in: " .. text)
    A.ok(text:find("boom-", 1, true), "the error text is kept")
    local secs = sections(text)
    for _, title in ipairs({ "Header", "Errors", "State", "Addons", "Settings" }) do
        A.ok(secs[title], "section " .. title .. " is missing")
    end
    A.ok(secs.Errors:find("none", 1, true), "the Errors section is intact")
    A.ok(secs.Settings:find("QuietUICharDB", 1, true), "the Settings section is intact")
    A.eq(QuietUIDB.lastDump, text, "the report with errors is still saved")
end, { beforeLoad = withClient })

h.test("IssueURL is the prefilled new-issue link with the report summary in the body", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB.presets = { ["1"] = { name = "Healer Deluxe", layout = {}, settings = {}, interfaceStyle = 0 } }
    QuietUICharDB.presetId = "1"
    local url = ns.Dump.IssueURL()
    local prefix = "https://github.com/rdurica/quiet-ui/issues/new?title=Bug%3A%20&body="
    A.type(url, "string", "IssueURL result")
    A.eq(url:sub(1, #prefix), prefix, "link start")
    local raw = url:sub(#prefix + 1)
    A.ok(#raw > 0, "empty body")
    A.falsy(raw:find("[^A-Za-z0-9%-_%.~%%]"), "unencoded character in the body: " .. raw)
    A.ok(#url < 2000, "link too long: " .. #url)
    local body = raw:gsub("%%(%x%x)", function(x) return string.char(tonumber(x, 16)) end)
    A.ok(body:find("9.8.7", 1, true), "QuietUI version in: " .. body)
    A.ok(body:find("54321", 1, true), "client build")
    A.ok(body:find("12.0.1", 1, true), "client version")
    A.ok(body:find("Healer Deluxe", 1, true), "preset")
    A.ok(body:lower():find("fading", 1, true), "modules")
    A.ok(body:find("Paste the /quiet dump report below, then describe what you did and what you expected.", 1, true),
        "paste instruction")
end, { beforeLoad = withClient })
