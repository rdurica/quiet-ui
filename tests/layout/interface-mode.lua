-- Interface-specific layouts: choices per mode, identities, indices, preview and validation.
local h = ...

h.test("interface-specific built-ins, custom layouts, identity, indices, preview and restore", function(t)
    local ns, A = t.ns, t.assert
    local style = 0
    QuietUIDB = {}; QuietUICharDB = {}
    local char, db = QuietUICharDB, QuietUIDB
    Enum = nil -- custom layouts are Account type 1 when no enum exists
    InputUtil = { GetCurrentInterfaceStyle = function() return style end }
    InCombatLockdown = function() return false end
    EditModePresetLayoutManager = { presetLayoutInfo = {
        { layoutName = "Modern", interfaceStyle = 0 },
        { layoutName = "Classic", interfaceStyle = 0 },
        { layoutName = "Gamepad", interfaceStyle = 1 },
    } }
    local info = { activeLayout = 4, layouts = {
        { layoutName = "QuietUI", layoutType = 1 },
        { layoutName = "aaaddd", layoutType = 1, interfaceStyle = 1 },
        { layoutName = "Same name", layoutType = 1, interfaceStyle = 0 },
        { layoutName = "Same name", layoutType = 1, interfaceStyle = 1 },
    } }
    C_EditMode = {
        GetLayouts = function() return info end,
        SetActiveLayout = function(index) info.activeLayout = index end,
        SaveLayouts = function() end,
        ConvertStringToLayoutInfo = function() return {} end,
    }
    local choices = ns.LayoutChoices()
    A.ok(#choices == 4 and choices[1].name == "Modern" and choices[2].name == "Classic")
    A.ok(choices[3].name == "QuietUI" and choices[4].ref.interfaceStyle == 0)
    local keyboardRef = choices[4].ref
    style = 1
    choices = ns.LayoutChoices()
    A.ok(#choices == 3 and choices[1].ref.builtin == 3, "Filtering must preserve absolute built-in identities")
    A.ok(choices[2].name == "aaaddd" and choices[2].ref.interfaceStyle == 1,
        "Custom gamepad layouts must be recognized through metadata, not names")
    local gamepadRef = choices[3].ref
    ns.PreviewLayout(choices[2].ref)
    A.eq(info.activeLayout, 5, "Filtered built-ins must not shift saved layout indices")
    ns.CommitLayoutPreview()
    ns.PreviewLayout(gamepadRef)
    A.eq(info.activeLayout, 7, "Same-name layouts must resolve by interface style")
    ns.CommitLayoutPreview()
    style = 0
    ns.PreviewLayout(keyboardRef)
    A.eq(info.activeLayout, 6)
    ns.CancelLayoutPreview()
    A.eq(info.activeLayout, 7, "Cancel must restore the original interface-specific identity")
    InputUtil = { IsGamepadUIEnabled = function() return true end }
    A.eq(ns.LayoutChoices()[1].ref.builtin, 3, "Use the available mode API on older clients")
    InputUtil = nil
    A.eq(ns.LayoutChoices()[1].name, "Modern", "Missing mode APIs must use the keyboard layout list")
    InputUtil = { GetCurrentInterfaceStyle = function() return style end }
    local id = ns.Settings.SavePreset(nil, "Test A", { layoutName = "QuietUI", layoutType = 1 }, { chat = false })
    ns.Settings.ActivatePreset(id)
    style = 1
    local before = info.activeLayout
    A.ok(ns.ValidatePresetInterface() and char.presetId == nil,
        "Startup must detach a legacy keyboard preset in gamepad mode")
    A.ok(char.chat == false and info.activeLayout == before, "Detach must preserve settings and the active layout")
    A.eq(db.presets[id].layout.layoutName, "QuietUI", "Detach must not modify the shared preset")
    ns.Settings.SavePreset(id, "Test A", { builtin = 3 }, { chatFade = 0 })
    ns.Settings.ActivatePreset(id)
    A.ok(ns.ValidatePresetInterface() and char.presetId == id, "Matching presets must remain selected")
    style = 0
    A.ok(ns.ValidatePresetInterface() and char.presetId == nil and char.chatFade == 0,
        "Gamepad built-ins must detach in keyboard mode")
    ns.Settings.SavePreset(id, "Test A", { layoutName = "Missing", layoutType = 1 }, {})
    ns.Settings.ActivatePreset(id)
    A.ok(ns.ValidatePresetInterface() and char.presetId == id, "Missing layouts retain the existing fallback behavior")
    local read = C_EditMode.GetLayouts
    C_EditMode.GetLayouts = function() return nil end
    A.ok(not ns.ValidatePresetInterface() and char.presetId == id, "Wait until layouts are available before validation")
    C_EditMode.GetLayouts = read
end)
