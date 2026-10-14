-- Preset layout selection, preview and startup validation through the public layout API.
local h = ...

local function layoutEnv(t, layouts, active)
    local ns = t.ns
    QuietUIDB = {}; QuietUICharDB = {}
    ns.Layout.STRING = "export"
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
    A.type(ns.Layout.SelectPreset, "function", "Preset layout selection is not implemented")
    local id = ns.Settings.SavePreset(nil, "Healer", { layoutName = "Raid", layoutType = 1 }, {})
    ns.Settings.ActivatePreset(id)
    A.ok(ns.Layout.SelectPreset())
    A.ok(info.activeLayout == 4 and QuietUICharDB.previousLayout == 3)
    info.layouts[1], info.layouts[2] = info.layouts[2], info.layouts[1]
    A.ok(ns.Layout.SelectPreset() and info.activeLayout == 3, "Resolve layout by identity, not index")
    env.combat = true
    info.layouts[1].layoutName = "Renamed"
    local before = #mock.printed
    A.ok(not ns.Layout.SelectPreset() and #mock.printed == before)
    env.combat = false
    A.ok(ns.Layout.SelectPreset() and info.activeLayout == 5)
    A.eq(#mock.printed, before + 1)
    A.ok(mock.printed[#mock.printed]:find("missing", 1, true))
    A.ok(ns.Layout.SelectPreset() and #mock.printed == before + 1, "Warn once per session")
    A.eq(ns.Settings.Presets()[id].layout.layoutName, "Raid", "Keep invalid reference for repair")
    A.ok(ns.Layout.RestorePrevious() and info.activeLayout == 4, "Restore original by name after reorder")
    info.layouts[3] = nil
    A.ok(ns.Layout.SelectPreset())
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
    A.type(ns.Layout.Preview, "function", "Immediate layout preview is not implemented")
    ns.Layout.Preview({ layoutName = "Raid", layoutType = 1 })
    A.eq(info.activeLayout, 3, "Preview must switch immediately without Save")
    A.eq(QuietUICharDB.previousLayout, before, "Preview must not overwrite restore metadata")
    ns.Layout.CancelPreview()
    A.eq(info.activeLayout, 4, "Closing without Save must restore the original layout")
    env.combat = true
    ns.Layout.Preview({ layoutName = "Raid", layoutType = 1 })
    A.eq(info.activeLayout, 4)
    env.combat = false
    ns.Layout.UpdatePreview()
    A.eq(info.activeLayout, 3, "Combat preview must apply when combat ends")
    ns.Layout.CommitPreview()
    ns.Layout.CancelPreview()
    A.eq(info.activeLayout, 3, "Save must keep the selected layout")
    env.combat = true
    ns.Layout.Preview({ layoutName = "Original", layoutType = 1 })
    ns.Layout.CancelPreview()
    env.combat = false
    ns.Layout.UpdatePreview()
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
        ns.Layout.UpdatePreview()
        env.info.activeLayout = index
    end
    ns.Layout.Preview({ layoutName = "Original", layoutType = 1 })
    A.ok(switches == 1 and env.info.activeLayout == 4)
    ns.Layout.CommitPreview()
end)

h.test("preview save keeps restore metadata; disabled previews take no ownership", function(t)
    local ns, A = t.ns, t.assert
    local env = previewEnv(t)
    local info = env.info
    QuietUIDB.enabled = true
    ns.Layout.Preview({ layoutName = "Raid", layoutType = 1 })
    ns.Layout.CommitPreview(true)
    A.eq(QuietUICharDB.previousLayoutRef.layoutName, "Original", "Save must remember layout before preview")
    A.ok(ns.Layout.RestorePrevious() and info.activeLayout == 4)
    QuietUIDB.enabled = false
    ns.Layout.Preview({ layoutName = "Raid", layoutType = 1 })
    A.eq(info.activeLayout, 3, "Preview must work while QuietUI is disabled")
    ns.Layout.CommitPreview(true)
    A.eq(QuietUICharDB.previousLayout, nil, "Disabled previews must not take ownership of the layout")
end)
