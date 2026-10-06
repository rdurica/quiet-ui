-- Run from the addon directory: lua tests/preset-builtins.lua
local ns = {}
local db, char, copies, switches = {}, {}, 0, 0
ns.DB = function() return db end
ns.CharDB = function() return char end
ns.Print = function() end
InCombatLockdown = function() return false end
local info = { activeLayout = 4, layouts = {
    { layoutName = 'Original', layoutType = 1 },
    { layoutName = 'QuietUI', layoutType = 1 },
} }
EditModePresetLayoutManager = {
    GetCopyOfPresetLayouts = function()
        copies = copies + 1
        return { { layoutName = 'Modern' }, { layoutName = 'Classic' }, { layoutName = 'Controller' } }
    end,
}
C_EditMode = {
    GetLayouts = function() return info end,
    SetActiveLayout = function(index) switches = switches + 1; info.activeLayout = index end,
    SaveLayouts = function() end,
    ConvertStringToLayoutInfo = function() return {} end,
}
assert(loadfile('Presets.lua'))('QuietUI', ns)
assert(loadfile('Layout.lua'))('QuietUI', ns)
assert(ns.LayoutChoices()[3].name == 'Controller', 'Read the actual name of the third built-in layout')
local id = ns.SavePreset(nil, 'Test A', { builtin = 3 }, { chat = false })
ns.ActivatePreset(id)
for _ = 1, 600 do
    assert(ns.SelectPresetLayout())
end
assert(switches == 1 and info.activeLayout == 3, 'A settled third layout must not be switched again')
assert(copies == 1, 'Repeated layout checks must not deep-copy the full built-in layouts')
assert(ns.LayoutLabel({ builtin = 3 }) == 'Controller')
assert(char.previousLayout == 4 and char.previousLayoutRef.layoutName == 'Original')
assert(ns.LayoutStatus() == 'Active layout: 3; preset layout: 3; preview: none.')
assert(ns.RestorePreviousLayout() and info.activeLayout == 4)
EditModePresetLayoutManager = {
    presetLayoutInfo = { { layoutName = 'Modern', interfaceStyle = 0 },
        { layoutName = 'Classic', interfaceStyle = 0 }, { layoutName = 'Gamepad', interfaceStyle = 1 } },
    GetCopyOfPresetLayouts = function() error('Do not copy all systems when metadata is available') end,
}
InputUtil = { GetCurrentInterfaceStyle = function() return 1 end }
assert(ns.LayoutChoices()[1].name == 'Gamepad (Gamepad mode only)', 'Filter built-ins by interface style')
assert(ns.LayoutLabel({ builtin = 3 }) == 'Gamepad (Gamepad mode only)')
print('PASS third built-in layout names, cached metadata, selection and restore')
