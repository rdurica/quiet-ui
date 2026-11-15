-- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN naming QuietUI are reported like errors, also while QuietUI is off (R2).
local h = ...

local HINT = "Type /quiet dump to report it."
local FN = "MainActionBar:SetAlpha()"

local function start(t)
    QuietUICharDB = { welcomed = true }
    t.boot()
end

local function entry(name)
    for _, e in ipairs(QuietUIDB.errors or {}) do
        if e.name == name then return e end
    end
end

local function errorsSection(text)
    local out, on = {}, false
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local title = line:match("^== (.-) ==%s*$")
        if title then on = (title == "Errors")
        elseif on then out[#out + 1] = line end
    end
    return table.concat(out, "\n")
end

h.test("A blocked action of QuietUI prints one hint line and records an entry without a stack", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    local out = A.capture(mock, function() mock:fire("ADDON_ACTION_BLOCKED", "QuietUI", FN) end)
    A.eq(#out, 1, "chat lines")
    A.ok(out[1]:find(FN, 1, true), "line names the function: " .. tostring(out[1]))
    A.ok(out[1]:sub(-#HINT) == HINT, "line ends with the hint: " .. tostring(out[1]))
    local e = entry("action blocked: " .. FN)
    A.type(e, "table", "errors entry")
    A.eq(e.message, "ADDON_ACTION_BLOCKED " .. FN)
    A.eq(e.stack, "", "stack")
    A.eq(e.count, 1)
end)

h.test("A repeated blocked action counts up and prints once", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    local out = A.capture(mock, function()
        mock:fire("ADDON_ACTION_BLOCKED", "QuietUI", FN)
        mock:fire("ADDON_ACTION_BLOCKED", "QuietUI", FN)
    end)
    A.eq(#out, 1, "chat lines")
    A.eq(entry("action blocked: " .. FN).count, 2)
    A.eq(#QuietUIDB.errors, 1, "one entry")
end)

h.test("A forbidden action of QuietUI is reported as action forbidden", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    local out = A.capture(mock, function() mock:fire("ADDON_ACTION_FORBIDDEN", "QuietUI", "PlayerFrame:Hide()") end)
    A.eq(#out, 1, "chat lines")
    A.ok(out[1]:sub(-#HINT) == HINT, "line ends with the hint: " .. tostring(out[1]))
    local e = entry("action forbidden: PlayerFrame:Hide()")
    A.type(e, "table", "errors entry")
    A.eq(e.message, "ADDON_ACTION_FORBIDDEN PlayerFrame:Hide()")
    A.eq(e.stack, "")
    A.eq(entry("action blocked: PlayerFrame:Hide()"), nil, "not recorded as blocked")
end)

h.test("An action blocked for another addon records nothing and prints nothing", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    local out = A.capture(mock, function()
        mock:fire("ADDON_ACTION_BLOCKED", "SomeOtherAddon", FN)
        mock:fire("ADDON_ACTION_FORBIDDEN", "SomeOtherAddon", FN)
    end)
    A.eq(#out, 0, "chat lines: " .. table.concat(out, " | "))
    A.eq(#(QuietUIDB.errors or {}), 0, "errors")
end)

h.test("A blocked action is recorded while QuietUI is off after /quiet off", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    SlashCmdList.QUIETUI("off")
    A.eq(QuietUIDB.enabled, false)
    local out = A.capture(mock, function() mock:fire("ADDON_ACTION_BLOCKED", "QuietUI", FN) end)
    A.eq(#out, 1, "chat lines")
    A.eq(entry("action blocked: " .. FN).count, 1)
end)

h.test("A blocked action is recorded when QuietUI was off at boot", function(t)
    local A, mock = t.assert, t.mock
    QuietUICharDB = { welcomed = true }
    QuietUIDB.enabled = false
    t.boot()
    local out = A.capture(mock, function() mock:fire("ADDON_ACTION_BLOCKED", "QuietUI", FN) end)
    A.eq(#out, 1, "chat lines")
    A.type(entry("action blocked: " .. FN), "table", "errors entry")
end)

h.test("The dump shows the blocked action in Errors", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    mock:fire("ADDON_ACTION_BLOCKED", "QuietUI", FN)
    local errors = errorsSection(t.ns.Dump.Build())
    A.ok(errors:find("action blocked: " .. FN, 1, true), "name in: " .. errors)
    A.ok(errors:find("ADDON_ACTION_BLOCKED " .. FN, 1, true), "message in: " .. errors)
    A.falsy(errors:find("none", 1, true), "none marker")
end)
