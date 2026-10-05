-- Run from the addon directory: lua tests/preset-command.lua
local ns = {}
ns.FindFaders = function() end
ns.UpdateParty = function() end
local db, char = { enabled = true }, {}
ns.DB = function() return db end
ns.CharDB = function() return char end
assert(loadfile('Presets.lua'))('QuietUI', ns)
local healer = ns.SavePreset(nil, 'Raid Healer', { layoutName = 'Raid' }, { chatFade = 0 })
local minimal = ns.SavePreset(nil, 'Minimal', { layoutName = 'Quiet' }, { chat = false })
ns.ForceQuietLayout = function() return ns.ActivePreset() ~= nil end
ns.ModernChat = function() return false end
local combat, selected, restored = false, {}, 0
ns.SelectPresetLayout = function()
    if combat then return false end
    selected[#selected + 1] = ns.ActivePreset().layout.layoutName
    char.previousLayout = char.previousLayout or 3
    char.presetLayoutManaged = true
    return true
end
ns.RestorePreviousLayout = function()
    if combat then return false end
    restored = restored + 1
    char.previousLayout, char.presetLayoutManaged = nil, nil
    return true
end
for _, key in ipairs({ 'RefreshWorld', 'EnsureLayout', 'RefreshChrome', 'RestoreChat',
    'NextFadeTick', 'BeginTick', 'UpdateBars', 'UpdateFaders', 'UpdateMenuButton',
    'UpdateBagSlots', 'HideQuestCatcher', 'HideRangeMark', 'HideBarCatchers',
    'ResetMenu', 'RestoreAlpha', 'ForgetCursor', 'NoteCombat', 'MarkCombatEnd' }) do ns[key] = function() end end
ns.Report = function(_, err) error(err) end
ns.ShowAll = function() return false end
local messages, canceled, refreshed = {}, 0, 0
ns.Print = function(message) messages[#messages + 1] = message end
ns.CancelLayoutPreview = function() canceled = canceled + 1 end
ns.RefreshSetup = function() refreshed = refreshed + 1 end
local events = { scripts = {} }
function events:SetScript(key, value) self.scripts[key] = value end
function events:RegisterEvent() end
CreateFrame = function() return events end
SlashCmdList = {}
assert(loadfile('QuietUI.lua'))('QuietUI', ns)
for i = 1, 100 do
    local name = debug.getupvalue(events.scripts.OnEvent, i)
    if name == 'booted' then debug.setupvalue(events.scripts.OnEvent, i, true); break end
end
local command = SlashCmdList.QUIETUI
command('preset')
assert(messages[1] == 'Current preset: <no preset>.')
assert(messages[2] == 'Available presets: "Minimal", "Raid Healer".')
assert(char.presetId == nil and #selected == 0 and canceled == 0)
command('  PrEsEt "rAiD hEaLeR"  ')
assert(char.presetId == healer and char.chatFade == 0 and db.enabled)
assert(selected[1] == 'Raid' and char.previousLayout == 3)
assert(canceled == 1 and refreshed == 1)
assert(messages[#messages] == 'Preset "Raid Healer" selected.')
command('preset Missing')
assert(messages[#messages]:find('was not found', 1, true))
command('preset "Raid Healer')
assert(messages[#messages] == 'Use /quiet preset "name".')
command('preset ""')
assert(messages[#messages]:find('was not found', 1, true))
assert(char.presetId == healer and #selected == 1 and canceled == 1)
db.presets.duplicate = { name = 'RAID HEALER', settings = {} }
command('preset "Raid Healer"')
assert(messages[#messages]:find('More than one preset', 1, true))
assert(char.presetId == healer and canceled == 1)
db.presets.duplicate = nil
combat = true
command('preset Minimal')
assert(char.presetId == minimal and char.chat == false and char.chatFade == nil)
assert(#selected == 1 and char.previousLayout == 3 and db.enabled)
combat = false
events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')
assert(selected[2] == 'Quiet' and char.previousLayout == 3)
command('preset Raid Healer')
assert(char.presetId == healer and selected[3] == 'Raid')
command('off')
assert(not db.enabled and restored == 1 and char.previousLayout == nil)
command('preset Minimal')
assert(not db.enabled and char.presetId == minimal and #selected == 3)
command('on')
assert(db.enabled and selected[4] == 'Quiet' and char.previousLayout == 3)
command('preset')
assert(messages[#messages - 1] == 'Current preset: Minimal.')
db.presets = {}
command('preset')
assert(messages[#messages] == 'Available presets: none.')
assert(char.presetId == nil)
print('PASS preset commands, names, errors, snapshots, combat, disabled selection and restore')
