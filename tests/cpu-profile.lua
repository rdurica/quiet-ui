-- Run from the addon directory: lua tests/cpu-profile.lua
local ns, now, clock, messages = {}, 0, 0, {}
local db = { enabled = false }
ns.DB = function() return db end
ns.Print = function(message) messages[#messages + 1] = message end
ns.Report = function(_, err) error(err) end
ns.UpdateLayoutPreview = function() clock = clock + 3; return true end
GetTime = function() return now end
debugprofilestop = function() return clock end
local events = { scripts = {} }
function events:SetScript(key, value) self.scripts[key] = value end
function events:RegisterEvent() end
CreateFrame = function() return events end
SlashCmdList = {}
assert(loadfile('QuietUI.lua'))('QuietUI', ns)
for i = 1, 100 do
    local name = debug.getupvalue(events.scripts.OnUpdate, i)
    if name == 'booted' then debug.setupvalue(events.scripts.OnUpdate, i, true); break end
end
SlashCmdList.QUIETUI('profile')
assert(not db.enabled, 'Profiling must not toggle the addon')
for _ = 1, 10 do now = now + 0.1; events.scripts.OnUpdate(events, 0.1) end
now = 10
events.scripts.OnUpdate(events, 0.1)
assert(messages[2]:find('CPU timing: 10.0 seconds', 1, true))
assert(messages[3] == 'layout: 3.000 ms/s, 3.000 ms/call (10 calls).', messages[3])
now = 20
events.scripts.OnUpdate(events, 0.1)
assert(#messages == 3, 'Completed profiling must not keep reporting')
debugprofilestop = nil
SlashCmdList.QUIETUI('profile')
assert(messages[4] == 'CPU timing is not available on this client.')
assert(not db.enabled)
local timerReads = 0
debugprofilestop = function() timerReads = timerReads + 1; return clock end
db.enabled = true
ns.IsSecret = function() return false end
ns.Usable = function() return false end
for _, key in ipairs({ 'InEditMode', 'InCombat', 'InForcedInstance', 'InGroup', 'InVehicle',
    'HasTarget', 'Glancing', 'OnlyOnHover', 'RequireLivingTarget', 'GroupAuras', 'ConsumeHud',
    'ShowAll', 'FocusChanged', 'FrameHot', 'ModernChat' }) do ns[key] = function() return false end end
for _, key in ipairs({ 'ForgetCursor', 'UpdateFaders', 'UpdateMenuButton', 'UpdateBagSlots',
    'UpdateRange', 'FindFaders', 'ScanSwing', 'RefreshWorld', 'RefreshChrome', 'NextFadeTick',
    'BeginTick', 'UpdateBars' }) do ns[key] = function() end end
ns.Pinned = function(name) if name == 'resource' then clock = clock + 1 end; return false end
-- Visibility and threshold decisions now share this two-millisecond lookup.
ns.PlayerStyle = function() clock = clock + 2; return 'resource' end
ns.AlwaysShowDebuffs = function() clock = clock + 4; return true end
UnitPowerType = function() clock = clock + 0.5; return 0, 'MANA' end
UnitHealthPercent, UnitPowerPercent = function() return 0 end, function() return 0 end
C_CurveUtil = { CreateCurve = function() return { AddPoint = function() end } end }
assert(loadfile('Faders.lua'))('QuietUI', ns)
ns.UpdateParty = function() clock = clock + 3 end
-- Keep the test's unrelated frame discovery and regular faders idle.
ns.FindFaders, ns.UpdateFaders, ns.UpdateRange = function() end, function() end, function() end
now = 30
events.scripts.OnUpdate(events, 0.1)
assert(timerReads == 0, 'Inactive profiling must not read the CPU timer')
SlashCmdList.QUIETUI('profile')
for i = 1, 9 do now = 30 + i; events.scripts.OnUpdate(events, 0.1) end
now = 40
events.scripts.OnUpdate(events, 0.1)
local output = table.concat(messages, '\n')
for label, expected in pairs({
    ['resource bar'] = '0.900 ms/s, 1.000 ms/call (9 calls).',
    ['player frame'] = '1.800 ms/s, 2.000 ms/call (9 calls).',
    ['party frames'] = '2.700 ms/s, 3.000 ms/call (9 calls).',
    ['buffs'] = '3.600 ms/s, 4.000 ms/call (9 calls).',
}) do
    local row = 'smooth / ' .. label .. ': ' .. expected
    assert(output:find(row, 1, true), 'Missing or incorrect detailed timing: ' .. row)
end
assert(output:find('smooth: 9.450 ms/s, 10.500 ms/call (9 calls).', 1, true),
    'Smooth total must include shared sampling and retain its original meaning')
local reads = timerReads
now = 41
events.scripts.OnUpdate(events, 0.1)
assert(timerReads == reads, 'Completed profiling must disable detailed timers too')
print('PASS temporary CPU timing, smooth breakdown, completion, disabled state and unavailable timer')
