-- The welcome: the Custom choice under the Classic and Modern cards, its second screen of module
-- checkboxes, what each answer writes, and Custom Save refusing a module change in combat.
local h = ...

local MODULES = { "Chat", "Fading", "Helpers", "Layout", "Modernize" }

local function descendants(frame, out)
    out = out or {}
    for _, child in ipairs(frame._children or {}) do
        out[#out + 1] = child
        descendants(child, out)
    end
    return out
end

local function welcome(mock)
    local found = mock:find(function(f) return f.cards and f.note end)[1]
    assert(found, "no welcome frame")
    return found
end

local function textOf(f)
    for _, key in ipairs({ "label", "title" }) do
        local region = f[key]
        if type(region) == "table" and type(region._text) == "string" and region._text ~= "" then return region._text end
    end
    if type(f._text) == "string" and f._text ~= "" then return f._text end
end

-- Visible controls of the window with the text they start with.
local function control(frame, text, needBox)
    for _, f in ipairs(descendants(frame)) do
        local label = textOf(f)
        if label and label:sub(1, #text) == text and f:IsVisible() and (not needBox or f.box) then return f end
    end
end

local function custom(frame)
    local card = frame.cards.custom
    if card then return card end
    return assert(control(frame, "Custom"), "no Custom choice")
end

local function box(frame, name)
    return assert(control(frame, name, true), "no " .. name .. " checkbox")
end

local function click(b) b._scripts.OnClick(b) end

-- A secure /reload button: PreClick saves, the macro reloads, PostClick closes.
local function press(button)
    if button._scripts.PreClick then
        button._scripts.PreClick(button)
        if button:GetAttribute("type") == "macro" and button:GetAttribute("macrotext") == "/reload" then ReloadUI() end
        button._scripts.PostClick(button)
    else
        click(button)
    end
end

-- Runs fn with InCombatLockdown stubbed to true, then puts the old function back, also when fn fails.
local function inCombat(fn)
    local was = InCombatLockdown
    InCombatLockdown = function() return true end
    local ok, err = pcall(fn)
    InCombatLockdown = was
    if not ok then error(err, 0) end
end

local function said(mock, text)
    for _, line in ipairs(mock.printed) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local function counter()
    local reloads = { n = 0 }
    ReloadUI = function() reloads.n = reloads.n + 1 end
    return reloads
end

local function modules(ns)
    local out = {}
    for _, name in ipairs(MODULES) do out[name] = ns.Settings.Module(name:lower()) end
    return out
end

local function noFalse(map)
    for _, value in pairs(map or {}) do
        if value == false then return false end
    end
    return true
end

h.test("Welcome on a fresh character offers Classic, Modern and Custom", function(t)
    local mock, A = t.mock, t.assert
    t.boot()
    local frame = welcome(mock)
    A.ok(frame:IsShown(), "welcome is shown")
    A.ok(frame.cards.classic:IsVisible() and frame.cards.modern:IsVisible(), "the two cards")
    A.ok(custom(frame):IsVisible(), "a Custom choice")
    A.falsy(control(frame, "Chat", true), "the module checkboxes are not on the first screen")
end)

h.test("Custom shows the second screen with only Chat checked", function(t)
    local mock, A = t.mock, t.assert
    t.boot()
    local frame = welcome(mock)
    click(custom(frame))
    A.falsy(frame.cards.classic:IsVisible() or frame.cards.modern:IsVisible(), "the cards are gone")
    for _, name in ipairs(MODULES) do
        A.ok(box(frame, name), name .. " checkbox")
    end
    A.ok(box(frame, "Chat").box._checked, "Chat is checked")
    for _, name in ipairs({ "Fading", "Helpers", "Layout", "Modernize" }) do
        A.falsy(box(frame, name).box._checked, name .. " is not checked")
    end
    A.ok(control(frame, "Back"), "a Back button")
    A.ok(control(frame, "Save"), "a Save button")
    A.eq(QuietUICharDB.welcomed, nil, "nothing is answered yet")
end)

h.test("Back returns from the second screen to the cards", function(t)
    local mock, A = t.mock, t.assert
    t.boot()
    local frame = welcome(mock)
    click(custom(frame))
    click(box(frame, "Fading"))
    click(control(frame, "Back"))
    A.ok(frame:IsShown(), "the welcome stays open")
    A.ok(frame.cards.classic:IsVisible() and frame.cards.modern:IsVisible() and custom(frame):IsVisible(), "the cards are back")
    A.falsy(control(frame, "Chat", true), "the checkboxes are gone")
    A.eq(QuietUICharDB.welcomed, nil, "Back answers nothing")
    A.eq(QuietUICharDB.modules, nil, "Back saves nothing")
end)

h.test("With nothing checked Save is disabled", function(t)
    local mock, A = t.mock, t.assert
    t.boot()
    local frame = welcome(mock)
    click(custom(frame))
    A.ok(control(frame, "Save"):IsEnabled(), "Chat alone can be saved")
    click(box(frame, "Chat"))
    A.falsy(control(frame, "Save"):IsEnabled(), "nothing checked disables Save")
    click(box(frame, "Fading"))
    A.ok(control(frame, "Save"):IsEnabled(), "a checked module enables it again")
end)

h.test("Custom Save with only Chat writes the chat-only set, marks welcomed and reloads", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local reloads = counter()
    local frame = welcome(mock)
    click(custom(frame))
    press(control(frame, "Save"))
    A.deep(QuietUICharDB.modules, { fading = false, helpers = false, layout = false })
    A.eq(QuietUICharDB.welcomed, true)
    A.eq(reloads.n, 1, "the new set reloads the UI")
    A.falsy(frame:IsShown(), "the welcome closes")
    A.deep(modules(ns), { Chat = true, Fading = false, Helpers = false, Layout = false, Modernize = false })
end)

h.test("Custom Save writes whichever modules are checked", function(t)
    local mock, A = t.mock, t.assert
    t.boot()
    local reloads = counter()
    local frame = welcome(mock)
    click(custom(frame))
    click(box(frame, "Fading"))
    click(box(frame, "Modernize"))
    press(control(frame, "Save"))
    A.deep(QuietUICharDB.modules, { helpers = false, layout = false, modernize = true })
    A.eq(reloads.n, 1)
end)

h.test("Classic writes the Classic set and Modern writes all five on", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    counter()
    local frame = welcome(mock)
    frame.cards.classic:Click()
    press(frame.choose)
    A.deep(modules(ns), { Chat = true, Fading = true, Helpers = true, Layout = true, Modernize = false })
    A.ok(noFalse(QuietUICharDB.modules), "no module is stored off")
    QuietUICharDB.welcomed = nil
    ns.Setup.Welcome()
    frame = welcome(mock)
    frame.cards.modern:Click()
    press(frame.choose)
    A.deep(modules(ns), { Chat = true, Fading = true, Helpers = true, Layout = true, Modernize = true })
    A.ok(noFalse(QuietUICharDB.modules), "no module is stored off")
    A.eq(QuietUICharDB.modules.modernize, true)
end)

h.test("Classic and Modern replace an earlier custom set", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUIDB = { enabled = true, layoutHash = "x" }
    QuietUICharDB = { modules = { chat = false, fading = false, modernize = true } }
    t.boot(false)
    local reloads = counter()
    local frame = welcome(mock)
    frame.cards.classic:Click()
    press(frame.choose)
    A.deep(modules(ns), { Chat = true, Fading = true, Helpers = true, Layout = true, Modernize = false },
        "Classic is the Classic set, whatever was set before")
    A.eq(reloads.n, 1, "a different set reloads")
end)

h.test("A set that is neither Classic nor Modern selects no card", function(t)
    local mock, A = t.mock, t.assert
    QuietUIDB = { enabled = true, layoutHash = "x" }
    QuietUICharDB = { modules = { fading = false } }
    t.boot(false)
    local frame = welcome(mock)
    A.eq(frame.selected, nil, "no card for another set")
    A.falsy(frame.choose:IsEnabled(), "a card must be picked first")
end)

h.test("Modernize on selects Modern and the Classic set selects Classic", function(t)
    local mock, A = t.mock, t.assert
    QuietUIDB = { enabled = true, layoutHash = "x" }
    QuietUICharDB = { modules = { modernize = true } }
    t.boot(false)
    A.eq(welcome(mock).selected, "modern")
end)

h.test("Classic, Modern and Custom with a preset change the preset and the note names it", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local id = ns.Settings.SavePreset(nil, "Raid", { builtin = 1 }, {})
    ns.Settings.ActivatePreset(id)
    QuietUICharDB.welcomed = nil
    ns.Setup.Welcome()
    counter()
    local frame = welcome(mock)
    A.ok(frame.note:GetText():find('preset "Raid"', 1, true), "the note names the preset")
    frame.cards.modern:Click()
    press(frame.choose)
    local settings = QuietUIDB.presets[id].settings
    A.eq(settings.modules and settings.modules.modernize, true, "Modern goes into the preset")
    A.ok(noFalse(settings.modules), "all five on")

    QuietUICharDB.welcomed = nil
    ns.Setup.Welcome()
    frame = welcome(mock)
    click(custom(frame))
    A.ok(frame.note:GetText():find('preset "Raid"', 1, true), "the second screen names the preset too")
    press(control(frame, "Save"))
    A.deep(QuietUIDB.presets[id].settings.modules, { fading = false, helpers = false, layout = false },
        "Custom goes into the preset")
end)

h.test("A character that answered keeps its modules and sees no welcome", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = { welcomed = true, chat = false, modernize = { enabled = true, theme = "dark" } }
    t.boot()
    A.falsy(mock:find(function(f) return f.cards and f.note end)[1] and welcome(mock):IsShown(), "no welcome")
    A.falsy(ns.Setup.WelcomeOpen())
    A.deep(modules(ns), { Chat = false, Fading = true, Helpers = true, Layout = true, Modernize = true },
        "the old Modern chat and Modernize choices carry over")
end)

h.test("A character that answered with nothing changed keeps the Classic set", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = { welcomed = true }
    t.boot()
    A.falsy(ns.Setup.WelcomeOpen())
    A.deep(modules(ns), { Chat = true, Fading = true, Helpers = true, Layout = true, Modernize = false })
    A.eq(#mock:find(function(f) return f.cards and f.note and f:IsShown() end), 0)
end)

h.test("Custom Save in combat is refused: nothing written, not welcomed, no reload", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local reloads = counter()
    local restored = 0
    ns.RestoreAll = function() restored = restored + 1 end
    local frame = welcome(mock)
    -- Combat from the start: the Save button is never armed with /reload.
    inCombat(function()
        click(custom(frame))
        click(box(frame, "Fading"))
        press(control(frame, "Save"))
    end)
    A.ok(said(mock, "Leave combat to change modules."), "the refusal is printed")
    A.eq(QuietUICharDB.modules, nil, "no modules are written")
    A.eq(QuietUICharDB.welcomed, nil, "the welcome is not marked answered")
    A.eq(reloads.n, 0, "no reload")
    A.eq(restored, 0, "nothing is restored")
    A.ok(frame:IsShown(), "the welcome stays open")
    A.ok(box(frame, "Fading").box._checked, "the second screen keeps the picks")
end)

h.test("Nothing is armed before a click, so combat starting after the screen was filled cannot reload", function(t)
    local mock, A = t.mock, t.assert
    t.boot()
    local reloads = counter()
    local frame = welcome(mock)
    click(custom(frame))
    local save = control(frame, "Save")
    A.eq(save:GetAttribute("type"), nil, "not armed while the screen is filled in")
    inCombat(function() press(save) end)
    A.ok(said(mock, "Leave combat to change modules."), "the refusal is printed")
    A.eq(QuietUICharDB.modules, nil, "no modules are written")
    A.eq(QuietUICharDB.welcomed, nil, "the welcome is not marked answered")
    A.eq(reloads.n, 0, "no reload")
    A.eq(save:GetAttribute("type"), nil, "still not armed")
    -- Out of combat the same click saves and reloads, and disarms again.
    press(save)
    A.eq(reloads.n, 1, "reloads out of combat")
    A.eq(save:GetAttribute("type"), nil, "disarmed after the click")
end)
