-- Run from the addon directory: lua tests/preset-startup.lua
local ns, ready, checks, switches = {}, false, 0, 0
local db = { enabled = true }
local char = {}
ns.DB = function() return db end
ns.CharDB = function() return char end
ns.Print = function() end
ns.Report = function(_, err) error(err) end
InputUtil = { GetCurrentInterfaceStyle = function() return 1 end }
GetTime = function() return 20 end
InCombatLockdown = function() return false end
local info = { activeLayout = 3, layouts = { { layoutName = 'QuietUI', layoutType = 1 } } }
C_EditMode = {
    GetLayouts = function() if ready then return info end end,
    SetActiveLayout = function() switches = switches + 1 end,
    SaveLayouts = function() end,
    ConvertStringToLayoutInfo = function() return {} end,
}
assert(loadfile('Presets.lua'))('QuietUI', ns)
assert(loadfile('Layout.lua'))('QuietUI', ns)
local id = ns.SavePreset(nil, 'Test A', { layoutName = 'QuietUI', layoutType = 1 }, { chat = false })
-- Simulate the character's saved selection from before the mode change.
db.presets[id].interfaceStyle = nil
char.presetId = id
local validate = ns.ValidatePresetInterface
ns.ValidatePresetInterface = function() checks = checks + 1; return validate() end
ns.ForceQuietLayout = function() return ns.ActivePreset() ~= nil end
ns.ModernChat = function() return false end
for _, key in ipairs({ 'RefreshWorld', 'FindFaders', 'ScanSwing', 'EnsureLayout', 'RefreshChrome',
    'RestoreChat', 'NextFadeTick', 'BeginTick', 'UpdateBars', 'UpdateFaders', 'UpdateMenuButton',
    'UpdateParty', 'UpdateBagSlots', 'EnsureMinimap', 'ForgetCursor', 'UpdateRange', 'UpdateSmooth' }) do
    ns[key] = function() end
end
for _, key in ipairs({ 'ShowAll', 'FocusChanged', 'ConsumeHud', 'FrameHot' }) do
    ns[key] = function() return false end
end
local events = { scripts = {} }
function events:SetScript(key, fn) self.scripts[key] = fn end
function events:RegisterEvent() end
CreateFrame = function() return events end
SlashCmdList = {}
assert(loadfile('QuietUI.lua'))('QuietUI', ns)
events.scripts.OnEvent(events, 'PLAYER_LOGIN')
assert(char.presetId == id and switches == 0, 'Unloaded layouts must defer validation and selection')
ready = true
events.scripts.OnUpdate(events, 0.1)
assert(char.presetId == nil and char.chat == false and switches == 0)
local completedChecks = checks
events.scripts.OnEvent(events, 'PLAYER_ENTERING_WORLD', true, false)
events.scripts.OnUpdate(events, 0.1)
ns.ApplyAll()
assert(checks == completedChecks, 'Completed startup validation must run only once per session')
assert(db.presets[id].layout.layoutName == 'QuietUI', 'Startup must preserve the shared preset')
print('PASS once-only startup validation, delayed layouts and detach before selection')
