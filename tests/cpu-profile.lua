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
print('PASS temporary CPU timing, completion, disabled state and unavailable timer')
