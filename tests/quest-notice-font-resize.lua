-- Run from the addon directory: lua tests/quest-notice-font-resize.lua
-- The tracker text size option resizes its font objects in place; the notice follows.
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
    function f:GetFont() return 'Fonts/default.ttf', self.fontSize or 12, '' end
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

test('A tracker font resized in place restyles the shown notice', function()
    local s = environment()
    for _ = 1, 5 do s.ns.UpdateQuestNotice(0.016) end
    local body = UIParent.children[2].children[2]
    assert(body.font and body.font[2] == 12, 'Notice body did not start at the tracker size')
    GameFontHighlightSmall.fontSize = 16
    s.ns.UpdateQuestNotice(0.016)
    assert(body.font[2] == 16, 'Notice kept the old tracker font size: ' .. tostring(body.font[2]))
end)

os.exit(failures == 0 and 0 or 1)
