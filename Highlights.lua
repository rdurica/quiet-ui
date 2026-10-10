local _, ns = ...

local GLOW = "Interface\\AddOns\\QuietUI\\Media\\glow.tga"
local SPARK = "Interface\\AddOns\\QuietUI\\Media\\spark.tga"
-- Where the glow sits on the SoftTargetFrame; tune the offset here.
local ANCHOR = { point = "CENTER", relative = "CENTER", x = 0, y = 0 }
local CVARS = { "SoftTargetInteract", "SoftTargetInteractRange", "SoftTargetNameplateInteract",
    "SoftTargetIconGameObject" }
local WANT = { SoftTargetInteract = "3", SoftTargetInteractRange = "15", SoftTargetNameplateInteract = "1",
    SoftTargetIconGameObject = "1" }
local BLOCKED = { party = true, raid = true, pvp = true, arena = true }
local COLORS = {
    herb = { 0.35, 0.95, 0.45 },
    ore = { 0.95, 0.75, 0.25 },
    quest = { 1, 0.97, 0.9 },
}
-- Lower-case substrings of the soft-target icon texture. Out-of-reach herbs use
-- "UnableGatherHerbs", which still contains the herb pattern.
local PATTERNS = {
    herb = { "gatherherbs" },
    ore = { "mine" },
    -- The quest object icon texture has not been verified in game yet.
    quest = {},
}
local ORDER = { "herb", "ore", "quest" }
local SPARKS = 7

local root, textures, loops = nil, {}, {}
local targetGUID, anchorToken
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
    if ReadCVar(api, name) == value then return end
    local ok, err = pcall(api.SetCVar, name, value)
    if not ok then ns.Report("highlights", err) end
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
            if db.highlightCVars[name] ~= nil then WriteCVar(api, name, WANT[name]) end
        end
    elseif type(db.highlightCVars) == "table" then
        for _, name in ipairs(CVARS) do
            local value = db.highlightCVars[name]
            if value ~= nil then WriteCVar(api, name, tostring(value)) end
        end
        db.highlightCVars = nil
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
    return tex
end

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

    -- A wide, faint halo under an elliptical ground glow.
    local halo = Texture(GLOW, 150, 76, "BACKGROUND")
    if halo then
        Try(halo, "SetPoint", "CENTER", root, "CENTER")
        local pulse = Loop(halo, "BOUNCE")
        local fade = Animation(pulse, "Alpha", 1.2)
        Try(fade, "SetFromAlpha", 0.2)
        Try(fade, "SetToAlpha", 0.4)
    end

    local aura = Texture(GLOW, 96, 48, "BORDER")
    if aura then
        Try(aura, "SetPoint", "CENTER", root, "CENTER")
        local pulse = Loop(aura, "BOUNCE")
        local fade = Animation(pulse, "Alpha", 0.8)
        Try(fade, "SetFromAlpha", 0.5)
        Try(fade, "SetToAlpha", 0.95)
        local grow = Animation(pulse, "Scale", 0.8)
        Try(grow, "SetScaleFrom", 0.9, 0.9)
        Try(grow, "SetScaleTo", 1.1, 1.1)
    end

    for i = 1, SPARKS do
        local spark = Texture(SPARK, 7, 7)
        if spark then
            -- Spread across the ellipse, alternating near and far from the center.
            local angle = (i - 1) / SPARKS * 2 * math.pi
            local reach = (i % 2 == 0) and 0.45 or 0.85
            Try(spark, "SetPoint", "CENTER", root, "CENTER", math.cos(angle) * 40 * reach,
                math.sin(angle) * 14 * reach)
            Try(spark, "SetAlpha", 0)
            local rise = Loop(spark, "REPEAT")
            local delay = (i - 1) * 0.19
            local move = Animation(rise, "Translation", 1.4, delay)
            Try(move, "SetOffset", 0, 30)
            local fadeIn = Animation(rise, "Alpha", 0.2, delay)
            Try(fadeIn, "SetFromAlpha", 0)
            Try(fadeIn, "SetToAlpha", 1)
            Try(fadeIn, "SetOrder", 1)
            local fadeOut = Animation(rise, "Alpha", 1.2, delay + 0.2)
            Try(fadeOut, "SetFromAlpha", 1)
            Try(fadeOut, "SetToAlpha", 0)
        end
    end
    return root
end

local function HideNow()
    anchorToken = nil
    if not root then return end
    for _, group in ipairs(loops) do Try(group, "Stop") end
    root:Hide()
    Try(root, "ClearAllPoints")
    Try(root, "SetParent", UIParent)
end

local function ShowOn(plate, soft, token, color)
    if not Build() then return end
    Try(root, "SetParent", plate)
    Try(root, "ClearAllPoints")
    Try(root, "SetPoint", ANCHOR.point, soft, ANCHOR.relative, ANCHOR.x, ANCHOR.y)
    local level = Try(soft, "GetFrameLevel")
    if type(level) == "number" and not Secret(level) then
        Try(root, "SetFrameLevel", math.max(0, level - 1))
    end
    for _, tex in ipairs(textures) do Try(tex, "SetVertexColor", color[1], color[2], color[3]) end
    Try(root, "SetAlpha", 1)
    root:Show()
    for _, group in ipairs(loops) do Try(group, "Play") end
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

-- Reads the icon of plate (or the scanned target plate) and shows or hides the glow.
local function Evaluate(plate, token)
    if not Active() or InCombat() or not targetGUID then return HideNow() end
    if not plate then plate, token = FindPlate(targetGUID) end
    if not ns.Usable(plate) then return HideNow() end
    local unitFrame = plate.UnitFrame
    local soft = type(unitFrame) == "table" and unitFrame.SoftTargetFrame
    if type(soft) ~= "table" or not ns.Usable(soft) then
        ns.Report("highlights soft target", "The soft target icon is not available on this client.")
        return HideNow()
    end
    local kind = Category(IconTexture(soft))
    if not kind then return HideNow() end
    ShowOn(plate, soft, token, COLORS[kind])
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
    if not targetGUID or not Active() or InCombat() then return end
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
    SyncCVars()
    -- No events arrive while off, so the remembered target may be stale.
    if Active() then targetGUID = ReadTarget() end
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
        Evaluate()
        Recheck()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        PlateAdded((...))
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local token = ...
        if anchorToken and token == anchorToken then HideNow() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        fighting = true
        HideNow()
    elseif event == "PLAYER_REGEN_ENABLED" then
        fighting = false
        SyncCVars()
        Evaluate()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        SyncCVars()
        Evaluate()
    end
end
