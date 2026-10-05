local ns = {}
ns.FindFaders = function() end
ns.UpdateParty = function() end
local enabled, combat, ready = true, false, true
ns.DB = function() return { enabled = enabled } end
ns.CharDB = function() return { previousLayout = 3, presetLayoutManaged = true } end
ns.ForceQuietLayout = function() return true end
ns.ActivePreset = function() return { name = 'Healer' } end
ns.ModernChat = function() return false end
local selected, quiet, restored = 0, 0, 0
ns.SelectQuietLayout = function() quiet = quiet + 1; return true end
ns.SelectPresetLayout = function() if combat or not ready then return false end; selected = selected + 1; return true end
ns.RestorePreviousLayout = function() if combat then return false end; restored = restored + 1; return true end
for _, key in ipairs({ 'UpdateRange', 'UpdateSmooth', 'ForgetCursor', 'BeginTick', 'NextFadeTick', 'RefreshWorld', 'EnsureLayout', 'RefreshChrome', 'RestoreChat', 'UpdateBars',
    'UpdateFaders', 'UpdateMenuButton', 'UpdateBagSlots', 'HideQuestCatcher', 'HideRangeMark',
    'HideBarCatchers', 'ResetMenu', 'RestoreAlpha', 'Print', 'Report' }) do ns[key] = function() end end
ns.FrameHot = function() return false end
ns.FocusChanged = function() return false end
ns.ConsumeHud = function() return false end
ns.ShowAll = function() return false end
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
ns.ApplyAll()
assert(selected == 1 and quiet == 0, 'Active presets must select their own layout')
ns.LayoutSettingsChanged(); ns.ApplyAll()
assert(selected == 2, 'Saving a different layout must invalidate selection')
combat = true; ns.LayoutSettingsChanged(); ns.ApplyAll()
assert(selected == 2)
combat = false; events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')
assert(selected == 3, 'Combat must defer selection')
combat = true; enabled = false; ns.ApplyAll()
ns.ForceQuietLayout = function() return false end
combat = false; events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')
assert(restored == 1, 'Restore must finish while disabled, even after detaching the preset')
enabled = true; ns.ForceQuietLayout = function() return true end
ready = false; ns.LayoutSettingsChanged(); ns.ApplyAll()
assert(selected == 3)
ready = true; events.scripts.OnUpdate(events, 0.1)
assert(selected == 4, 'Retry pending layout after Edit Mode becomes ready without another event')
print('PASS preset runtime selection, save invalidation, combat and disabled restore')
local previews = 0
ns.UpdateLayoutPreview = function() previews = previews + 1; return true end
ns.LayoutSettingsChanged(); ns.ApplyAll()
assert(selected == 4 and previews > 0, 'Saved layout must not override an active preview')
enabled = false
local previous = previews
events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')
assert(previews > previous, 'Deferred previews must retry while disabled')
print('PASS runtime preview priority and disabled retries')
