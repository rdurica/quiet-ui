-- Setup: the Modules tab, the sidebar following the modules in the draft, the split Chat and Helpers
-- tabs, Save with a changed module set, and refusing a module change in combat.
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

local function labelOf(f)
    local label = f.label and f.label._text
    if type(label) == "string" and label ~= "" then return label end
end

-- A check box row ("Choice") on a page, found by the start of its label.
local function choice(root, text)
    for _, f in ipairs(descendants(root)) do
        local label = labelOf(f)
        if f.box and label and label:sub(1, #text) == text then return f end
    end
end

local function stepper(root, text)
    for _, f in ipairs(descendants(root)) do
        if f.plus and f.minus and f.label and f.label._text == text then return f end
    end
end

local function moduleBox(ui, name)
    local modules = page(ui, "modules")
    assert(modules, "no Modules page")
    local box = choice(modules, name)
    assert(box, "no " .. name .. " checkbox on the Modules page")
    return box
end

local function tab(ui, label)
    for _, t in ipairs(ui.tabs) do if t.label._text == label then return t end end
end

local function sidebar(ui)
    local out = {}
    for _, t in ipairs(ui.tabs) do
        if t:IsShown() then out[#out + 1] = t.label._text end
    end
    return out
end

local function said(mock, text)
    for _, line in ipairs(mock.printed) do
        if line:find(text, 1, true) then return true end
    end
    return false
end

-- Runs fn with InCombatLockdown stubbed to true, then puts the old function back, also when fn fails.
local function inCombat(fn)
    local was = InCombatLockdown
    InCombatLockdown = function() return true end
    local ok, err = pcall(fn)
    InCombatLockdown = was
    if not ok then error(err, 0) end
end

-- Opens the window on a booted addon. ApplyAll, RestoreAll and ReloadUI are recorders, in call order.
local function open(t, char)
    local ns = t.ns
    QuietUICharDB = char or {}
    t.boot()
    local log = { events = {} }
    ns.ApplyAll = function() log.events[#log.events + 1] = "apply" end
    ns.RestoreAll = function()
        log.events[#log.events + 1] = "restore"
        -- The old set is still the saved one while everything is restored.
        local saved = QuietUICharDB.modules
        log.fadingSavedAtRestore = not (type(saved) == "table" and saved.fading == false)
    end
    ReloadUI = function()
        log.events[#log.events + 1] = "reload"
        log.modulesAtReload = QuietUICharDB.modules and ns.Copy(QuietUICharDB.modules)
    end
    ns.Setup.Show()
    return t.mock:findByName("QuietUISetup"), log
end

h.test("Modules is the first tab and the sidebar lists the tabs of the modules that are on", function(t)
    local A = t.assert
    local ui = open(t)
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Chat,Helpers,Info",
        "defaults: every module but Modernize is on")
    A.eq(ui.tabs[1].label._text, "Modules", "Modules comes first")
    A.eq(ui.pages[1].id, "modules")
end)

h.test("Modernize on adds the Modern tab", function(t)
    local A = t.assert
    local ui = open(t, { modules = { modernize = true } })
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Chat,Helpers,Modern,Info")
end)

h.test("Modules page: five checkboxes follow the saved set", function(t)
    local ns, A = t.ns, t.assert
    local ui = open(t)
    for _, name in ipairs({ "Chat", "Fading", "Helpers", "Layout" }) do
        A.ok(moduleBox(ui, name).box._checked, name .. " is on by default")
    end
    A.falsy(moduleBox(ui, "Modernize").box._checked, "Modernize is off by default")
    ui:Hide()
    QuietUICharDB.modules = { fading = false, modernize = true }
    ns.Setup.Show()
    A.falsy(moduleBox(ui, "Fading").box._checked, "a saved Fading off shows unchecked")
    A.ok(moduleBox(ui, "Chat").box._checked)
    A.ok(moduleBox(ui, "Modernize").box._checked, "a saved Modernize on shows checked")
end)

h.test("With only Chat on the sidebar shows Modules, General, Chat and Info, and General has no layout controls", function(t)
    local A = t.assert
    local ui = open(t, { modules = { fading = false, helpers = false, layout = false } })
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Chat,Info")
    A.falsy(ui.layoutSelector:IsShown(), "no layout selector")
    A.falsy(ui.forceLayout:IsShown(), "no Force QuietUI layout")
    A.falsy(ui.import:IsShown(), "no Import layout")
end)

h.test("With Layout off an active preset shows no layout selector and Save keeps its layout link", function(t)
    local ns, A = t.ns, t.assert
    local ui = open(t)
    ui:Hide()
    local id = ns.Settings.SavePreset(nil, "Raid", { builtin = 1 }, { modules = { layout = false } })
    ns.Settings.ActivatePreset(id)
    ns.Setup.Show()
    A.falsy(ui.layoutSelector:IsShown(), "no layout selector with Layout off")
    A.falsy(ui.forceLayout:IsShown())
    click(ui.save)
    A.falsy(said(t.mock, "Edit Mode layout"), "Layout off does not ask for a layout")
    A.eq(ns.Settings.Presets()[id].layout.builtin, 1, "the preset keeps its link")
end)

h.test("With Layout on the layout controls stay on General", function(t)
    local A = t.assert
    local ui = open(t)
    A.ok(ui.forceLayout:IsShown(), "Force QuietUI layout without a preset")
    A.ok(ui.import:IsShown(), "Import layout")
end)

h.test("Unchecking a module in the draft hides its tabs at once and saves nothing", function(t)
    local A = t.assert
    local ui = open(t)
    click(tab(ui, "Modules"))
    click(moduleBox(ui, "Fading"))
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Chat,Helpers,Info", "Visible, Bars, Groups and Player left")
    click(moduleBox(ui, "Fading"))
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Chat,Helpers,Info", "checking brings them back")
    click(moduleBox(ui, "Chat"))
    click(moduleBox(ui, "Helpers"))
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Info")
    click(moduleBox(ui, "Modernize"))
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Modern,Info")
    A.eq(QuietUICharDB.modules, nil, "nothing is saved before Save")
end)

h.test("Unchecking Layout in the draft hides Import layout and the layout controls at once", function(t)
    local A = t.assert
    local ui = open(t)
    click(moduleBox(ui, "Layout"))
    A.falsy(ui.import:IsShown(), "Import layout leaves")
    A.falsy(ui.forceLayout:IsShown(), "Force QuietUI layout leaves")
    click(moduleBox(ui, "Layout"))
    A.ok(ui.import:IsShown() and ui.forceLayout:IsShown(), "they come back")
end)

h.test("Closing with X restores the saved tabs", function(t)
    local ns, A = t.ns, t.assert
    local ui = open(t)
    click(moduleBox(ui, "Fading"))
    click(moduleBox(ui, "Modernize"))
    click(ui.close)
    A.falsy(ui:IsShown())
    ns.Setup.Show()
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Chat,Helpers,Info", "the saved tabs are back")
    A.ok(moduleBox(ui, "Fading").box._checked and not moduleBox(ui, "Modernize").box._checked, "the boxes match the saved set")
end)

h.test("Closing through Escape restores the saved tabs", function(t)
    local ns, A = t.ns, t.assert
    local ui = open(t)
    local escape = false
    for _, name in ipairs(UISpecialFrames) do if name == "QuietUISetup" then escape = true end end
    A.ok(escape, "Escape closes the window")
    click(moduleBox(ui, "Helpers"))
    ui:Hide()
    ns.Setup.Show()
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Chat,Helpers,Info")
    A.ok(moduleBox(ui, "Helpers").box._checked)
end)

h.test("An open page whose tab leaves falls back to Modules", function(t)
    local A = t.assert
    local ui = open(t, { modules = { modernize = true } })
    click(tab(ui, "Modern"))
    A.eq(ui.page, "modern")
    click(ui.reset)
    A.eq(table.concat(sidebar(ui), ","), "Modules,General,Visible,Bars,Groups,Player,Chat,Helpers,Info", "Reset turns Modernize off")
    A.eq(ui.page, "modules", "the open page falls back to Modules")
    A.ok(page(ui, "modules"):IsShown(), "the Modules page shows")
    A.falsy(page(ui, "modern"):IsShown(), "the Modern page is gone")
end)

h.test("A reopened window does not open a page whose tab left", function(t)
    local ns, A = t.ns, t.assert
    local ui = open(t)
    click(tab(ui, "Bars"))
    A.eq(ui.page, "bars")
    ui:Hide()
    QuietUICharDB.modules = { fading = false }
    ns.Setup.Show()
    A.eq(ui.page, "modules")
    A.ok(page(ui, "modules"):IsShown())
    A.falsy(page(ui, "bars"):IsShown())
end)

h.test("The Chat tab has no Modern chat checkbox", function(t)
    local A = t.assert
    local ui = open(t)
    local chat = page(ui, "chat")
    A.ok(chat, "a Chat page")
    A.falsy(choice(chat, "Modern chat"), "no Modern chat checkbox")
    A.ok(stepper(chat, "Fade after"), "Fade after stays")
    A.ok(stepper(chat, "Tabs"), "Tabs stays")
    A.falsy(choice(chat, "Quest updates"), "the quest options moved to Helpers")
    A.falsy(choice(chat, "Quest mobs"))
end)

h.test("The Helpers tab holds quests, highlights and quest mobs", function(t)
    local A = t.assert
    local ui = open(t)
    local helpers = page(ui, "helpers")
    A.ok(helpers, "a Helpers page")
    for _, label in ipairs({ "Quest updates", "Herbs", "Ore", "Interact objects", "Quest mobs" }) do
        A.ok(choice(helpers, label), label .. " is on the Helpers page")
    end
    A.ok(stepper(helpers, "Text size"), "the quest notice size")
    A.falsy(stepper(helpers, "Fade after"), "chat options stay on Chat")
end)

h.test("The Modern tab has no Modernize checkbox and its options are always usable", function(t)
    local A = t.assert
    local ui = open(t, { modules = { modernize = true } })
    local modern = page(ui, "modern")
    A.ok(modern, "a Modern page")
    A.falsy(choice(modern, "Modernize"), "no Modernize checkbox")
    local theme = stepper(modern, "Theme")
    A.ok(theme and theme:IsShown(), "Theme shows")
    A.ok(choice(modern, "Show on big XP gain"):IsShown(), "areas show")
    for _, f in ipairs(descendants(modern)) do
        if f.label and f.label._text == "Reset positions" or f._text == "Reset positions" then
            A.ok(f:IsShown() and f:IsEnabled(), "Reset positions is enabled")
        end
    end
end)

h.test("Save with a changed module set restores everything, then reloads", function(t)
    local ns, A = t.ns, t.assert
    local ui, log = open(t)
    click(moduleBox(ui, "Fading"))
    click(ui.save)
    A.eq(table.concat(log.events, ","), "restore,reload", "RestoreAll, then ReloadUI, no apply")
    A.ok(log.fadingSavedAtRestore, "the old set is still in effect while everything is restored")
    A.deep(log.modulesAtReload, { fading = false }, "the new set is saved before the reload")
    A.deep(QuietUICharDB.modules, { fading = false })
    A.eq(QuietUICharDB.chat, nil, "no legacy chat key")
    A.eq(ns.Settings.Module("fading"), false)
end)

h.test("Turning Modernize on in Modules reloads and stores only the module", function(t)
    local A = t.assert
    local ui, log = open(t)
    click(moduleBox(ui, "Modernize"))
    click(ui.save)
    A.eq(table.concat(log.events, ","), "restore,reload")
    A.eq(QuietUICharDB.modules.modernize, true)
    A.eq(QuietUICharDB.modernize == nil or QuietUICharDB.modernize.enabled == nil, true, "no legacy enabled flag")
end)

h.test("Save stores only the modules that differ from the defaults", function(t)
    local A = t.assert
    local ui = open(t)
    click(moduleBox(ui, "Chat"))
    click(moduleBox(ui, "Layout"))
    click(moduleBox(ui, "Modernize"))
    click(ui.save)
    A.deep(QuietUICharDB.modules, { chat = false, layout = false, modernize = true })
    A.eq(QuietUICharDB.chat, nil)
end)

h.test("Save with an unchanged module set applies without a reload", function(t)
    local A = t.assert
    local ui, log = open(t)
    click(stepper(page(ui, "chat"), "Fade after").plus)
    click(ui.save)
    A.eq(QuietUICharDB.chatFade, 15, "the other setting is saved")
    A.eq(QuietUICharDB.modules, nil, "the default set stores nothing")
    local joined = table.concat(log.events, ",")
    A.falsy(joined:find("reload", 1, true), "no reload")
    A.falsy(joined:find("restore", 1, true), "no restore")
    A.ok(joined:find("apply", 1, true), "applied in place")
end)

h.test("Save with a saved non-default set that stays the same applies without a reload", function(t)
    local A = t.assert
    local ui, log = open(t, { modules = { fading = false } })
    click(stepper(page(ui, "chat"), "Fade after").plus)
    click(ui.save)
    A.deep(QuietUICharDB.modules, { fading = false })
    A.falsy(table.concat(log.events, ","):find("reload", 1, true), "no reload")
end)

h.test("Save with no module checked prints a message and saves nothing", function(t)
    local ns, A = t.ns, t.assert
    local ui, log = open(t)
    click(stepper(page(ui, "chat"), "Fade after").plus)
    for _, name in ipairs({ "Chat", "Fading", "Helpers", "Layout" }) do click(moduleBox(ui, name)) end
    click(ui.save)
    A.ok(said(t.mock, "Choose at least one module, or turn QuietUI off with /quiet off."), "the message is printed")
    A.eq(QuietUICharDB.modules, nil, "no module set is saved")
    A.eq(QuietUICharDB.chatFade, nil, "no other setting is saved either")
    A.eq(#log.events, 0, "nothing is restored, applied or reloaded")
    A.ok(ns.Settings.Module("chat"), "the saved set is untouched")
end)

h.test("Save into a shared preset with a changed module set restores everything, then reloads", function(t)
    local ns, A = t.ns, t.assert
    local ui, log = open(t)
    ui:Hide()
    local id = ns.Settings.SavePreset(nil, "Raid", { builtin = 1 }, {})
    ns.Settings.ActivatePreset(id)
    ns.Setup.Show()
    click(moduleBox(ui, "Fading"))
    click(ui.save)
    A.deep(QuietUIDB.presets[id].settings.modules, { fading = false }, "the preset holds the set")
    A.eq(table.concat(log.events, ","), "restore,reload")
end)

h.test("A preset save that fails after a module change brings the old set back", function(t)
    local ns, A = t.ns, t.assert
    local ui, log = open(t)
    ui:Hide()
    local id = ns.Settings.SavePreset(nil, "Raid", { builtin = 1 }, {})
    ns.Settings.ActivatePreset(id)
    ns.Setup.Show()
    click(moduleBox(ui, "Fading"))
    QuietUIDB.presets[id] = nil
    click(ui.save)
    A.eq(table.concat(log.events, ","), "restore,apply", "restored, then applied again, no reload")
end)

h.test("Save arms the reload only for the click that needs it and disarms it afterwards", function(t)
    local A = t.assert
    local ui, log = open(t)
    A.eq(ui.save:GetAttribute("type"), nil, "not armed ahead of a click")
    click(moduleBox(ui, "Fading"))
    A.eq(ui.save:GetAttribute("type"), nil, "a changed draft arms nothing either")
    click(ui.save)
    A.eq(table.concat(log.events, ","), "restore,reload")
    A.eq(ui.save:GetAttribute("type"), nil, "disarmed after the click")
end)

-- A physical click reaches PreClick and PostClick twice, but the secure action runs on one event only.
for _, keyDown in ipairs({ false, true }) do
    h.test("A press and release reload exactly once with key-down " .. tostring(keyDown), function(t)
        local ns, A = t.ns, t.assert
        local ui, log = open(t)
        t.mock.cvars.ActionButtonUseKeyDown = keyDown and "1" or "0"
        click(moduleBox(ui, "Fading"))
        ui.save:ClickPressRelease()
        A.eq(table.concat(log.events, ","), "restore,reload", "one restore, one reload, nothing applied in place")
        A.eq(ui.save:GetAttribute("type"), nil, "disarmed")
        A.deep(QuietUICharDB.modules, { fading = false })
        A.ok(not ns.Settings.Module("fading"))
    end)
end

local REFUSAL = "Leave combat to change modules."

h.test("Save with a changed module set in combat is refused and saves nothing", function(t)
    local ns, A = t.ns, t.assert
    local ui, log = open(t)
    click(stepper(page(ui, "chat"), "Fade after").plus)
    click(moduleBox(ui, "Fading"))
    inCombat(function() click(ui.save) end)
    A.ok(said(t.mock, REFUSAL), "the refusal is printed")
    A.eq(#log.events, 0, "no RestoreAll, no ReloadUI, no apply")
    A.eq(QuietUICharDB.modules, nil, "no module set is saved")
    A.eq(QuietUICharDB.chatFade, nil, "no other setting is saved either")
    A.ok(ns.Settings.Module("fading"), "the saved set is untouched")
    -- Out of combat the same draft saves.
    click(ui.save)
    A.eq(table.concat(log.events, ","), "restore,reload", "the draft stays and saves after combat")
    A.deep(QuietUICharDB.modules, { fading = false })
end)

h.test("Save with an unchanged module set in combat still applies", function(t)
    local A = t.assert
    local ui, log = open(t)
    click(stepper(page(ui, "chat"), "Fade after").plus)
    inCombat(function() click(ui.save) end)
    A.falsy(said(t.mock, REFUSAL), "no refusal")
    A.eq(QuietUICharDB.chatFade, 15, "the other setting is saved")
    A.eq(table.concat(log.events, ","), "apply", "applied in place, no restore, no reload")
end)

h.test("Reset default in combat is refused when it would change the module set", function(t)
    local A = t.assert
    local ui, log = open(t, { modules = { modernize = true }, chatFade = 15 })
    inCombat(function() click(ui.reset) end)
    A.ok(said(t.mock, REFUSAL), "the refusal is printed")
    A.eq(#log.events, 0, "no RestoreAll, no ReloadUI, no apply")
    A.deep(QuietUICharDB.modules, { modernize = true }, "the saved set is untouched")
    A.eq(QuietUICharDB.chatFade, 15, "nothing else is reset")
end)

h.test("Reset default in combat still resets when the module set is already the default", function(t)
    local A = t.assert
    local ui, log = open(t, { chatFade = 15 })
    inCombat(function() click(ui.reset) end)
    A.falsy(said(t.mock, REFUSAL), "no refusal")
    A.eq(QuietUICharDB.chatFade, nil, "the setting is reset")
    A.eq(table.concat(log.events, ","), "apply", "applied in place, no reload")
end)

h.test("Reset default arms the reload only for its click and disarms it afterwards", function(t)
    local ns, A = t.ns, t.assert
    local ui, log = open(t, { modules = { fading = false } })
    A.eq(ui.reset:GetAttribute("type"), nil, "not armed ahead of a click")
    click(ui.reset)
    A.eq(table.concat(log.events, ","), "restore,reload")
    A.ok(ns.Settings.Module("fading"), "the default modules are back")
    A.eq(ui.reset:GetAttribute("type"), nil, "disarmed after the click")
end)
