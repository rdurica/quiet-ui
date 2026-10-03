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

function ns.FindFaders(deep)
    FindNamed(statusFrames, STATUS_NAMES)
    FindNamed(cooldownFrames, COOLDOWN_NAMES)
    FindNamed(resourceFrames, RESOURCE_NAMES)
    FindNamed(questFrames, QUEST_NAMES)
    FindNamed(auraFrames, AURA_NAMES)
    for i = 1, #resourceFrames do
        resourceFrames[i]._quietKids = nil
    end
    for i = 1, #auraFrames do
        auraFrames[i]._quietKids = nil
    end
    FindMeters(deep)
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
    if ns.OnlyOnHover("xp") then return false end
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
local function HoverFrames(name, frames)
    local catchers = hoverCatchers[name]
    if not catchers then catchers = {}; hoverCatchers[name] = catchers end
    local hovered = false
    for i, target in ipairs(frames) do
        local box = catchers[i]
        if ns.OnlyOnHover(name) and ns.DB().enabled and not ns.InEditMode()
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
                if type(strata) == "string" and not ns.IsSecret(strata) then box:SetFrameStrata(strata) end
                local level = target:GetFrameLevel()
                if type(level) ~= "number" or ns.IsSecret(level) then level = 1 end
                box:SetFrameLevel(math.max(0, level - 1))
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
    if not frame or not frame.GetParent or not ancestor then return false end
    local parent = frame:GetParent()
    local depth = 0
    while parent and depth < 6 do
        if parent == ancestor then return true end
        if not parent.GetParent then return false end
        parent = parent:GetParent()
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
local auraWeight = 0
local aurasCurved = false
local resourceWeight = 0
local samplingPower = false
local sampledKind
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

-- Boolean show for the portrait. Low power stays on the curve below.
-- Edit mode shows it even when the player frame is off.
local function PlayerShouldShow()
    if ns.InEditMode() then return true end
    if DeadTargetBlocked() then return false end
    if ns.PlayerStyle() ~= "classic" then return false end
    return ns.Glancing()
        or ns.Hit(PlayerFrame)
        or ns.Hit(PetFrame)
        or ns.InCombat()
        or ns.InForcedInstance()
        or ns.InGroup()
        or ns.InVehicle()
        or ns.HasTarget()
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
        curve = MakeCurve(BlendPoints(rest, forced, t))
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
    HoverFrames("resource", resourceFrames)
    local show = ResourceForced() and true or false
    resourceWeight = NextWeight(resourceWeight, show, elapsed)
    local powerAlpha = EvalPower(resourceWeight)
    local healthAlpha = EvalHealth(resourceWeight)
    for _, frame in ipairs(resourceFrames) do
        PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    end
end

local function UpdatePlayer(elapsed)
    local show = PlayerShouldShow() and true or false
    local blocked = DeadTargetBlocked()
    local useCurve = not blocked and ns.PlayerStyle() == "classic" and RestingPower() ~= nil
    playerCurved, playerWeight = TakeWeight(playerCurved, playerWeight, show, elapsed, useCurve)
    local alpha = useCurve and EvalPower(playerWeight) or nil
    local player = PlayerFrame
    local pet = PetFrame
    local target = TargetFrame
    if IsFadeable(target) then
        if blocked then
            ns.EaseAlpha(target, false, elapsed)
        elseif target._quietAlpha ~= nil or target._quietSecret ~= nil then
            ns.ReleaseAlpha(target)
        end
    end
    if alpha ~= nil then
        PaintSecret(player, alpha)
        if not Under(pet, player) then PaintSecret(pet, alpha) end
    else
        PaintNumeric(player, show, elapsed)
        if not Under(pet, player) then PaintNumeric(pet, show, elapsed) end
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

local function AurasShouldShow()
    if ns.OnlyOnHover("auras") then
        local hovered = false
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then hovered = true; break end
        end
        return ns.VisibilityShow("auras", false, hovered)
    end
    local show = ns.InCombat() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
        or ns.Pinned("auras") or ns.Glancing()
    if not show then
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then
                show = true
                break
            end
        end
    end
    if not show and ns.GroupAuras() and PlayerShouldShow() then
        show = true
    end
    return show
end

local function UpdateAuras(elapsed)
    local show = AurasShouldShow() and true or false
    local useCurve = not ns.OnlyOnHover("auras") and ns.GroupAuras() and ns.PlayerStyle() == "classic" and RestingPower() ~= nil
    aurasCurved, auraWeight = TakeWeight(aurasCurved, auraWeight, show, elapsed, useCurve)
    local alpha = useCurve and EvalPower(auraWeight) or nil
    local keepDebuffs = not ns.OnlyOnHover("auras") and ns.AlwaysShowDebuffs()
    for _, frame in ipairs(auraFrames) do
        if keepDebuffs and frame == _G.DebuffFrame then
            PaintNumeric(frame, true, elapsed)
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
    end
    local strata = target.GetFrameStrata and target:GetFrameStrata()
    if type(strata) == "string" then
        box:SetFrameStrata(strata)
    end
    local level = target.GetFrameLevel and target:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    box:SetFrameLevel(math.max(level - 1, 0))
    if not box:IsShown() then box:Show() end
end

function ns.HideQuestCatcher()
    if not questCatcher then return end
    questCatcher:Hide()
    questCatcherTarget = nil
end

function ns.UpdateSmooth(elapsed)
    samplingPower = false
    local ok, kind = pcall(ReadRestingPower)
    sampledKind = ok and kind or nil
    if not ok then ns.Report("player power", kind) end
    for i = 1, powerSampleCount do powerAlphas[i] = nil end
    powerSampleCount = 0
    samplingPower = true
    Run("resource bar", UpdateResource, elapsed)
    Run("player frame", UpdatePlayer, elapsed)
    Run("buffs", UpdateAuras, elapsed)
    samplingPower = false
end

-- A green gradient over the target nameplate health bar. A flat tint turns the red bar grey. Secret results are left as they were.
-- Strong on the left, fading out to the right, so the health bar still reads.
local rangeMark
local rangeSlot = { at = -1, helpful = nil, slot = nil }

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
    if rangeSlot.helpful == helpful and now - rangeSlot.at < 0.25 then
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

-- "show", "hide", or "hold". Bars that are already up draw their own range, so this stays quiet.
local function RangeDecision()
    if type(ns.Range) ~= "function" then return "hide" end
    local yards, kind, spellName = ns.Range()
    if not yards then return "hide" end
    if ns.ShowAll() or ns.Glancing() or (ns.AnyBarsAlwaysVisible and ns.AnyBarsAlwaysVisible()) then return "hide" end
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

local function TargetPlate()
    local finder = C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if type(finder) ~= "function" then finder = GetNamePlateForUnit end
    if type(finder) ~= "function" then
        ns.Report("range nameplate", "GetNamePlateForUnit missing")
        return nil
    end
    local ok, plate = pcall(finder, "target")
    if not ok or not ns.Usable(plate) then return nil end
    local unitOk, unit = pcall(function() return plate.UnitFrame or plate.unitFrame or plate end)
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

function ns.UpdateFaders(elapsed)
    local glance = ns.Glancing()
    local function UpdateVisible(name, frames, usual, noHover, exception)
        local hovered = HoverFrames(name, frames)
        if ns.OnlyOnHover(name) then
            UpdateGroup(frames, ns.InEditMode() or exception or hovered, elapsed)
        else
            UpdateGroup(frames, usual or ns.Pinned(name) or glance, elapsed, noHover)
        end
    end
    Run("xp bar", UpdateVisible, "xp", statusFrames, XPShouldShow(), false, ns.XPForced())
    Run("cooldown manager", UpdateVisible, "cooldowns", cooldownFrames, CooldownsShouldShow(), true)
    Run("damage meter", UpdateVisible, "meter", meterFrames, MeterShouldShow(), true)
    Run("quest catcher", PlaceQuestCatcher)
    local questHot = questCatcher and ns.Hit(questCatcher)
    Run("quest tracker", UpdateGroup, questFrames, ns.VisibilityShow("quests", false, questHot), elapsed)
end
