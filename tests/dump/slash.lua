-- /quiet dump: needs QuietUI on, works in combat.
local h = ...

local OFF = "QuietUI is off. Turn it on with /quiet on, then type /quiet dump."

local function start(t)
    QuietUICharDB = { welcomed = true }
    t.boot()
end

local function windowShown(t)
    local win = t.mock:findByName("QuietUIDump")
    return win ~= nil and win:IsShown()
end

h.test("/quiet dump while on opens the QuietUIDump window", function(t)
    local A = t.assert
    start(t)
    A.falsy(windowShown(t), "closed before the command")
    SlashCmdList.QUIETUI("dump")
    A.ok(windowShown(t), "the report window is open")
    SlashCmdList.QUIETUI("  Dump  ")
    A.ok(windowShown(t), "spaces and case do not matter")
end)

h.test("/quiet dump while QuietUI is off prints how to turn it on and opens no window", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    SlashCmdList.QUIETUI("off")
    A.eq(QuietUIDB.enabled, false)
    local lines = A.capture(mock, SlashCmdList.QUIETUI, "dump")
    A.eq(#lines, 1, "exactly one line is printed")
    A.ok(lines[1]:sub(-#OFF) == OFF, "the line ends with: " .. OFF .. " (got " .. lines[1] .. ")")
    A.falsy(windowShown(t), "no window opens")
    A.eq(mock:findByName("QuietUIDump"), nil, "no window is created")
    A.eq(QuietUIDB.enabled, false, "the command does not turn QuietUI on")
end)

h.test("/quiet dump in combat opens the window", function(t)
    local A, mock = t.assert, t.mock
    start(t)
    mock.state.combat = true
    A.noThrow(SlashCmdList.QUIETUI, "dump")
    A.ok(windowShown(t), "the window opens in combat")
    A.notPrinted(mock, "Leave combat")
end)
