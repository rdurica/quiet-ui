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

function ns.Report(name, err)
    if reported[name] then return end
    reported[name] = true
    print(PREFIX .. name .. " error (shown once): " .. tostring(err))
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
    return frame:IsMouseOver() and true or false
end
