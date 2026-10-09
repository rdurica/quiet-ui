-- Run from the addon directory: lua tests/quest-notice.lua
local cases, failures = 0, 0
local function test(name, fn)
    cases = cases + 1
    local ok, err = pcall(fn)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function widget(parent, kind)
    local f = { parent = parent, kind = kind, alpha = 1, shown = true, children = {}, regions = {}, points = {}, width = 280, height = 160 }
    if parent then parent.children[#parent.children + 1] = f end
    function f:IsForbidden() return self.forbidden or false end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.parent = p end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetAlpha() return self.alpha end
    function f:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
    function f:EnableMouse(b) self.mouse = b end
    function f:SetMouseClickEnabled(b) self.click = b end
    function f:SetMouseMotionEnabled(b) self.motion = b end
    function f:IsMouseOver() return self.hot or false end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:SetSize(w,h) self.width, self.height = w,h end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:GetPoint(i) return table.unpack(self.points[i or 1] or {}) end
    function f:GetNumPoints() return #self.points end
    function f:SetAllPoints(target) self.allPoints = target end
    function f:GetLeft() return self.left or 100 end
    function f:GetTop() return self.top or 500 end
    function f:GetRight() return self:GetLeft() + self.width end
    function f:GetBottom() return self:GetTop() - self.height end
    function f:GetEffectiveScale() return 1 end
    function f:GetFrameLevel() return 5 end
    function f:GetFrameStrata() return 'MEDIUM' end
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text end
    function f:GetStringHeight() return 16 end
    function f:GetStringWidth() return #(self.text or '') * 6 end
    function f:CreateFontString() local r = widget(self, 'text'); self.regions[#self.regions+1] = r; return r end
    function f:CreateTexture() local r = widget(self, 'texture'); self.regions[#self.regions+1] = r; return r end
    function f:GetRegions() return table.unpack(self.regions) end
    function f:GetChildren() return table.unpack(self.children) end
    function f:SetScript(name, fn) self[name] = fn end
    for _, name in ipairs({'SetFrameLevel','SetFrameStrata','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetJustifyH','SetJustifyV','SetFont','SetTextColor','SetWordWrap','SetSpacing','SetColorTexture','SetTexture','SetClampedToScreen','SetScale'}) do f[name] = function() end end
    return f
end
local function quest(id, count)
    return { id = id, title = 'Quest ' .. id, objectives = {
        {text = 'Wolves ' .. (count or 0) .. '/8', finished = false, type = 'monster'},
        {text = 'Find the relic', finished = false, type = 'object'},
    }, complete = false }
end
local function environment(classic)
    local s = { log = {quest(1)}, reads = 0, time = 0, reports = {} }
    UIParent = widget()
    ObjectiveTrackerFrame, QuestWatchFrame = widget(UIParent), nil
    local tracker = ObjectiveTrackerFrame
    -- Any manipulation of the original tracker is a contract violation.
    for _, method in ipairs({'SetAlpha','SetParent','Hide','Show'}) do tracker[method] = function() error('Must not manipulate Blizzard tracker') end end
    CreateFrame = function(_, _, parent) return widget(parent or UIParent, 'frame') end
    GetTime = function() return s.time end
    local function byID(id) for _, q in ipairs(s.log) do if q.id == id then return q end end end
    C_QuestLog = nil
    GetNumQuestLogEntries, GetQuestLogTitle, GetNumQuestLeaderBoards, GetQuestLogLeaderBoard, IsQuestComplete = nil,nil,nil,nil,nil
    if not classic then
        C_QuestLog = {
            GetNumQuestLogEntries = function() s.reads = s.reads + 1; return #s.log, #s.log end,
            GetInfo = function(i) local q = s.log[i]; if q then return {questID=q.id,title=q.title,isHeader=false,isComplete=q.complete and 1 or 0} end end,
            GetTitleForQuestID = function(id) local q = byID(id); return q and q.title end,
            GetQuestObjectives = function(id) local q = byID(id); return q and q.objectives end,
            ReadyForTurnIn = function(id) local q = byID(id); return q and q.complete end,
            IsComplete = function(id) local q = byID(id); return q and q.complete end,
        }
    else
        GetNumQuestLogEntries = function() s.reads = s.reads + 1; return #s.log, #s.log end
        GetQuestLogTitle = function(i) local q = s.log[i]; if q then return q.title,10,0,false,false,q.complete and 1 or 0,1,q.id end end
        GetNumQuestLeaderBoards = function(i) local q=s.log[i]; return q and q.objectives and #q.objectives end
        GetQuestLogLeaderBoard = function(j,i) local q=s.log[i]; local o=q and q.objectives and q.objectives[j]; if o then return o.text,o.type,o.finished end end
        IsQuestComplete = function(id) local q=byID(id); return q and q.complete end
    end
    local ns = {}
    ns.DB = function() return {enabled = s.disabled ~= true} end
    ns.IsSecret = function(v) return type(v)=='table' and v.secret==true end
    ns.Usable = function(f) return f and not f:IsForbidden() end
    ns.Report = function(key,err) s.reports[#s.reports+1] = {key,err} end
    ns.InEditMode = function() return s.edit or false end
    ns.Glancing = function() return s.glance or false end
    ns.Pinned = function(key) assert(key=='quests'); return s.pinned or false end
    ns.OnlyOnHover = function(key) assert(key=='quests'); return s.hoverOnly or false end
    ns.Hit = function(f) return f and (f==tracker and s.hover or f.hot) or false end
    ns.MouseOver = ns.Hit
    assert(loadfile('QuestNotice.lua'))('QuietUI',ns)
    for _, name in ipairs({'ApplyQuestNotice','RestoreQuestNotice','QuestNoticeEvent','UpdateQuestNotice'}) do assert(type(ns[name])=='function','Missing public seam '..name) end
    function s.tick(dt) dt=dt or 0.05; s.time=s.time+dt; ns.UpdateQuestNotice(dt) end
    function s.pump(seconds) for _=1,math.ceil((seconds or 0.5)/0.05) do s.tick(0.05) end end
    function s.event(name,...) ns.QuestNoticeEvent(name,...); s.pump() end
    function s.text()
        local texts={}
        local function visit(f)
            if not f:IsShown() or f:GetEffectiveAlpha()<=0.001 then return end
            if f.text then texts[#texts+1]=f.text end
            for _, child in ipairs(f.children) do visit(child) end
        end
        for _, f in ipairs(UIParent.children) do if f~=tracker then visit(f) end end
        return table.concat(texts,'\n')
    end
    function s.has(text) assert(s.text():find(text,1,true),'Expected visible '..text..', got '..s.text()) end
    function s.silent() assert(s.text()=='','Unexpected notice: '..s.text()) end
    function s.change(count) s.log[1].objectives[1].text='Wolves '..count..'/8'; s.event('QUEST_LOG_UPDATE') end
    ns.ApplyQuestNotice(); s.pump()
    s.ns,s.tracker = ns,tracker
    return s
end

test('startup and duplicate events are silent; idle updates do not scan log',function()
    local s=environment(); s.silent(); s.event('QUEST_LOG_UPDATE'); s.silent()
    local reads=s.reads; s.pump(3); assert(s.reads==reads,'Idle must not read quest log')
end)
for _, classic in ipairs({false,true}) do
    test((classic and 'classic' or 'modern')..' acceptance displays only accepted quest with objectives',function()
        local s=environment(classic); s.log[2]=quest(2)
        if classic then s.event('QUEST_ACCEPTED',2,2) else s.event('QUEST_ACCEPTED',2) end
        s.has('Quest 2'); s.has('Wolves 0/8'); s.has('Find the relic')
        assert(not s.text():find('Quest 1',1,true),'Must not show unchanged quests')
    end)
    test((classic and 'classic' or 'modern')..' progress only shows changed objectives, complete has no dialog dependency',function()
        local s=environment(classic); s.change(3); s.has('Quest 1'); s.has('Wolves 3/8')
        assert(not s.text():find('Find the relic',1,true),'Unchanged objective must not appear')
        s.log[1].complete=true; s.event('QUEST_LOG_UPDATE'); s.has('Complete')
    end)
end
test('accepted quest waits for delayed log data',function()
    local s=environment(); s.event('QUEST_ACCEPTED',2); s.silent()
    s.log[2]=quest(2); s.event('QUEST_LOG_UPDATE'); s.has('Quest 2')
end)
test('acceptance before first world-entry scan announces new quest only',function()
    local s=environment()
    s.ns.QuestNoticeEvent('PLAYER_ENTERING_WORLD',false,false)
    s.log[2]=quest(2)
    s.ns.QuestNoticeEvent('QUEST_ACCEPTED',2)
    s.tick(0)
    s.has('Quest 2'); s.has('Wolves 0/8')
    assert(not s.text():find('Quest 1',1,true),'Existing baseline quests must remain silent')
end)
test('modern stable objective text detects numeric progress and displays count',function()
    local s=environment()
    s.ns.RestoreQuestNotice()
    s.log[1].objectives[1]={text='Wolves slain',finished=false,type='monster',numFulfilled=0,numRequired=8}
    s.ns.ApplyQuestNotice(); s.pump(); s.silent()
    s.log[1].objectives[1].numFulfilled=3
    s.event('QUEST_LOG_UPDATE')
    s.has('Quest 1'); s.has('Wolves slain'); s.has('3/8')
    assert(not s.text():find('Find the relic',1,true),'Unchanged objective must not appear')
end)
test('classic nil unfinished completion is valid without IsQuestComplete',function()
    local s=environment(true)
    -- Explicit nil is the classic unfinished marker, not missing quest data.
    GetQuestLogTitle=function(index)
        local q=s.log[index]
        if q then return q.title,10,0,false,false,q.complete and 1 or nil,1,q.id end
    end
    IsQuestComplete=nil
    s.ns.RestoreQuestNotice(); s.ns.ApplyQuestNotice(); s.pump(); s.silent()
    s.change(3); s.has('Quest 1'); s.has('Wolves 3/8')
end)
test('transient empty modern objectives preserve nonempty unfinished baseline',function()
    local s=environment(); local previous=s.log[1].objectives
    s.log[1].objectives={}; s.event('QUEST_LOG_UPDATE'); s.silent()
    s.log[1].objectives=previous; s.event('QUEST_LOG_UPDATE'); s.silent()
    s.change(3); s.has('Quest 1'); s.has('Wolves 3/8')
    assert(not s.text():find('Find the relic',1,true),'Unchanged objective must not appear after incomplete read')
end)
test('missing required classic title reader reports exactly once',function()
    local s=environment(true); GetQuestLogTitle=nil
    s.ns.RestoreQuestNotice(); s.ns.ApplyQuestNotice()
    s.event('QUEST_LOG_UPDATE'); s.pump(12); s.silent()
    s.event('QUEST_LOG_UPDATE'); s.pump(12); s.silent()
    assert(#s.reports==1,'Missing required title reader must report once; got '..#s.reports)
end)
test('transient empty objectives preserve already complete quest baseline',function()
    local s=environment()
    s.log[1].complete=true; s.event('QUEST_LOG_UPDATE'); s.has('Complete'); s.pump(6); s.silent()
    local previous=s.log[1].objectives
    s.log[1].objectives={}; s.event('QUEST_LOG_UPDATE'); s.silent()
    s.log[1].objectives=previous; s.event('QUEST_LOG_UPDATE'); s.silent()
end)
test('completion transition is announced even when objectives are temporarily empty',function()
    local s=environment()
    s.log[1].complete=true; s.log[1].objectives={}; s.event('QUEST_LOG_UPDATE')
    s.has('Quest 1'); s.has('Complete')
end)
test('throwing quest API reports once across retries and repeated events',function()
    local s=environment()
    C_QuestLog.GetNumQuestLogEntries=function()
        s.reads=s.reads+1
        error('Quest reader failed')
    end
    s.event('QUEST_LOG_UPDATE'); s.pump(12); s.silent()
    s.event('QUEST_LOG_UPDATE'); s.pump(12); s.silent()
    assert(#s.reports==1,'Throwing quest API must report once; got '..#s.reports)
end)
test('temporary incomplete objectives preserve previous snapshot',function()
    local s=environment(); local old=s.log[1].objectives; s.log[1].objectives=nil
    s.event('QUEST_LOG_UPDATE'); s.silent(); s.log[1].objectives=old
    s.event('QUEST_LOG_UPDATE'); s.silent(); s.change(2); s.has('Wolves 2/8')
end)
test('duplicate events do not extend five second lifetime',function()
    local s=environment(); s.change(1); s.pump(3); s.event('QUEST_LOG_UPDATE'); s.pump(1.5); s.pump(0.5); s.silent()
end)
test('five seconds hold followed by 0.3 second fade',function()
    local s=environment(); s.log[1].objectives[1].text='Wolves 1/8'; s.ns.QuestNoticeEvent('QUEST_LOG_UPDATE'); s.tick(0)
    s.pump(4.9); s.has('Wolves 1/8'); s.pump(0.2)
    local partial=false
    for _, f in ipairs(UIParent.children) do if f~=s.tracker and f:IsShown() and f.alpha>0 and f.alpha<1 then partial=true end end
    assert(partial,'Notice must fade numerically after five seconds'); s.pump(0.3); s.silent()
end)
test('QUEST_COMPLETE dialog and removal do not create notices',function()
    local s=environment(); s.event('QUEST_COMPLETE'); s.silent(); s.log={}; s.event('QUEST_LOG_UPDATE'); s.silent(); s.event('QUEST_TURNED_IN',1); s.silent()
end)
test('classic index reorder is silent',function()
    local s=environment(true); s.log[2]=quest(2); s.ns.RestoreQuestNotice(); s.ns.ApplyQuestNotice(); s.pump()
    s.log[1],s.log[2]=s.log[2],s.log[1]; s.event('QUEST_LOG_UPDATE'); s.silent()
end)
test('multiple changed quests are queued and shown sequentially',function()
    local s=environment(); s.log[2]=quest(2); s.ns.RestoreQuestNotice(); s.ns.ApplyQuestNotice(); s.pump()
    for _,q in ipairs(s.log) do q.objectives[1].text='Wolves 2/8' end
    s.event('QUEST_LOG_UPDATE'); local first=s.text(); assert(first:find('Quest 1',1,true) or first:find('Quest 2',1,true))
    assert(not (first:find('Quest 1',1,true) and first:find('Quest 2',1,true)),'Show one quest at a time')
    s.pump(5.4); local second=s.text(); assert(second~='' and second~=first,'Other quest must follow')
end)
test('same quest coalesces and refreshes its lifetime',function()
    local s=environment(); s.change(1); s.pump(3); s.change(2); s.pump(2); s.has('Wolves 2/8'); s.pump(4); s.silent()
end)
test('queue caps five quests and drops oldest waiting entry',function()
    local s=environment(); s.change(1)
    for id=2,7 do s.log[#s.log+1]=quest(id); s.event('QUEST_ACCEPTED',id) end
    local observed={}; for _=1,8 do observed[#observed+1]=s.text(); s.pump(5.4) end
    local text=table.concat(observed,'\n'); assert(not text:find('Quest 2',1,true),'Oldest waiting quest must be dropped')
    assert(text:find('Quest 7',1,true),'Newest queued quest must survive')
    local seen={}; for _,v in ipairs(observed) do local id=v:match('Quest (%d+)'); if id then seen[id]=true end end
    local count=0; for _ in pairs(seen) do count=count+1 end
    assert(count<=5,'Queue including current must contain at most five different quests')
end)
for _, mode in ipairs({'hover','glance','edit','pinned','hoverOnly'}) do
    test(mode..' suppresses notice while time keeps running',function()
        local s=environment(); s[mode]=true; s.change(1); s.silent(); s.pump(6); s[mode]=false; s.tick(); s.silent()
    end)
end
test('Apply is idempotent, disable resets, world entry is silent',function()
    local s=environment(); s.change(1); s.ns.ApplyQuestNotice(); s.tick(); s.has('Wolves 1/8')
    s.ns.RestoreQuestNotice(); s.silent(); s.log[1].objectives[1].text='Wolves 2/8'
    s.ns.ApplyQuestNotice(); s.pump(); s.silent(); s.change(3); s.has('Wolves 3/8')
    s.event('PLAYER_ENTERING_WORLD',false,false); s.silent(); s.change(4); s.has('Wolves 4/8')
end)
test('notice is on UIParent, copies tracker placement and width, never captures clicks',function()
    local s=environment(); s.change(1); local found=false
    for _,f in ipairs(UIParent.children) do if f~=s.tracker and f:IsShown() and f.alpha>0 and #f.children>0 then
        found=true; assert(f.parent==UIParent); assert(f.width==s.tracker.width); assert(f.mouse~=true and f.click~=true,'Notice must not intercept clicks')
        local anchored=f.allPoints==s.tracker
        for _,p in ipairs(f.points) do for _,v in ipairs(p) do if v==s.tracker then anchored=true end end end
        assert(anchored or (#f.points>0),'Must position notice at tracker')
    end end
    assert(found,'Expected visible notice frame')
end)
test('missing and forbidden trackers safely suppress',function()
    local s=environment(); ObjectiveTrackerFrame=nil; s.change(1); s.silent()
    ObjectiveTrackerFrame=s.tracker; s.tracker.forbidden=true; s.tick(); s.silent()
end)
test('secret objective data does not become a false update',function()
    local s=environment(); local secret=setmetatable({secret=true},{__tostring=function() error('Secret text consumed') end,__lt=function() error('Secret compared') end})
    s.log[1].objectives[1].text=secret; s.event('QUEST_LOG_UPDATE'); s.silent()
    s.log[1].objectives[1].text='Wolves 0/8'; s.event('QUEST_LOG_UPDATE'); s.silent(); s.change(1); s.has('Wolves 1/8')
end)
test('missing APIs remain quiet and report once',function()
    local s=environment(); C_QuestLog=nil; s.event('QUEST_LOG_UPDATE'); s.pump(2); s.silent()
    assert(#s.reports<=1,'Missing APIs should report once')
end)
test('unavailable log data retries within a finite window',function()
    local s=environment()
    C_QuestLog.GetNumQuestLogEntries=function() s.reads=s.reads+1; return nil end
    s.event('QUEST_LOG_UPDATE'); s.pump(12); s.silent()
    local reads=s.reads; s.pump(2); assert(s.reads==reads,'Unavailable data must stop polling after a bounded retry window')
    assert(#s.reports<=1,'Unavailable API should report once')
end)
test('temporary missing title preserves snapshot without a false notice',function()
    local s=environment(); s.log[1].title=nil; s.event('QUEST_LOG_UPDATE'); s.silent()
    s.log[1].title='Quest 1'; s.event('QUEST_LOG_UPDATE'); s.silent(); s.change(1); s.has('Wolves 1/8')
end)
test('secret quest ID is ignored safely without erasing previous baseline',function()
    local s=environment(); s.log[1].id=setmetatable({secret=true},{__tostring=function() error('Secret ID consumed') end,__lt=function() error('Secret ID compared') end})
    s.event('QUEST_LOG_UPDATE'); s.silent(); s.log[1].id=1; s.event('QUEST_LOG_UPDATE'); s.silent()
    s.change(1); s.has('Wolves 1/8')
end)
test('QuestWatchFrame is used when the modern tracker is absent',function()
    local s=environment(); QuestWatchFrame=s.tracker; ObjectiveTrackerFrame=nil; s.change(1); s.has('Wolves 1/8')
end)
print(string.format('%d/%d quest notice cases passed',cases-failures,cases))
if failures>0 then os.exit(1) end
