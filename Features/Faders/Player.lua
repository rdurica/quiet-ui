local _, ns = ...
local Faders = ns.Faders

local state = Faders.state

local function DeadTargetBlocked()
    if not ns.Settings.RequireLivingTarget() or ns.World.InEditMode() or ns.Glancing() then return false end
    local fn = type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost
        or (type(UnitIsDead) == "function" and UnitIsDead)
    if not fn then return false end
    local ok, dead = pcall(fn, "target")
    if not ok then
        ns.Report("target life", dead)
        return false
    end
    if ns.IsSecret(dead) then return false end
    return dead and true or false
end

local function PlayerDeathBlocked()
    if ns.World.InEditMode() or ns.Glancing() then return false end
    if type(UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, dead = pcall(UnitIsDeadOrGhost, "player")
    if not ok then ns.Report("player life", dead); return false end
    if ns.IsSecret(dead) then return false end
    return dead and true or false
end

local function ReadPlayerStyle()
    if state.samplingPower and state.sampledPlayerStyle ~= nil then return state.sampledPlayerStyle end
    local style = ns.Settings.PlayerStyle()
    if state.samplingPower then state.sampledPlayerStyle = style end
    return style
end

-- Boolean show for the portrait. Health and power stay on the curves below.
-- Edit mode shows it even when the player frame is off.
function Faders.PlayerShouldShow(blocked)
    if state.samplingPower and state.sampledPlayerShow ~= nil then return state.sampledPlayerShow end
    if ns.World.InEditMode() then return true end
    if blocked == nil then blocked = DeadTargetBlocked() end
    if blocked then return false end
    if ReadPlayerStyle() ~= "classic" then return false end
    return ns.Glancing()
        or ns.World.InCombat()
        or ns.World.InForcedInstance()
        or ns.World.InGroup()
        or ns.World.InVehicle()
        or ns.World.HasTarget()
        or ns.Hit(PlayerFrame)
        or ns.Hit(PetFrame)
end

function Faders.PlayerUsesThresholds()
    if state.samplingPower and state.sampledPlayerThresholds ~= nil then return state.sampledPlayerThresholds end
    if ReadPlayerStyle() ~= "classic" then return false end
    local kind, percent = Faders.ReadThreshold()
    return percent ~= nil and (kind == "health" or Faders.RestingPower() ~= nil)
end

function Faders.RestorePlayer()
    Faders.RestorePets()
    state.playerWeight, state.playerCurved = 0, false
end

function Faders.UpdatePlayer(elapsed)
    local blocked = DeadTargetBlocked()
    local show = Faders.PlayerShouldShow(blocked) and true or false
    local deathBlocked = PlayerDeathBlocked()
    local useCurve = Faders.PlayerUsesThresholds()
    if state.samplingPower then state.sampledPlayerShow, state.sampledPlayerThresholds = show, useCurve end
    state.playerCurved, state.playerWeight = Faders.TakeWeight(state.playerCurved, state.playerWeight, show, elapsed, useCurve)
    local alpha = useCurve and Faders.EvalPlayerThresholds(state.playerWeight) or nil
    local player = PlayerFrame
    local pet = PetFrame
    local under = Faders.PetUnderPlayer(pet, player)
    local inherited, canHidePortrait = nil, true
    if under then inherited, canHidePortrait = Faders.IsolatePet(pet, player, show) end
    local target = TargetFrame
    if Faders.IsFadeable(target) then
        if blocked then
            ns.EaseAlpha(target, false, elapsed)
        elseif target._quietAlpha ~= nil or target._quietSecret ~= nil then
            ns.ReleaseAlpha(target)
        end
    end
    if inherited then
        inherited.weight = Faders.NextWeight(inherited.weight, show, elapsed)
        local petAlpha = useCurve and Faders.EvalPlayerThresholds(state.playerWeight, inherited.alpha, "pet")
            or inherited.weight * inherited.alpha
        Faders.PaintSecret(pet, petAlpha)
    elseif not under then
        if alpha ~= nil then Faders.PaintSecret(pet, alpha)
        else Faders.PaintNumeric(pet, show, elapsed) end
    end
    if deathBlocked and canHidePortrait then
        -- An unreadable alpha must clear directly; resampling health could reveal it.
        Faders.PaintNumeric(player, false, elapsed)
    elseif alpha ~= nil then
        Faders.PaintSecret(player, alpha)
    else
        Faders.PaintNumeric(player, show, elapsed)
    end
end
