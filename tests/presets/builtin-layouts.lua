-- Built-in Edit Mode layouts as preset layouts: names, cached metadata, selection, restore.
local h = ...

h.test("third built-in layout: name, one-time selection, cached copy, restore, mode filter", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = {}; QuietUICharDB = {}
    local copies, switches = 0, 0
    InCombatLockdown = function() return false end
    local info = { activeLayout = 4, layouts = {
        { layoutName = "Original", layoutType = 1 },
        { layoutName = "QuietUI", layoutType = 1 },
    } }
    EditModePresetLayoutManager = {
        GetCopyOfPresetLayouts = function()
            copies = copies + 1
            return { { layoutName = "Modern" }, { layoutName = "Classic" }, { layoutName = "Controller" } }
        end,
    }
    C_EditMode = {
        GetLayouts = function() return info end,
        SetActiveLayout = function(index) switches = switches + 1; info.activeLayout = index end,
        SaveLayouts = function() end,
        ConvertStringToLayoutInfo = function() return {} end,
    }
    A.eq(ns.LayoutChoices()[3].name, "Controller", "Read the actual name of the third built-in layout")
    local id = ns.Settings.SavePreset(nil, "Test A", { builtin = 3 }, { chat = false })
    ns.Settings.ActivatePreset(id)
    for _ = 1, 600 do A.ok(ns.SelectPresetLayout()) end
    A.ok(switches == 1 and info.activeLayout == 3, "A settled third layout must not be switched again")
    A.eq(copies, 1, "Repeated layout checks must not deep-copy the full built-in layouts")
    A.eq(ns.LayoutLabel({ builtin = 3 }), "Controller")
    A.ok(QuietUICharDB.previousLayout == 4 and QuietUICharDB.previousLayoutRef.layoutName == "Original")
    A.eq(ns.LayoutStatus(), "Active layout: 3; preset layout: 3; preview: none.")
    A.ok(ns.RestorePreviousLayout() and info.activeLayout == 4)
    EditModePresetLayoutManager = {
        presetLayoutInfo = { { layoutName = "Modern", interfaceStyle = 0 },
            { layoutName = "Classic", interfaceStyle = 0 }, { layoutName = "Gamepad", interfaceStyle = 1 } },
        GetCopyOfPresetLayouts = function() error("Do not copy all systems when metadata is available") end,
    }
    InputUtil = { GetCurrentInterfaceStyle = function() return 1 end }
    A.eq(ns.LayoutChoices()[1].name, "Gamepad (Gamepad mode only)", "Filter built-ins by interface style")
    A.eq(ns.LayoutLabel({ builtin = 3 }), "Gamepad (Gamepad mode only)")
end)
