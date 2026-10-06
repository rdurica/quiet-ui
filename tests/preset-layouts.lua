local ns = {}
QuietUIDB = {}; QuietUICharDB = {}
ns.DB = function() return QuietUIDB end
ns.CharDB = function() return QuietUICharDB end
ns.Print = function(message) ns.messages[#ns.messages + 1] = message end
ns.messages = {}
ns.Report = function(_, err) error(err) end
ns.LAYOUT_STRING = 'export'
local combat = false
InCombatLockdown = function() return combat end
local info = { activeLayout = 3, layouts = {
    { layoutName = 'Original', layoutType = 1 },
    { layoutName = 'Raid', layoutType = 1 },
    { layoutName = 'QuietUI', layoutType = 1 },
} }
C_EditMode = {
    GetLayouts = function() return info end,
    SetActiveLayout = function(index) info.activeLayout = index end,
    SaveLayouts = function(value) info = value end,
    ConvertStringToLayoutInfo = function() return {} end,
}
assert(loadfile('Presets.lua'))('QuietUI', ns)
assert(loadfile('Layout.lua'))('QuietUI', ns)
assert(type(ns.SelectPresetLayout) == 'function', 'Preset layout selection is not implemented')
local id = ns.SavePreset(nil, 'Healer', { layoutName = 'Raid', layoutType = 1 }, {})
ns.ActivatePreset(id)
assert(ns.SelectPresetLayout())
assert(info.activeLayout == 4 and QuietUICharDB.previousLayout == 3)
info.layouts[1], info.layouts[2] = info.layouts[2], info.layouts[1]
assert(ns.SelectPresetLayout() and info.activeLayout == 3, 'Resolve layout by identity, not index')
combat = true
info.layouts[1].layoutName = 'Renamed'
assert(not ns.SelectPresetLayout() and #ns.messages == 0)
combat = false
assert(ns.SelectPresetLayout() and info.activeLayout == 5)
assert(#ns.messages == 1 and ns.messages[1]:find('missing'))
assert(ns.SelectPresetLayout() and #ns.messages == 1, 'Warn once per session')
assert(ns.Presets()[id].layout.layoutName == 'Raid', 'Keep invalid reference for repair')
assert(ns.RestorePreviousLayout() and info.activeLayout == 4, 'Restore original by name after reorder')
info.layouts[3] = nil
assert(ns.SelectPresetLayout())
assert(info.layouts[3].layoutName == 'QuietUI', 'Create missing fallback')
print('PASS preset layouts, combat, fallback, warning and restore')
info.layouts[1] = { layoutName = 'Raid', layoutType = 1 }
info.activeLayout = 4
local before = QuietUICharDB.previousLayout
assert(type(ns.PreviewLayout) == 'function', 'Immediate layout preview is not implemented')
ns.PreviewLayout({ layoutName = 'Raid', layoutType = 1 })
assert(info.activeLayout == 3, 'Preview must switch immediately without Save')
assert(QuietUICharDB.previousLayout == before, 'Preview must not overwrite restore metadata')
ns.CancelLayoutPreview()
assert(info.activeLayout == 4, 'Closing without Save must restore the original layout')
combat = true
ns.PreviewLayout({ layoutName = 'Raid', layoutType = 1 })
assert(info.activeLayout == 4)
combat = false
ns.UpdateLayoutPreview()
assert(info.activeLayout == 3, 'Combat preview must apply when combat ends')
ns.CommitLayoutPreview()
ns.CancelLayoutPreview()
assert(info.activeLayout == 3, 'Save must keep the selected layout')
combat = true
ns.PreviewLayout({ layoutName = 'Original', layoutType = 1 })
ns.CancelLayoutPreview()
combat = false
ns.UpdateLayoutPreview()
assert(info.activeLayout == 3, 'Cancelling a queued preview must not apply it later')
print('PASS immediate layout preview, cancel, commit and combat deferral')

local switches = 0
C_EditMode.SetActiveLayout = function(index)
    switches = switches + 1
    assert(switches < 3, 'Layout preview recursively entered SetActiveLayout')
    ns.UpdateLayoutPreview()
    info.activeLayout = index
end
ns.PreviewLayout({ layoutName = 'Original', layoutType = 1 })
assert(switches == 1 and info.activeLayout == 4)
ns.CommitLayoutPreview()
print('PASS preview reentrancy protection')
C_EditMode.SetActiveLayout = function(index) info.activeLayout = index end
QuietUICharDB.previousLayout = nil
QuietUICharDB.previousLayoutRef = nil
QuietUIDB.enabled = true
ns.PreviewLayout({ layoutName = 'Raid', layoutType = 1 })
ns.CommitLayoutPreview(true)
assert(QuietUICharDB.previousLayoutRef.layoutName == 'Original', 'Save must remember layout before preview')
assert(ns.RestorePreviousLayout() and info.activeLayout == 4)
QuietUIDB.enabled = false
ns.PreviewLayout({ layoutName = 'Raid', layoutType = 1 })
assert(info.activeLayout == 3, 'Preview must work while QuietUI is disabled')
ns.CommitLayoutPreview(true)
assert(QuietUICharDB.previousLayout == nil, 'Disabled previews must not take ownership of the layout')
print('PASS preview save restore metadata and disabled preview')
