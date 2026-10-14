local ADDON, ns = ...

-- Wiring: apply / restore, events, the per-frame update, and /quiet.

local booted = false
local chromeAcc = 0
local glancing = false
local layoutPending = nil
local layoutChosen = false
local presetCheckPending = false
local finishingLayout = false
local settleUntil = 0
local settleToken = 0
local settleArmed = false
local rescanPending = false
local rescanMissed = false

local function Run(label, fn, ...)
    ns.Profiler.Run(label, fn, ...)
end

-- Select once per enable, restore on disable. Both wait out combat and login.
-- With Force QuietUI layout off, the active Edit Mode layout stays as it is.
local function CheckStartupPreset()
    if not presetCheckPending then return true end
    if ns.ValidatePresetInterface and not ns.ValidatePresetInterface() then return false end
    presetCheckPending = false
    return true
end

local function FinishLayout()
    if not CheckStartupPreset() then return end
    if finishingLayout then return end
    if ns.UpdateLayoutPreview and ns.UpdateLayoutPreview() then return end
    if layoutPending == "select" and not ns.Settings.ForceQuietLayout() then
        layoutPending = nil
        return
    end
    if layoutPending ~= "select" and layoutPending ~= "restore" then return end
    finishingLayout = true
    local job = layoutPending
    local select = ns.Settings.ActivePreset and ns.Settings.ActivePreset() and ns.SelectPresetLayout or ns.SelectQuietLayout
    local fn = job == "select" and select or ns.RestorePreviousLayout
    local ok, done = pcall(fn)
    finishingLayout = false
    if not ok then
        layoutPending = nil
        if job == "select" then layoutChosen = true end
        ns.Report("layout", done)
    elseif done then
        layoutPending = nil
        if job == "select" then layoutChosen = true end
    end
end

-- A new character applies the default preset after login. Keep selecting until that settles.
local function ArmLayoutSettle()
    if not ns.DB().enabled or not ns.Settings.ForceQuietLayout() then return end
    settleToken = settleToken + 1
    local token = settleToken
    layoutChosen = false
    layoutPending = "select"
    local now = type(GetTime) == "function" and GetTime() or 0
    settleUntil = now + 10
    FinishLayout()
    if not (C_Timer and C_Timer.After) then return end
    for _, delay in ipairs({ 1, 3, 6 }) do
        C_Timer.After(delay, function()
            if token ~= settleToken or not ns.DB().enabled or not ns.Settings.ForceQuietLayout() then return end
            if type(GetTime) == "function" and GetTime() > settleUntil then return end
            layoutChosen = false
            layoutPending = "select"
            FinishLayout()
        end)
    end
end

local function RestoreAll()
    ns.Registry.Restore()
    ns.RestoreAlpha()
    -- The layout restore waits until the core restore is done.
    if layoutPending == "restore" then FinishLayout() end
end

local function ApplyAll()
    if not CheckStartupPreset() then return end
    if not ns.DB().enabled then
        RestoreAll()
        return
    end
    ns.Registry.Apply()
    ns.Registry.Fade(0)
end

ns.ApplyAll = ApplyAll
ns.RestoreAll = RestoreAll

-- Glance and Layout register last: Layout restores first of the features but finishes after RestoreAlpha.
ns.Feature({
    name = "glance",
    restore = function() glancing = false end,
})

ns.Feature({
    name = "layout",
    apply = function()
        if ns.Settings.ForceQuietLayout() then
            if not layoutChosen then
                layoutPending = "select"
                FinishLayout()
            end
        else
            -- A later Save with force on selects again. previousLayout stays.
            layoutChosen = false
            layoutPending = nil
        end
        ns.EnsureLayout()
    end,
    restore = function()
        ns.CancelLayoutPreview()
        settleToken = settleToken + 1
        settleUntil = 0
        layoutChosen = false
        if ns.Settings.ForceQuietLayout() or ns.Settings.CharDB().presetLayoutManaged then
            layoutPending = "restore"
        else
            layoutPending = nil
        end
    end,
    -- These also arrive while off: a layout job waits for combat or Edit Mode to end.
    always = { "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED" },
    events = {
        PLAYER_REGEN_ENABLED = function()
            FinishLayout()
            if ns.DB().enabled then ns.EnsureLayout() end
        end,
        EDIT_MODE_LAYOUTS_UPDATED = function()
            FinishLayout()
            if not ns.DB().enabled then return end
            ns.EnsureLayout()
            if not ns.Settings.ForceQuietLayout() then return end
            if type(GetTime) == "function" and GetTime() > settleUntil then return end
            layoutChosen = false
            layoutPending = "select"
            FinishLayout()
        end,
        PLAYER_ENTERING_WORLD = function(isInitialLogin, isReloading)
            -- Boot usually armed it already; arm once if it was skipped.
            if (isInitialLogin or isReloading) and not settleArmed then
                settleArmed = true
                ArmLayoutSettle()
            end
        end,
    },
})

function ns.LayoutSettingsChanged()
    settleToken = settleToken + 1
    settleUntil = 0
    layoutChosen = false
    if layoutPending ~= "restore" then layoutPending = nil end
end

-- Frames may have loaded: a deep scan, then apply again.
local function Rescan()
    ns.Registry.Phase("rescan", true)
    ApplyAll()
end

-- Boot and its delayed retries: the same scan, outside the rescan phase.
local function BootScan()
    ns.World.RefreshWorld()
    ns.FindFaders(true)
    ns.ScanSwing()
    ApplyAll()
end

local function RunRescan()
    rescanPending = false
    if not booted or not ns.DB().enabled then return end
    Run("rescan", Rescan)
end

-- Events coalesce into at most one rescan per frame.
function ns.RequestRescan()
    if not ns.DB().enabled then
        -- Catch up on enable; frames may have loaded meanwhile.
        rescanMissed = true
        return
    end
    if rescanPending then return end
    rescanMissed = false
    if not (C_Timer and C_Timer.After) then
        RunRescan()
        return
    end
    rescanPending = true
    C_Timer.After(0, RunRescan)
end

-- A default on the header binding is stored as HEADER_QUIETUI, so ` does nothing.
-- Take that key, or a free `, for QUIETUI_GLANCE. Leave any other action alone.
local function EnsureGlanceBinding()
    if type(GetBindingKey) ~= "function" or type(SetBinding) ~= "function" then return end
    if type(GetBindingAction) ~= "function" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local ok, existing = pcall(GetBindingKey, "QUIETUI_GLANCE")
    if ok and type(existing) == "string" and existing ~= "" then return end
    local actionOk, action = pcall(GetBindingAction, "`")
    if not actionOk or type(action) ~= "string" then return end
    if action ~= "" and action ~= "HEADER_QUIETUI" then return end
    local setOk, bound = pcall(SetBinding, "`", "QUIETUI_GLANCE")
    if not setOk or not bound then return end
    if type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then return end
    local setOk2, set = pcall(GetCurrentBindingSet)
    if setOk2 and type(set) == "number" then
        pcall(SaveBindings, set)
    end
end

local function Boot()
    local first = not booted
    booted = true
    ns.Registry.SetBooted(true)
    ns.Registry.InstallHooks()
    if first then presetCheckPending = true end
    ns.Settings.CharDB()
    ns.Settings.Effective()
    if first then
        local state = ns.DB().enabled and "on, enjoy the quiet" or "off for now"
        ns.Print("is " .. state .. ".")
        print("   |cffffffff/quiet|r  switch it on or off")
        print("   |cffffffff/quiet setup|r  choose what stays visible")
    end
    BootScan()
    EnsureGlanceBinding()
    ns.EnsureMinimap()
    if first and ns.DB().enabled then
        settleArmed = true
        ArmLayoutSettle()
    end
    if first and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            ApplyAll()
            ns.EnsureMinimap()
        end)
        C_Timer.After(2, BootScan)
    end
end

------------------------------------------------------------------------------
-- Boot events. Everything else arrives through the registry's event frame.
------------------------------------------------------------------------------
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name == ADDON then
        ns.DB()
    elseif booted then
        ns.RequestRescan()
    end
end

function handlers.PLAYER_LOGIN()
    ns.DB()
    Boot()
end

function handlers.PLAYER_ENTERING_WORLD()
    ns.DB()
    if booted then
        ns.RequestRescan()
    else
        Boot()
    end
end

local events = ns.Registry.Frame()
local lastPointerX, lastPointerY
local pointerMoved = false
local lastFlyout = false
local lastGlance = false
local wasHot = false
local lastShowAll = false
local slowAcc = 0
local fallbackAcc = 0
-- No focus API: a full button walk stays near 20 Hz instead of every pixel.
local FALLBACK_RESCAN = 0.05

local function PointerMoved()
    if type(GetCursorPosition) ~= "function" then
        pointerMoved = true
        return true
    end
    local x, y = GetCursorPosition()
    if x == lastPointerX and y == lastPointerY then
        pointerMoved = false
        return false
    end
    lastPointerX, lastPointerY = x, y
    pointerMoved = true
    return true
end

function ns.PointerMoved()
    return pointerMoved
end

local disabledLayoutAcc = 0

events:SetScript("OnUpdate", function(_, elapsed)
    if not booted then return end
    ns.Profiler.Finish(layoutPending)
    if not ns.DB().enabled then
        disabledLayoutAcc = disabledLayoutAcc + (elapsed or 0)
        if disabledLayoutAcc >= 0.1 then
            disabledLayoutAcc = 0
            Run("layout", FinishLayout)
        end
        return
    end
    elapsed = elapsed or 0
    local flyout = ns.World.FlyoutOpen and ns.World.FlyoutOpen() or false
    local glance = ns.Glancing() and true or false
    local moved = PointerMoved()
    local hud = ns.World.ConsumeHud()
    slowAcc = slowAcc + elapsed
    local slow = slowAcc >= 0.1
    if slow then
        if layoutPending or (ns.LayoutPreviewActive and ns.LayoutPreviewActive()) then
            Run("layout", FinishLayout)
        end
        slowAcc = 0
        ns.World.ForgetCursor()
    end
    local showAll = ns.World.ShowAll()
    local focusChanged = false
    if moved or slow then
        local changed = ns.FocusChanged()
        if changed == nil then
            if moved then
                fallbackAcc = fallbackAcc + elapsed
                if fallbackAcc >= FALLBACK_RESCAN then
                    fallbackAcc = 0
                    focusChanged = true
                end
            end
        else
            fallbackAcc = 0
            focusChanged = changed
        end
    end
    local rescan = focusChanged or hud or flyout ~= lastFlyout or glance ~= lastGlance
        or showAll ~= lastShowAll
    lastFlyout = flyout
    lastGlance = glance
    lastShowAll = showAll
    if rescan or wasHot then
        Run(nil, ns.Registry.Fade, elapsed, rescan)
        wasHot = ns.FrameHot()
    end
    if slow then
        if not rescan and not wasHot then
            Run(nil, ns.Registry.Fade, elapsed, false, true)
            if ns.FrameHot() then wasHot = true end
        end
        ns.Registry.Phase("tick")
    end
    ns.Registry.Phase("frame", elapsed)
    chromeAcc = chromeAcc + elapsed
    if chromeAcc < 1 then return end
    chromeAcc = 0
    ns.Registry.Phase("rescan", false)
end)

ns.Feature({
    name = "quietui",
    early = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" },
    events = handlers,
})

------------------------------------------------------------------------------
-- Press Glance to show the faded HUD. Press again and the rules apply.
-- The binding system calls a global; down and up both arrive.
------------------------------------------------------------------------------
BINDING_CATEGORY_QUIETUI = "QuietUI"
BINDING_NAME_QUIETUI_GLANCE = "Glance"

function ns.ToggleGlance()
    if not ns.DB().enabled then return end
    glancing = not glancing
end

function QuietUIGlance(keystate)
    if keystate == "down" then ns.ToggleGlance() end
end

function ns.Glancing()
    return glancing
end

------------------------------------------------------------------------------
-- /quiet on | off | setup | glance | preset, no argument toggles.
------------------------------------------------------------------------------
SLASH_QUIETUI1 = "/quiet"
SLASH_QUIETUI2 = "/quietui"
SlashCmdList["QUIETUI"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")
    local command, argument = msg:match("^(%S+)%s*(.-)$")
    if command and command:lower() == "preset" then
        ns.Settings.PresetCommand(argument)
        return
    end
    msg = msg:lower()
    if msg == "profile" then
        ns.Profiler.Start()
        return
    end
    if msg == "setup" then
        ns.ShowSetup()
        return
    end
    if msg == "glance" then
        ns.ToggleGlance()
        return
    end
    local db = ns.DB()
    if msg == "on" then
        db.enabled = true
    elseif msg == "off" then
        db.enabled = false
    else
        db.enabled = not db.enabled
    end
    if booted then
        if db.enabled then
            ApplyAll()
            if rescanMissed then ns.RequestRescan() end
        else
            RestoreAll()
        end
    end
    ns.Print(db.enabled and "enabled" or "disabled")
end
