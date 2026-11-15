local _, ns = ...

-- Saved variables, messages and small helpers every other file uses.

local PREFIX = "|cff8fd4c8QuietUI|r: "
local reported = {}

function ns.DB()
    if type(QuietUIDB) ~= "table" then
        QuietUIDB = {}
    end
    if QuietUIDB.enabled == nil then
        QuietUIDB.enabled = true
    end
    return QuietUIDB
end

function ns.Print(msg)
    print(PREFIX .. tostring(msg))
end

local MAX_ERRORS = 20
local recorded = {}  -- name -> entry of this session, so only a repeat in the session counts up

local function Text(value)
    local ok, text = pcall(tostring, value)
    return ok and text or "?"
end

-- Every call is kept in QuietUIDB.errors (newest last) so /quiet dump can show it after a /reload.
local function Record(name, err)
    local db = ns.DB()
    if type(db.errors) ~= "table" then
        db.errors = {}
        recorded = {}
    end
    local list = db.errors
    local entry = recorded[name]
    if entry then
        local found = false
        for i = 1, #list do
            if list[i] == entry then found = true break end
        end
        if not found then entry = nil end
    end
    if entry then
        entry.count = (tonumber(entry.count) or 1) + 1
        return
    end
    local stack = ""
    if type(debugstack) == "function" then
        local ok, text = pcall(debugstack, 3)
        if ok and type(text) == "string" then stack = text end
    end
    entry = { name = Text(name), message = Text(err), stack = stack, time = date("%Y-%m-%d %H:%M:%S"),
        version = ns.Dump and ns.Dump.Version() or "?", count = 1 }
    list[#list + 1] = entry
    recorded[name] = entry
    while #list > MAX_ERRORS do table.remove(list, 1) end
end

function ns.Report(name, err)
    -- A record failure must never hide the error itself.
    pcall(Record, name, err)
    if reported[name] then return end
    reported[name] = true
    print(PREFIX .. name .. " error (shown once): " .. tostring(err) .. " Type /quiet dump to report it.")
end

function ns.Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

-- Forbidden frames throw on almost any method call from addon code.
function ns.Usable(frame)
    if type(frame) ~= "table" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

-- Secret values (this client hides unit power even out of combat) cannot be
-- compared or used in arithmetic, only passed on to widgets.
function ns.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) and true or false
end

function ns.Wipe(t)
    if type(t) ~= "table" then return t end
    for key in pairs(t) do t[key] = nil end
    return t
end

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = ns.Copy(item) end
    return result
end

function ns.FrameName(frame)
    if ns.Usable(frame) and frame.GetName then
        return frame:GetName()
    end
end

function ns.MouseOver(frame)
    if not frame or not frame.IsShown or not frame.IsMouseOver then return false end
    if not frame:IsShown() then return false end
    -- A rect that follows secret text answers with a secret boolean, which cannot be tested.
    local over = frame:IsMouseOver()
    if ns.IsSecret(over) then return false end
    return over and true or false
end
