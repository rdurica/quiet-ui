-- Run from the addon directory: lua tests/quest-notice-draw.lua
-- A shown notice with stable placement repaints only its alpha each frame.
local failures = 0
local unpack = table.unpack or unpack
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local calls = {}
local function counted(key) calls[key] = (calls[key] or 0) + 1 end
local function widget(parent)
    local f = { parent = parent, alpha = 1, shown = true, children = {}, width = 280 }
    if parent then parent.children[#parent.children + 1] = f end
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetWidth() return self.width end
    function f:SetWidth(w) counted('SetWidth'); self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:ClearAllPoints() counted('ClearAllPoints') end
    function f:SetPoint() counted('SetPoint') end
    function f:GetEffectiveScale() return 1 end
    function f:IsMouseOver() return false end
    function f:SetText(text) self.text = text end
    function f:GetStringHeight() return 16 end
    function f:SetFont(...) counted('SetFont'); self.font = { ... } end
    function f:GetFont() return 'Fonts/default.ttf', 12, '' end
    function f:SetTextColor() counted('SetTextColor') end
    function f:GetTextColor() return 1, 1, 1, 1 end
    function f:CreateFontString() return widget(self) end
    for _, name in ipairs({ 'EnableMouse', 'SetMouseClickEnabled', 'SetMouseMotionEnabled', 'SetFrameStrata',
        'SetJustifyH', 'SetWordWrap', 'RegisterEvent', 'UnregisterEvent', 'SetScript' }) do
        f[name] = function() end
    end
    return f
end

local function environment()
    local s = { size = 'default' }
    UIParent = widget()
    ObjectiveTrackerFrame, QuestWatchFrame, WatchFrame = widget(UIParent), nil, nil
    QuestObjectiveTracker, QUEST_TRACKER_MODULE, UIErrorsFrame = nil, nil, nil
    ObjectiveTrackerFont, ObjectiveTrackerHeaderFont = nil, nil
    GameFontNormal, GameFontHighlightSmall = widget(), widget()
    CreateFrame = function(_, _, parent) return widget(parent or UIParent) end
    s.log = { { id = 1, title = 'Quest 1', objectives = { { text = 'Wolves 0/8', finished = false, type = 'monster' } } } }
    C_QuestLog = {
        GetNumQuestLogEntries = function() return #s.log end,
        GetInfo = function(i) local q = s.log[i]; if q then return { questID = q.id, title = q.title, isHeader = false } end end,
        GetQuestObjectives = function(id) return s.log[id] and s.log[id].objectives end,
        ReadyForTurnIn = function() return false end,
    }
    local ns = {}
    ns.QuestNoticeEnabled = function() return true end
    ns.QuestNoticeSize = function() return s.size end
    ns.IsSecret = function() return false end
    ns.Usable = function(f) return f and not f:IsForbidden() end
    ns.Report = function(key, err) error(key .. ': ' .. tostring(err)) end
    for _, name in ipairs({ 'InEditMode', 'Glancing', 'Pinned', 'OnlyOnHover', 'Hit' }) do
        ns[name] = function() return false end
    end
    assert(loadfile('QuestNotice.lua'))('QuietUI', ns)
    ns.ApplyQuestNotice()
    for _ = 1, 10 do ns.UpdateQuestNotice(0.05) end
    s.log[1].objectives[1].text = 'Wolves 3/8'
    ns.QuestNoticeEvent('QUEST_LOG_UPDATE')
    ns.UpdateQuestNotice(0.05)
    local notice = UIParent.children[2]
    assert(notice and notice.shown and notice.alpha == 1 and notice.children[1].text == 'Quest 1',
        'Progress notice must be shown before measuring Draw')
    s.ns = ns
    return s
end

test('Stable shown notice sets font and point at most once in 60 frames', function()
    local s = environment()
    for key in pairs(calls) do calls[key] = 0 end
    for _ = 1, 60 do s.ns.UpdateQuestNotice(0.016) end
    local fonts, points = calls.SetFont or 0, calls.SetPoint or 0
    print('Stable notice, 60 frames: SetFont=' .. fonts .. ' SetPoint=' .. points)
    assert(fonts <= 1, 'Stable notice restyled every frame: SetFont=' .. fonts)
    assert(points <= 1, 'Stable notice re-anchored every frame: SetPoint=' .. points)
end)

test('Changing questNoticeSize forces a new Style', function()
    local s = environment()
    for _ = 1, 5 do s.ns.UpdateQuestNotice(0.016) end
    for key in pairs(calls) do calls[key] = 0 end
    s.size = 'larger'
    s.ns.UpdateQuestNotice(0.016)
    assert((calls.SetFont or 0) >= 1, 'Larger text size did not restyle the notice')
end)

os.exit(failures == 0 and 0 or 1)
