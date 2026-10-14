local _, ns = ...

-- World state read once per rescan: combat, group, target, vehicle, instance, plus the
-- cursor, edit mode and the "show everything" rule the bars follow.

local World = {}
ns.World = World

-- Returns fn()'s result, or false when the API is missing or throws.
local function Safe(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and not ns.IsSecret(result) and result and true or false
end

-- A corpse still counts as attackable. Enemy needs a living target.
local function TargetAlive()
    if type(UnitIsDeadOrGhost) == "function" then
        return not Safe(UnitIsDeadOrGhost, "target")
    end
    if type(UnitIsDead) == "function" then
        return not Safe(UnitIsDead, "target")
    end
    return true
end

local function HostileTarget()
    if type(UnitCanAttack) ~= "function" then return false end
    return Safe(UnitCanAttack, "player", "target") and TargetAlive()
end

local function FriendlyTarget()
    if type(UnitIsFriend) ~= "function" then return false end
    return Safe(UnitIsFriend, "player", "target") and TargetAlive()
end

local state = {
    combat = false,
    instance = false,
    group = false,
    vehicle = false,
    target = false,
    hostile = false,
    friendly = false,
}

function World.InEditMode()
    local frame = EditModeManagerFrame
    return frame and frame.IsShown and frame:IsShown() and true or false
end

function World.RefreshWorld()
    local combat = state.combat
    if type(InCombatLockdown) == "function" then
        local ok, locked = pcall(InCombatLockdown)
        if ok then combat = locked and true or false end
    end
    local group = type(IsInGroup) == "function" and Safe(IsInGroup) or false
    local vehicle = type(UnitHasVehicleUI) == "function" and Safe(UnitHasVehicleUI, "player") or false
    local target = type(UnitExists) == "function" and Safe(UnitExists, "target") or false
    local hostile = target and HostileTarget()
    local friendly = target and FriendlyTarget()
    local instance = false
    if type(IsInInstance) == "function" then
        instance = Safe(function()
            local inInstance, kind = IsInInstance()
            return inInstance and (
                kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena"
            )
        end)
    end
    if combat ~= state.combat or group ~= state.group or vehicle ~= state.vehicle
        or target ~= state.target or instance ~= state.instance
        or hostile ~= state.hostile or friendly ~= state.friendly then
        state.combat, state.group, state.vehicle = combat, group, vehicle
        state.target, state.instance = target, instance
        state.hostile, state.friendly = hostile, friendly
        World.TouchHud()
    end
end

function World.NoteCombat(on)
    local nextOn = on and true or false
    if nextOn ~= state.combat then
        state.combat = nextOn
        World.TouchHud()
    end
end

function World.InCombat()
    return state.combat
end

function World.InGroup()
    return state.group
end

function World.InForcedInstance()
    return state.instance
end

function World.InVehicle()
    return state.vehicle
end

function World.HasTarget()
    return state.target
end

function World.HostileTarget()
    return state.hostile
end

function World.FriendlyTarget()
    return state.friendly
end

-- false means this tick has not read the cursor yet. nil is a real empty cursor.
local cursorKind = false
local hudDirty = true

function World.TouchHud()
    hudDirty = true
end

function World.ConsumeHud()
    local dirty = hudDirty
    hudDirty = false
    return dirty
end

function World.ForgetCursor()
    cursorKind = false
end

function World.BeginTick(hover)
    if not hover then return end
    cursorKind = false
    ns.RefreshMouse()
end

local function CursorKind()
    if cursorKind ~= false then return cursorKind end
    if type(GetCursorInfo) ~= "function" then
        cursorKind = nil
        return nil
    end
    local ok, kind = pcall(GetCursorInfo)
    cursorKind = ok and kind or nil
    return cursorKind
end

function World.CursorBusy()
    return CursorKind() ~= nil
end

function World.CursorHasItem()
    return CursorKind() == "item"
end

function World.FlyoutOpen()
    return SpellFlyout and SpellFlyout.IsShown and SpellFlyout:IsShown() and true or false
end

-- Explicit HUD/bar-editing exceptions also reveal hover-only bars and XP.
function World.XPForced()
    return World.InEditMode() or World.FlyoutOpen() or World.CursorBusy()
end

-- Action bars are fully visible while this is true.
function World.ShowAll()
    return state.combat or World.InEditMode() or state.vehicle or state.instance
        or World.FlyoutOpen() or World.CursorBusy()
end
