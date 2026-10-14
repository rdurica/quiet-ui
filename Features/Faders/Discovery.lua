local _, ns = ...

-- Non-bar frames that fade: XP bar, cooldown manager, personal resource bar,
-- damage meter, the player frame, the pet frame, the quest tracker, buffs,
-- and the range gradient on the target nameplate.
--
-- Faders.state is private to this feature: the frame lists, the per-frame sampling
-- (UpdateSmooth) and the curve caches. Files here call each other through Faders.

local Faders = {}
ns.Faders = Faders

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

local state = {
    -- Frame lists, filled in place by Find.
    statusFrames = {},
    cooldownFrames = {},
    resourceFrames = {},
    questFrames = {},
    auraFrames = {},
    meterFrames = {},
    partyActive = false,
    -- Smooth weights and the per-frame samples UpdateSmooth resets.
    playerWeight = 0,
    playerCurved = false,
    auraWeight = 0,
    aurasCurved = false,
    resourceWeight = 0,
    samplingPower = false,
    thresholdRead = false,
    powerWeights = {},
    powerAlphas = {},
    powerSampleCount = 0,
    thresholdWeights = {},
    thresholdAlphas = {},
    thresholdSampleCount = 0,
    -- Curve caches.
    curveCache = {},
    thresholdCurves = {},
}
Faders.state = state

local statusFrames = state.statusFrames
local cooldownFrames = state.cooldownFrames
local resourceFrames = state.resourceFrames
local questFrames = state.questFrames
local auraFrames = state.auraFrames
local powerWeights, powerAlphas = state.powerWeights, state.powerAlphas
local thresholdAlphas = state.thresholdAlphas

function Faders.IsFadeable(frame)
    return ns.Usable(frame) and frame.SetAlpha and frame.IsShown and true or false
end

function Faders.FindNamed(list, names)
    for i = #list, 1, -1 do
        list[i] = nil
    end
    for _, name in ipairs(names) do
        local frame = _G[name]
        if Faders.IsFadeable(frame) then
            list[#list + 1] = frame
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

function Faders.KidsOf(frame)
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

function Faders.Find(deep)
    Faders.FindNamed(statusFrames, STATUS_NAMES)
    Faders.FindNamed(cooldownFrames, COOLDOWN_NAMES)
    Faders.FindNamed(resourceFrames, RESOURCE_NAMES)
    Faders.FindNamed(questFrames, QUEST_NAMES)
    Faders.FindNamed(auraFrames, AURA_NAMES)
    RefreshKids(resourceFrames)
    RefreshKids(auraFrames)
    Faders.FindMeters(deep)
    local active = ns.Settings.AutoHideParty and ns.Settings.AutoHideParty() or false
    if active and (deep or not state.partyActive or Faders.PartyChanged()) then
        Faders.FindParty()
    end
    state.partyActive = active
end

-- Catch hover even when Blizzard's container is not mouse-enabled.
local hoverCatchers = {}

function Faders.ParkHover(name)
    local catchers = hoverCatchers[name]
    if not catchers or catchers.parked then return end
    for i = 1, #catchers do
        local box = catchers[i]
        if box:IsShown() then box:Hide() end
    end
    catchers.parked = true
end

function Faders.HoverFrames(name, frames, active)
    local catchers = hoverCatchers[name]
    if not catchers then catchers = {}; hoverCatchers[name] = catchers end
    if active == nil then active = ns.Settings.OnlyOnHover(name) end
    if not active then
        Faders.ParkHover(name)
        return false
    end
    catchers.parked = nil
    local hovered = false
    for i, target in ipairs(frames) do
        local box = catchers[i]
        if ns.DB().enabled and not ns.World.InEditMode()
            and ns.Usable(target) and target:IsShown() then
            if not box then
                box = ns.Catcher.Create()
                if box then catchers[i] = box end
            end
            if box then
                if box._quietHoverTarget ~= target then
                    box:ClearAllPoints()
                    box:SetAllPoints(target)
                    box._quietHoverTarget = target
                end
                ns.Catcher.Strata(box, target)
                local level = target.GetFrameLevel and target:GetFrameLevel() or 1
                if type(level) ~= "number" or ns.IsSecret(level) then level = 1 end
                ns.Catcher.Level(box, math.max(0, level - 1))
                if not box:IsShown() then box:Show() end
                if ns.Hit(box) then hovered = true end
            end
            if ns.Hit(target) then hovered = true end
        elseif box then box:Hide() end
    end
    for i = #frames + 1, #catchers do catchers[i]:Hide() end
    return hovered
end

function Faders.HideHoverCatchers()
    for _, catchers in pairs(hoverCatchers) do
        for _, box in ipairs(catchers) do box:Hide() end
    end
end

-- A group shows together when any shown member is hovered.
function Faders.UpdateGroup(frames, show, elapsed, noHover)
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
function Faders.Under(frame, ancestor)
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

function Faders.PaintNumeric(frame, show, elapsed)
    if not (Faders.IsFadeable(frame) and frame:IsShown()) then return end
    ns.EaseAlpha(frame, show, elapsed)
end

function Faders.HoldResult(frame, alpha)
    if type(alpha) == "number" and not ns.IsSecret(alpha) then
        ns.HoldAlpha(frame, alpha)
    else
        ns.HoldSecretAlpha(frame, alpha)
    end
end

function Faders.PaintSecret(frame, alpha)
    if not (Faders.IsFadeable(frame) and frame:IsShown()) or alpha == nil then return end
    Faders.HoldResult(frame, alpha)
end

function Faders.UpdateSmooth(elapsed, profile)
    state.samplingPower = false
    state.sampledPlayerShow, state.sampledPlayerThresholds, state.sampledPlayerStyle = nil, nil, nil
    state.thresholdRead = false
    local ok, kind = pcall(Faders.ReadRestingPower)
    state.sampledKind = ok and kind or nil
    if not ok then ns.Report("player power", kind) end
    for i = 1, state.powerSampleCount do powerAlphas[i] = nil end
    state.powerSampleCount = 0
    for i = 1, state.thresholdSampleCount do thresholdAlphas[i] = nil end
    state.thresholdSampleCount = 0
    state.samplingPower = true
    local run = profile or ns.Run
    run("resource bar", Faders.UpdateResource, elapsed)
    run("player frame", Faders.UpdatePlayer, elapsed)
    run("party frames", Faders.UpdateParty, elapsed)
    run("buffs", Faders.UpdateAuras, elapsed)
    state.samplingPower = false
end
