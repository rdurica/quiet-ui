local ADDON, ns = ...

-- Wiring: apply / restore, events, the per-frame update, and /quiet.

local booted = false
local chromeAcc = 0
local rescanPending = false
local rescanMissed = false

local function Run(label, fn, ...)
    ns.Profiler.Run(label, fn, ...)
end

local function RestoreAll()
    ns.Registry.Restore()
    ns.RestoreAlpha()
    -- The layout restore waits until the core restore is done.
    ns.Layout.FinishRestore()
end

local function ApplyAll()
    if not ns.Layout.CheckStartupPreset() then return end
    if not ns.DB().enabled then
        RestoreAll()
        return
    end
    ns.Registry.Apply()
    ns.Registry.Fade(0)
end

ns.ApplyAll = ApplyAll
ns.RestoreAll = RestoreAll

-- Frames may have loaded: a deep scan, then apply again.
local function Rescan()
    ns.Registry.Phase("rescan", true)
    ApplyAll()
end

-- Boot and its delayed retries: the same scan, outside the rescan phase.
local function BootScan()
    ns.World.RefreshWorld()
    ns.Faders.Find(true)
    ns.Bars.ScanSwing()
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

local function Boot()
    local first = not booted
    booted = true
    ns.Registry.SetBooted(true)
    ns.Registry.InstallHooks()
    if first then ns.Layout.ArmStartupPreset() end
    ns.Settings.CharDB()
    ns.Settings.Effective()
    if first then
        local state = ns.DB().enabled and "on, enjoy the quiet" or "off for now"
        ns.Print("is " .. state .. ".")
        print("   |cffffffff/quiet|r  switch it on or off")
        print("   |cffffffff/quiet setup|r  choose what stays visible")
        ns.Setup.Welcome()
    end
    BootScan()
    ns.Glance.EnsureBinding()
    ns.Setup.EnsureMinimap()
    if first and ns.DB().enabled then
        ns.Layout.BootSettle()
    end
    if first and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            ApplyAll()
            ns.Setup.EnsureMinimap()
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
-- A running fade steps 30 times a second with the summed time, as the smooth faders do; a change
-- (focus, HUD, flyout, Glance) still applies on its own frame, so things appear at once.
local HOT_STEP = 1 / 30
local hotElapsed = 0

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
    ns.Profiler.Finish(ns.Layout.Pending())
    if not ns.DB().enabled then
        disabledLayoutAcc = disabledLayoutAcc + (elapsed or 0)
        if disabledLayoutAcc >= 0.1 then
            disabledLayoutAcc = 0
            Run("layout", ns.Layout.Finish)
        end
        return
    end
    elapsed = elapsed or 0
    local flyout = ns.World.FlyoutOpen and ns.World.FlyoutOpen() or false
    local glance = ns.Glance.Active() and true or false
    local moved = PointerMoved()
    local hud = ns.World.ConsumeHud()
    slowAcc = slowAcc + elapsed
    local slow = slowAcc >= 0.1
    if slow then
        if ns.Layout.Busy() then
            Run("layout", ns.Layout.Finish)
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
    hotElapsed = hotElapsed + elapsed
    if rescan or (wasHot and hotElapsed >= HOT_STEP) then
        Run(nil, ns.Registry.Fade, wasHot and hotElapsed or elapsed, rescan)
        hotElapsed = 0
        wasHot = ns.FrameHot()
    end
    if slow then
        if not rescan and not wasHot then
            Run(nil, ns.Registry.Fade, elapsed, false, true)
            hotElapsed = 0
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
        ns.Setup.Show()
        return
    end
    if msg == "glance" then
        ns.Glance.Toggle()
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
