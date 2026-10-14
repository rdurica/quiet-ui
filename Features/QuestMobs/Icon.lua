local _, ns = ...

-- A small icon left of an attackable quest mob's nameplate: an exclamation mark for a mob
-- to kill, a pouch for a mob that drops a quest item. Events only, no per-frame update.
local ICONS = {
    kill = "Interface\\AddOns\\QuietUI\\Media\\quest-kill.tga",
    loot = "Interface\\AddOns\\QuietUI\\Media\\quest-loot.tga",
}
-- The pouch reads smaller than the exclamation at the same size, so its texture overhangs the frame.
local SCALE = { kill = 1, loot = 1.12 }
local GAP, MIN_SIZE, MAX_SIZE = 6, 14, 24


local QuestMobs = {}
ns.QuestMobs = QuestMobs

-- Private to the QuestMobs files. Other features never read it.
local S = {
    pool = {},
    icons = {}, -- unit token -> icon frame on its plate
    pending = false,
    generation = 0,
    stopped = false,
    broken = false, -- frames cannot be destroyed, so stop creating after a failure
}
QuestMobs.state = S

function QuestMobs.True(value)
    return not ns.IsSecret(value) and value == true
end

function QuestMobs.Active()
    if S.stopped then return false end
    local db = ns.DB and ns.DB()
    if not (db and db.enabled) then return false end
    -- The setting accessor lives in Setup.lua; missing means on.
    if type(ns.Settings.QuestMobs) == "function" then return ns.Settings.QuestMobs() ~= false end
    return true
end

-- Icons -------------------------------------------------------------------------------

local function Acquire()
    local icon = table.remove(S.pool)
    if icon then return icon end
    if S.broken or type(CreateFrame) ~= "function" then return end
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or type(frame) ~= "table" then
        S.broken = true
        ns.Report("quest mobs frame", frame)
        return
    end
    ns.Plates.Try(frame, "EnableMouse", false)
    local tex = ns.Plates.Try(frame, "CreateTexture", nil, "ARTWORK")
    if type(tex) ~= "table" then
        S.broken = true
        frame:Hide()
        ns.Report("quest mobs texture", "Textures are not available on this client.")
        return
    end
    ns.Plates.Try(tex, "SetPoint", "CENTER", frame, "CENTER")
    frame.icon = tex
    frame:Hide()
    return frame
end

function QuestMobs.Release(token)
    local icon = S.icons[token]
    if not icon then return end
    S.icons[token] = nil
    icon:Hide()
    ns.Plates.Try(icon, "ClearAllPoints")
    ns.Plates.Try(icon, "SetParent", UIParent)
    S.pool[#S.pool + 1] = icon
end

function QuestMobs.ReleaseAll()
    for token in pairs(S.icons) do QuestMobs.Release(token) end
end

function QuestMobs.Show(token, plate, kind)
    local icon = S.icons[token]
    if not icon then
        icon = Acquire()
        if not icon then return end
        S.icons[token] = icon
    end
    local unitFrame = plate.UnitFrame
    local bar = type(unitFrame) == "table" and (unitFrame.healthBar or unitFrame.HealthBar)
    local anchor = type(bar) == "table" and bar or unitFrame
    if type(anchor) ~= "table" or not ns.Usable(anchor) then anchor = plate end
    local height = ns.Plates.Try(anchor, "GetHeight")
    local size = MIN_SIZE
    if type(height) == "number" and not ns.IsSecret(height) and height > 0 then
        size = math.min(MAX_SIZE, math.max(MIN_SIZE, height))
    end
    ns.Plates.Try(icon, "SetParent", plate)
    ns.Plates.Try(icon, "ClearAllPoints")
    ns.Plates.Try(icon, "SetPoint", "RIGHT", anchor, "LEFT", -GAP, 0)
    ns.Plates.Try(icon, "SetSize", size, size)
    ns.Plates.Try(icon.icon, "SetSize", size * SCALE[kind], size * SCALE[kind])
    ns.Plates.Try(icon.icon, "SetTexture", ICONS[kind])
    icon:Show()
end

