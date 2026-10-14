local _, ns = ...

-- Quest log snapshots and the changes read from them. State shared by the feature's files lives
-- on Q.state; helpers shared between them on Q.

ns.QuestNotice = ns.QuestNotice or {}
local Q = ns.QuestNotice
Q.state = Q.state or {
    active = false, baseline = false, dirty = false,
    snapshots = {}, accepted = {}, acceptedShown = {}, queue = {},
    -- Last placement and style inputs; Draw repeats the layout only when one changes.
    placed = {},
    clock = 0, retryUntil = 0, retryAt = 0,
    reported = false,
}
local S = Q.state
-- Default matches the tracker. Smaller is only a little under it; larger is the roomier notice.
Q.TEXT_SCALE = { smaller = 0.9, default = 1, larger = 1.2 }

function Q.Secret(value)
    return ns.IsSecret and ns.IsSecret(value)
end

function Q.Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    if not S.reported then
        S.reported = true
        ns.Report("quest notice", a)
    end
end

-- Placement probes are optional. A missing tracker piece falls back quietly.
function Q.Try(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

function Q.Number(value)
    return not Q.Secret(value) and type(value) == "number"
end

function Q.Text(value)
    return not Q.Secret(value) and type(value) == "string" and value ~= ""
end

function Q.Flag(value)
    if Q.Secret(value) then return end
    if type(value) == "boolean" then return value end
    if Q.Number(value) then return value > 0 end
end

local function ReportUnavailable()
    if S.reported then return end
    S.reported = true
    ns.Report("quest notice", "Quest information is not available on this client.")
end

local function ReadObjectives(id, index, modern)
    local result = {}
    if modern and type(C_QuestLog.GetQuestObjectives) == "function" then
        local objectives = Q.Call(C_QuestLog.GetQuestObjectives, id)
        if Q.Secret(objectives) or type(objectives) ~= "table" then return end
        for i, objective in ipairs(objectives) do
            if Q.Secret(objective) or type(objective) ~= "table" or not Q.Text(objective.text) then return end
            local finished = Q.Flag(objective.finished)
            local fulfilled, required, kind = objective.numFulfilled, objective.numRequired, objective.type
            if finished == nil or Q.Secret(kind) or (kind ~= nil and type(kind) ~= "string") then return end
            if Q.Secret(fulfilled) or Q.Secret(required) then return end
            if fulfilled ~= nil and not Q.Number(fulfilled) then return end
            if required ~= nil and not Q.Number(required) then return end
            result[i] = { text = objective.text, finished = finished, kind = kind,
                fulfilled = fulfilled, required = required }
        end
    else
        if type(GetNumQuestLeaderBoards) ~= "function" or type(GetQuestLogLeaderBoard) ~= "function" then
            ReportUnavailable()
            return
        end
        local count = Q.Call(GetNumQuestLeaderBoards, index)
        if not Q.Number(count) or count < 0 then return end
        for i = 1, count do
            local text, kind, finished = Q.Call(GetQuestLogLeaderBoard, i, index)
            finished = Q.Flag(finished)
            if not Q.Text(text) or Q.Secret(kind) or (kind ~= nil and type(kind) ~= "string") or finished == nil then return end
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
    local count = Q.Call(counter)
    if not Q.Number(count) or count < 0 then return end
    local result, complete = {}, true
    for index = 1, count do
        local id, title, header, done
        if modern then
            local info = Q.Call(C_QuestLog.GetInfo, index)
            if not Q.Secret(info) and type(info) == "table" then
                id, title, header, done = info.questID, info.title, info.isHeader, info.isComplete
            end
        else
            local ignored
            title, ignored, ignored, header, ignored, done, ignored, id = Q.Call(GetQuestLogTitle, index)
        end
        if Q.Secret(header) then
            complete = false
        elseif header ~= true then
            if not Q.Number(id) or id <= 0 or not Q.Text(title) then
                complete = false
            else
                local objectives = ReadObjectives(id, index, modern)
                local ready
                if modern then
                    ready = Q.Flag(Q.Call(C_QuestLog.ReadyForTurnIn, id))
                    if ready == nil then ready = Q.Flag(Q.Call(C_QuestLog.IsComplete, id)) end
                else
                    ready = Q.Flag(Q.Call(IsQuestComplete, id))
                end
                if ready == nil then
                    ready = Q.Flag(done)
                    -- Classic uses nil for an unfinished, otherwise readable quest.
                    if not modern and not Q.Secret(done) and done == nil then ready = false end
                end
                local old = S.snapshots[id]
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

function Q.Enqueue(quest, objectives, status)
    local notice = { id = quest.id, title = quest.title, objectives = objectives, status = status, age = 0 }
    if S.current and S.current.id == quest.id then
        S.current = notice
        return
    end
    for i, entry in ipairs(S.queue) do
        if entry.id == quest.id then S.queue[i] = notice; return end
    end
    if not S.current then S.current = notice; return end
    if #S.queue >= 4 then table.remove(S.queue, 1) end
    S.queue[#S.queue + 1] = notice
end

function Q.ReadChanges()
    local log, complete = ReadLog()
    if not log then return false end
    if not S.baseline then
        -- Incomplete startup data must never announce the existing log.
        for id, quest in pairs(log) do
            S.snapshots[id] = quest
            if S.accepted[id] then
                Q.Enqueue(quest, quest.objectives, quest.complete and "Complete" or "Accepted")
                S.accepted[id], S.acceptedShown[id] = nil, true
            end
        end
        if complete then S.baseline = true end
        for id, deadline in pairs(S.accepted) do
            if S.clock >= deadline then S.accepted[id] = nil else complete = false end
        end
        return complete
    end
    local pending = not complete
    for id, quest in pairs(log) do
        local old = S.snapshots[id]
        if S.accepted[id] then
            Q.Enqueue(quest, quest.objectives, quest.complete and "Complete" or "Accepted")
            S.accepted[id], S.acceptedShown[id] = nil, true
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
                Q.Enqueue(quest, changed, "Complete")
            elseif #changed > 0 then
                Q.Enqueue(quest, changed)
            end
        end
        S.snapshots[id] = quest
    end
    if complete then
        for id in pairs(S.snapshots) do
            if not log[id] then S.snapshots[id], S.acceptedShown[id] = nil, nil end
        end
    end
    for id, deadline in pairs(S.accepted) do
        if S.clock >= deadline then S.accepted[id] = nil else pending = true end
    end
    return not pending
end

