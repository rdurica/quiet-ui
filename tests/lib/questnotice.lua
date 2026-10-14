-- Helper for the Quest notice area tests (tests/questnotice/*.lua), loaded with h.lib("questnotice").
local unpack = table.unpack or unpack
local Q = {}

------------------------------------------------------------------------------
-- Quest notice fixture: `local s = Q.fixture(t.mock, t.ns [, opts])`, inside a test
-- (mock installed, addon loaded). It resets the quest tracker globals, gives the tracker a size and a
-- fake quest log, then calls ns.QuestNotice.Apply() and lets the first scans settle.
--   opts.classic     read the log through the classic globals (C_QuestLog = nil)
--   opts.disabled    start with Quest updates off (QuietUICharDB.questNotice = false)
--   opts.unguarded   do not make the Blizzard tracker error when touched
--   opts.bodyFont    define GameFontHighlightSmall (the notice body font) at size 12
-- s.log (quests: s.quest(id, count)), s.tracker, s.reads (log counter reads),
-- s.tick(dt) / s.pump(seconds) / s.event(name, ...) drive ns.QuestNotice.Update and
-- ns.QuestNotice.Event. s.frame() is the notice frame, s.text() the text it shows now
-- ("" while hidden or faded out), s.has(text) / s.silent() assert on it,
-- s.reports() counts the "quest notice" errors printed. Geometry of mock frames comes from
-- their _left/_top/_h/_scale fields and anchors: s.left/top/bottom/scale(frame).
-- s.nativeModule(classic) adds a first-slot quest module to the tracker, s.font(...) makes a
-- font object, s.trackerFonts() installs the tracker font objects.
function Q.fixture(mock, ns, opts)
    opts = opts or {}
    local G = _G
    local s = { mock = mock, ns = ns, reads = 0 }
    for _, name in ipairs({ "QuestObjectiveTracker", "QUEST_TRACKER_MODULE", "WatchFrame", "QuestWatchFrame",
        "ObjectiveTrackerFont", "ObjectiveTrackerHeaderFont", "GameFontHighlightSmall", "UIErrorsFrame" }) do
        G[name] = nil
    end
    local first = #mock.frames
    local create = G.CreateFrame
    G.CreateFrame = function(...)
        local f = create(...)
        f.SetMouseClickEnabled = function(self, v) self._click = v end
        f.SetMouseMotionEnabled = function(self, v) self._motion = v end
        return f
    end

    function s.scale(f)
        local v = 1
        while f do v = v * (f._scale or 1); f = f._parent end
        return v
    end
    function s.left(f)
        if f._left then return f._left end
        local p = f._points[1]
        if p and type(p[2]) == "table" then
            return s.left(p[2]) * s.scale(p[2]) / s.scale(f) + (p[4] or 0)
        end
        return 100
    end
    function s.bottom(f) return s.top(f) - f._h end
    function s.top(f)
        if f._top then return f._top end
        local p = f._points[1]
        if p and type(p[2]) == "table" then
            local rel, edge = p[2], p[3] or p[1]
            return (edge:find("BOTTOM") and s.bottom(rel) or s.top(rel)) * s.scale(rel) / s.scale(f) + (p[5] or 0)
        end
        return 500
    end
    local function prepare(f, guard)
        f.GetEffectiveScale = function(self) return s.scale(self) end
        if guard then
            for _, m in ipairs({ "SetAlpha", "SetParent", "Hide", "Show" }) do
                f[m] = function() error("Must not manipulate Blizzard tracker", 0) end
            end
        end
        return f
    end
    s.prepare = prepare
    local tracker = prepare(G.ObjectiveTrackerFrame, not opts.unguarded)
    tracker._w, tracker._h, tracker._left, tracker._top = 280, 160, 100, 500
    s.tracker = tracker

    function s.quest(id, count)
        return { id = id, title = "Quest " .. id, complete = false, objectives = {
            { text = "Wolves " .. (count or 0) .. "/8", finished = false, type = "monster" },
            { text = "Find the relic", finished = false, type = "object" } } }
    end
    s.log = { s.quest(1) }
    local function byID(id) for _, q in ipairs(s.log) do if q.id == id then return q end end end
    if not opts.classic then
        G.GetNumQuestLogEntries, G.GetQuestLogTitle, G.GetNumQuestLeaderBoards = nil, nil, nil
        G.GetQuestLogLeaderBoard, G.IsQuestComplete = nil, nil
        G.C_QuestLog = {
            GetNumQuestLogEntries = function() s.reads = s.reads + 1; return #s.log, #s.log end,
            GetInfo = function(i)
                local q = s.log[i]
                if q then return { questID = q.id, title = q.title, isHeader = false, isComplete = q.complete and 1 or 0 } end
            end,
            GetTitleForQuestID = function(id) local q = byID(id); return q and q.title end,
            GetQuestObjectives = function(id) local q = byID(id); return q and q.objectives end,
            ReadyForTurnIn = function(id) local q = byID(id); return q and q.complete end,
            IsComplete = function(id) local q = byID(id); return q and q.complete end,
        }
    else
        G.C_QuestLog = nil
        G.GetNumQuestLogEntries = function() s.reads = s.reads + 1; return #s.log, #s.log end
        G.GetQuestLogTitle = function(i)
            local q = s.log[i]
            if q then return q.title, 10, 0, false, false, q.complete and 1 or 0, 1, q.id end
        end
        G.GetNumQuestLeaderBoards = function(i) local q = s.log[i]; return q and q.objectives and #q.objectives end
        G.GetQuestLogLeaderBoard = function(j, i)
            local q = s.log[i]
            local o = q and q.objectives and q.objectives[j]
            if o then return o.text, o.type, o.finished end
        end
        G.IsQuestComplete = function(id) local q = byID(id); return q and q.complete end
    end

    function s.font(path, size, flags, r, g, b, a)
        local f = G.CreateFrame("Font")
        f:SetFont(path, size, flags or "")
        f._textColor = { r or 1, g or 1, b or 1, a or 1 }
        f.GetTextColor = function(self) return unpack(self._textColor) end
        return f
    end
    function s.trackerFonts()
        G.ObjectiveTrackerHeaderFont = s.font("Fonts/header-object.ttf", 16, "OUTLINE", 0.8, 0.7, 0.2, 1)
        G.ObjectiveTrackerFont = s.font("Fonts/goal-object.ttf", 14, "", 0.65, 0.65, 0.65, 1)
    end
    if opts.bodyFont then G.GameFontHighlightSmall = s.font("Fonts/default.ttf", 12) end

    function s.tick(dt) ns.QuestNotice.Update(dt or 0.05) end
    function s.pump(seconds) for _ = 1, math.ceil((seconds or 0.5) / 0.05) do s.tick(0.05) end end
    function s.event(name, ...) ns.QuestNotice.Event(name, ...); s.pump() end
    function s.change(count)
        s.log[1].objectives[1].text = "Wolves " .. count .. "/8"
        s.event("QUEST_LOG_UPDATE")
    end
    function s.reports()
        local n = 0
        for _, line in ipairs(mock.printed) do
            if line:find("quest notice error", 1, true) then n = n + 1 end
        end
        return n
    end

    local cached
    function s.frame()
        if cached then return cached end
        for i = first + 1, #mock.frames do
            local f, fonts = mock.frames[i], 0
            for _, r in ipairs(f._regions) do if r._kind == "FontString" then fonts = fonts + 1 end end
            if fonts == 2 and f._parent == G.UIParent then cached = f; return f end
        end
    end
    function s.notice()
        local f = s.frame()
        if f and f._shown and f:GetEffectiveAlpha() > 0.001 then return f end
        error("Expected visible notice frame", 0)
    end
    function s.text()
        local f = s.frame()
        if not f or not f._shown or f:GetEffectiveAlpha() <= 0.001 then return "" end
        local parts = {}
        for _, r in ipairs(f._regions) do
            if r._kind == "FontString" and r._text ~= "" then parts[#parts + 1] = r._text end
        end
        return table.concat(parts, "\n")
    end
    function s.textRegion(text)
        for _, r in ipairs(s.notice()._regions) do
            if r._kind == "FontString" and r._text:find(text, 1, true) then return r end
        end
        error("Expected text region " .. text, 0)
    end
    function s.has(text)
        local v = s.text()
        if not v:find(text, 1, true) then error("Expected visible " .. text .. ", got " .. v, 0) end
    end
    function s.silent()
        local v = s.text()
        if v ~= "" then error("Unexpected notice: " .. v, 0) end
    end

    -- First quest slot of the native tracker. Its frames error when the notice mutates them.
    function s.nativeModule(classic)
        local module = G.CreateFrame("Frame", nil, s.tracker)
        local contents = G.CreateFrame("Frame", nil, module)
        module.ContentsFrame = contents
        contents._left, contents._top, contents._w = 125, 445, 250
        module.Header = G.CreateFrame("Frame", nil, module)
        module.Header.Text = module.Header:CreateFontString()
        module.Header.Text._left, module.Header.Text._top = 125, 470
        module.blockOffsetX, module.fromHeaderOffsetY = 20, -10
        function module:GetExistingBlock() error("Must not look up quest blocks", 0) end
        for _, f in ipairs({ module, contents, module.Header, module.Header.Text }) do
            prepare(f)
            for _, m in ipairs({ "SetAlpha", "SetParent", "Show", "Hide", "ClearAllPoints", "SetPoint", "SetWidth",
                "SetHeight", "SetSize", "SetText", "SetFont", "SetFontObject", "SetTextColor" }) do
                f[m] = function() error("Must not mutate native widget: " .. m, 0) end
            end
        end
        G[classic and "QUEST_TRACKER_MODULE" or "QuestObjectiveTracker"] = module
        return module
    end
    function s.slotLocation(actual, module)
        local contents = module.ContentsFrame
        local scale = s.scale(contents)
        local left = (s.left(contents) + module.blockOffsetX) * scale
        local top = (s.top(contents) + module.fromHeaderOffsetY) * scale
        if math.abs(s.left(actual) * s.scale(actual) - left) >= 0.01 then
            error("Notice must use the first quest slot left", 0)
        end
        if math.abs(s.top(actual) * s.scale(actual) - top) >= 0.01 then
            error("Notice must use the first quest slot top", 0)
        end
    end
    function s.sameFont(actual, expected, scale)
        local a, b, c = actual:GetFont()
        local x, y, z = expected:GetFont()
        if a ~= x or c ~= z then error("Must use native font path and flags", 0) end
        if math.abs(b - y * (scale or 1)) >= 0.01 then
            error("Notice text scale must follow the selected size, got " .. tostring(b), 0)
        end
        for i = 1, 4 do
            if not actual._textColor or actual._textColor[i] ~= expected._textColor[i] then
                error("Must use native text color", 0)
            end
        end
    end

    if opts.disabled then QuietUICharDB.questNotice = false end
    ns.QuestNotice.Apply()
    s.pump()
    return s
end

return Q
