local _, ns = ...

-- Non-bar frames that fade: XP bar, cooldown manager, personal resource bar,
-- damage meter, the player frame, the pet frame, the quest tracker, buffs,
-- and the range gradient on the target nameplate.

local STATUS_NAMES = {
    "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer",
    "MainMenuExpBar",
    "ReputationWatchBar",
}

local COOLDOWN_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

local RESOURCE_NAMES = {
    "PersonalResourceDisplayFrame",
}

local PARTY_NAMES = {
    "CompactPartyFrameContainer",
    "CompactRaidFrameContainer",
    "PartyFrame",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4",
}

local QUEST_NAMES = {
    "ObjectiveTrackerFrame",
    "QuestWatchFrame",
    "WatchFrame",
}

local AURA_NAMES = {
    "BuffFrame",
    "DebuffFrame",
    "TemporaryEnchantFrame",
}

-- Keep the meter readable for a moment after combat ends.
local METER_AFTER_COMBAT = 10

-- Quest XP arrives out of combat, so the XP bar shows it for a moment.
local XP_AFTER_QUEST = 5

-- The resource bar also shows out of combat below this share of max power.
local LOW_POWER = 0.7

-- Mana, focus and energy rest at max; rage and the rest rest at zero.
local RESTS_AT_MAX = { [0] = true, [2] = true, [3] = true }

local statusFrames = {}
local cooldownFrames = {}
local resourceFrames = {}
local partyFrames = {}
local partyAlphaBlocks = {}
local managedParty = {}
local FindPartyFrames, PartyChanged
local partyActive = false
local questFrames = {}
local auraFrames = {}
local meterFrames = {}
local meterSet = {}
local lastCombat
local lastQuestXP

local function IsFadeable(frame)
    return ns.Usable(frame) and frame.SetAlpha and frame.IsShown and true or false
end

local function FindNamed(list, names)
    for i = #list, 1, -1 do
        list[i] = nil
    end
    for _, name in ipairs(names) do
        local frame = _G[name]
        if IsFadeable(frame) then
            list[#list + 1] = frame
        end
    end
end

local function AddMeter(frame)
    if meterSet[frame] or not IsFadeable(frame) then return end
    meterSet[frame] = true
    meterFrames[#meterFrames + 1] = frame
end

-- The meter is load-on-demand and its window names are not fixed, so a deep
-- scan of UIParent picks up whatever DamageMeter* frames exist.
local function FindMeters(deep)
    AddMeter(_G.DamageMeter)
    for i = 1, 10 do
        AddMeter(_G["DamageMeterSessionWindow" .. i])
    end
    if not deep or not UIParent or not UIParent.GetChildren then return end
    for _, child in ipairs({ UIParent:GetChildren() }) do
        local name = ns.FrameName(child)
        if name and name:find("^DamageMeter") then
            AddMeter(child)
        end
    end
end

-- Drop the child cache only when the frame grew or the count cannot be read.
local function RefreshKids(list)
    for i = 1, #list do
        local frame = list[i]
        local count, known
        if type(frame.GetNumChildren) == "function" then
            local ok, value = pcall(frame.GetNumChildren, frame)
            if ok and type(value) == "number" and not ns.IsSecret(value) then
                count, known = value, true
            end
        end
        if not known or frame._quietKidCount ~= count then
            frame._quietKids = nil
            frame._quietKidCount = known and count or nil
        end
    end
end

function ns.FindFaders(deep)
    FindNamed(statusFrames, STATUS_NAMES)
    FindNamed(cooldownFrames, COOLDOWN_NAMES)
    FindNamed(resourceFrames, RESOURCE_NAMES)
    FindNamed(questFrames, QUEST_NAMES)
    FindNamed(auraFrames, AURA_NAMES)
    RefreshKids(resourceFrames)
    RefreshKids(auraFrames)
    FindMeters(deep)
    local active = ns.AutoHideParty and ns.AutoHideParty() or false
    if active and (deep or not partyActive or PartyChanged()) then
        FindPartyFrames()
    end
    partyActive = active
end

-- A roster change can swap members without changing the container counts.
function ns.ScanParty()
    if ns.AutoHideParty and ns.AutoHideParty() then
        FindPartyFrames()
        partyActive = true
    end
end

function ns.MarkCombatEnd()
    if type(GetTime) == "function" then
        lastCombat = GetTime()
    end
    ns.TouchHud()
end

function ns.MarkQuestXP(xp)
    if type(xp) == "number" and not ns.IsSecret(xp) and xp <= 0 then return end
    if type(GetTime) == "function" then
        lastQuestXP = GetTime()
    end
    ns.TouchHud()
end

local function XPShouldShow()
    if ns.ShowAll() then return true end
    if lastQuestXP and type(GetTime) == "function" then
        return GetTime() - lastQuestXP < XP_AFTER_QUEST
    end
    return false
end

local function MeterShouldShow()
    if ns.InCombat() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode() then return true end
    if lastCombat and type(GetTime) == "function" then
        return GetTime() - lastCombat < METER_AFTER_COMBAT
    end
    return false
end

-- Catch hover even when Blizzard's container is not mouse-enabled.
local hoverCatchers = {}

local function ParkHover(name)
    local catchers = hoverCatchers[name]
    if not catchers or catchers.parked then return end
    for i = 1, #catchers do
        local box = catchers[i]
        if box:IsShown() then box:Hide() end
    end
    catchers.parked = true
end

local function HoverFrames(name, frames, active)
    local catchers = hoverCatchers[name]
    if not catchers then catchers = {}; hoverCatchers[name] = catchers end
    if active == nil then active = ns.OnlyOnHover(name) end
    if not active then
        ParkHover(name)
        return false
    end
    catchers.parked = nil
    local hovered = false
    for i, target in ipairs(frames) do
        local box = catchers[i]
        if ns.DB().enabled and not ns.InEditMode()
            and ns.Usable(target) and target:IsShown() then
            if not box then
                local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
                if ok and created then
                    box = created
                    catchers[i] = box
                    ns.ArmCatcher(box)
                end
            end
            if box then
                if box._quietHoverTarget ~= target then
                    box:ClearAllPoints()
                    box:SetAllPoints(target)
                    box._quietHoverTarget = target
                end
                local strata = target.GetFrameStrata and target:GetFrameStrata()
                if type(strata) == "string" and not ns.IsSecret(strata) and box._quietStrata ~= strata then
                    box:SetFrameStrata(strata)
                    box._quietStrata = strata
                end
                local level = target.GetFrameLevel and target:GetFrameLevel() or 1
                if type(level) ~= "number" or ns.IsSecret(level) then level = 1 end
                level = math.max(0, level - 1)
                if box._quietLevel ~= level then
                    box:SetFrameLevel(level)
                    box._quietLevel = level
                end
                if not box:IsShown() then box:Show() end
                if ns.Hit(box) then hovered = true end
            end
            if ns.Hit(target) then hovered = true end
        elseif box then box:Hide() end
    end
    for i = #frames + 1, #catchers do catchers[i]:Hide() end
    return hovered
end

function ns.HideHoverCatchers()
    for _, catchers in pairs(hoverCatchers) do
        for _, box in ipairs(catchers) do box:Hide() end
    end
end

-- A group shows together when any shown member is hovered.
local function UpdateGroup(frames, show, elapsed, noHover)
    if not show and not noHover then
        for _, frame in ipairs(frames) do
            if ns.Hit(frame) then
                show = true
                break
            end
        end
    end
    for _, frame in ipairs(frames) do
        if frame:IsShown() then
            ns.UpdateFaded(frame, show, elapsed)
        end
    end
end

-- A child already follows its parent alpha. Fading it again would compound.
local function Under(frame, ancestor)
    if not ns.Usable(frame) or type(frame.GetParent) ~= "function" or not ancestor then return false end
    local ok, parent = pcall(frame.GetParent, frame)
    if not ok then return false end
    local depth = 0
    while parent and depth < 6 do
        if parent == ancestor then return true end
        if not ns.Usable(parent) or type(parent.GetParent) ~= "function" then return false end
        ok, parent = pcall(parent.GetParent, parent)
        if not ok then return false end
        depth = depth + 1
    end
    return false
end

-- Same length as the bar fade. Showing snaps to 1. Hiding eases.
local SMOOTH = 0.3
local POWER_FROM = LOW_POWER - 0.001
local HEALTH_FROM = 0.999

local POWER_REST = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { LOW_POWER, 0 },
    { 1, 0 },
}
local POWER_FORCED = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { LOW_POWER, 1 },
    { 1, 1 },
}
local HEALTH_REST = {
    { 0, 1 },
    { HEALTH_FROM, 1 },
    { 1, 0 },
}
local HEALTH_FORCED = {
    { 0, 1 },
    { HEALTH_FROM, 1 },
    { 1, 1 },
}

local curveCache = {}
local playerWeight = 0
local playerCurved = false
local inheritedPets = {}
local auraWeight = 0
local aurasCurved = false
local resourceWeight = 0
local samplingPower = false
local sampledKind
local sampledPlayerShow, sampledPlayerThresholds, sampledPlayerStyle
local thresholdRead = false
local sampledThresholdKind, sampledThresholdPercent
local powerWeights, powerAlphas = {}, {}
local powerSampleCount = 0

local function DeadTargetBlocked()
    if not ns.RequireLivingTarget() or ns.InEditMode() then return false end
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
    if ns.InEditMode() or ns.Glancing() then return false end
    if type(UnitIsDeadOrGhost) ~= "function" then return false end
    local ok, dead = pcall(UnitIsDeadOrGhost, "player")
    if not ok then ns.Report("player life", dead); return false end
    if ns.IsSecret(dead) then return false end
    return dead and true or false
end

local function ReadPlayerStyle()
    if samplingPower and sampledPlayerStyle ~= nil then return sampledPlayerStyle end
    local style = ns.PlayerStyle()
    if samplingPower then sampledPlayerStyle = style end
    return style
end

-- Boolean show for the portrait. Health and power stay on the curves below.
-- Edit mode shows it even when the player frame is off.
local function PlayerShouldShow(blocked)
    if samplingPower and sampledPlayerShow ~= nil then return sampledPlayerShow end
    if ns.InEditMode() then return true end
    if blocked == nil then blocked = DeadTargetBlocked() end
    if blocked then return false end
    if ReadPlayerStyle() ~= "classic" then return false end
    return ns.Glancing()
        or ns.InCombat()
        or ns.InForcedInstance()
        or ns.InGroup()
        or ns.InVehicle()
        or ns.HasTarget()
        or ns.Hit(PlayerFrame)
        or ns.Hit(PetFrame)
end

local function ResourceForced()
    return ns.InCombat() or ns.InForcedInstance() or ns.InEditMode() or ns.Pinned("resource")
        or ns.Glancing()
end

-- Mana, focus and energy. Rage and the rest stay out even when the type number
-- is hidden, as long as the token is still a plain string.
local function ReadRestingPower()
    if type(UnitPowerType) ~= "function" then return nil end
    local kind, token = UnitPowerType("player")
    if type(token) == "string" and not ns.IsSecret(token) then
        if token == "MANA" or token == "FOCUS" or token == "ENERGY" then return kind end
        return nil
    end
    if not ns.IsSecret(kind) then
        if RESTS_AT_MAX[kind] then return kind end
        return nil
    end
    return kind
end

local function RestingPower()
    if samplingPower then return sampledKind end
    return ReadRestingPower()
end

-- Secret values cannot be lerped, so the curve points move and the widget fades.
local function MakeCurve(points)
    if not C_CurveUtil or type(C_CurveUtil.CreateCurve) ~= "function" then
        ns.Report("resource bar", "C_CurveUtil.CreateCurve missing")
        return nil
    end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        for i = 1, #points do
            c:AddPoint(points[i][1], points[i][2])
        end
        return c
    end)
    if not ok then
        ns.Report("resource bar", curve)
        return nil
    end
    return curve
end

local function CurveFor(points, key)
    if key then
        local cached = curveCache[key]
        if cached ~= nil then return cached or nil end
        curveCache[key] = false
    end
    local curve = MakeCurve(points)
    if key then
        curveCache[key] = curve or false
    end
    return curve
end

local function BlendPoints(rest, forced, t)
    if t <= 0 then return rest end
    if t >= 1 then return forced end
    local out = {}
    for i = 1, #rest do
        local y0, y1 = rest[i][2], forced[i][2]
        out[i] = { rest[i][1], y0 + (y1 - y0) * t }
    end
    return out
end

local function BlendedCurve(rest, forced, t, name)
    local curve
    if t <= 0 then
        curve = CurveFor(rest, name .. ":0")
    elseif t >= 1 then
        curve = CurveFor(forced, name .. ":1")
    else
        local key = name .. ":blend"
        curve = CurveFor(rest, key)
        if not curve then return nil end
        if type(curve.ClearPoints) ~= "function" then
            return MakeCurve(BlendPoints(rest, forced, t))
        end
        local ok, err = pcall(function()
            curve:ClearPoints()
            for i = 1, #rest do
                local y0, y1 = rest[i][2], forced[i][2]
                curve:AddPoint(rest[i][1], y0 + (y1 - y0) * t)
            end
        end)
        if not ok then
            curveCache[key] = nil
            ns.Report("resource bar", err)
            return MakeCurve(BlendPoints(rest, forced, t))
        end
    end
    return curve
end

local function NextWeight(current, show, elapsed)
    if show or current <= 0 then return show and 1 or 0 end
    local step = (elapsed or 0) / SMOOTH
    if current <= step then return 0 end
    return current - step
end

local function TakeWeight(curved, weight, show, elapsed, useCurve)
    if not useCurve then return false, weight end
    if not curved then
        weight = show and 1 or 0
    end
    return true, NextWeight(weight, show, elapsed)
end

local function EvalPower(weight)
    local kind = RestingPower()
    if kind == nil then return nil end
    if weight >= 1 then return 1 end
    -- Weights are plain numbers; the cached result may be secret and is never compared.
    if samplingPower then
        for i = 1, powerSampleCount do
            if powerWeights[i] == weight then return powerAlphas[i] end
        end
    end
    local curve = BlendedCurve(POWER_REST, POWER_FORCED, weight, "power")
    if not curve or type(UnitPowerPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitPowerPercent, "player", kind, false, curve)
    if ok and alpha ~= nil then
        if samplingPower then
            powerSampleCount = powerSampleCount + 1
            powerWeights[powerSampleCount] = weight
            powerAlphas[powerSampleCount] = alpha
        end
        return alpha
    end
    if not ok then ns.Report("player power", alpha) end
    return 0
end

local function EvalHealth(weight)
    if weight >= 1 then return 1 end
    local curve = BlendedCurve(HEALTH_REST, HEALTH_FORCED, weight, "health")
    if not curve or type(UnitHealthPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitHealthPercent, "player", false, curve)
    if ok and alpha ~= nil then return alpha end
    if not ok then ns.Report("player health", alpha) end
    return 0
end

local thresholdCurves = {}
local thresholdWeights, thresholdAlphas = {}, {}
local thresholdSampleCount = 0

local function ThresholdCurve(name, percent, above, below)
    local cached = thresholdCurves[name]
    if cached and cached.percent == percent and cached.above == above and cached.below == below then
        return cached.curve
    end
    local ok, curve = pcall(function()
        local c = cached and cached.curve
        if not c then
            c = C_CurveUtil.CreateCurve()
            c:SetType(Enum.LuaCurveType.Step)
        end
        c:ClearPoints()
        c:AddPoint(0, below or 1)
        c:AddPoint(percent / 100, above)
        return c
    end)
    if ok then
        cached = cached or {}
        cached.curve, cached.percent, cached.above, cached.below = curve, percent, above, below
        thresholdCurves[name] = cached
        return curve
    end
    thresholdCurves[name] = nil
    ns.Report("player threshold curve", curve)
end

local function ReadThreshold()
    if samplingPower and thresholdRead then return sampledThresholdKind, sampledThresholdPercent end
    local kind, percent = "health", 70
    if ns.PlayerThreshold then kind, percent = ns.PlayerThreshold() end
    if samplingPower then
        sampledThresholdKind, sampledThresholdPercent = kind, percent
        thresholdRead = true
    end
    return kind, percent
end

local function EvalPlayerThresholds(weight, scale, name)
    scale = scale or 1
    if weight >= 1 then return scale end
    if samplingPower and not name then
        for i = 1, thresholdSampleCount do
            if thresholdWeights[i] == weight then return thresholdAlphas[i] end
        end
    end
    local kind, percent = ReadThreshold()
    local alpha = weight * scale
    if percent then
        -- Curve points are plain numbers; only the evaluated alpha may be secret.
        local curve = ThresholdCurve(name or kind, percent, weight * scale, scale)
        if curve then
            local fn
            if kind == "health" then fn = UnitHealthPercent else fn = UnitPowerPercent end
            if type(fn) == "function" then
                local ok, result
                if kind == "health" then ok, result = pcall(fn, "player", false, curve)
                else ok, result = pcall(fn, "player", RestingPower(), false, curve) end
                if ok and result ~= nil then alpha = result
                elseif not ok then ns.Report("player " .. kind, result) end
            else ns.Report("player " .. kind, "Percentage API missing") end
        end
    end
    if samplingPower and not name then
        thresholdSampleCount = thresholdSampleCount + 1
        thresholdWeights[thresholdSampleCount] = weight
        thresholdAlphas[thresholdSampleCount] = alpha
    end
    return alpha
end

local function PlayerUsesThresholds()
    if samplingPower and sampledPlayerThresholds ~= nil then return sampledPlayerThresholds end
    if ReadPlayerStyle() ~= "classic" then return false end
    local kind, percent = ReadThreshold()
    return percent ~= nil and (kind == "health" or RestingPower() ~= nil)
end

local function PaintNumeric(frame, show, elapsed)
    if not (IsFadeable(frame) and frame:IsShown()) then return end
    ns.EaseAlpha(frame, show, elapsed)
end

local function HoldResult(frame, alpha)
    if type(alpha) == "number" and not ns.IsSecret(alpha) then
        ns.HoldAlpha(frame, alpha)
    else
        ns.HoldSecretAlpha(frame, alpha)
    end
end

local function PaintSecret(frame, alpha)
    if not (IsFadeable(frame) and frame:IsShown()) or alpha == nil then return end
    HoldResult(frame, alpha)
end

local function HealthPart(frame)
    local health = frame.HealthBarsContainer
    if ns.Usable(health) and health.SetAlpha then return health end
end

local function KidsOf(frame)
    local kids = frame._quietKids
    if kids then return kids end
    kids = {}
    frame._quietKids = kids
    if not frame.GetChildren then return kids end
    for _, child in ipairs({ frame:GetChildren() }) do
        kids[#kids + 1] = child
    end
    return kids
end

-- Two secret alphas cannot be merged, so the health part follows missing
-- health and every other child follows low power. The frame itself stays at 1.
local function PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    if not (IsFadeable(frame) and frame:IsShown()) then return end
    local health = HealthPart(frame)
    local kids = KidsOf(frame)
    if not health or #kids == 0 then
        if powerAlpha ~= nil then
            PaintSecret(frame, powerAlpha)
        else
            PaintNumeric(frame, show, elapsed)
        end
        return
    end
    if frame._quietAlpha ~= 1 or frame._quietSecret ~= nil then
        ns.HoldAlpha(frame, 1)
    end
    for i = 1, #kids do
        local child = kids[i]
        if ns.Usable(child) and child.SetAlpha then
            if child == health then
                HoldResult(child, healthAlpha)
            elseif powerAlpha ~= nil then
                HoldResult(child, powerAlpha)
            else
                ns.EaseAlpha(child, show, elapsed)
            end
        end
    end
end

local function UpdateResource(elapsed)
    if ns.OnlyOnHover("resource") then
        local hovered = HoverFrames("resource", resourceFrames)
        for _, frame in ipairs(resourceFrames) do
            if ns.Hit(frame) then hovered = true; break end
            for _, child in ipairs(KidsOf(frame)) do
                if ns.Usable(child) and ns.Hit(child) then hovered = true; break end
            end
        end
        local show = ns.VisibilityShow("resource", false, hovered)
        resourceWeight = show and 1 or 0
        for _, frame in ipairs(resourceFrames) do
            if IsFadeable(frame) and frame:IsShown() then
                local kids = KidsOf(frame)
                if #kids == 0 then PaintNumeric(frame, show, elapsed)
                else ns.HoldAlpha(frame, 1) end
                for _, child in ipairs(kids) do
                    if IsFadeable(child) then ns.EaseAlpha(child, show, elapsed) end
                end
            end
        end
        return
    end
    ParkHover("resource")
    local show = ResourceForced() and true or false
    resourceWeight = NextWeight(resourceWeight, show, elapsed)
    local powerAlpha = EvalPower(resourceWeight)
    local healthAlpha = EvalHealth(resourceWeight)
    for _, frame in ipairs(resourceFrames) do
        PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    end
end

local petAnchor = setmetatable({}, { __mode = "k" })

local function WatchPetParent(pet)
    if pet._quietParentHook or type(pet.SetParent) ~= "function" or type(hooksecurefunc) ~= "function" then
        return pet._quietParentHook and true or false
    end
    local ok = pcall(hooksecurefunc, pet, "SetParent", function(self)
        petAnchor[self] = nil
    end)
    if ok then pet._quietParentHook = true end
    return pet._quietParentHook and true or false
end

local function PetUnderPlayer(pet, player)
    if not ns.Usable(pet) or not player or type(pet.GetParent) ~= "function" then return false end
    local known = petAnchor[pet]
    if known and known.player == player then return known.under end
    local ok, parent = pcall(pet.GetParent, pet)
    if not ok then return false end
    local direct = parent == player or parent == UIParent or parent == nil
    local under = parent == player or (not direct and Under(pet, player)) or false
    -- Intermediate ancestors can move without the pet's SetParent hook firing.
    if direct and WatchPetParent(pet) then
        petAnchor[pet] = { player = player, under = under }
    end
    return under
end

local function IsolatePet(pet, player, show)
    if inheritedPets[pet] then return inheritedPets[pet], true end
    if type(pet.IsIgnoringParentAlpha) ~= "function" then
        ns.Report("pet alpha inheritance", "Inheritance getter missing")
        return nil, false
    end
    local ok, ignoring = pcall(pet.IsIgnoringParentAlpha, pet)
    if not ok then ns.Report("pet alpha inheritance", ignoring); return nil, false end
    if ns.IsSecret(ignoring) then return nil, false end
    if ignoring then return nil, true end
    if type(pet.SetIgnoreParentAlpha) ~= "function" or type(pet.GetAlpha) ~= "function" then
        ns.Report("pet alpha inheritance", "Inheritance setter or alpha getter missing")
        return nil, false
    end
    local read, alpha = pcall(pet.GetAlpha, pet)
    if not read then ns.Report("pet alpha inheritance", alpha); return nil, false end
    if ns.IsSecret(alpha) then return nil, false end
    if type(alpha) ~= "number" then
        ns.Report("pet alpha inheritance", "Pet alpha unavailable")
        return nil, false
    end
    local weight = player._quietAlpha
    if type(weight) ~= "number" and type(player.GetAlpha) == "function" then
        local readPlayer, value = pcall(player.GetAlpha, player)
        if not readPlayer then ns.Report("player alpha", value)
        elseif not ns.IsSecret(value) then weight = value end
    end
    if ns.IsSecret(weight) or type(weight) ~= "number" then weight = show and 1 or 0 end
    local changed, err = pcall(pet.SetIgnoreParentAlpha, pet, true)
    if not changed then ns.Report("pet alpha inheritance", err); return nil, false end
    local saved = { ignoring = ignoring, alpha = alpha, weight = weight }
    inheritedPets[pet] = saved
    return saved, true
end

function ns.RestorePlayerFader()
    for pet, saved in pairs(inheritedPets) do
        if ns.Usable(pet) and type(pet.SetIgnoreParentAlpha) == "function" then
            local ok, err = pcall(pet.SetIgnoreParentAlpha, pet, saved.ignoring)
            if not ok then ns.Report("restore pet inheritance", err) end
        end
        inheritedPets[pet] = nil
    end
    playerWeight, playerCurved = 0, false
end

local function UpdatePlayer(elapsed)
    local blocked = DeadTargetBlocked()
    local show = PlayerShouldShow(blocked) and true or false
    local deathBlocked = PlayerDeathBlocked()
    local useCurve = PlayerUsesThresholds()
    if samplingPower then sampledPlayerShow, sampledPlayerThresholds = show, useCurve end
    playerCurved, playerWeight = TakeWeight(playerCurved, playerWeight, show, elapsed, useCurve)
    local alpha = useCurve and EvalPlayerThresholds(playerWeight) or nil
    local player = PlayerFrame
    local pet = PetFrame
    local under = PetUnderPlayer(pet, player)
    local inherited, canHidePortrait = nil, true
    if under then inherited, canHidePortrait = IsolatePet(pet, player, show) end
    local target = TargetFrame
    if IsFadeable(target) then
        if blocked then
            ns.EaseAlpha(target, false, elapsed)
        elseif target._quietAlpha ~= nil or target._quietSecret ~= nil then
            ns.ReleaseAlpha(target)
        end
    end
    if inherited then
        inherited.weight = NextWeight(inherited.weight, show, elapsed)
        local petAlpha = useCurve and EvalPlayerThresholds(playerWeight, inherited.alpha, "pet")
            or inherited.weight * inherited.alpha
        PaintSecret(pet, petAlpha)
    elseif not under then
        if alpha ~= nil then PaintSecret(pet, alpha)
        else PaintNumeric(pet, show, elapsed) end
    end
    if deathBlocked and canHidePortrait then
        -- An unreadable alpha must clear directly; resampling health could reveal it.
        PaintNumeric(player, false, elapsed)
    elseif alpha ~= nil then
        PaintSecret(player, alpha)
    else
        PaintNumeric(player, show, elapsed)
    end
end

-- Cooldowns matter only when fighting or grouped, so hover does not count.
local function CooldownsShouldShow()
    return ns.InCombat() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
end

-- Aura buttons can sit outside their container's bounds, so children count too.
local function MouseOverAny(frame)
    if ns.Hit(frame) then return true end
    local kids = KidsOf(frame)
    for i = 1, #kids do
        if ns.Usable(kids[i]) and ns.Hit(kids[i]) then return true end
    end
    return false
end

local function AurasShouldShow(hoverOnly, grouped)
    if hoverOnly then
        local hovered = false
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then hovered = true; break end
        end
        return ns.VisibilityShow("auras", false, hovered)
    end
    local show = ns.InCombat() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
        or ns.Pinned("auras") or ns.Glancing()
    if not show and grouped and PlayerShouldShow() then
        show = true
    end
    if not show then
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then
                show = true
                break
            end
        end
    end
    return show
end

local function UpdateAuras(elapsed)
    local hoverOnly = ns.OnlyOnHover("auras")
    local grouped = not hoverOnly and ns.GroupAuras()
    local show = AurasShouldShow(hoverOnly, grouped) and true or false
    local useCurve = grouped and PlayerUsesThresholds()
    aurasCurved, auraWeight = TakeWeight(aurasCurved, auraWeight, show, elapsed, useCurve)
    local alpha = useCurve and EvalPlayerThresholds(auraWeight) or nil
    local keepDebuffs = not hoverOnly and ns.AlwaysShowDebuffs()
    for _, frame in ipairs(auraFrames) do
        if keepDebuffs and frame == _G.DebuffFrame then
            if frame._quietSecret ~= nil or frame._quietAlpha ~= 1 then
                PaintNumeric(frame, true, elapsed)
            end
        elseif alpha ~= nil then
            PaintSecret(frame, alpha)
        else
            PaintNumeric(frame, show, elapsed)
        end
    end
end

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

-- The tracker container is not mouse-enabled, so the gaps between quests are
-- not hover. This frame is not its child: a faded parent would drop the mouse.
local questCatcher
local questCatcherTarget

local function ShownQuest()
    for i = 1, #questFrames do
        local frame = questFrames[i]
        if ns.Usable(frame) and frame:IsShown() then
            return frame
        end
    end
end

local function EnsureQuestCatcher()
    if questCatcher then return questCatcher end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    ns.ArmCatcher(created)
    created:Hide()
    questCatcher = created
    return created
end

local function PlaceQuestCatcher()
    local box = EnsureQuestCatcher()
    if not box then return end
    local target = ShownQuest()
    if not target or ns.InEditMode() or not ns.DB().enabled then
        box:Hide()
        questCatcherTarget = nil
        return
    end
    if questCatcherTarget ~= target then
        box:SetParent(UIParent)
        box:ClearAllPoints()
        box:SetAllPoints(target)
        questCatcherTarget = target
        -- SetParent can move strata and level, so write them again.
        box._quietStrata, box._quietLevel = nil, nil
    end
    local strata = target.GetFrameStrata and target:GetFrameStrata()
    if type(strata) == "string" and not ns.IsSecret(strata) and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = target.GetFrameLevel and target:GetFrameLevel() or 1
    if type(level) ~= "number" or ns.IsSecret(level) then level = 1 end
    level = math.max(level - 1, 0)
    if box._quietLevel ~= level then
        box:SetFrameLevel(level)
        box._quietLevel = level
    end
    if not box:IsShown() then box:Show() end
end

function ns.QuestTrackerHovered()
    return questCatcher and ns.Hit(questCatcher) or false
end

function ns.HideQuestCatcher()
    if not questCatcher then return end
    questCatcher:Hide()
    questCatcherTarget = nil
end

-- Selection highlights and ready-check indicators can ignore container alpha.
local function CollectPartyAlpha(frame, root, found, depth)
    if depth > 8 or not ns.Usable(frame) then return end
    if type(frame.SetAlpha) == "function" then
        local ignoring = false
        if type(frame.IsIgnoringParentAlpha) == "function" then
            local ok, value = pcall(frame.IsIgnoringParentAlpha, frame)
            ignoring = ok and not ns.IsSecret(value) and value == true
        end
        if frame == root or ignoring then found[frame] = root end
    end
    local highlight = frame.selectionHighlight
    if ns.Usable(highlight) and type(highlight.SetAlpha) == "function"
        and type(highlight.IsIgnoringParentAlpha) ~= "function" then
        found[highlight] = root
    end
    for _, method in ipairs({ "GetRegions", "GetChildren" }) do
        if type(frame[method]) == "function" then
            local ok, children = pcall(function() return { frame[method](frame) } end)
            if ok then
                for _, child in ipairs(children) do CollectPartyAlpha(child, root, found, depth + 1) end
            end
        end
    end
end

-- Per root: the frame and its child + region count. A count that cannot be
-- read is a change, so the full scan stays the fallback.
local partySigFrames, partySigCounts = {}, {}

local function ReadCount(frame, method)
    if type(frame[method]) ~= "function" then return nil end
    local ok, value = pcall(frame[method], frame)
    if ok and type(value) == "number" and not ns.IsSecret(value) then return value end
end

local function PartyCount(frame)
    if not ns.Usable(frame) then return -1 end
    local kids, regions = ReadCount(frame, "GetNumChildren"), ReadCount(frame, "GetNumRegions")
    if not kids or not regions then return nil end
    return kids + regions
end

-- Reads the signature and remembers it; true when it moved since the last read.
PartyChanged = function()
    local changed = false
    for i = 1, #PARTY_NAMES do
        local frame = _G[PARTY_NAMES[i]]
        local count = PartyCount(frame)
        if count == nil or partySigFrames[i] ~= frame or partySigCounts[i] ~= count then
            changed = true
        end
        partySigFrames[i], partySigCounts[i] = frame, count
    end
    return changed
end

FindPartyFrames = function()
    -- Record the signature this scan saw, so the next tick compares against it.
    PartyChanged()
    local candidates = {}
    FindNamed(candidates, PARTY_NAMES)
    local roots = {}
    for _, frame in ipairs(candidates) do
        local nested = false
        for _, other in ipairs(candidates) do
            if frame ~= other and Under(frame, other) then nested = true; break end
        end
        if not nested then roots[frame] = true end
    end
    local alphaFrames = {}
    for frame in pairs(roots) do CollectPartyAlpha(frame, frame, alphaFrames, 0) end
    for frame in pairs(managedParty) do
        if not alphaFrames[frame] then
            ns.ReleaseAlpha(frame, true)
            managedParty[frame] = nil
        end
    end
    partyAlphaBlocks = {}
    for frame, root in pairs(alphaFrames) do
        local block = partyAlphaBlocks[root]
        if not block then block = {}; partyAlphaBlocks[root] = block end
        block[#block + 1] = frame
    end
    for i = #partyFrames, 1, -1 do partyFrames[i] = nil end
    for _, frame in ipairs(candidates) do
        if roots[frame] then
            partyFrames[#partyFrames + 1] = frame
            roots[frame] = nil
        end
    end
end

function ns.UpdateParty(elapsed)
    local active = ns.DB().enabled and ns.AutoHideParty and ns.AutoHideParty() or false
    if not active then
        -- Roster events stop while off; the next FindFaders scans in full.
        partyActive = false
        ParkHover("party")
        for frame in pairs(managedParty) do
            ns.ReleaseAlpha(frame, true)
            managedParty[frame] = nil
        end
        return
    end
    if not ns.InGroup() and not ns.InCombat() and not ns.InForcedInstance()
        and not ns.InEditMode() and not ns.Glancing() then
        ParkHover("party")
        return
    end
    local hovered = HoverFrames("party", partyFrames, true)
    local show = ns.InCombat() or ns.InForcedInstance() or ns.InEditMode() or ns.Glancing() or hovered
    local target = show and 1 or 0
    for root, block in pairs(partyAlphaBlocks) do
        if ns.Usable(root) and root:IsShown() then
            for _, frame in ipairs(block) do
                local settled = managedParty[frame] and frame._quietSecret == nil and frame._quietAlpha == target
                if not settled and (frame == root or ns.Usable(frame)) then
                    ns.EaseAlpha(frame, show, elapsed)
                    managedParty[frame] = true
                end
            end
        end
    end
end

function ns.UpdateSmooth(elapsed, profile)
    samplingPower = false
    sampledPlayerShow, sampledPlayerThresholds, sampledPlayerStyle = nil, nil, nil
    thresholdRead = false
    local ok, kind = pcall(ReadRestingPower)
    sampledKind = ok and kind or nil
    if not ok then ns.Report("player power", kind) end
    for i = 1, powerSampleCount do powerAlphas[i] = nil end
    powerSampleCount = 0
    for i = 1, thresholdSampleCount do thresholdAlphas[i] = nil end
    thresholdSampleCount = 0
    samplingPower = true
    local run = profile or Run
    run("resource bar", UpdateResource, elapsed)
    run("player frame", UpdatePlayer, elapsed)
    run("party frames", ns.UpdateParty, elapsed)
    run("buffs", UpdateAuras, elapsed)
    samplingPower = false
end

-- A green gradient over the target nameplate health bar. A flat tint turns the red bar grey. Secret results are left as they were.
-- Strong on the left, fading out to the right, so the health bar still reads.
local rangeMark
local rangeSlot = { at = nil, helpful = nil, slot = nil }
-- Bar 1 changes come as events; the timer only covers a missed one.
local SLOT_FALLBACK = 5

local function PlainNumber(value)
    return type(value) == "number" and not ns.IsSecret(value)
end

local function ActionSpell(slot)
    local ok, kind, id = pcall(GetActionInfo, slot)
    if not ok or ns.IsSecret(kind) or ns.IsSecret(id) then return nil end
    if kind == "spell" and type(id) == "number" then return id end
    if kind ~= "macro" or type(GetMacroSpell) ~= "function" then return nil end
    local spellOk, spell = pcall(GetMacroSpell, id)
    if not spellOk or ns.IsSecret(spell) then return nil end
    if type(spell) == "number" then return spell end
    if type(spell) == "string" and spell ~= "" then return spell end
end

local function SpellFacts(spellID)
    local name, maxRange
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            if type(info.name) == "string" and not ns.IsSecret(info.name) then name = info.name end
            if PlainNumber(info.maxRange) then maxRange = info.maxRange end
        end
    end
    if type(GetSpellInfo) == "function" and (not name or not maxRange) then
        local ok, spellName, _, _, _, _, range = pcall(GetSpellInfo, spellID)
        if ok then
            if not name and type(spellName) == "string" and not ns.IsSecret(spellName) then
                name = spellName
            end
            if not maxRange and PlainNumber(range) then maxRange = range end
        end
    end
    if not name and not maxRange and not (C_Spell and type(C_Spell.GetSpellInfo) == "function")
        and type(GetSpellInfo) ~= "function" then
        ns.Report("range spell", "spell info missing")
    end
    return name, maxRange
end

-- nil means the harm flag could not be read, so the slot is skipped.
local function SpellKind(spellID, name, helpful)
    local modern
    if C_Spell then
        if helpful then modern = C_Spell.IsSpellHelpful else modern = C_Spell.IsSpellHarmful end
    end
    if type(modern) == "function" then
        local ok, result = pcall(modern, spellID)
        if ok and not ns.IsSecret(result) then return result and true or false end
        if ok and ns.IsSecret(result) then return nil end
    end
    local classic = IsHarmfulSpell
    if helpful then classic = IsHelpfulSpell end
    if type(classic) == "function" and type(name) == "string" then
        local ok, result = pcall(classic, name)
        if ok and not ns.IsSecret(result) then return result and true or false end
        if ok and ns.IsSecret(result) then return nil end
    end
    if type(modern) ~= "function" and type(classic) ~= "function" then
        ns.Report("range spell", "spell harm check missing")
    end
end

-- Longest matching spell on bar 1. A tie keeps the left slot.
local function BestSlot(helpful)
    if type(GetActionInfo) ~= "function" then
        ns.Report("range spell", "GetActionInfo missing")
        return nil
    end
    local bestSlot, bestRange
    for slot = 1, 12 do
        local spellID = ActionSpell(slot)
        if spellID then
            local name, maxRange = SpellFacts(spellID)
            local matches = maxRange and maxRange > 0 and SpellKind(spellID, name, helpful)
            if matches and (not bestRange or maxRange > bestRange) then
                bestRange = maxRange
                bestSlot = slot
            end
        end
    end
    return bestSlot
end

-- Bar 1 changes rarely, so the chosen spell is cached. Distance is read every frame.
local function CachedSlot(helpful)
    local now = type(GetTime) == "function" and GetTime() or 0
    if rangeSlot.at and rangeSlot.helpful == helpful and now - rangeSlot.at < SLOT_FALLBACK then
        return rangeSlot.slot
    end
    local slot = BestSlot(helpful)
    rangeSlot.helpful = helpful
    rangeSlot.at = now
    rangeSlot.slot = slot
    return slot
end

-- "in", "out", "no", or "hold". A named spell does not have to sit on bar 1.
local function ReadSpellRange(name)
    local fn = C_Spell and C_Spell.IsSpellInRange
    if type(fn) ~= "function" then fn = IsSpellInRange end
    if type(fn) ~= "function" then
        ns.Report("range check", "IsSpellInRange missing")
        return "no"
    end
    local ok, result = pcall(fn, name, "target")
    if not ok then
        ns.Report("range check", result)
        return "no"
    end
    if result == nil then return "no" end
    if ns.IsSecret(result) then return "hold" end
    if result == 1 or result == true then return "in" end
    if result == 0 or result == false then return "out" end
    return "no"
end

-- "in", "out", "no", or "hold". 0 and 1 both mean the spell can be used on this target.
local function ReadActionRange(slot)
    if type(IsActionInRange) ~= "function" then
        ns.Report("range check", "IsActionInRange missing")
        return "no"
    end
    local ok, result = pcall(IsActionInRange, slot)
    if not ok then
        ns.Report("range check", result)
        return "no"
    end
    if result == nil then return "no" end
    if ns.IsSecret(result) then return "hold" end
    if result == 1 or result == true then return "in" end
    if result == 0 or result == false then return "out" end
    return "no"
end

-- "alive", "hide", or "hold".
local function TargetLife()
    if type(UnitExists) ~= "function" then return "hide" end
    local ok, exists = pcall(UnitExists, "target")
    if not ok or ns.IsSecret(exists) then return ok and "hold" or "hide" end
    if not exists then return "hide" end
    local deadFn = type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost
        or (type(UnitIsDead) == "function" and UnitIsDead)
    if not deadFn then return "alive" end
    local deadOk, dead = pcall(deadFn, "target")
    if not deadOk then return "hide" end
    if ns.IsSecret(dead) then return "hold" end
    if dead then return "hide" end
    return "alive"
end

-- "ok", "hide", or "hold". Friendly is reaction 5 and above.
local function FriendlyReaction()
    if type(UnitReaction) ~= "function" then
        ns.Report("range check", "UnitReaction missing")
        return "hide"
    end
    local ok, reaction = pcall(UnitReaction, "player", "target")
    if not ok then return "hide" end
    if ns.IsSecret(reaction) then return "hold" end
    if type(reaction) ~= "number" or reaction < 5 then return "hide" end
    return "ok"
end

-- "show", "hide", or "hold". Automatic bar triggers and Glance suppress the indicator.
local function RangeDecision()
    if type(ns.Range) ~= "function" then return "hide" end
    local yards, kind, spellName = ns.Range()
    if not yards then return "hide" end
    if ns.ShowAll() or ns.Glancing() then return "hide" end
    local life = TargetLife()
    if life ~= "alive" then return life end
    if kind == "friendly" then
        local who = FriendlyReaction()
        if who ~= "ok" then return who end
    end
    local reach
    if spellName then
        reach = ReadSpellRange(spellName)
    else
        local slot = CachedSlot(kind == "friendly")
        if not slot then return "hide" end
        reach = ReadActionRange(slot)
    end
    if reach == "hold" or reach == "no" then return reach == "hold" and "hold" or "hide" end
    if yards == "spell" then return reach == "in" and "show" or "hide" end
    if type(CheckInteractDistance) ~= "function" then
        ns.Report("range distance", "CheckInteractDistance missing")
        return "hide"
    end
    local index = yards == 10 and 2 or 1
    local ok, near = pcall(CheckInteractDistance, "target", index)
    if not ok then
        ns.Report("range distance", near)
        return "hide"
    end
    if ns.IsSecret(near) then return "hold" end
    if near == 1 or near == true then return "show" end
    return "hide"
end

local function EnsureRangeMark()
    if rangeMark then return rangeMark end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    local tex = created:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetColorTexture(1, 1, 1, 1)
    local painted = false
    if type(CreateColor) == "function" and type(tex.SetGradient) == "function" then
        local gradientOk = pcall(tex.SetGradient, tex, "HORIZONTAL",
            CreateColor(0.15, 0.82, 0.22, 0.9),
            CreateColor(0.55, 0.95, 0.4, 0.15))
        painted = gradientOk
    end
    if not painted and type(tex.SetGradientAlpha) == "function" then
        painted = pcall(tex.SetGradientAlpha, tex, "HORIZONTAL", 0.15, 0.82, 0.22, 0.9, 0.55, 0.95, 0.4, 0.15)
    end
    if not painted then
        tex:SetColorTexture(0.2, 0.78, 0.28, 0.75)
    end
    created:EnableMouse(false)
    if type(created.SetMouseClickEnabled) == "function" then
        pcall(created.SetMouseClickEnabled, created, false)
    end
    if type(created.SetMouseMotionEnabled) == "function" then
        pcall(created.SetMouseMotionEnabled, created, false)
    end
    created:SetAlpha(0)
    created._quietAlpha = 0
    created:Hide()
    rangeMark = created
    return created
end

function ns.HideRangeMark()
    if not rangeMark then return end
    rangeMark._quietAlpha = 0
    rangeMark._quietSecret = nil
    rangeMark._quietApplying = true
    rangeMark:SetAlpha(0)
    rangeMark._quietApplying = false
    rangeMark:Hide()
    local parentOk, parent = pcall(rangeMark.GetParent, rangeMark)
    if not parentOk or parent ~= UIParent then
        pcall(rangeMark.SetParent, rangeMark, UIParent)
    end
end

-- The visible bar, when the nameplate root is only the click area.
-- Nameplate GetRect is empty or in world scale, so the gradient is a child of the
-- health bar and is moved back to UIParent when it hides. The plate's alpha is left alone.
local function ShownBox(frame)
    if not ns.Usable(frame) or not frame.IsShown then return nil end
    local shownOk, shown = pcall(frame.IsShown, frame)
    if not shownOk or not shown then return nil end
    return frame
end

-- A health bar is wide and short. The nameplate click area is tall, and that box is what irritates.
local function BarArea(frame)
    if not ShownBox(frame) or not frame.GetWidth or not frame.GetHeight then return nil end
    local widthOk, width = pcall(frame.GetWidth, frame)
    local heightOk, height = pcall(frame.GetHeight, frame)
    if not widthOk or not heightOk then return nil end
    if not PlainNumber(width) or not PlainNumber(height) then return nil end
    if width < 40 or width > 320 or height < 4 or height > 20 then return nil end
    return width * height
end

local function ChildrenOf(frame)
    if not ns.Usable(frame) or not frame.GetChildren then return nil end
    local ok, list = pcall(function() return { frame:GetChildren() } end)
    if ok then return list end
end

local function TightestBar(root)
    local best, bestArea
    local function visit(frame, depth)
        if not frame or depth > 5 then return end
        local area = BarArea(frame)
        if area and (not bestArea or area < bestArea) then
            best, bestArea = frame, area
        end
        local list = ChildrenOf(frame)
        if not list then return end
        for i = 1, #list do
            visit(list[i], depth + 1)
        end
    end
    visit(root, 0)
    return best
end

function ns.ForgetRangeSlot()
    rangeSlot.at = nil
end

-- The last found bar, kept while the target keeps the same plate.
local cachedPlate, cachedUnit, cachedBar

function ns.ForgetRangePlate()
    cachedPlate, cachedUnit, cachedBar = nil, nil, nil
end

local function PlateUnit(plate)
    return plate.UnitFrame or plate.unitFrame or plate
end

local function TargetPlate()
    local finder = C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if type(finder) ~= "function" then finder = GetNamePlateForUnit end
    if type(finder) ~= "function" then
        ns.Report("range nameplate", "GetNamePlateForUnit missing")
        return nil
    end
    local ok, plate = pcall(finder, "target")
    if not ok or not ns.Usable(plate) then return nil end
    if cachedBar and cachedPlate == plate and ShownBox(cachedUnit) and ShownBox(cachedBar) then
        return cachedBar, plate
    end
    cachedPlate, cachedUnit, cachedBar = nil, nil, nil
    local unitOk, unit = pcall(PlateUnit, plate)
    if not unitOk or not ShownBox(unit) then return nil end
    local namedOk, named = pcall(function()
        return unit.healthBar or unit.HealthBar or unit.HealthBarsContainer
    end)
    local bar
    if namedOk and named then
        if BarArea(named) then
            bar = named
        else
            bar = TightestBar(named)
        end
    end
    bar = bar or TightestBar(unit)
    if not bar then return nil end
    cachedPlate, cachedUnit, cachedBar = plate, unit, bar
    return bar, plate
end

-- true when placed, false when the nameplate is gone.
-- The gradient fills the health bar. Parenting to the plate would cover the name too.
local function PlaceRangeMark(mark)
    local bar = TargetPlate()
    if not bar then return false end
    local parentOk, parent = pcall(mark.GetParent, mark)
    if parentOk and parent == bar then return true end
    local moved = pcall(function()
        mark:SetParent(bar)
        mark:ClearAllPoints()
        mark:SetAllPoints(bar)
        if mark.SetIgnoreParentAlpha then mark:SetIgnoreParentAlpha(true) end
    end)
    if not moved then
        ns.Report("range nameplate", "could not anchor to the nameplate")
        return false
    end
    local levelOk, level = pcall(bar.GetFrameLevel, bar)
    if not levelOk or not PlainNumber(level) then level = 1 end
    pcall(mark.SetFrameLevel, mark, level + 20)
    return true
end

function ns.UpdateRange(elapsed)
    local state = RangeDecision()
    if state == "hold" then return end
    if state ~= "show" then
        if not rangeMark or not rangeMark:IsShown() then return end
        local placed = PlaceRangeMark(rangeMark)
        if not placed then
            ns.HideRangeMark()
            return
        end
        ns.EaseAlpha(rangeMark, false, elapsed)
        if rangeMark._quietAlpha == 0 then ns.HideRangeMark() end
        return
    end
    local mark = EnsureRangeMark()
    if not mark then return end
    local placed = PlaceRangeMark(mark)
    if not placed then
        ns.HideRangeMark()
        return
    end
    if not mark:IsShown() then
        mark._quietApplying = true
        mark:SetAlpha(0)
        mark._quietApplying = false
        mark._quietAlpha = 0
        mark:Show()
    end
    ns.EaseAlpha(mark, true, elapsed)
end

local function UpdateVisible(name, frames, usual, noHover, exception, glance, elapsed)
    local hovered = HoverFrames(name, frames)
    if ns.OnlyOnHover(name) then
        UpdateGroup(frames, ns.InEditMode() or glance or exception or hovered, elapsed)
    else
        UpdateGroup(frames, usual or ns.Pinned(name) or glance, elapsed, noHover)
    end
end

function ns.UpdateFaders(elapsed)
    local glance = ns.Glancing()
    Run("xp bar", UpdateVisible, "xp", statusFrames, XPShouldShow(), false, ns.XPForced(), glance, elapsed)
    Run("cooldown manager", UpdateVisible, "cooldowns", cooldownFrames, CooldownsShouldShow(), true, nil,
        glance, elapsed)
    Run("damage meter", UpdateVisible, "meter", meterFrames, MeterShouldShow(), true, nil, glance, elapsed)
    Run("quest catcher", PlaceQuestCatcher)
    local questHot = questCatcher and ns.Hit(questCatcher)
    Run("quest tracker", UpdateGroup, questFrames, ns.VisibilityShow("quests", false, questHot), elapsed)
end
