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
    function f:IsMouseOver() return self.mouseOver == true or self.hot or false end
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
    function f:GetLeft()
        if self.left then return self.left end
        local p=self.points[1]
        if p and type(p[2])=='table' then return p[2]:GetLeft()*p[2]:GetEffectiveScale()/self:GetEffectiveScale()+(p[4] or 0) end
        return 100
    end
    function f:GetTop()
        if self.top then return self.top end
        local p=self.points[1]
        if p and type(p[2])=='table' then
            local edge=p[3] or p[1]
            return (edge:find('BOTTOM') and p[2]:GetBottom() or p[2]:GetTop())*p[2]:GetEffectiveScale()/self:GetEffectiveScale()+(p[5] or 0)
        end
        return 500
    end
    function f:GetRight() return self:GetLeft() + self.width end
    function f:GetBottom() return self:GetTop() - self.height end
    function f:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
    function f:SetScale(scale) self.scale=scale end
    function f:GetFrameLevel() return 5 end
    function f:GetFrameStrata() return 'MEDIUM' end
    function f:SetText(text) self.text = text end
    function f:GetText() return self.text end
    function f:GetStringHeight() return 16 end
    function f:GetStringWidth() return #(self.text or '') * 6 end
    function f:CreateFontString(_, _, template)
        local r=widget(self,'text'); r.fontObject=template; self.regions[#self.regions+1]=r; return r
    end
    function f:SetFont(path,size,flags) self.font={path,size,flags} end
    function f:GetFont() return table.unpack(self.font or {'Fonts/default.ttf',12,''}) end
    function f:SetFontObject(object)
        self.fontObject=object
        if type(object)=='table' and object.GetFont then self.font={object:GetFont()} end
        if type(object)=='table' and object.GetTextColor then self.color={object:GetTextColor()} end
    end
    function f:GetFontObject() return self.fontObject end
    function f:SetTextColor(...) self.color={...} end
    function f:GetTextColor() return table.unpack(self.color or {1,1,1,1}) end
    function f:SetBackdrop(value) self.backdrop=value end
    function f:SetBackdropColor(...) self.backdropColor={...} end
    function f:SetBackdropBorderColor(...) self.backdropBorderColor={...} end
    function f:CreateTexture() local r = widget(self, 'texture'); self.regions[#self.regions+1] = r; return r end
    function f:GetRegions() return table.unpack(self.regions) end
    function f:GetChildren() return table.unpack(self.children) end
    function f:SetScript(name, fn) self[name] = fn end
    function f:GetScript(name) return self[name] end
    function f:RegisterEvent(event) self.registered = self.registered or {}; self.registered[event] = true end
    function f:UnregisterEvent(event) if self.registered then self.registered[event] = nil end end
    function f:UnregisterAllEvents() self.registered = {} end
    for _, name in ipairs({'SetFrameLevel','SetFrameStrata','SetJustifyH','SetJustifyV','SetWordWrap','SetSpacing','SetColorTexture','SetTexture','SetClampedToScreen'}) do f[name] = function() end end
    return f
end
local function quest(id, count)
    return { id = id, title = 'Quest ' .. id, objectives = {
        {text = 'Wolves ' .. (count or 0) .. '/8', finished = false, type = 'monster'},
        {text = 'Find the relic', finished = false, type = 'object'},
    }, complete = false }
end
local function environment(classic, flag)
    local s = { log = {quest(1)}, reads = 0, time = 0, reports = {}, flag = flag }
    QuestObjectiveTracker, QUEST_TRACKER_MODULE, WatchFrame = nil,nil,nil
    ObjectiveTrackerFont, ObjectiveTrackerHeaderFont = nil,nil
    GameFontNormal, GameFontHighlightSmall = nil,nil
    UIParent = widget()
    ObjectiveTrackerFrame, QuestWatchFrame = widget(UIParent), nil
    local tracker = ObjectiveTrackerFrame
    -- Any manipulation of the original tracker is a contract violation.
    for _, method in ipairs({'SetAlpha','SetParent','Hide','Show'}) do tracker[method] = function() error('Must not manipulate Blizzard tracker') end end
    CreateFrame = function(_, _, parent, template) local f=widget(parent or UIParent,'frame'); f.template=template; return f end
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
    ns.QuestNoticeEnabled = function() return s.flag ~= false end
    ns.QuestNoticeSize = function()
        if s.size == 'smaller' or s.size == 'larger' then return s.size end
        return 'default'
    end
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
    function s.notice()
        for _,f in ipairs(UIParent.children) do
            if f~=tracker and f:IsShown() and f.alpha>0 and #f.children>0 then return f end
        end
        error('Expected visible notice frame')
    end
    function s.textRegion(text)
        for _,r in ipairs(s.notice().regions) do if r.kind=='text' and r:GetText() and r:GetText():find(text,1,true) then return r end end
        error('Expected text region '..text)
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
for _, mode in ipairs({'glance','edit','pinned','hoverOnly'}) do
    test(mode..' suppresses notice while time keeps running',function()
        local s=environment(); s[mode]=true; s.change(1); s.silent(); s.pump(6); s[mode]=false; s.tick(); s.silent()
    end)
end
test('hover dismisses the visible notice and does not restore it',function()
    local s=environment(); s.change(1); s.has('Wolves 1/8')
    s.hover=true; s.tick(); s.silent()
    s.hover=false; s.tick(); s.pump(1); s.silent()
end)
test('quest area rectangle dismisses a visible notice on the same update',function()
    local s=environment(); s.change(1); s.has('Wolves 1/8')
    s.tracker.mouseOver=true; s.tick(); s.silent()
    s.tracker.mouseOver=false; s.tick(); s.silent()
end)
test('hover dismisses only the visible notice and still shows the next queued quest',function()
    local s=environment(); s.change(1); s.log[2]=quest(2); s.event('QUEST_ACCEPTED',2)
    s.tracker.mouseOver=true; s.tick(); s.silent()
    s.tracker.mouseOver=false; s.tick()
    s.has('Quest 2'); assert(not s.text():find('Quest 1',1,true),'Hovered notice must not return')
end)
test('Apply is idempotent, disable resets, world entry is silent',function()
    local s=environment(); s.change(1); s.ns.ApplyQuestNotice(); s.tick(); s.has('Wolves 1/8')
    s.ns.RestoreQuestNotice(); s.silent(); s.log[1].objectives[1].text='Wolves 2/8'
    s.ns.ApplyQuestNotice(); s.pump(); s.silent(); s.change(3); s.has('Wolves 3/8')
    s.event('PLAYER_ENTERING_WORLD',false,false); s.silent(); s.change(4); s.has('Wolves 4/8')
end)
test('notice is on UIParent, uses tracker width fallback, never captures clicks',function()
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

-- Native module frames are read-only. The notice always uses the first quest slot.
local function protectNative(f)
    for _,method in ipairs({'SetAlpha','SetParent','Show','Hide','ClearAllPoints','SetPoint','SetWidth','SetHeight','SetSize','SetText','SetFont','SetFontObject','SetTextColor'}) do
        f[method]=function() error('Must not mutate native widget: '..method) end
    end
    return f
end
local function nativeModule(s, classic)
    local module=widget(s.tracker,'frame')
    module.ContentsFrame=widget(module,'frame')
    module.ContentsFrame.left,module.ContentsFrame.top,module.ContentsFrame.width=125,445,250
    module.Header=widget(module,'frame')
    module.Header.Text=widget(module.Header,'text')
    module.Header.Text.left,module.Header.Text.top=125,470
    module.blockOffsetX,module.fromHeaderOffsetY=20,-10
    function module:GetExistingBlock() error('Must not look up quest blocks') end
    protectNative(module.ContentsFrame); protectNative(module.Header.Text); protectNative(module.Header); protectNative(module)
    if classic then QUEST_TRACKER_MODULE=module else QuestObjectiveTracker=module end
    return module
end
local function slotLocation(actual, module)
    local contents=module.ContentsFrame
    local scale=contents:GetEffectiveScale()
    local left=(contents:GetLeft()+module.blockOffsetX)*scale
    local top=(contents:GetTop()+module.fromHeaderOffsetY)*scale
    assert(math.abs(actual:GetLeft()*actual:GetEffectiveScale()-left)<0.01,'Notice must use the first quest slot left')
    assert(math.abs(actual:GetTop()*actual:GetEffectiveScale()-top)<0.01,'Notice must use the first quest slot top')
end
local function sameFont(actual,expected,scale)
    scale=scale or 1
    local a,b,c=actual:GetFont(); local x,y,z=expected:GetFont()
    assert(a==x and c==z,'Must use native font path and flags')
    assert(math.abs(b-y*scale)<0.01,'Notice text scale must follow the selected size')
    local r,g,bl,al=actual:GetTextColor(); local er,eg,eb,ea=expected:GetTextColor()
    assert(r==er and g==eg and bl==eb and al==ea,'Must use native text color')
end
local function trackerFonts()
    ObjectiveTrackerHeaderFont=widget(nil,'font')
    ObjectiveTrackerHeaderFont:SetFont('Fonts/header-object.ttf',16,'OUTLINE')
    ObjectiveTrackerHeaderFont:SetTextColor(0.8,0.7,0.2,1)
    ObjectiveTrackerFont=widget(nil,'font')
    ObjectiveTrackerFont:SetFont('Fonts/goal-object.ttf',14,'')
    ObjectiveTrackerFont:SetTextColor(0.65,0.65,0.65,1)
end
local function trackerOrigin(actual, tracker)
    assert(math.abs(actual:GetLeft()*actual:GetEffectiveScale()-tracker:GetLeft()*tracker:GetEffectiveScale())<0.01,
        'Failed module placement must use the tracker left')
    assert(math.abs(actual:GetTop()*actual:GetEffectiveScale()-tracker:GetTop()*tracker:GetEffectiveScale())<0.01,
        'Failed module placement must use the tracker top')
end

test('notice is text only without background, border or backdrop template',function()
    local s=environment(); s.change(1); local f=s.notice()
    assert(not f.template or not f.template:find('BackdropTemplate',1,true),'Must not request BackdropTemplate')
    assert(not f.backdrop and not f.backdropColor and not f.backdropBorderColor,'Must not create backdrop')
    for _,r in ipairs(f.regions) do assert(r.kind~='texture','Must not create background or border textures') end
    assert(f.parent==UIParent and f.mouse~=true and f.click~=true and f.motion~=true,'Text must remain independent and nonclickable')
end)
for _,classic in ipairs({false,true}) do
    test((classic and 'classic' or 'modern')..' notice is the first quest slot with tracker fonts',function()
        local s=environment(classic); local module=nativeModule(s,classic); trackerFonts()
        s.change(3); local title=s.textRegion('Quest 1')
        slotLocation(title,module)
        sameFont(title,ObjectiveTrackerHeaderFont); sameFont(s.textRegion('Wolves 3/8'),ObjectiveTrackerFont)
        assert(title:GetTop()*title:GetEffectiveScale()<module.Header.Text:GetTop()*module.Header.Text:GetEffectiveScale(),
            'First slot must lie below the quest section header')
        assert(s.notice().parent==UIParent,'First-slot placement must not reparent notice')
    end)
end
test('module offset changes refresh the first slot without a new quest event',function()
    local s=environment(); local module=nativeModule(s); trackerFonts()
    s.change(1); slotLocation(s.textRegion('Quest 1'),module); sameFont(s.textRegion('Quest 1'),ObjectiveTrackerHeaderFont)
    module.ContentsFrame.left,module.ContentsFrame.top=130,400
    module.blockOffsetX,module.fromHeaderOffsetY=48,-28
    ObjectiveTrackerHeaderFont:SetFont('Fonts/reflow.ttf',17,'')
    ObjectiveTrackerHeaderFont:SetTextColor(0.5,0.6,0.7,1)
    s.tick(); slotLocation(s.textRegion('Quest 1'),module); sameFont(s.textRegion('Quest 1'),ObjectiveTrackerHeaderFont)
end)
test('tracker header fallback places text below header when no quest module exists',function()
    local s=environment(); s.tracker.Header=widget(s.tracker,'frame')
    s.tracker.Header.Text=widget(s.tracker.Header,'text')
    s.tracker.Header.Text.left,s.tracker.Header.Text.top,s.tracker.Header.Text.height=115,490,22
    protectNative(s.tracker.Header.Text); protectNative(s.tracker.Header)
    s.change(1); local title=s.textRegion('Quest 1')
    assert(title:GetTop()<=s.tracker.Header.Text:GetBottom(),'Must not draw over tracker header')
    assert(title:GetTop()>s.tracker:GetBottom(),'Fallback must stay within quest area')
end)
test('replacement tracker uses the new module first slot',function()
    local s=environment(); local module=nativeModule(s)
    s.change(1); slotLocation(s.textRegion('Quest 1'),module)
    local replacement=widget(UIParent,'frame')
    for _,method in ipairs({'SetAlpha','SetParent','Hide','Show'}) do replacement[method]=function() error('Must not mutate replacement tracker') end end
    s.tracker=replacement; ObjectiveTrackerFrame=replacement
    local newModule=nativeModule(s)
    newModule.ContentsFrame.left,newModule.ContentsFrame.top=160,380
    newModule.blockOffsetX,newModule.fromHeaderOffsetY=12,-16
    s.tick(); slotLocation(s.textRegion('Quest 1'),newModule)
end)
for _,failure in ipairs({'missing','throwing','forbidden','secret'}) do
    test(failure..' module slot metadata falls back to the tracker origin',function()
        local s=environment(); local module=nativeModule(s)
        if failure=='missing' then module.ContentsFrame=nil
        elseif failure=='throwing' then module.ContentsFrame.GetLeft=function() error('Contents unavailable') end
        elseif failure=='forbidden' then module.ContentsFrame.forbidden=true
        else
            module.blockOffsetX=setmetatable({secret=true},{__lt=function() error('Secret compared') end,__add=function() error('Secret arithmetic') end})
        end
        s.change(1); s.has('Wolves 1/8'); trackerOrigin(s.textRegion('Quest 1'),s.tracker)
    end)
end
test('unavailable native font getters preserve a usable text fallback',function()
    local s=environment(); local module=nativeModule(s); trackerFonts()
    ObjectiveTrackerHeaderFont.GetFont=function() error('Font unavailable') end
    ObjectiveTrackerFont.GetTextColor=function() return {secret=true} end
    s.change(1); s.has('Quest 1'); s.has('Wolves 1/8'); slotLocation(s.textRegion('Quest 1'),module)
    local title=s.textRegion('Quest 1'); assert(title.fontObject or title.font,'Must retain usable font fallback')
end)
test('first slot keeps physical position and font size under Edit Mode scale',function()
    local s=environment(); s.tracker.scale=1.25
    local module=nativeModule(s); trackerFonts()
    s.change(1); local title=s.textRegion('Quest 1')
    slotLocation(title,module)
    local _,size=title:GetFont(); local _,nativeSize=ObjectiveTrackerHeaderFont:GetFont()
    assert(math.abs(size*title:GetEffectiveScale()-nativeSize*module.ContentsFrame:GetEffectiveScale())<0.01,
        'Default size must match the tracker font under Edit Mode scale')
end)
test('text size offers default, a little smaller, and the larger notice',function()
    local s=environment(); nativeModule(s); trackerFonts()
    s.change(1); sameFont(s.textRegion('Quest 1'),ObjectiveTrackerHeaderFont,1)
    sameFont(s.textRegion('Wolves 1/8'),ObjectiveTrackerFont,1)
    s.size='smaller'; s.tick(); sameFont(s.textRegion('Quest 1'),ObjectiveTrackerHeaderFont,0.9)
    s.size='larger'; s.tick(); sameFont(s.textRegion('Quest 1'),ObjectiveTrackerHeaderFont,1.2)
    s.size='huge'; s.tick(); sameFont(s.textRegion('Quest 1'),ObjectiveTrackerHeaderFont,1)
end)
test('center quest text is dropped only while notices are on',function()
    local s=environment()
    local shown, registered = {}, { UI_INFO_MESSAGE = true, UI_ERROR_MESSAGE = true }
    UIErrorsFrame = {
        RegisterEvent = function(_, event) registered[event] = true end,
        UnregisterEvent = function(_, event) registered[event] = nil end,
        GetScript = function()
            return function(_, _, messageType, message) shown[#shown+1] = messageType .. ':' .. tostring(message) end
        end,
    }
    s.ns.ApplyQuestNotice()
    local proxy
    for _, f in ipairs(UIParent.children) do
        if f.registered and f.registered.UI_INFO_MESSAGE then proxy = f end
    end
    assert(proxy, 'Center filter must listen for info messages')
    assert(not registered.UI_INFO_MESSAGE and not registered.UI_ERROR_MESSAGE, 'Default error frame must release these events')
    local function saw(kind) return table.concat(shown, '|'):find(kind .. ':', 1, true) end
    proxy:OnEvent('UI_INFO_MESSAGE', 305, 'Wolves slain: 1/8')
    proxy:OnEvent('UI_INFO_MESSAGE', 179, 'Quest accepted: Bears')
    proxy:OnEvent('UI_INFO_MESSAGE', 180, 'Bears completed.')
    proxy:OnEvent('UI_INFO_MESSAGE', 196, 'Experience gained: 100')
    proxy:OnEvent('UI_INFO_MESSAGE', 50, 'Not enough mana')
    proxy:OnEvent('UI_ERROR_MESSAGE', 181, 'Quest failed')
    assert(not saw(305) and not saw(179) and not saw(180), 'Quest progress, acceptance and completion must leave the center')
    assert(saw(196) and saw(50) and saw(181), 'Rewards, other info and quest failures must stay')
    s.flag=false
    proxy:OnEvent('UI_INFO_MESSAGE', 305, 'Wolves slain: 2/8')
    assert(saw(305), 'Notices off must restore center quest text')
    s.ns.RestoreQuestNotice()
    assert(registered.UI_INFO_MESSAGE and registered.UI_ERROR_MESSAGE, 'Disable must return events to the error frame')
    assert(not proxy.registered.UI_INFO_MESSAGE, 'Disable must stop the filter')
end)
test('setting off from startup is silent and does not read the quest log',function()
    local s=environment(false,false); assert(s.reads==0,'Disabled notices must not create baseline reads')
    s.log[2]=quest(2); s.event('QUEST_ACCEPTED',2); s.change(2); s.pump(12); s.silent()
    assert(s.reads==0,'Disabled events and idle must not read quest log')
end)
test('runtime setting off immediately clears current and queued notices',function()
    local s=environment(); s.change(1); s.log[2]=quest(2); s.event('QUEST_ACCEPTED',2)
    s.flag=false; s.tick(); s.silent()
    local reads=s.reads; s.log[1].objectives[1].text='Wolves 4/8'; s.event('QUEST_LOG_UPDATE'); s.pump(6)
    assert(s.reads==reads,'Off must stop quest reads and retry work')
    s.flag=nil; s.tick(); s.pump(); s.silent(); s.pump(6); s.silent()
    s.change(5); s.has('Wolves 5/8')
    assert(not s.text():find('Quest 2',1,true),'Previous queued notices must be discarded')
end)
test('setting on via Apply creates a silent fresh baseline and subsequent progress notice',function()
    local s=environment(false,false); s.log[2]=quest(2)
    s.event('QUEST_ACCEPTED',2); s.flag=true; s.ns.ApplyQuestNotice(); s.pump(); s.silent()
    s.change(3); s.has('Wolves 3/8')
    assert(not s.text():find('Quest 2',1,true),'Off-period acceptance must not replay')
end)
print(string.format('%d/%d quest notice cases passed',cases-failures,cases))
if failures>0 then os.exit(1) end
