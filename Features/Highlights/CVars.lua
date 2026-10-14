local _, ns = ...

-- Soft-target highlights. Defines the Highlights table and its private state; this
-- file keeps the activity gate and the soft-target CVars, Glow.lua draws the glow.

local Highlights = {}
ns.Highlights = Highlights

-- Private to the Highlights files. Other features never read it.
local S = {
    targetGUID = nil,
    fighting = false,
    stopped = false,
}
Highlights.state = S

local CVARS = { "SoftTargetInteract", "SoftTargetInteractRange", "SoftTargetNameplateInteract",
    "SoftTargetIconGameObject", "SoftTargetInteractArc", "SoftTargetIconInteract" }
local WANT = { SoftTargetInteract = "3", SoftTargetInteractRange = "15", SoftTargetNameplateInteract = "1",
    SoftTargetIconGameObject = "1", SoftTargetInteractArc = "2", SoftTargetIconInteract = "1" }
local BLOCKED = { party = true, raid = true, pvp = true, arena = true }

function Highlights.Secret(value)
    return ns.IsSecret and ns.IsSecret(value)
end

function Highlights.InCombat()
    if S.fighting then return true end
    local ok, combat = pcall(InCombatLockdown)
    return ok and combat == true
end

local function InBlockedInstance()
    if type(IsInInstance) ~= "function" then return false end
    local ok, _, kind = pcall(IsInInstance)
    return ok and not Highlights.Secret(kind) and BLOCKED[kind] == true
end

function Highlights.Flags()
    local flags = type(ns.Settings.Highlights) == "function" and ns.Settings.Highlights()
    return type(flags) == "table" and flags or {}
end

function Highlights.Active()
    if S.stopped then return false end
    local db = ns.DB and ns.DB()
    if not (db and db.enabled) then return false end
    local flags = Highlights.Flags()
    if not (flags.herb or flags.ore or flags.quest) then return false end
    return not InBlockedInstance()
end

-- CVars -------------------------------------------------------------------------------

local function CVarApi()
    if type(C_CVar) == "table" and type(C_CVar.GetCVar) == "function" and type(C_CVar.SetCVar) == "function" then
        return C_CVar
    end
    ns.Report("highlights", "Console variables are not available on this client.")
end

local function ReadCVar(api, name)
    local ok, value = pcall(api.GetCVar, name)
    if ok and value ~= nil and not Highlights.Secret(value) then return tostring(value) end
end

local function WriteCVar(api, name, value)
    if ReadCVar(api, name) == value then return true end
    local ok, err = pcall(api.SetCVar, name, value)
    if not ok then ns.Report("highlights", err) end
    return ok
end

-- Only a game object needs its nameplate and icon for the glow. Our SoftTargetInteract 3 also
-- picks NPCs, which would get a friendly plate or a name and icon the player never asked for.
local function Wanted(name, originals)
    if type(S.targetGUID) == "string" and S.targetGUID:find("^GameObject") then return WANT[name] end
    if name == "SoftTargetNameplateInteract" then return tostring(originals[name]) end
    if name == "SoftTargetIconInteract" then
        -- Keep the player's icon only if they already used soft interact themselves.
        if tostring(originals.SoftTargetInteract) == "0" then return "0" end
        return tostring(originals[name])
    end
    return WANT[name]
end

-- CVars change only out of combat; REGEN_ENABLED calls this again with the current state.
function Highlights.SyncCVars()
    if Highlights.InCombat() then return end
    local api = CVarApi()
    if not api then return end
    local db = QuietUIDB
    if type(db) ~= "table" then return end
    if Highlights.Active() then
        if type(db.highlightCVars) ~= "table" then
            local saved = {}
            for _, name in ipairs(CVARS) do saved[name] = ReadCVar(api, name) end
            if next(saved) == nil then return end
            db.highlightCVars = saved
        end
        -- Only CVars whose original could be read are changed.
        for _, name in ipairs(CVARS) do
            -- Older snapshots may predate a newly managed CVar.
            if db.highlightCVars[name] == nil then db.highlightCVars[name] = ReadCVar(api, name) end
            if db.highlightCVars[name] ~= nil then WriteCVar(api, name, Wanted(name, db.highlightCVars)) end
        end
    elseif type(db.highlightCVars) == "table" then
        local restored = true
        for _, name in ipairs(CVARS) do
            local value = db.highlightCVars[name]
            if value ~= nil and not WriteCVar(api, name, tostring(value)) then restored = false end
        end
        if restored then db.highlightCVars = nil end
    end
end

