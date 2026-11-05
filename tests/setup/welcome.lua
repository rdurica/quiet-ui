-- The welcome: Classic or Modern, once per character, also after an update.
-- Choose is a secure /reload button: a click runs PreClick (save), the macro, then PostClick (hide).
local h = ...

local function choose(button)
    button._scripts.PreClick(button)
    if button:GetAttribute("type") == "macro" and button:GetAttribute("macrotext") == "/reload" then ReloadUI() end
    button._scripts.PostClick(button)
end

local function welcome(mock)
    return mock:find(function(f) return f.cards and f.note end)[1]
end

local function counter()
    local reloads = { n = 0 }
    ReloadUI = function() reloads.n = reloads.n + 1 end
    return reloads
end

h.test("Welcome opens on a fresh install and Modern turns Modernize on with a reload", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local reloads = counter()
    local frame = welcome(mock)
    A.ok(frame and frame:IsShown(), "welcome is shown")
    A.ok(ns.Setup.WelcomeOpen(), "welcome reports open")
    A.ok(frame.cards.classic and frame.cards.modern, "two choices")
    A.falsy(frame.choose:IsEnabled(), "a fresh install picks a card first")
    frame.cards.modern:Click()
    A.ok(frame:IsShown() and frame.choose:IsEnabled(), "a card only selects")
    A.eq(reloads.n, 0)
    choose(frame.choose)
    A.falsy(frame:IsShown(), "a choice closes the welcome")
    A.eq(QuietUICharDB.welcomed, true)
    A.eq(ns.Settings.Modernize(), true)
    A.eq(reloads.n, 1)
end)

h.test("Classic on a fresh install keeps the look and closes without a reload", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local reloads = counter()
    local frame = welcome(mock)
    frame.cards.modern:Click()
    frame.cards.classic:Click()
    choose(frame.choose)
    A.eq(QuietUICharDB.welcomed, true)
    A.eq(ns.Settings.Modernize(), false)
    A.eq(reloads.n, 0, "the same look does not reload")
    A.falsy(ns.Setup.WelcomeOpen())
end)

h.test("Welcome stays closed on a character that answered", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = { welcomed = true }
    t.boot()
    A.falsy(welcome(mock))
    A.falsy(ns.Setup.WelcomeOpen())
end)

h.test("Another character of the account asks again", function(t)
    local mock, A = t.mock, t.assert
    QuietUIDB = { enabled = true, welcomed = true, layoutHash = "x" }
    QuietUICharDB = {}
    t.boot()
    local frame = welcome(mock)
    A.ok(frame and frame:IsShown(), "a new character sees the welcome")
    A.eq(QuietUIDB.welcomed, nil, "the account no longer holds the answer")
end)

h.test("An updating player sees the current look selected", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUIDB = { enabled = true, layoutHash = "x" }
    t.boot()
    local reloads = counter()
    local frame = welcome(mock)
    A.ok(frame:IsShown() and frame.choose:IsEnabled(), "Choose is ready")
    A.eq(frame.selected, "classic")
    choose(frame.choose)
    A.eq(reloads.n, 0)
    A.eq(QuietUICharDB.welcomed, true)
    A.eq(ns.Settings.Modernize(), false)
end)

h.test("A character with Modernize on sees Modern selected", function(t)
    local mock, A = t.mock, t.assert
    QuietUICharDB = { modernize = { enabled = true } }
    t.boot(false)
    A.eq(welcome(mock).selected, "modern")
end)

h.test("A character with a preset changes that preset and is told so", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local id = ns.Settings.SavePreset(nil, "Raid", { builtin = 1 }, {})
    ns.Settings.ActivatePreset(id)
    QuietUICharDB.welcomed = nil
    ns.Setup.Welcome()
    local reloads = counter()
    local frame = welcome(mock)
    A.ok(frame.note:GetText():find('preset "Raid"', 1, true), "the note names the preset")
    frame.cards.modern:Click()
    choose(frame.choose)
    A.eq(reloads.n, 1)
    A.eq(QuietUIDB.presets[id].settings.modernize.enabled, true, "the preset holds the choice")
end)

h.test("A look chosen in combat asks for /reload", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local reloads = counter()
    local frame = welcome(mock)
    mock.state.combat = true
    frame.cards.modern:Click()
    choose(frame.choose)
    A.eq(reloads.n, 0)
    A.eq(ns.Settings.Modernize(), true)
    local said = false
    for _, line in ipairs(mock.printed) do if line:find("/reload", 1, true) then said = true end end
    A.ok(said, "the player is told to /reload")
end)
