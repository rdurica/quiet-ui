-- Run from the addon directory: lua tests/quest-notice-runtime.lua
local ns, calls, events = {}, {}, { scripts = {}, registered = {} }
local db = { enabled = true }
local function spy(name)
    return function(...) calls[name] = calls[name] or {}; calls[name][#calls[name]+1] = {...} end
end
ns.DB = function() return db end
ns.CharDB = function() return {} end
ns.ForceQuietLayout = function() return false end
ns.ModernChat = function() return false end
ns.FrameHot = function() return false end
ns.FocusChanged = function() return false end
ns.ConsumeHud = function() return false end
ns.ShowAll = function() return false end
for _, key in ipairs({'UpdateRange','UpdateSmooth','ForgetCursor','BeginTick','NextFadeTick','RefreshWorld','EnsureLayout','RefreshChrome','RestoreChat','UpdateBars',
    'UpdateFaders','UpdateMenuButton','UpdateBagSlots','HideQuestCatcher','HideRangeMark','HideBarCatchers','ResetMenu','RestoreAlpha','Print','FindFaders','UpdateParty','ScanSwing',
    'EnsureMinimap','NoteCombat','MarkCombatEnd','MarkQuestXP','ForgetBarButtons'}) do ns[key] = function() end end
local errors={}
ns.Report = function(key,err) errors[#errors+1]=key..': '..tostring(err) end
for _, key in ipairs({'ApplyQuestNotice','RestoreQuestNotice','QuestNoticeEvent','UpdateQuestNotice'}) do ns[key]=spy(key) end
function events:SetScript(key,value) self.scripts[key]=value end
function events:RegisterEvent(name) self.registered[name]=true end
CreateFrame = function() return events end
GetTime = function() return 100 end
GetCursorPosition = function() return 0,0 end
C_Timer = nil
SlashCmdList = {}
assert(loadfile('QuietUI.lua'))('QuietUI',ns)
local failures,cases=0,0
local function test(name,fn)
    cases=cases+1; local ok,err=pcall(fn)
    print((ok and 'PASS ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)))
    if not ok then failures=failures+1 end
end
local function count(name) return #(calls[name] or {}) end
local function dispatch(name,...) events.scripts.OnEvent(events,name,...) end
local function update(dt) events.scripts.OnUpdate(events,dt) end
-- Use the actual public event path instead of mutating booted upvalues.
dispatch('PLAYER_LOGIN')
test('boot applies quest notice lifecycle without runtime errors',function()
    assert(#errors==0,table.concat(errors,'; ')); assert(count('ApplyQuestNotice')>0,'Boot must apply quest notice')
end)
test('Save ApplyAll reapplies quest notice',function()
    local n=count('ApplyQuestNotice'); ns.ApplyAll(); assert(count('ApplyQuestNotice')>n)
end)
test('quest events register independently and forward arguments unchanged',function()
    for _,name in ipairs({'QUEST_ACCEPTED','QUEST_LOG_UPDATE','QUEST_WATCH_UPDATE'}) do
        assert(events.registered[name],'Missing registered '..name)
        local n=count('QuestNoticeEvent'); dispatch(name,11,22)
        assert(count('QuestNoticeEvent')==n+1,'Missing forward '..name)
        local args=calls.QuestNoticeEvent[n+1]; assert(args[1]==name and args[2]==11 and args[3]==22,'Event arguments lost')
    end
end)
test('world entry reaches quest baseline reset',function()
    local n=count('QuestNoticeEvent'); dispatch('PLAYER_ENTERING_WORLD',true,false)
    assert(count('QuestNoticeEvent')>n,'World entry must reset quest snapshot')
    local found=false
    for i=n+1,count('QuestNoticeEvent') do if calls.QuestNoticeEvent[i][1]=='PLAYER_ENTERING_WORLD' then found=true end end
    assert(found,'World entry reset event missing')
end)
test('stationary active OnUpdate ticks notice each frame',function()
    local n=count('UpdateQuestNotice'); update(0.013); update(0.017)
    assert(count('UpdateQuestNotice')==n+2,'Notice timer must update independently of fade rescan')
    assert(calls.UpdateQuestNotice[n+1][1]==0.013 and calls.UpdateQuestNotice[n+2][1]==0.017,'Elapsed must be forwarded')
end)
test('disable restores, blocks quest events and stops notice timer',function()
    local n=count('RestoreQuestNotice'); SlashCmdList.QUIETUI('off')
    assert(count('RestoreQuestNotice')>n,'Disable must restore quest notice')
    local ev,tick=count('QuestNoticeEvent'),count('UpdateQuestNotice')
    dispatch('QUEST_ACCEPTED',42); update(0.1)
    assert(count('QuestNoticeEvent')==ev and count('UpdateQuestNotice')==tick,'Disabled runtime must not accumulate notices')
end)
test('enable applies and resumes update',function()
    local n=count('ApplyQuestNotice'); SlashCmdList.QUIETUI('on'); assert(count('ApplyQuestNotice')>n)
    n=count('UpdateQuestNotice'); update(0.01); assert(count('UpdateQuestNotice')==n+1)
    assert(#errors==0,table.concat(errors,'; '))
end)
test('TOC loads quest module before runtime',function()
    local f=assert(io.open('QuietUI.toc')); local toc=f:read('*a'); f:close()
    local feature=toc:find('QuestNotice.lua',1,true); local runtime=toc:find('QuietUI.lua',1,true)
    assert(feature and runtime and feature<runtime,'TOC must load QuestNotice before QuietUI')
end)
print(string.format('%d/%d quest notice runtime cases passed',cases-failures,cases))
if failures>0 then os.exit(1) end
