-- Setup and Welcome combat lockdown: auto-hide via state driver, reopen after combat
-- preserving drafts and tabs, refuse /quiet setup and drag in combat, work while QuietUI is off.
local h = ...

local function click(b) b._scripts.OnClick(b) end

local function descendants(frame, out)
    out = out or {}
    for _, child in ipairs(frame._children or {}) do
        out[#out + 1] = child
        descendants(child, out)
    end
    return out
end

local function page(ui, id)
    for _, p in ipairs(ui.pages) do if p.id == id then return p end end
end

local function tab(ui, id)
    for _, t in ipairs(ui.tabs) do if t.id == id then return t end end
end

local function stepper(root, text)
    for _, f in ipairs(descendants(root)) do
        if f.plus and f.minus and f.label and f.label._text == text then return f end
    end
end

local function welcome(mock)
    return mock:find(function(f) return f.cards and f.note end)[1]
end

local function said(mock, text)
    for _, line in ipairs(mock.printed) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

local function leaveCombat(mock)
    mock.state.combat = false
    mock:fire("PLAYER_REGEN_ENABLED")
end

h.test("QuietUISetup hides on combat and reopens on PLAYER_REGEN_ENABLED preserving draft and active tab", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = { welcomed = true }
    t.boot()
    ns.Setup.Show()
    local ui = mock:findByName("QuietUISetup")
    A.ok(ui and ui:IsShown(), "setup starts shown")
    A.eq(ui._stateDrivers and ui._stateDrivers.visibility, "[combat] hide", "combat visibility driver registered")

    click(tab(ui, "chat"))
    click(stepper(page(ui, "chat"), "Fade after").plus)
    A.eq(ui.page, "chat", "chat tab is active")
    A.eq(QuietUICharDB.chatFade, nil, "draft is unsaved")

    mock.state.combat = true
    A.falsy(ui:IsShown(), "combat hides setup via state driver")

    leaveCombat(mock)
    A.ok(ui:IsShown(), "leaving combat reopens setup")
    A.eq(ui.page, "chat", "active tab is preserved")
    A.eq(stepper(page(ui, "chat"), "Fade after").value._text, "15 s", "unsaved draft is preserved")
    A.eq(QuietUICharDB.chatFade, nil, "draft stays unsaved until Save")
end)

h.test("QuietUISetup and welcome reopen when the combat driver hides them before lockdown begins", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = {}
    t.boot()
    ns.Setup.Show()
    local ui = mock:findByName("QuietUISetup")
    local wel = welcome(mock)
    A.ok(ui:IsShown() and wel and wel:IsShown(), "both start shown")

    local lockdown = InCombatLockdown
    InCombatLockdown = function() return false end
    mock.state.combat = true
    InCombatLockdown = lockdown
    A.falsy(ui:IsShown() or wel:IsShown(), "driver hid both")

    leaveCombat(mock)
    A.ok(ui:IsShown(), "setup reopens")
    A.ok(wel:IsShown(), "welcome reopens")
end)

h.test("PLAYER_REGEN_ENABLED does not open QuietUISetup when it was never open or closed out of combat", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = { welcomed = true }
    t.boot()

    -- Never opened before combat.
    mock.state.combat = true
    leaveCombat(mock)
    local ui = mock:findByName("QuietUISetup")
    A.falsy(ui and ui:IsShown(), "never opened stays closed after combat")

    -- Opened and closed normally via X out of combat.
    ns.Setup.Show()
    ui = mock:findByName("QuietUISetup")
    click(ui.close)
    A.falsy(ui:IsShown())
    mock.state.combat = true
    leaveCombat(mock)
    A.falsy(ui:IsShown(), "closed setup stays closed after combat")
end)

h.test("Setup.Show, /quiet setup and minimap click in combat print notice without ADDON_ACTION_BLOCKED", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = { welcomed = true }
    t.boot()
    local minimap = ns.Setup.MinimapButton()
    A.ok(minimap, "minimap button exists")

    mock.state.combat = true
    ns.Setup.Show()
    A.ok(said(mock, "Leave combat to open setup."), "Setup.Show prints combat notice")
    local ui = mock:findByName("QuietUISetup")
    A.falsy(ui and ui:IsShown(), "setup is not shown in combat")

    mock.printed = {}
    SlashCmdList["QUIETUI"]("setup")
    A.ok(said(mock, "Leave combat to open setup."), "/quiet setup prints combat notice")

    mock.printed = {}
    minimap._scripts.OnMouseUp(minimap, "LeftButton")
    A.ok(said(mock, "Leave combat to open setup."), "minimap click prints combat notice")

    leaveCombat(mock)
    ui = mock:findByName("QuietUISetup")
    A.falsy(ui and ui:IsShown(), "refused open in combat does not auto-open after combat")
end)

h.test("Dragging QuietUISetup in combat returns early without ADDON_ACTION_BLOCKED", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUICharDB = { welcomed = true }
    t.boot()
    ns.Setup.Show()
    local ui = mock:findByName("QuietUISetup")
    local handle = ui.dragHandle

    -- Starting drag while in combat.
    mock.state.combat = true
    handle._scripts.OnDragStart(handle)
    A.falsy(ui:IsMoving(), "drag start does not start moving in combat")

    -- Combat starting mid-drag.
    leaveCombat(mock)
    handle._scripts.OnDragStart(handle)
    A.ok(ui:IsMoving(), "drag started out of combat")
    mock.state.combat = true
    handle._scripts.OnDragStop(handle)
end)

h.test("Welcome hides on combat and reopens preserving Custom screen, and defers if opened during combat", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    t.boot()
    local frame = welcome(mock)
    A.ok(frame and frame:IsShown(), "welcome opens on boot")
    A.eq(frame._stateDrivers and frame._stateDrivers.visibility, "[combat] hide", "welcome registers combat driver")

    click(frame.customButton)
    A.ok(frame.save and frame.save:IsShown(), "Custom screen is open")

    mock.state.combat = true
    A.falsy(ns.Setup.WelcomeOpen(), "combat hides welcome")

    leaveCombat(mock)
    A.ok(ns.Setup.WelcomeOpen(), "leaving combat reopens welcome")
    A.ok(frame.save and frame.save:IsShown(), "Custom screen is preserved")
end)

h.test("Setup.Welcome called during combat defers until PLAYER_REGEN_ENABLED", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    mock.state.combat = true
    t.boot()
    A.falsy(ns.Setup.WelcomeOpen(), "welcome does not open in combat")

    leaveCombat(mock)
    A.ok(ns.Setup.WelcomeOpen(), "welcome opens once combat ends")
end)

h.test("Combat reopen for Setup and Welcome works while QuietUI is turned off", function(t)
    local ns, mock, A = t.ns, t.mock, t.assert
    QuietUIDB = { enabled = false }
    QuietUICharDB = {}
    mock.state.combat = true
    t.boot()
    A.falsy(ns.Setup.WelcomeOpen(), "welcome deferred in combat while addon is off")

    leaveCombat(mock)
    A.ok(ns.Setup.WelcomeOpen(), "welcome opens after combat even while addon is off")
    local frame = welcome(mock)
    frame.cards.classic:Click()
    frame.choose._scripts.PreClick(frame.choose)
    frame.choose._scripts.PostClick(frame.choose)
    A.eq(QuietUICharDB.welcomed, true)

    ns.Setup.Show()
    local ui = mock:findByName("QuietUISetup")
    click(tab(ui, "chat"))
    mock.state.combat = true
    A.falsy(ui:IsShown(), "setup hides on combat while addon is off")

    leaveCombat(mock)
    A.ok(ui:IsShown(), "setup reopens after combat even while addon is off")
    A.eq(ui.page, "chat", "tab preserved while addon is off")
end)
