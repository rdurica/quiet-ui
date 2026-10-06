-- Run from the addon directory: lua tests/preset-interface.lua
local ns, mode, canceled, applied = {}, 0, 0, 0
local db, char, messages = {}, {}, {}
ns.DB = function() return db end
ns.CharDB = function() return char end
ns.Print = function(message) messages[#messages + 1] = message end
ns.CurrentInterfaceStyle = function() return mode end
ns.LayoutInterfaceStyle = function(ref)
    if ref.builtin == 3 or ref.layoutName == 'aaaddd' then return 1 end
    return ref.interfaceStyle or 0
end
ns.CancelLayoutPreview = function() canceled = canceled + 1 end
ns.ApplyAll = function() applied = applied + 1 end
assert(loadfile('Presets.lua'))('QuietUI', ns)
local keyboard = ns.SavePreset(nil, 'Keyboard', { layoutName = 'QuietUI', layoutType = 1 }, { chat = false })
mode = 1
local gamepad = ns.SavePreset(nil, 'Test A', { builtin = 3 }, { chatFade = 0 })
local custom = ns.SavePreset(nil, 'Custom', { layoutName = 'aaaddd', layoutType = 1 }, {})
assert(db.presets[keyboard].interfaceStyle == 0 and db.presets[gamepad].interfaceStyle == 1)
assert(db.presets[custom].interfaceStyle == 1)
-- Older saved presets acquire their tag from the linked layout.
db.presets[gamepad].interfaceStyle = nil
db.presets[custom].interfaceStyle = nil
mode = 0
local list = ns.PresetList()
assert(#list == 1 and list[1].id == keyboard)
assert(db.presets[gamepad].interfaceStyle == 1 and db.presets[custom].interfaceStyle == 1)
assert(ns.ActivatePreset(keyboard))
ns.PresetCommand('Test A')
assert(char.presetId == keyboard and canceled == 0 and applied == 0,
    'Incompatible commands must leave settings and previews untouched')
assert(messages[#messages]:find('current interface mode', 1, true))
assert(not ns.ActivatePreset(gamepad) and char.presetId == keyboard,
    'Direct activation must reject incompatible presets too')
ns.PresetCommand('')
assert(messages[#messages] == 'Available presets: "Keyboard".')
mode = 1
list = ns.PresetList()
assert(#list == 2 and list[1].id == custom and list[2].id == gamepad)
ns.PresetCommand('Test A')
assert(char.presetId == gamepad and char.chatFade == 0 and canceled == 1 and applied == 1)
ns.SavePreset(gamepad, 'Test A', { layoutName = 'QuietUI', layoutType = 1 }, {})
assert(db.presets[gamepad].interfaceStyle == 0, 'Saving a different linked mode must update the preset tag')
print('PASS shared preset mode tags, legacy migration, lists, commands and activation guards')
