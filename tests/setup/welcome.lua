-- The first-run welcome: Classic or Modern, once per account, fresh installs only.
-- Choose is a secure /reload button: a click runs PreClick (save), the macro, then PostClick (hide).
local h = ...

local function choose(button)
    button._scripts.PreClick(button)
    if button:GetAttribute("macrotext") == "/reload" then ReloadUI() end
    button._scripts.PostClick(button)
end

local function welcome(mock)
    return mock:find(function(f) return f.cards and f.note end)[1]
end

h.test("Welcome opens on a fresh install and Modern turns Modernize on with a reload", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    local reloads = 0
    t.boot()
    ReloadUI = function() reloads = reloads + 1 end
    local frame = welcome(mock)
    A.ok(frame and frame:IsShown(), "welcome is shown")
    A.ok(ns.Setup.WelcomeOpen(), "welcome reports open")
    A.ok(frame.cards.classic and frame.cards.modern, "two choices")
    A.falsy(frame.choose:IsEnabled(), "Choose waits for a card")
    frame.cards.modern:Click()
    A.ok(frame:IsShown() and frame.choose:IsEnabled(), "a card only selects")
    A.eq(reloads, 0)
    A.eq(frame.choose:GetAttribute("type"), "macro")
    choose(frame.choose)
    A.falsy(frame:IsShown(), "a choice closes the welcome")
    A.eq(QuietUIDB.welcomed, true)
    A.eq(ns.Settings.Modernize(), true)
    A.eq(reloads, 1)
end)

h.test("Classic keeps Modernize off and reloads", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    local reloads = 0
    t.boot()
    ReloadUI = function() reloads = reloads + 1 end
    local frame = welcome(mock)
    frame.cards.modern:Click()
    frame.cards.classic:Click()
    A.eq(frame.choose:GetAttribute("type"), "macro")
    choose(frame.choose)
    A.eq(QuietUIDB.welcomed, true)
    A.eq(ns.Settings.Modernize(), false)
    A.eq(reloads, 1)
    A.falsy(ns.Setup.WelcomeOpen())
end)

h.test("Welcome stays closed once answered", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUIDB = { welcomed = true }
    t.boot()
    A.falsy(welcome(mock))
    A.falsy(ns.Setup.WelcomeOpen())
end)

h.test("An account that answered the layout prompt skips the welcome", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUIDB = { layoutHash = "x" }
    t.boot()
    A.falsy(welcome(mock))
    A.eq(QuietUIDB.welcomed, true)
end)
