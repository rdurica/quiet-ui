local _, ns = ...

local QuestMobs = ns.QuestMobs
local S = QuestMobs.state

local LINE_TITLE, LINE_OBJECTIVE = 17, 8

-- Quest data --------------------------------------------------------------------------

local function Normalize(text)
    text = text:lower():gsub("%d+%s*/%s*%d+", ""):gsub(":", ""):gsub("%s+", " ")
    return (text:match("^%s*(.-)%s*$"))
end

-- Objectives of a quest, read once per recalculation through cache.
local function Objectives(questID, cache)
    local list = cache[questID]
    if list ~= nil then return list or nil end
    local api = type(C_QuestLog) == "table" and C_QuestLog.GetQuestObjectives
    if type(api) ~= "function" then
        ns.Report("quest mobs objectives", "Quest objectives are not available on this client.")
        cache[questID] = false
        return
    end
    local ok, raw = pcall(api, questID)
    list = false
    if ok and type(raw) == "table" then
        list = {}
        for _, o in ipairs(raw) do
            if type(o) == "table" and type(o.text) == "string" and not ns.IsSecret(o.text) then
                list[#list + 1] = { text = Normalize(o.text), kind = not ns.IsSecret(o.type) and o.type or nil, finished = QuestMobs.True(o.finished) }
            end
        end
    end
    cache[questID] = list
    return list or nil
end

-- "loot" only when every open objective line on the tooltip is a matched item.
local function KindFromTooltip(token, cache)
    local api = type(C_TooltipInfo) == "table" and C_TooltipInfo.GetUnit
    if type(api) ~= "function" then
        ns.Report("quest mobs tooltip", "Tooltip data is not available on this client.")
        return "kill"
    end
    local ok, data = pcall(api, token)
    local lines = ok and type(data) == "table" and data.lines
    if type(lines) ~= "table" then return "kill" end
    local questID, counted = nil, 0
    for _, line in ipairs(lines) do
        local kind = type(line) == "table" and line.type
        -- Anything unreadable could hide a kill objective.
        if ns.IsSecret(kind) then return "kill" end
        if kind == LINE_TITLE then
            local id = line.id
            if type(id) ~= "number" or ns.IsSecret(id) then return "kill" end
            questID = id
        elseif kind == LINE_OBJECTIVE and questID then
            local text = line.leftText
            if type(text) ~= "string" or ns.IsSecret(text) then return "kill" end
            local have, need = text:match("(%d+)%s*/%s*(%d+)")
            if not (have and tonumber(have) >= tonumber(need)) then
                local wanted, match = Normalize(text), nil
                for _, o in ipairs(Objectives(questID, cache) or {}) do
                    if o.text == wanted then match = o break end
                end
                if not (match and match.finished) then
                    if not (match and match.kind == "item") then return "kill" end
                    counted = counted + 1
                end
            end
        end
    end
    return counted > 0 and "loot" or "kill"
end

local function Kind(token, cache)
    if type(UnitCanAttack) ~= "function" then return end
    local ok, attack = pcall(UnitCanAttack, "player", token)
    if not ok or not QuestMobs.True(attack) then return end
    local isRelated = type(C_QuestLog) == "table" and C_QuestLog.UnitIsRelatedToActiveQuest
    if type(isRelated) ~= "function" then
        ns.Report("quest mobs relations", "Quest relations are not available on this client.")
        return
    end
    local okRelated, related = pcall(isRelated, token)
    if not okRelated or not QuestMobs.True(related) then return end
    return KindFromTooltip(token, cache)
end

-- Nameplates --------------------------------------------------------------------------

local function Evaluate(token, plate, cache)
    local kind = Kind(token, cache)
    if kind then QuestMobs.Show(token, plate, kind) else QuestMobs.Release(token) end
end

local function PlateAdded(token)
    if type(token) ~= "string" then return end
    QuestMobs.Release(token)
    if not QuestMobs.Active() then return end
    local api = type(C_NamePlate) == "table" and C_NamePlate.GetNamePlateForUnit or GetNamePlateForUnit
    if type(api) ~= "function" then
        ns.Report("quest mobs nameplates", "Nameplates are not available on this client.")
        return
    end
    local ok, plate = pcall(api, token)
    if ok and ns.Usable(plate) then Evaluate(token, plate, {}) end
end

local function Recalculate()
    if not QuestMobs.Active() then return QuestMobs.ReleaseAll() end
    local api = type(C_NamePlate) == "table" and C_NamePlate.GetNamePlates
    if type(api) ~= "function" then
        ns.Report("quest mobs nameplates", "Nameplates are not available on this client.")
        return QuestMobs.ReleaseAll()
    end
    local ok, plates = pcall(api)
    local seen, cache = {}, {}
    if ok and type(plates) == "table" then
        for _, plate in ipairs(plates) do
            if ns.Usable(plate) then
                local token = ns.Plates.Token(plate)
                if token then
                    seen[token] = true
                    Evaluate(token, plate, cache)
                end
            end
        end
    end
    for token in pairs(S.icons) do
        if not seen[token] then QuestMobs.Release(token) end
    end
end

-- Quest log events often come in bursts; fold them into one recalculation next frame.
local function Schedule()
    if S.pending then return end
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return Recalculate() end
    S.pending = true
    local token = S.generation
    local ok = pcall(C_Timer.After, 0, function()
        if token ~= S.generation then return end
        S.pending = false
        Recalculate()
    end)
    if not ok then
        S.pending = false
        Recalculate()
    end
end

-- Public ------------------------------------------------------------------------------

function QuestMobs.Apply()
    S.stopped = false
    S.generation = S.generation + 1
    S.pending = false
    Recalculate()
end

function QuestMobs.Restore()
    S.stopped = true
    S.generation = S.generation + 1
    S.pending = false
    QuestMobs.ReleaseAll()
end

function QuestMobs.Event(event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        PlateAdded((...))
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        QuestMobs.Release((...))
    elseif event == "QUEST_LOG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        Schedule()
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        if (...) == "player" then Schedule() end
    end
end

local EVENTS = { "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_QUEST_LOG_CHANGED", "QUEST_LOG_UPDATE" }
local events = {}
for _, event in ipairs(EVENTS) do
    events[event] = function(...)
        if type(QuestMobs.Event) == "function" then QuestMobs.Event(event, ...) end
    end
end

ns.Feature({
    name = "quest mobs",
    apply = function() if type(QuestMobs.Apply) == "function" then QuestMobs.Apply() end end,
    restore = function() if type(QuestMobs.Restore) == "function" then QuestMobs.Restore() end end,
    events = events,
})
