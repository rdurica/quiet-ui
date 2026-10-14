-- Preset layout selection, preview and startup validation through the public layout API.
local h = ...

local function layoutEnv(t, layouts, active)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = {}
    ns.LAYOUT_STRING = "export"
    local env = { combat = false }
    InCombatLockdown = function() return env.combat end
    env.info = { activeLayout = active or 3, layouts = layouts or {
        { layoutName = "Original", layoutType = 1 },
        { layoutName = "Raid", layoutType = 1 },
        { layoutName = "QuietUI", layoutType = 1 },
    } }
    C_EditMode = {
        GetLayouts = function() return env.info end,
        SetActiveLayout = function(index) env.info.activeLayout = index end,
        SaveLayouts = function(value) env.info = value end,
        ConvertStringToLayoutInfo = function() return {} end,
    }
    return env
end

h.test("preset layouts: combat, fallback, warn once and restore by name", function(t)
    local ns, A, mock = t.ns, t.assert, t.mock
    local env = layoutEnv(t)
    local info = env.info
    A.type(ns.SelectPresetLayout, "function", "Preset layout selection is not implemented")
    local id = ns.Settings.SavePreset(nil, "Healer", { layoutName = "Raid", layoutType = 1 }, {})
    ns.Settings.ActivatePreset(id)
    A.ok(ns.SelectPresetLayout())
    A.ok(info.activeLayout == 4 and QuietUICharDB.previousLayout == 3)
    info.layouts[1], info.layouts[2] = info.layouts[2], info.layouts[1]
    A.ok(ns.SelectPresetLayout() and info.activeLayout == 3, "Resolve layout by identity, not index")
    env.combat = true
    info.layouts[1].layoutName = "Renamed"
    local before = #mock.printed
    A.ok(not ns.SelectPresetLayout() and #mock.printed == before)
    env.combat = false
    A.ok(ns.SelectPresetLayout() and info.activeLayout == 5)
    A.eq(#mock.printed, before + 1)
    A.ok(mock.printed[#mock.printed]:find("missing", 1, true))
    A.ok(ns.SelectPresetLayout() and #mock.printed == before + 1, "Warn once per session")
    A.eq(ns.Settings.Presets()[id].layout.layoutName, "Raid", "Keep invalid reference for repair")
    A.ok(ns.RestorePreviousLayout() and info.activeLayout == 4, "Restore original by name after reorder")
    info.layouts[3] = nil
    A.ok(ns.SelectPresetLayout())
    A.eq(info.layouts[3].layoutName, "QuietUI", "Create missing fallback")
end)

-- Layout order Raid, Original, QuietUI with Original active (index 4).
local function previewEnv(t)
    return layoutEnv(t, {
        { layoutName = "Raid", layoutType = 1 },
        { layoutName = "Original", layoutType = 1 },
        { layoutName = "QuietUI", layoutType = 1 },
    }, 4)
end

h.test("immediate layout preview: switch, cancel, commit and combat deferral", function(t)
    local ns, A = t.ns, t.assert
    local env = previewEnv(t)
    local info = env.info
    local before = QuietUICharDB.previousLayout
    A.type(ns.PreviewLayout, "function", "Immediate layout preview is not implemented")
    ns.PreviewLayout({ layoutName = "Raid", layoutType = 1 })
    A.eq(info.activeLayout, 3, "Preview must switch immediately without Save")
    A.eq(QuietUICharDB.previousLayout, before, "Preview must not overwrite restore metadata")
    ns.CancelLayoutPreview()
    A.eq(info.activeLayout, 4, "Closing without Save must restore the original layout")
    env.combat = true
    ns.PreviewLayout({ layoutName = "Raid", layoutType = 1 })
    A.eq(info.activeLayout, 4)
    env.combat = false
    ns.UpdateLayoutPreview()
    A.eq(info.activeLayout, 3, "Combat preview must apply when combat ends")
    ns.CommitLayoutPreview()
    ns.CancelLayoutPreview()
    A.eq(info.activeLayout, 3, "Save must keep the selected layout")
    env.combat = true
    ns.PreviewLayout({ layoutName = "Original", layoutType = 1 })
    ns.CancelLayoutPreview()
    env.combat = false
    ns.UpdateLayoutPreview()
    A.eq(info.activeLayout, 3, "Cancelling a queued preview must not apply it later")
end)

h.test("preview is protected against reentrancy", function(t)
    local ns, A = t.ns, t.assert
    local env = previewEnv(t)
    env.info.activeLayout = 3
    local switches = 0
    C_EditMode.SetActiveLayout = function(index)
        switches = switches + 1
        A.ok(switches < 3, "Layout preview recursively entered SetActiveLayout")
        ns.UpdateLayoutPreview()
        env.info.activeLayout = index
    end
    ns.PreviewLayout({ layoutName = "Original", layoutType = 1 })
    A.ok(switches == 1 and env.info.activeLayout == 4)
    ns.CommitLayoutPreview()
end)

h.test("preview save keeps restore metadata; disabled previews take no ownership", function(t)
    local ns, A = t.ns, t.assert
    local env = previewEnv(t)
    local info = env.info
    QuietUIDB.enabled = true
    ns.PreviewLayout({ layoutName = "Raid", layoutType = 1 })
    ns.CommitLayoutPreview(true)
    A.eq(QuietUICharDB.previousLayoutRef.layoutName, "Original", "Save must remember layout before preview")
    A.ok(ns.RestorePreviousLayout() and info.activeLayout == 4)
    QuietUIDB.enabled = false
    ns.PreviewLayout({ layoutName = "Raid", layoutType = 1 })
    A.eq(info.activeLayout, 3, "Preview must work while QuietUI is disabled")
    ns.CommitLayoutPreview(true)
    A.eq(QuietUICharDB.previousLayout, nil, "Disabled previews must not take ownership of the layout")
end)
