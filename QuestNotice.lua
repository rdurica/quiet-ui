local _, ns = ...

local active, baseline, dirty = false, false, false
local noticesOn
local snapshots, accepted, acceptedShown, queue = {}, {}, {}, {}
local current, frame, titleText, bodyText
local drawn, drawnWidth
-- Last placement and style inputs; Draw repeats the layout only when one changes.
local placed = {}
local clock, retryUntil, retryAt = 0, 0, 0
local reported = false
-- Default matches the tracker. Smaller is only a little under it; larger is the roomier notice.
local TEXT_SCALE = { smaller = 0.9, default = 1, larger = 1.2 }

local function Secret(value)
    return ns.IsSecret and ns.IsSecret(value)
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    if not reported then
        reported = true
        ns.Report("quest notice", a)
    end
end

-- Placement probes are optional. A missing tracker piece falls back quietly.
local function Try(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
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
                if objectives and #objectives == 0 and old and #old.objectives > 0 then
                    objectives = old.objectives
                    complete = false
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
    if frame and frame:IsShown() then frame:Hide(); frame:SetAlpha(0) end
end

local hoverDismissed = false

local function ClearNotice()
    snapshots, accepted, acceptedShown, queue = {}, {}, {}, {}
    current, baseline, dirty, hoverDismissed = nil, false, false, false
    Hide()
end

local function Reset()
    ClearNotice()
    dirty, retryUntil, retryAt = true, clock + 10, clock
end

-- Missing means on. Only an explicit false turns notices off.
local function Enabled()
    return type(ns.QuestNoticeEnabled) ~= "function" or ns.QuestNoticeEnabled() ~= false
end

-- Center-screen quest lines. Rewards and failures stay on the error frame.
local CENTER_QUEST = {}
local centerProxy, centerHandler, centerOwned

local function CenterType(name, fallback)
    local value = _G[name]
    if type(value) == "number" then return value end
    return fallback
end

for _, entry in ipairs({
    { "LE_GAME_ERR_QUEST_ACCEPTED_S", 179 },
    { "LE_GAME_ERR_QUEST_COMPLETE_S", 180 },
    { "LE_GAME_ERR_QUEST_OBJECTIVE_COMPLETE_S", 303 },
    { "LE_GAME_ERR_QUEST_UNKNOWN_COMPLETE", 304 },
    { "LE_GAME_ERR_QUEST_ADD_KILL_SII", 305 },
    { "LE_GAME_ERR_QUEST_ADD_FOUND_SII", 306 },
    { "LE_GAME_ERR_QUEST_ADD_ITEM_SII", 307 },
    { "LE_GAME_ERR_QUEST_ADD_PLAYER_KILL_SII", 308 },
}) do
    CENTER_QUEST[CenterType(entry[1], entry[2])] = true
end

local function ShowCenter(event, messageType, message)
    if not UIErrorsFrame then return end
    if type(centerHandler) == "function" then
        centerHandler(UIErrorsFrame, event, messageType, message)
        return
    end
    if type(UIErrorsFrame.AddMessage) ~= "function" then return end
    if event == "UI_ERROR_MESSAGE" then
        UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1, 1)
    else
        UIErrorsFrame:AddMessage(message, 1, 1, 0, 1)
    end
end

local function ReleaseCenterEvents()
    if centerProxy then
        if type(centerProxy.UnregisterAllEvents) == "function" then
            pcall(centerProxy.UnregisterAllEvents, centerProxy)
        else
            pcall(centerProxy.UnregisterEvent, centerProxy, "UI_INFO_MESSAGE")
            pcall(centerProxy.UnregisterEvent, centerProxy, "UI_ERROR_MESSAGE")
        end
        if type(centerProxy.SetScript) == "function" then centerProxy:SetScript("OnEvent", nil) end
        centerProxy = nil
    end
    if centerOwned and UIErrorsFrame and type(UIErrorsFrame.RegisterEvent) == "function" then
        pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_INFO_MESSAGE")
        pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
    end
    centerHandler, centerOwned = nil, false
end

local function InstallCenterFilter()
    if centerOwned or not UIErrorsFrame or type(UIErrorsFrame.UnregisterEvent) ~= "function" then return end
    if type(CreateFrame) ~= "function" then return end
    local infoOk = pcall(UIErrorsFrame.UnregisterEvent, UIErrorsFrame, "UI_INFO_MESSAGE")
    local errorOk = pcall(UIErrorsFrame.UnregisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
    if not infoOk and not errorOk then return end
    if type(UIErrorsFrame.GetScript) == "function" then
        local ok, handler = pcall(UIErrorsFrame.GetScript, UIErrorsFrame, "OnEvent")
        if ok and type(handler) == "function" then centerHandler = handler end
    end
    local createdOk, created = pcall(CreateFrame, "Frame")
    if not createdOk or not created or type(created.RegisterEvent) ~= "function" or type(created.SetScript) ~= "function" then
        if infoOk and type(UIErrorsFrame.RegisterEvent) == "function" then
            pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_INFO_MESSAGE")
        end
        if errorOk and type(UIErrorsFrame.RegisterEvent) == "function" then
            pcall(UIErrorsFrame.RegisterEvent, UIErrorsFrame, "UI_ERROR_MESSAGE")
        end
        centerHandler = nil
        return
    end
    centerProxy = created
    centerProxy:SetScript("OnEvent", function(_, event, messageType, message)
        if active and Enabled() and not Secret(messageType) and CENTER_QUEST[messageType] then return end
        ShowCenter(event, messageType, message)
    end)
    local heardInfo = pcall(centerProxy.RegisterEvent, centerProxy, "UI_INFO_MESSAGE")
    local heardError = pcall(centerProxy.RegisterEvent, centerProxy, "UI_ERROR_MESSAGE")
    if not heardInfo and not heardError then
        centerOwned = true
        ReleaseCenterEvents()
        return
    end
    centerOwned = true
end

local function Sync()
    local on = Enabled()
    if on == noticesOn then return on end
    noticesOn = on
    if on then Reset() else ClearNotice() end
    return on
end

function ns.ApplyQuestNotice()
    active = true
    Sync()
    InstallCenterFilter()
end

function ns.RestoreQuestNotice()
    active = false
    noticesOn = nil
    ClearNotice()
    ReleaseCenterEvents()
end

function ns.QuestNoticeEvent(event, first, second)
    if not active or not Sync() then return end
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

local TRACKER_NAMES = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }

local function Tracker()
    for i = 1, #TRACKER_NAMES do
        local tracker = _G[TRACKER_NAMES[i]]
        if tracker and ns.Usable(tracker) and Call(tracker.IsShown, tracker) then return tracker end
    end
end

local function EnsureFrame()
    if frame then return frame end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    frame = created
    Call(frame.EnableMouse, frame, false)
    Call(frame.SetMouseClickEnabled, frame, false)
    Call(frame.SetMouseMotionEnabled, frame, false)
    Call(frame.SetFrameStrata, frame, "MEDIUM")
    titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetWordWrap(true)
    bodyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bodyText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, 0)
    bodyText:SetJustifyH("LEFT")
    bodyText:SetWordWrap(true)
    Hide()
    return frame
end

local function ScaleOf(region)
    local scale = Try(region.GetEffectiveScale, region)
    if Number(scale) and scale > 0 then return scale end
    return 1
end

local function Offset(value)
    if value == nil then return 0 end
    if Number(value) then return value end
end

-- First slot under the quest header. Individual quest blocks are not consulted.
local function FirstSlot(tracker)
    local module = QuestObjectiveTracker
    if not (module and ns.Usable(module)) then module = QUEST_TRACKER_MODULE end
    if module and ns.Usable(module) then
        local contents = module.ContentsFrame
        local dx, dy = Offset(module.blockOffsetX), Offset(module.fromHeaderOffsetY)
        if contents and ns.Usable(contents) and dx and dy
            and Number(Try(contents.GetLeft, contents)) and Number(Try(contents.GetTop, contents)) then
            return contents, "TOPLEFT", dx, dy
        end
    end
    local header = tracker.Header
    local text = type(header) == "table" and header.Text
    if text and ns.Usable(text) and Number(Try(text.GetLeft, text)) and Number(Try(text.GetBottom, text)) then
        return text, "BOTTOMLEFT", 0, 0
    end
    return tracker, "TOPLEFT", 0, 0
end

local function Style(region, object, anchorScale, chosen)
    if type(object) ~= "table" or not ns.Usable(object) then return end
    local path, size, flags = Try(object.GetFont, object)
    local r, g, b, a = Try(object.GetTextColor, object)
    local noticeScale = ScaleOf(region)
    local textScale = TEXT_SCALE[chosen] or TEXT_SCALE.default
    if type(path) == "string" and Number(size) and size > 0 then
        region:SetFont(path, size * textScale * anchorScale / noticeScale, type(flags) == "string" and flags or "")
    end
    if Number(r) and Number(g) and Number(b) then
        region:SetTextColor(r, g, b, Number(a) and a or 1)
    end
end

-- The rectangle, not the frame under the cursor. The notice sits in that area and must not keep itself up.
local function MouseOver(region)
    if not region or not ns.Usable(region) then return false end
    return Try(region.IsMouseOver, region) == true
end

local function AreaHover()
    local tracker = Tracker()
    if not tracker then return false end
    if ns.QuestTrackerHovered and ns.QuestTrackerHovered() then return true end
    return ns.Hit(tracker) or MouseOver(tracker)
end

local function Draw(alpha)
    local tracker = Tracker()
    if not tracker or ns.Glancing() or ns.InEditMode() or ns.Pinned("quests") or ns.OnlyOnHover("quests") then Hide(); return end
    local width = Call(tracker.GetWidth, tracker)
    if not Number(width) or width <= 20 or not EnsureFrame() then Hide(); return end
    local anchor, point, dx, dy = FirstSlot(tracker)
    local anchorScale = ScaleOf(anchor)
    local frameScale = ScaleOf(frame)
    local chosen = type(ns.QuestNoticeSize) == "function" and ns.QuestNoticeSize() or "default"
    local titleFont = ObjectiveTrackerHeaderFont or GameFontNormal
    local bodyFont = ObjectiveTrackerFont or GameFontHighlightSmall
    -- The tracker text size option resizes the same font objects in place.
    local _, titleSize = Try(titleFont and titleFont.GetFont, titleFont)
    local _, bodySize = Try(bodyFont and bodyFont.GetFont, bodyFont)
    if not Number(titleSize) then titleSize = nil end
    if not Number(bodySize) then bodySize = nil end
    if placed.anchor ~= anchor or placed.point ~= point or placed.dx ~= dx or placed.dy ~= dy or placed.width ~= width
        or placed.anchorScale ~= anchorScale or placed.frameScale ~= frameScale or placed.size ~= chosen
        or placed.titleFont ~= titleFont or placed.bodyFont ~= bodyFont
        or placed.titleSize ~= titleSize or placed.bodySize ~= bodySize then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", anchor, point, dx * anchorScale / frameScale, dy * anchorScale / frameScale)
        frame:SetWidth(width)
        titleText:SetWidth(width)
        bodyText:SetWidth(width)
        Style(titleText, titleFont, anchorScale, chosen)
        Style(bodyText, bodyFont, anchorScale, chosen)
        placed.anchor, placed.point, placed.dx, placed.dy, placed.width = anchor, point, dx, dy, width
        placed.anchorScale, placed.frameScale, placed.size = anchorScale, frameScale, chosen
        placed.titleFont, placed.bodyFont = titleFont, bodyFont
        placed.titleSize, placed.bodySize = titleSize, bodySize
        -- A new font size changes the measured height.
        drawn = nil
    end
    if drawn ~= current or drawnWidth ~= width then
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
        local titleHeight = titleText:GetStringHeight()
        local bodyHeight = bodyText:GetStringHeight()
        frame:SetHeight((Number(titleHeight) and titleHeight or 0) + (Number(bodyHeight) and bodyHeight or 0))
        drawn, drawnWidth = current, width
    end
    frame:SetAlpha(alpha)
    if not frame:IsShown() then frame:Show() end
end

function ns.UpdateQuestNotice(elapsed)
    if not active then return end
    elapsed = elapsed or 0
    clock = clock + elapsed
    if not Sync() then return end
    if dirty and clock >= retryAt then
        local settled = ReadChanges()
        dirty = not settled and clock < retryUntil
        retryAt = clock + 0.2
    end
    if not current then Hide(); return end
    if AreaHover() then
        if not hoverDismissed then
            current = table.remove(queue, 1)
            drawn, drawnWidth = nil, nil
            hoverDismissed = true
        end
        Hide()
        return
    end
    hoverDismissed = false
    current.age = current.age + elapsed
    if current.age >= 5.3 then
        current = table.remove(queue, 1)
        if not current then Hide(); return end
    end
    Draw(current.age <= 5 and 1 or math.max(0, 1 - (current.age - 5) / 0.3))
end
