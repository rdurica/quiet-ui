local _, ns = ...

-- Nameplate helpers shared by Highlights and QuestMobs.

local Plates = {}
ns.Plates = Plates

-- Calls obj:method(...) when it exists, swallowing errors; returns its first two results.
function Plates.Try(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, obj, ...)
    if ok then return a, b end
end

-- The unit token of a nameplate, or nil when it is missing or secret.
function Plates.Token(plate)
    local unitFrame = plate.UnitFrame
    local token = type(unitFrame) == "table" and unitFrame.unit
    if type(token) == "string" and not ns.IsSecret(token) then return token end
    token = plate.namePlateUnitToken
    if type(token) == "string" and not ns.IsSecret(token) then return token end
end
