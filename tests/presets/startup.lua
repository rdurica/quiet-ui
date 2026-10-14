-- Startup validation of the active preset against the interface mode, driven by real events.
local h = ...

h.test("once-only startup validation, delayed layouts and detach before selection", function(t)
    local ns, A, mock = t.ns, t.assert, t.mock
    local ready, switches = false, 0
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    InputUtil = { GetCurrentInterfaceStyle = function() return 1 end }
    InCombatLockdown = function() return false end
    local info = { activeLayout = 3, layouts = { { layoutName = "QuietUI", layoutType = 1 } } }
    C_EditMode = {
        GetLayouts = function() if ready then return info end end,
        SetActiveLayout = function() switches = switches + 1 end,
        SaveLayouts = function() end,
        ConvertStringToLayoutInfo = function() return {} end,
    }
    local id = ns.Settings.SavePreset(nil, "Test A", { layoutName = "QuietUI", layoutType = 1 }, { chat = false })
    -- Simulate the character's saved selection from before the mode change.
    QuietUIDB.presets[id].interfaceStyle = nil
    QuietUICharDB.presetId = id
    local checks = 0
    local validate = ns.Layout.ValidatePresetInterface
    ns.Layout.ValidatePresetInterface = function() checks = checks + 1; return validate() end
    mock:fire("PLAYER_LOGIN")
    A.ok(QuietUICharDB.presetId == id and switches == 0, "Unloaded layouts must defer validation and selection")
    ready = true
    mock:tick(0.1)
    A.ok(QuietUICharDB.presetId == nil and QuietUICharDB.chat == false and switches == 0)
    local completedChecks = checks
    A.ok(completedChecks > 0, "Validation ran once layouts were loaded")
    mock:fire("PLAYER_ENTERING_WORLD", true, false)
    mock:tick(0.1)
    ns.ApplyAll()
    A.eq(checks, completedChecks, "Completed startup validation must run only once per session")
    A.eq(QuietUIDB.presets[id].layout.layoutName, "QuietUI", "Startup must preserve the shared preset")
end)
