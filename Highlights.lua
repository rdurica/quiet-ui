local _, ns = ...

local GLOW = "Interface\\AddOns\\QuietUI\\Media\\glow.tga"
local GLINT = "Interface\\AddOns\\QuietUI\\Media\\glint.tga"
local SPARK = "Interface\\AddOns\\QuietUI\\Media\\spark.tga"
-- The soft-target icon floats above the object; the plate gives no world position,
-- so the glow drops by a fixed offset measured in game.
local ANCHOR = { point = "CENTER", relative = "CENTER", x = 0, y = -90 }
local CVARS = { "SoftTargetInteract", "SoftTargetInteractRange", "SoftTargetNameplateInteract",
    "SoftTargetIconGameObject", "SoftTargetInteractArc", "SoftTargetIconInteract" }
local WANT = { SoftTargetInteract = "3", SoftTargetInteractRange = "15", SoftTargetNameplateInteract = "1",
    SoftTargetIconGameObject = "1", SoftTargetInteractArc = "2", SoftTargetIconInteract = "1" }
local BLOCKED = { party = true, raid = true, pvp = true, arena = true }
local GLOW_STRENGTH = { herb = 0.55, ore = 0.8, quest = 0.64 }
local COLORS = {
    herb = { 0.30, 0.74, 0.40 },
    ore = { 0.95, 0.75, 0.25 },
    quest = { 0.78, 0.76, 0.70 },
}
-- Lower-case substrings of the soft-target icon texture. Out-of-reach herbs use
-- "UnableGatherHerbs", which still contains the herb pattern.
local PATTERNS = {
    herb = { "gatherherbs" },
    ore = { "crosshair_mine", "crosshair_unablemine" },
    -- Keep the legacy quest setting key for saved characters and presets.
    quest = { "crosshair_interact_64", "crosshair_unableinteract_64" },
}
local ORDER = { "herb", "ore", "quest" }
local SPARKS = 7

local root, textures, loops = nil, {}, {}
local glowTextures = {}
local targetGUID, anchorToken, hiddenIcon
local recheckToken = 0
local fighting, stopped = false, false

local function Secret(value)
    return ns.IsSecret and ns.IsSecret(value)
end

local function Try(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, obj, ...)
    if ok then return a, b end
end

local function InCombat()
    if fighting then return true end
    local ok, combat = pcall(InCombatLockdown)
    return ok and combat == true
end

local function InBlockedInstance()
    if type(IsInInstance) ~= "function" then return false end
    local ok, _, kind = pcall(IsInInstance)
    return ok and not Secret(kind) and BLOCKED[kind] == true
end

local function Flags()
    local flags = type(ns.Highlights) == "function" and ns.Highlights()
    return type(flags) == "table" and flags or {}
end

local function Active()
    if stopped then return false end
    local db = ns.DB and ns.DB()
    if not (db and db.enabled) then return false end
    local flags = Flags()
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
    if ok and value ~= nil and not Secret(value) then return tostring(value) end
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
    if type(targetGUID) == "string" and targetGUID:find("^GameObject") then return WANT[name] end
    if name == "SoftTargetNameplateInteract" then return tostring(originals[name]) end
    if name == "SoftTargetIconInteract" then
        -- Keep the player's icon only if they already used soft interact themselves.
        if tostring(originals.SoftTargetInteract) == "0" then return "0" end
        return tostring(originals[name])
    end
    return WANT[name]
end

-- CVars change only out of combat; REGEN_ENABLED calls this again with the current state.
local function SyncCVars()
    if InCombat() then return end
    local api = CVarApi()
    if not api then return end
    local db = QuietUIDB
    if type(db) ~= "table" then return end
    if Active() then
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

-- Glow --------------------------------------------------------------------------------

local function Loop(owner, looping)
    local group = Try(owner, "CreateAnimationGroup")
    if type(group) ~= "table" then
        ns.Report("highlights animations", "Animations are not available on this client.")
        return
    end
    Try(group, "SetLooping", looping)
    loops[#loops + 1] = group
    return group
end

local function Animation(group, kind, duration, delay)
    local anim = group and Try(group, "CreateAnimation", kind)
    if type(anim) ~= "table" then return end
    Try(anim, "SetDuration", duration)
    if delay then Try(anim, "SetStartDelay", delay) end
    return anim
end

local function Texture(path, width, height, layer)
    local tex = Try(root, "CreateTexture", nil, layer or "ARTWORK")
    if type(tex) ~= "table" then return end
    Try(tex, "SetTexture", path)
    Try(tex, "SetBlendMode", "ADD")
    Try(tex, "SetSize", width, height)
    textures[#textures + 1] = tex
    if path == GLOW then glowTextures[#glowTextures + 1] = tex end
    return tex
end

-- All recognized categories share the same glow and rising particles.
local function Build()
    if root then return root end
    if type(CreateFrame) ~= "function" then return end
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or type(frame) ~= "table" then
        ns.Report("highlights", frame)
        return
    end
    root = frame
    root:Hide()
    Try(root, "EnableMouse", false)
    Try(root, "SetSize", 64, 64)

    -- A soft cloud behind the object, with a quieter outer halo.
    local halo = Texture(GLOW, 104, 90, "BACKGROUND")
    if halo then
        Try(halo, "SetPoint", "CENTER", root, "CENTER")
        local pulse = Loop(halo, "BOUNCE")
        local fade = Animation(pulse, "Alpha", 1.2)
        Try(fade, "SetFromAlpha", 0.14)
        Try(fade, "SetToAlpha", 0.26)
    end

    local aura = Texture(GLOW, 78, 70, "BORDER")
    if aura then
        Try(aura, "SetPoint", "CENTER", root, "CENTER")
        local pulse = Loop(aura, "BOUNCE")
        local fade = Animation(pulse, "Alpha", 1.2)
        Try(fade, "SetFromAlpha", 0.38)
        Try(fade, "SetToAlpha", 0.64)
        local grow = Animation(pulse, "Scale", 1.2)
        Try(grow, "SetScaleFrom", 0.96, 0.96)
        Try(grow, "SetScaleTo", 1.04, 1.04)
    end

    for i = 1, SPARKS do
        local star = i % 2 == 0
        local width = star and (12 + i) or 5
        local spark = Texture(star and GLINT or SPARK, width, star and width * 1.2 or 5)
        if spark then
            -- Mix three four-point glints with small motes around the object.
            local angle = (i - 1) / SPARKS * 2 * math.pi
            local reach = star and 0.65 or 0.95
            Try(spark, "SetPoint", "CENTER", root, "CENTER", math.cos(angle) * 32 * reach,
                14 + math.sin(angle) * 20 * reach)
            Try(spark, "SetAlpha", 0)
            local rise = Loop(spark, "REPEAT")
            local delay = (i - 1) * 0.27
            local duration = 3.2 + i * 0.08
            local peak = star and 0.85 or 0.45
            local move = Animation(rise, "Translation", duration, delay)
            Try(move, "SetOffset", 0, star and 28 or 34)
            Try(move, "SetOrder", 1)
            local fadeIn = Animation(rise, "Alpha", 0.4, delay)
            Try(fadeIn, "SetFromAlpha", 0)
            Try(fadeIn, "SetToAlpha", peak)
            Try(fadeIn, "SetOrder", 1)
            local fadeOut = Animation(rise, "Alpha", duration - 0.4, delay + 0.4)
            Try(fadeOut, "SetFromAlpha", peak)
            Try(fadeOut, "SetToAlpha", 0)
            Try(fadeOut, "SetOrder", 1)
        end
    end
    return root
end

local function RestoreIcon()
    if not hiddenIcon then return end
    ns.ReleaseAlpha(hiddenIcon, true)
    hiddenIcon = nil
end

local function HideIcon(icon)
    if hiddenIcon ~= icon then RestoreIcon() end
    if not ns.Usable(icon) then return end
    -- Keep the texture readable for category detection while hiding only its artwork.
    ns.HoldAlpha(icon, 0)
    hiddenIcon = icon
end

local function HideGlow()
    anchorToken = nil
    if not root then return end
    for _, group in ipairs(loops) do Try(group, "Stop") end
    root:Hide()
    Try(root, "ClearAllPoints")
    Try(root, "SetParent", UIParent)
end

local function HideNow()
    RestoreIcon()
    HideGlow()
end

local function ShowOn(plate, soft, token, kind)
    if not Build() then return end
    local color = COLORS[kind]
    local glowY = kind == "ore" and 0 or 8
    for i, tex in ipairs(glowTextures) do
        local width = i == 1 and 104 or 78
        Try(tex, "SetWidth", width * (kind == "quest" and 0.8 or 1))
        Try(tex, "ClearAllPoints")
        Try(tex, "SetPoint", "CENTER", root, "CENTER", 0, glowY)
    end
    Try(root, "SetParent", plate)
    Try(root, "ClearAllPoints")
    Try(root, "SetPoint", ANCHOR.point, soft, ANCHOR.relative, ANCHOR.x, ANCHOR.y)
    local level = Try(soft, "GetFrameLevel")
    if type(level) == "number" and not Secret(level) then
        Try(root, "SetFrameLevel", math.max(0, level - 1))
    end
    for _, tex in ipairs(textures) do Try(tex, "SetVertexColor", color[1], color[2], color[3]) end
    local strength = GLOW_STRENGTH[kind]
    for _, tex in ipairs(glowTextures) do
        Try(tex, "SetVertexColor", color[1] * strength, color[2] * strength, color[3] * strength)
    end
    Try(root, "SetAlpha", 1)
    -- Play again only after HideNow stopped the loops, so re-checks do not restart the pulse.
    local wasShown = Try(root, "IsShown")
    root:Show()
    if not wasShown then
        for _, group in ipairs(loops) do Try(group, "Play") end
    end
    anchorToken = token
end

-- Nameplates --------------------------------------------------------------------------

local function SameGUID(token, guid)
    if type(token) ~= "string" or type(UnitGUID) ~= "function" then return false end
    local ok, value = pcall(UnitGUID, token)
    return ok and not Secret(value) and value ~= nil and value == guid
end

local function PlateApi()
    if type(C_NamePlate) == "table" then return C_NamePlate end
    ns.Report("highlights nameplates", "Nameplates are not available on this client.")
end

local function PlateToken(plate)
    local unitFrame = plate.UnitFrame
    local token = type(unitFrame) == "table" and unitFrame.unit
    if type(token) == "string" then return token end
    token = plate.namePlateUnitToken
    if type(token) == "string" then return token end
end

local function FindPlate(guid)
    local api = PlateApi()
    if not api or type(api.GetNamePlates) ~= "function" then return end
    local ok, plates = pcall(api.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        if ns.Usable(plate) then
            local token = PlateToken(plate)
            if SameGUID(token, guid) then return plate, token end
        end
    end
end

local function IconTexture(soft)
    local icon = soft.Icon
    if type(icon) ~= "table" then return end
    local texture = Try(icon, "GetTexture")
    if Secret(texture) or type(texture) ~= "string" or texture == "" then
        texture = Try(icon, "GetAtlas")
    end
    if Secret(texture) or type(texture) ~= "string" or texture == "" then return end
    return texture:lower()
end

local function Category(texture)
    if not texture then return end
    local flags = Flags()
    for _, kind in ipairs(ORDER) do
        if flags[kind] then
            for _, pattern in ipairs(PATTERNS[kind]) do
                if texture:find(pattern, 1, true) then return kind end
            end
        end
    end
end

-- True when the icon shows only because QuietUI turned it on; the saved originals tell.
local function OwnIcon(guid)
    local saved = type(QuietUIDB) == "table" and QuietUIDB.highlightCVars
    if type(saved) ~= "table" then return false end
    if tostring(saved.SoftTargetIconInteract) == "0" then return true end
    return guid:find("^GameObject") ~= nil and tostring(saved.SoftTargetIconGameObject) == "0"
end

-- Reads the icon of plate (or the scanned target plate) and shows or hides the glow.
local function Evaluate(plate, token)
    if not Active() or not targetGUID then return HideNow() end
    if not plate then plate, token = FindPlate(targetGUID) end
    if not ns.Usable(plate) then return HideNow() end
    local unitFrame = plate.UnitFrame
    local soft = type(unitFrame) == "table" and unitFrame.SoftTargetFrame
    if type(soft) ~= "table" or not ns.Usable(soft) then
        ns.Report("highlights soft target", "The soft target icon is not available on this client.")
        return HideNow()
    end
    local kind = Category(IconTexture(soft))
    if not kind then
        -- An unchecked category keeps the player's original choice of no icon.
        if not OwnIcon(targetGUID) then return HideNow() end
        HideGlow()
        HideIcon(soft.Icon)
        anchorToken = token
        return
    end
    HideIcon(soft.Icon)
    ShowOn(plate, soft, token, kind)
end

local function ReadTarget(newGUID)
    local guid = newGUID
    if guid == nil and type(UnitGUID) == "function" then
        local ok, value = pcall(UnitGUID, "softinteract")
        if ok then guid = value end
    end
    if Secret(guid) or type(guid) ~= "string" or guid == "" then return end
    return guid
end

-- The icon texture may be set a frame after the event, so look once more on the next frame.
-- A newer event or a restore invalidates the older check.
local function Recheck()
    recheckToken = recheckToken + 1
    if not targetGUID then return end
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return end
    local token = recheckToken
    pcall(C_Timer.After, 0, function()
        if token == recheckToken then Evaluate() end
    end)
end

local function PlateAdded(token)
    if not targetGUID or not Active() then return end
    local api = PlateApi()
    if not SameGUID(token, targetGUID) then return end
    local get = api and api.GetNamePlateForUnit or GetNamePlateForUnit
    if type(get) ~= "function" then return end
    local ok, plate = pcall(get, token)
    if ok and ns.Usable(plate) then
        Evaluate(plate, token)
        Recheck()
    end
end

-- Public ------------------------------------------------------------------------------

function ns.ApplyHighlights()
    stopped = false
    -- No events arrive while off, so the remembered target may be stale.
    if Active() then targetGUID = ReadTarget() end
    SyncCVars()
    Evaluate()
end

function ns.RestoreHighlights()
    stopped = true
    targetGUID = nil
    recheckToken = recheckToken + 1
    HideNow()
    SyncCVars()
end

function ns.HighlightsEvent(event, ...)
    if event == "PLAYER_SOFT_INTERACT_CHANGED" then
        local _, newGUID = ...
        targetGUID = ReadTarget(newGUID)
        SyncCVars()
        Evaluate()
        Recheck()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        PlateAdded((...))
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local token = ...
        if anchorToken and token == anchorToken then HideNow() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        fighting = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        fighting = false
        SyncCVars()
        Evaluate()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        SyncCVars()
        Evaluate()
    end
end
