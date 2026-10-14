-- Helper for the Highlights area tests (tests/highlights/*.lua), loaded with h.lib("highlights").
-- Builds a soft-target world on top of the harness mock: CVars, nameplates with a
-- SoftTargetFrame icon, the soft interact unit, combat and instance state.
-- Everything is observed through public ns.* and mock state (frames, CVars, saved variables).
local H = {}

H.ORE = { 0.95, 0.75, 0.25 }
H.HERB = { 0.30, 0.74, 0.40 }
H.INTERACT = { 0.78, 0.76, 0.70 }
H.HERBS = "Cursor Crosshair_GatherHerbs_64"
H.HERBS_FAR = "Cursor Crosshair_UnableGatherHerbs_64"
H.MINE = "Cursor Crosshair_Mine_64"
H.GEAR = "Cursor Crosshair_Interact_64"
H.SPEAK = "Cursor Crosshair_Speak_64"
H.NAMES = { "SoftTargetInteract", "SoftTargetInteractRange", "SoftTargetNameplateInteract",
    "SoftTargetIconGameObject", "SoftTargetInteractArc", "SoftTargetIconInteract" }
H.WANT = { SoftTargetInteract = "3", SoftTargetInteractRange = "15", SoftTargetNameplateInteract = "1",
    SoftTargetIconGameObject = "1", SoftTargetInteractArc = "2", SoftTargetIconInteract = "1" }
H.ORIGINAL = { SoftTargetInteract = "1", SoftTargetInteractRange = "10", SoftTargetNameplateInteract = "0",
    SoftTargetIconGameObject = "0", SoftTargetInteractArc = "0", SoftTargetIconInteract = "0" }
-- Icons were already on before QuietUI, so unrelated icons belong to the player.
H.ICONS_ON = { SoftTargetInteract = "1", SoftTargetInteractRange = "10", SoftTargetNameplateInteract = "0",
    SoftTargetIconGameObject = "1", SoftTargetInteractArc = "0", SoftTargetIconInteract = "1" }
-- Without a game object target the nameplate and icon CVars keep the originals, so NPCs stay bare.
H.IDLE = { SoftTargetInteract = "3", SoftTargetInteractRange = "15", SoftTargetNameplateInteract = "0",
    SoftTargetIconGameObject = "1", SoftTargetInteractArc = "2", SoftTargetIconInteract = "0" }

local GLOW_PATH = "interface\\addons\\quietui\\media\\glow.tga"

local function copy(src)
    local out = {}
    for k, v in pairs(src or {}) do out[k] = v end
    return out
end
H.copy = copy

-- opts: flags (categories on), enabled (default true), cvars (default ORIGINAL), saved
-- (stored highlightCVars), instance (instance type), combat.
function H.world(t, opts)
    opts = opts or {}
    local mock, ns, A = t.mock, t.ns, t.assert
    local w = { mock = mock, ns = ns, plates = {}, violations = {}, unitExistsCalls = 0 }

    for name, value in pairs(opts.cvars or H.ORIGINAL) do mock.cvars[name] = value end
    ns.DB().enabled = opts.enabled ~= false
    ns.DB().highlightCVars = opts.saved
    w.flags = copy(opts.flags)
    QuietUICharDB.highlights = next(w.flags) and w.flags or nil
    mock.state.combat = opts.combat == true
    if opts.instance then mock.state.instance, mock.state.instanceType = true, opts.instance end
    -- Highlights must not use UnitExists (the soft interact unit is read through UnitGUID).
    UnitExists = function() w.unitExistsCalls = w.unitExistsCalls + 1; error("UnitExists must not be called", 2) end

    function w.setFlags(flags)
        w.flags = copy(flags)
        QuietUICharDB.highlights = next(w.flags) and w.flags or nil
    end
    function w.apply() ns.ApplyHighlights() end
    function w.restore() ns.RestoreHighlights() end
    function w.event(name, ...) ns.HighlightsEvent(name, ...) end
    function w.combat(on) mock.state.combat = on end
    function w.instance(kind)
        mock.state.instance, mock.state.instanceType = kind ~= "none", kind
    end
    function w.writes() return #mock.cvarLog end
    function w.cvar(name) return mock.cvars[name] end
    function w.saved() return ns.DB().highlightCVars end

    -- The soft interact unit changes: UnitGUID("softinteract") and the event arguments.
    function w.target(guid, previous)
        mock.units.softinteract = guid and { exists = true, guid = guid } or nil
        w.event("PLAYER_SOFT_INTERACT_CHANGED", previous, guid)
    end
    function w.targetNoArgs(guid)
        mock.units.softinteract = guid and { exists = true, guid = guid } or nil
        w.event("PLAYER_SOFT_INTERACT_CHANGED")
    end

    local function watch(frame, label)
        for _, method in ipairs({ "SetAlpha", "SetPoint", "ClearAllPoints", "Show", "Hide" }) do
            frame[method] = function() w.violations[#w.violations + 1] = label .. ":" .. method end
        end
    end

    -- A nameplate for token / guid with a soft-target icon texture (nil or a number allowed).
    function w.addPlate(token, guid, texture, popts)
        popts = popts or {}
        local plate = CreateFrame("Frame", nil, UIParent)
        local unitFrame = CreateFrame("Frame", nil, plate)
        plate.UnitFrame = unitFrame
        if not popts.noUnitToken then unitFrame.unit = token end
        plate.namePlateUnitToken = token
        if not popts.noSoftTarget then
            local soft = CreateFrame("Frame", nil, unitFrame)
            soft:SetFrameLevel(5)
            local icon = soft:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(texture)
            if popts.atlas then icon.GetAtlas = function() return popts.atlas end end
            soft.Icon = icon
            unitFrame.SoftTargetFrame = soft
            plate.soft = soft
            -- Plate frames are Blizzard's; QuietUI may only read them (the icon is held by alpha).
            watch(soft, "soft")
        end
        watch(plate, "plate")
        watch(unitFrame, "unitFrame")
        mock.nameplates[token] = plate
        mock.units[token] = { exists = true, guid = guid }
        w.plates[#w.plates + 1] = plate
        return plate
    end
    function w.removePlate(token)
        mock.nameplates[token] = nil
        mock.units[token] = nil
    end

    local function within(f, root)
        local n = 0
        while f and n < 50 do
            if f == root then return true end
            f = f._parent
            n = n + 1
        end
        return false
    end
    w.within = within

    local function visible(f)
        local n = 0
        while f and n < 50 do
            if f._shown == false or (type(f._alpha) == "number" and f._alpha <= 0) then return false end
            f = f._parent
            n = n + 1
        end
        return true
    end

    local function textures(root)
        local out = {}
        for _, r in ipairs(root._regions) do
            if r._kind == "Texture" then out[#out + 1] = r end
        end
        return out
    end
    w.textures = textures

    -- The glow root: the frame that owns the aura texture (nil until first shown).
    function w.glow()
        for _, f in ipairs(mock.frames) do
            if f._kind == "Frame" then
                for _, r in ipairs(f._regions) do
                    if type(r._texture) == "string" and r._texture:lower() == GLOW_PATH then return f end
                end
            end
        end
    end
    function w.shownOn(plate)
        local g = w.glow()
        return g ~= nil and within(g, plate) and visible(g)
    end
    function w.nothingShown()
        local g = w.glow()
        return g == nil or not visible(g)
    end
    function w.hasColor(root, color)
        for _, tex in ipairs(textures(root)) do
            local c = tex._vertex
            if c and math.abs(c[1] - color[1]) < 0.01 and math.abs(c[2] - color[2]) < 0.01
                and math.abs(c[3] - color[3]) < 0.01 then return true end
        end
        return false
    end
    function w.groups()
        return mock:find(function(f) return f._kind == "AnimationGroup" end)
    end
    function w.loopsPlaying(root)
        for _, g in ipairs(w.groups()) do
            if (root == nil or within(g._owner, root)) and (g._looping == "BOUNCE" or g._looping == "REPEAT")
                and g._playing then return true end
        end
        return false
    end
    function w.assertHidden(msg)
        local g = w.glow()
        A.ok(g, (msg or "") .. "the glow frame was never created")
        A.eq(g._parent, UIParent, (msg or "") .. "the hidden glow was not returned to UIParent")
        A.ok(w.nothingShown(), (msg or "") .. "something from Highlights is still shown")
        A.falsy(w.loopsPlaying(), (msg or "") .. "a looping animation still plays while hidden")
    end
    function w.assertCVars(values, msg)
        for _, name in ipairs(H.NAMES) do
            A.eq(w.cvar(name), values[name], (msg or "CVar") .. ": " .. name)
        end
    end
    function w.assertSaved(values)
        local saved = w.saved()
        A.type(saved, "table", "highlightCVars was not stored")
        for _, name in ipairs(H.NAMES) do
            A.eq(tostring(saved[name]), values[name], "highlightCVars." .. name)
        end
    end
    function w.assertNoErrors()
        for _, line in ipairs(mock.printed) do
            A.falsy(line:find("error (shown once)", 1, true), "unexpected report: " .. line)
        end
    end
    function w.reported()
        for _, line in ipairs(mock.printed) do
            if line:find("error (shown once)", 1, true) then return true end
        end
        return false
    end
    -- Checked after every case that uses the world: plates stay untouched, no OnUpdate, no UnitExists.
    function w.assertHygiene()
        A.eq(#w.violations, 0, "plate frames were touched: " .. table.concat(w.violations, ", "))
        A.eq(w.unitExistsCalls, 0, "UnitExists was called")
        for _, f in ipairs(mock.frames) do
            local glow = w.glow()
            if glow and within(f, glow) then A.eq(f._scripts.OnUpdate, nil, "OnUpdate set on a glow frame") end
        end
    end
    return w
end

-- Declares a test; fn(t, A) returns its world so the shared hygiene checks run afterwards.
function H.case(h, name, fn)
    h.test(name, function(t)
        local w = fn(t, t.assert)
        if w then w.assertHygiene() end
    end)
end

-- A world with ore on and a mine target shown on nameplate1 (texture override via ...).
function H.oreShown(t, ...)
    local texture = select("#", ...) == 0 and H.MINE or ...
    local w = H.world(t, { flags = { ore = true } })
    w.apply()
    local plate = w.addPlate("nameplate1", "GameObject-0-1-2-3-1731-0001", texture)
    w.target("GameObject-0-1-2-3-1731-0001", nil)
    return w, plate
end

return H
