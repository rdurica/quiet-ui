local _, ns = ...

local active, baseline, dirty = false, false, false
local snapshots, accepted, acceptedShown, queue = {}, {}, {}, {}
local current, frame, titleText, bodyText
local drawn, drawnWidth, anchoredTracker
local clock, retryUntil, retryAt = 0, 0, 0
local reported = false

local function Secret(value)
    return ns.IsSecret and ns.IsSecret(value)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

local function Number(value)
    return not Secret(value) and type(value) == "number"
end

local function Text(value)
    return not Secret(value) and type(value) == "string" and value ~= ""
end

local function Flag(value)
    if Secret(value) then return end
    if type(value) == "boolean" then return value end
    if Number(value) then return value > 0 end
end

local function ReportUnavailable()
    if reported then return end
    reported = true
    ns.Report("quest notice", "Quest information is not available on this client.")
end

local function ReadObjectives(id, index, modern)
    local result = {}
    if modern and type(C_QuestLog.GetQuestObjectives) == "function" then
        local objectives = Call(C_QuestLog.GetQuestObjectives, id)
        if Secret(objectives) or type(objectives) ~= "table" then return end
        for i, objective in ipairs(objectives) do
            if Secret(objective) or type(objective) ~= "table" or not Text(objective.text) then return end
            local finished = Flag(objective.finished)
            local fulfilled, required, kind = objective.numFulfilled, objective.numRequired, objective.type
            if finished == nil or Secret(kind) or (kind ~= nil and type(kind) ~= "string") then return end
            if Secret(fulfilled) or Secret(required) then return end
            if fulfilled ~= nil and not Number(fulfilled) then return end
            if required ~= nil and not Number(required) then return end
            result[i] = { text = objective.text, finished = finished, kind = kind,
                fulfilled = fulfilled, required = required }
        end
    else
        if type(GetNumQuestLeaderBoards) ~= "function" or type(GetQuestLogLeaderBoard) ~= "function" then
            ReportUnavailable()
            return
        end
        local count = Call(GetNumQuestLeaderBoards, index)
        if not Number(count) or count < 0 then return end
        for i = 1, count do
            local text, kind, finished = Call(GetQuestLogLeaderBoard, i, index)
            finished = Flag(finished)
            if not Text(text) or Secret(kind) or (kind ~= nil and type(kind) ~= "string") or finished == nil then return end
            result[i] = { text = text, finished = finished, kind = kind }
        end
    end
    return result
end

local function ReadLog()
    local modern = C_QuestLog and type(C_QuestLog.GetInfo) == "function"
        and type(C_QuestLog.GetNumQuestLogEntries) == "function"
    local counter = modern and C_QuestLog.GetNumQuestLogEntries or GetNumQuestLogEntries
    if type(counter) ~= "function" or (not modern and type(GetQuestLogTitle) ~= "function") then
        ReportUnavailable()
        return
    end
    local count = Call(counter)
    if not Number(count) or count < 0 then return end
    local result, complete = {}, true
    for index = 1, count do
        local id, title, header, done
        if modern then
            local info = Call(C_QuestLog.GetInfo, index)
            if not Secret(info) and type(info) == "table" then
                id, title, header, done = info.questID, info.title, info.isHeader, info.isComplete
            end
        else
            local ignored
            title, ignored, ignored, header, ignored, done, ignored, id = Call(GetQuestLogTitle, index)
        end
        if Secret(header) then
            complete = false
        elseif header ~= true then
            if not Number(id) or id <= 0 or not Text(title) then
                complete = false
            else
                local objectives = ReadObjectives(id, index, modern)
                local ready
                if modern then
                    ready = Flag(Call(C_QuestLog.ReadyForTurnIn, id))
                    if ready == nil then ready = Flag(Call(C_QuestLog.IsComplete, id)) end
                else
                    ready = Flag(Call(IsQuestComplete, id))
                end
                if ready == nil then
                    ready = Flag(done)
                    -- Classic uses nil for an unfinished, otherwise readable quest.
                    if not modern and not Secret(done) and done == nil then ready = false end
                end
                local old = snapshots[id]
                -- A briefly empty objective response must not erase known progress.
                if objectives and #objectives == 0 and old and #old.objectives > 0
                    and not old.complete and ready == false then
                    objectives = nil
                end
                if objectives and ready ~= nil then
                    result[id] = { id = id, title = title, objectives = objectives, complete = ready }
                else
                    complete = false
                end
            end
        end
    end
    return result, complete
end

local function Enqueue(quest, objectives, status)
    local notice = { id = quest.id, title = quest.title, objectives = objectives, status = status, age = 0 }
    if current and current.id == quest.id then
        current = notice
        return
    end
    for i, entry in ipairs(queue) do
        if entry.id == quest.id then queue[i] = notice; return end
    end
    if not current then current = notice; return end
    if #queue >= 4 then table.remove(queue, 1) end
    queue[#queue + 1] = notice
end

local function ReadChanges()
    local log, complete = ReadLog()
    if not log then return false end
    if not baseline then
        -- Incomplete startup data must never announce the existing log.
        for id, quest in pairs(log) do
            snapshots[id] = quest
            if accepted[id] then
                Enqueue(quest, quest.objectives, quest.complete and "Complete" or "Accepted")
                accepted[id], acceptedShown[id] = nil, true
            end
        end
        if complete then baseline = true end
        for id, deadline in pairs(accepted) do
            if clock >= deadline then accepted[id] = nil else complete = false end
        end
        return complete
    end
    local pending = not complete
    for id, quest in pairs(log) do
        local old = snapshots[id]
        if accepted[id] then
            Enqueue(quest, quest.objectives, quest.complete and "Complete" or "Accepted")
            accepted[id], acceptedShown[id] = nil, true
        elseif old then
            local changed = {}
            for i, objective in ipairs(quest.objectives) do
                local before = old.objectives[i]
                if not before or objective.text ~= before.text or objective.finished ~= before.finished
                    or objective.kind ~= before.kind or objective.fulfilled ~= before.fulfilled
                    or objective.required ~= before.required then
                    changed[#changed + 1] = objective
                end
            end
            if quest.complete and not old.complete then
                Enqueue(quest, changed, "Complete")
            elseif #changed > 0 then
                Enqueue(quest, changed)
            end
        end
        snapshots[id] = quest
    end
    if complete then
        for id in pairs(snapshots) do
            if not log[id] then snapshots[id], acceptedShown[id] = nil, nil end
        end
    end
    for id, deadline in pairs(accepted) do
        if clock >= deadline then accepted[id] = nil else pending = true end
    end
    return not pending
end

local function Hide()
    if frame then frame:Hide(); frame:SetAlpha(0) end
end

local function Reset()
    snapshots, accepted, acceptedShown, queue = {}, {}, {}, {}
    current, baseline = nil, false
    dirty, retryUntil, retryAt = true, clock + 10, clock
    Hide()
end

function ns.ApplyQuestNotice()
    if active then return end
    active = true
    Reset()
end

function ns.RestoreQuestNotice()
    active = false
    snapshots, accepted, acceptedShown, queue = {}, {}, {}, {}
    current, baseline, dirty = nil, false, false
    Hide()
end

function ns.QuestNoticeEvent(event, first, second)
    if not active then return end
    if event == "PLAYER_ENTERING_WORLD" then Reset(); return end
    if event ~= "QUEST_ACCEPTED" and event ~= "QUEST_LOG_UPDATE" and event ~= "QUEST_WATCH_UPDATE" then return end
    if event == "QUEST_ACCEPTED" then
        local id
        if not Secret(second) then id = second end
        if id == nil and not Secret(first) then id = first end
        if Number(id) and id > 0 and not acceptedShown[id] then accepted[id] = clock + 10 end
    end
    dirty, retryUntil, retryAt = true, clock + 10, clock
end

local function Tracker()
    for _, tracker in ipairs({ ObjectiveTrackerFrame or false, QuestWatchFrame or false, WatchFrame or false }) do
        if tracker and ns.Usable(tracker) and Call(tracker.IsShown, tracker) then return tracker end
    end
end

local function EnsureFrame()
    if frame then return frame end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent, "BackdropTemplate")
    if not ok then ok, created = pcall(CreateFrame, "Frame", nil, UIParent) end
    if not ok or not created then return end
    frame = created
    Call(frame.EnableMouse, frame, false)
    Call(frame.SetMouseClickEnabled, frame, false)
    Call(frame.SetMouseMotionEnabled, frame, false)
    Call(frame.SetFrameStrata, frame, "MEDIUM")
    if type(frame.SetBackdrop) == "function" then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
        frame:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
    else
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(frame)
        background:SetColorTexture(0.05, 0.05, 0.05, 0.75)
        for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local border = frame:CreateTexture(nil, "BORDER")
            border:SetColorTexture(0.85, 0.85, 0.85, 0.35)
            if edge == "TOP" or edge == "BOTTOM" then
                border:SetPoint(edge .. "LEFT", frame, edge .. "LEFT")
                border:SetPoint(edge .. "RIGHT", frame, edge .. "RIGHT")
                border:SetHeight(1)
            else
                border:SetPoint("TOP" .. edge, frame, "TOP" .. edge)
                border:SetPoint("BOTTOM" .. edge, frame, "BOTTOM" .. edge)
                border:SetWidth(1)
            end
        end
    end
    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(true)
    bodyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bodyText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    Hide()
    return frame
end

local function Draw(alpha)
    local tracker = Tracker()
    if not tracker or ns.Glancing() or ns.InEditMode() or ns.Pinned("quests") or ns.OnlyOnHover("quests")
        or (ns.QuestTrackerHovered and ns.QuestTrackerHovered()) or ns.Hit(tracker) then Hide(); return end
    local width = Call(tracker.GetWidth, tracker)
    if not Number(width) or width <= 20 or not EnsureFrame() then Hide(); return end
    if anchoredTracker ~= tracker then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)
        anchoredTracker = tracker
    end
    if drawn ~= current or drawnWidth ~= width then
        frame:SetWidth(width)
        titleText:SetWidth(width - 20)
        bodyText:SetWidth(width - 20)
        titleText:SetText(current.title)
        local lines = {}
        if current.status then lines[#lines + 1] = current.status end
        for _, objective in ipairs(current.objectives) do
            local text = objective.text
            if objective.fulfilled ~= nil and objective.required ~= nil and objective.required > 0 then
                local progress = tostring(objective.fulfilled) .. "/" .. tostring(objective.required)
                if not text:find(progress, 1, true) then text = text .. " " .. progress end
            end
            lines[#lines + 1] = text
        end
        bodyText:SetText(table.concat(lines, "\n"))
        frame:SetHeight(titleText:GetStringHeight() + bodyText:GetStringHeight() + 26)
        drawn, drawnWidth = current, width
    end
    frame:SetAlpha(alpha)
    frame:Show()
end

function ns.UpdateQuestNotice(elapsed)
    if not active then return end
    elapsed = elapsed or 0
    clock = clock + elapsed
    if dirty and clock >= retryAt then
        local settled = ReadChanges()
        dirty = not settled and clock < retryUntil
        retryAt = clock + 0.2
    end
    if not current then Hide(); return end
    current.age = current.age + elapsed
    if current.age >= 5.3 then
        current = table.remove(queue, 1)
        if not current then Hide(); return end
    end
    Draw(current.age <= 5 and 1 or math.max(0, 1 - (current.age - 5) / 0.3))
end
