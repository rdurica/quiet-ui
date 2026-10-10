local _, ns = ...

-- A small icon left of an attackable quest mob's nameplate: an exclamation mark for a mob
-- to kill, a pouch for a mob that drops a quest item. Events only, no per-frame update.
local ICONS = {
    kill = "Interface\\AddOns\\QuietUI\\Media\\quest-kill.tga",
    loot = "Interface\\AddOns\\QuietUI\\Media\\quest-loot.tga",
}
-- The pouch reads smaller than the exclamation at the same size, so its texture overhangs the frame.
local SCALE = { kill = 1, loot = 1.12 }
local LINE_TITLE, LINE_OBJECTIVE = 17, 8
local GAP, MIN_SIZE, MAX_SIZE = 6, 14, 24

local pool = {}
local icons = {} -- unit token -> icon frame on its plate
local pending, generation = false, 0
local stopped = false
local broken = false -- frames cannot be destroyed, so stop creating after a failure

local function Try(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, obj, ...)
    if ok then return a, b end
end

local function True(value)
    return not ns.IsSecret(value) and value == true
end

local function Active()
    if stopped then return false end
    local db = ns.DB and ns.DB()
    if not (db and db.enabled) then return false end
    -- The setting accessor lives in Setup.lua; missing means on.
    if type(ns.QuestMobs) == "function" then return ns.QuestMobs() ~= false end
    return true
end

-- Icons -------------------------------------------------------------------------------

local function Acquire()
    local icon = table.remove(pool)
    if icon then return icon end
    if broken or type(CreateFrame) ~= "function" then return end
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or type(frame) ~= "table" then
        broken = true
        ns.Report("quest mobs frame", frame)
        return
    end
    Try(frame, "EnableMouse", false)
    local tex = Try(frame, "CreateTexture", nil, "ARTWORK")
    if type(tex) ~= "table" then
        broken = true
        frame:Hide()
        ns.Report("quest mobs texture", "Textures are not available on this client.")
        return
    end
    Try(tex, "SetPoint", "CENTER", frame, "CENTER")
    frame.icon = tex
    frame:Hide()
    return frame
end

local function Release(token)
    local icon = icons[token]
    if not icon then return end
    icons[token] = nil
    icon:Hide()
    Try(icon, "ClearAllPoints")
    Try(icon, "SetParent", UIParent)
    pool[#pool + 1] = icon
end

local function ReleaseAll()
    for token in pairs(icons) do Release(token) end
end

local function Show(token, plate, kind)
    local icon = icons[token]
    if not icon then
        icon = Acquire()
        if not icon then return end
        icons[token] = icon
    end
    local unitFrame = plate.UnitFrame
    local bar = type(unitFrame) == "table" and (unitFrame.healthBar or unitFrame.HealthBar)
    local anchor = type(bar) == "table" and bar or unitFrame
    if type(anchor) ~= "table" or not ns.Usable(anchor) then anchor = plate end
    local height = Try(anchor, "GetHeight")
    local size = MIN_SIZE
    if type(height) == "number" and not ns.IsSecret(height) and height > 0 then
        size = math.min(MAX_SIZE, math.max(MIN_SIZE, height))
    end
    Try(icon, "SetParent", plate)
    Try(icon, "ClearAllPoints")
    Try(icon, "SetPoint", "RIGHT", anchor, "LEFT", -GAP, 0)
    Try(icon, "SetSize", size, size)
    Try(icon.icon, "SetSize", size * SCALE[kind], size * SCALE[kind])
    Try(icon.icon, "SetTexture", ICONS[kind])
    icon:Show()
end

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
                list[#list + 1] = { text = Normalize(o.text), kind = not ns.IsSecret(o.type) and o.type or nil, finished = True(o.finished) }
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
    if not ok or not True(attack) then return end
    local isRelated = type(C_QuestLog) == "table" and C_QuestLog.UnitIsRelatedToActiveQuest
    if type(isRelated) ~= "function" then
        ns.Report("quest mobs relations", "Quest relations are not available on this client.")
        return
    end
    local okRelated, related = pcall(isRelated, token)
    if not okRelated or not True(related) then return end
    return KindFromTooltip(token, cache)
end

-- Nameplates --------------------------------------------------------------------------

local function PlateToken(plate)
    local unitFrame = plate.UnitFrame
    local token = type(unitFrame) == "table" and unitFrame.unit
    if type(token) == "string" and not ns.IsSecret(token) then return token end
    token = plate.namePlateUnitToken
    if type(token) == "string" and not ns.IsSecret(token) then return token end
end

local function Evaluate(token, plate, cache)
    local kind = Kind(token, cache)
    if kind then Show(token, plate, kind) else Release(token) end
end

local function PlateAdded(token)
    if type(token) ~= "string" then return end
    Release(token)
    if not Active() then return end
    local api = type(C_NamePlate) == "table" and C_NamePlate.GetNamePlateForUnit or GetNamePlateForUnit
    if type(api) ~= "function" then
        ns.Report("quest mobs nameplates", "Nameplates are not available on this client.")
        return
    end
    local ok, plate = pcall(api, token)
    if ok and ns.Usable(plate) then Evaluate(token, plate, {}) end
end

local function Recalculate()
    if not Active() then return ReleaseAll() end
    local api = type(C_NamePlate) == "table" and C_NamePlate.GetNamePlates
    if type(api) ~= "function" then
        ns.Report("quest mobs nameplates", "Nameplates are not available on this client.")
        return ReleaseAll()
    end
    local ok, plates = pcall(api)
    local seen, cache = {}, {}
    if ok and type(plates) == "table" then
        for _, plate in ipairs(plates) do
            if ns.Usable(plate) then
                local token = PlateToken(plate)
                if token then
                    seen[token] = true
                    Evaluate(token, plate, cache)
                end
            end
        end
    end
    for token in pairs(icons) do
        if not seen[token] then Release(token) end
    end
end

-- Quest log events often come in bursts; fold them into one recalculation next frame.
local function Schedule()
    if pending then return end
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return Recalculate() end
    pending = true
    local token = generation
    local ok = pcall(C_Timer.After, 0, function()
        if token ~= generation then return end
        pending = false
        Recalculate()
    end)
    if not ok then
        pending = false
        Recalculate()
    end
end

-- Public ------------------------------------------------------------------------------

function ns.ApplyQuestMobs()
    stopped = false
    generation = generation + 1
    pending = false
    Recalculate()
end

function ns.RestoreQuestMobs()
    stopped = true
    generation = generation + 1
    pending = false
    ReleaseAll()
end

function ns.QuestMobsEvent(event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        PlateAdded((...))
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Release((...))
    elseif event == "QUEST_LOG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        Schedule()
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        if (...) == "player" then Schedule() end
    end
end
