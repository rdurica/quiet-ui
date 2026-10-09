local ADDON, ns = ...

-- Wiring: apply / restore, events, the per-frame update, and /quiet.

local booted = false
local hookedGlobal = {}
local chromeAcc = 0
local glancing = false
local layoutPending = nil
local layoutChosen = false
local presetCheckPending = false
local finishingLayout = false
local settleUntil = 0
local settleToken = 0
local cpuProfile

local function StartCPUProfile()
    if type(debugprofilestop) ~= "function" then
        ns.Print("CPU timing is not available on this client.")
        return
    end
    cpuProfile = { started = GetTime(), sections = {}, frames = 0 }
    ns.Print("Measuring QuietUI for 10 seconds. Keep playing in the same situation.")
end

local function FinishCPUProfile()
    if not cpuProfile then return end
    cpuProfile.frames = cpuProfile.frames + 1
    local duration = GetTime() - cpuProfile.started
    if duration < 10 then return end
    local rows = {}
    for name, section in pairs(cpuProfile.sections) do
        rows[#rows + 1] = { name = name, ms = section.ms, calls = section.calls }
    end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    ns.Print(string.format("CPU timing: %.1f seconds, %d frames, preset %s; pending layout: %s.", duration,
        cpuProfile.frames, ns.ActivePreset and ns.ActivePreset() and ns.ActivePreset().name or "<no preset>",
        tostring(layoutPending or "none")))
    if ns.LayoutStatus then ns.Print(ns.LayoutStatus()) end
    for i = 1, math.min(8, #rows) do
        local row = rows[i]
        ns.Print(string.format("%s: %.3f ms/s, %.3f ms/call (%d calls).",
            row.name, row.ms / duration, row.ms / row.calls, row.calls))
    end
    cpuProfile = nil
end

local function Run(label, fn, ...)
    local profile = label and cpuProfile
    local started = profile and debugprofilestop()
    local ok, err = pcall(fn, ...)
    if profile then
        local ms = math.max(0, debugprofilestop() - started)
        local section = profile.sections[label]
        if not section then section = { ms = 0, calls = 0 }; profile.sections[label] = section end
        section.ms, section.calls = section.ms + ms, section.calls + 1
    end
    if not ok then ns.Report(label or "fades", err) end
end

local function UpdateFades(elapsed, rescan)
    if not ns.DB().enabled then return end
    ns.NextFadeTick()
    ns.BeginTick(rescan)
    local showAll = ns.ShowAll()
    Run("bar visibility", ns.UpdateBars, showAll, elapsed, rescan)
    Run("faders", ns.UpdateFaders, elapsed)
    Run("menu", ns.UpdateMenuButton, elapsed)
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
    if layoutPending == "select" and not ns.ForceQuietLayout() then
        layoutPending = nil
        return
    end
    if layoutPending ~= "select" and layoutPending ~= "restore" then return end
    finishingLayout = true
    local job = layoutPending
    local select = ns.ActivePreset and ns.ActivePreset() and ns.SelectPresetLayout or ns.SelectQuietLayout
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
    if not ns.DB().enabled or not ns.ForceQuietLayout() then return end
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
            if token ~= settleToken or not ns.DB().enabled or not ns.ForceQuietLayout() then return end
            if type(GetTime) == "function" and GetTime() > settleUntil then return end
            layoutChosen = false
            layoutPending = "select"
            FinishLayout()
        end)
    end
end

local function RestoreAll()
    if ns.HideHoverCatchers then ns.HideHoverCatchers() end
    if ns.UpdateParty then ns.UpdateParty(0) end
    if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
    glancing = false
    if type(ns.RestoreQuestNotice) == "function" then ns.RestoreQuestNotice() end
    ns.HideQuestCatcher()
    ns.HideRangeMark()
    ns.HideBarCatchers()
    ns.ResetMenu()
    ns.RestoreChat()
    ns.RestoreAlpha()
    if ns.RestorePlayerFader then ns.RestorePlayerFader() end
    settleToken = settleToken + 1
    settleUntil = 0
    layoutChosen = false
    if ns.ForceQuietLayout() or ns.CharDB().presetLayoutManaged then
        layoutPending = "restore"
        FinishLayout()
    else
        layoutPending = nil
    end
end

local function ApplyAll()
    if not CheckStartupPreset() then return end
    if not ns.DB().enabled then
        RestoreAll()
        return
    end
    if ns.ForgetBarButtons then ns.ForgetBarButtons() end
    ns.RefreshWorld()
    if type(ns.ApplyQuestNotice) == "function" then ns.ApplyQuestNotice() end
    if ns.ForceQuietLayout() then
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
    ns.RefreshChrome()
    if ns.ModernChat() then
        ns.StripAllChat()
    else
        ns.RestoreChat()
    end
    UpdateFades(0)
    ns.FindFaders(false)
    ns.UpdateParty(0)
    ns.UpdateBagSlots()
end

ns.ApplyAll = ApplyAll

function ns.LayoutSettingsChanged()
    settleToken = settleToken + 1
    settleUntil = 0
    layoutChosen = false
    if layoutPending ~= "restore" then layoutPending = nil end
end

local function Rescan()
    ns.RefreshWorld()
    ns.FindFaders(true)
    ns.ScanSwing()
    ApplyAll()
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
    if first then presetCheckPending = true end
    ns.CharDB()
    if ns.Settings then ns.Settings() end
    if first then
        local state = ns.DB().enabled and "on, enjoy the quiet" or "off for now"
        ns.Print("is " .. state .. ".")
        print("   |cffffffff/quiet|r  switch it on or off")
        print("   |cffffffff/quiet setup|r  choose what stays visible")
    end
    Rescan()
    EnsureGlanceBinding()
    ns.EnsureMinimap()
    if first and ns.DB().enabled then
        ArmLayoutSettle()
    end
    if first and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            ApplyAll()
            ns.EnsureMinimap()
        end)
        C_Timer.After(2, Rescan)
    end
end

local function HookGlobal(name, fn)
    if hookedGlobal[name] or type(_G[name]) ~= "function" then return end
    local ok = pcall(hooksecurefunc, name, function(...)
        if not ns.DB().enabled then return end
        Run(name, fn, ...)
    end)
    if ok then
        hookedGlobal[name] = true
    end
end

------------------------------------------------------------------------------
-- Events. Unknown names throw on this client, so each one is registered alone.
------------------------------------------------------------------------------
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name == ADDON then
        ns.DB()
    elseif booted and ns.DB().enabled then
        Rescan()
    end
end

function handlers.PLAYER_LOGIN()
    ns.DB()
    Boot()
end

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloading)
    ns.DB()
    Boot()
    if ns.DB().enabled and type(ns.QuestNoticeEvent) == "function" then
        ns.QuestNoticeEvent("PLAYER_ENTERING_WORLD", isInitialLogin, isReloading)
    end
    if ns.DB().enabled and (isInitialLogin or isReloading) then
        ArmLayoutSettle()
    end
end

function handlers.PLAYER_REGEN_DISABLED()
    ns.NoteCombat(true)
    ns.UpdateParty(0)
    UpdateFades(0)
end

function handlers.PLAYER_REGEN_ENABLED()
    ns.NoteCombat(false)
    ns.MarkCombatEnd()
    UpdateFades(0)
    ns.RefreshChrome()
    ns.EnsureLayout()
end

for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE" }) do
    local name = event
    handlers[name] = function(...)
        if type(ns.QuestNoticeEvent) == "function" then ns.QuestNoticeEvent(name, ...) end
    end
end

function handlers.QUEST_TURNED_IN(_, xp)
    ns.MarkQuestXP(xp)
end

function handlers.EDIT_MODE_LAYOUTS_UPDATED()
    if ns.ForgetBarButtons then ns.ForgetBarButtons() end
    ns.EnsureLayout()
    if not ns.DB().enabled or not ns.ForceQuietLayout() then return end
    if type(GetTime) == "function" and GetTime() > settleUntil then return end
    layoutChosen = false
    layoutPending = "select"
    FinishLayout()
end

function handlers.UPDATE_CHAT_WINDOWS()
    ns.StripAllChat(true)
end
handlers.UPDATE_FLOATING_CHAT_WINDOWS = handlers.UPDATE_CHAT_WINDOWS

function handlers.GROUP_ROSTER_UPDATE()
    ns.RefreshWorld()
    ns.FindFaders(false)
    ns.UpdateParty(0)
end

function handlers.PLAYER_TARGET_CHANGED()
    ns.RefreshWorld()
end

function handlers.UNIT_FLAGS(unit)
    if unit == "target" then ns.RefreshWorld() end
end

handlers.UNIT_FACTION = handlers.UNIT_FLAGS

function handlers.UNIT_ENTERED_VEHICLE()
    ns.RefreshWorld()
end

handlers.UNIT_EXITED_VEHICLE = handlers.UNIT_ENTERED_VEHICLE

-- These run before boot and while disabled; the rest only while active.
local ALWAYS = {
    ADDON_LOADED = true,
    PLAYER_LOGIN = true,
    PLAYER_ENTERING_WORLD = true,
}

local events = CreateFrame("Frame")
local lastPointerX, lastPointerY
local lastFlyout = false
local lastGlance = false
local wasHot = false
local lastShowAll = false
local slowAcc = 0
local fallbackAcc = 0
-- No focus API: a full button walk stays near 20 Hz instead of every pixel.
local FALLBACK_RESCAN = 0.05

local function PointerMoved()
    if type(GetCursorPosition) ~= "function" then return true end
    local x, y = GetCursorPosition()
    if x == lastPointerX and y == lastPointerY then return false end
    lastPointerX, lastPointerY = x, y
    return true
end

local function FlyoutShown()
    return SpellFlyout and SpellFlyout.IsShown and SpellFlyout:IsShown() and true or false
end

events:SetScript("OnEvent", function(_, event, ...)
    if booted and (event == "PLAYER_REGEN_ENABLED" or event == "EDIT_MODE_LAYOUTS_UPDATED") then
        Run("layout", FinishLayout)
    end
    local handler = handlers[event]
    if not handler then return end
    if not ALWAYS[event] and (not booted or not ns.DB().enabled) then return end
    Run(event, handler, ...)
end)

local disabledLayoutAcc = 0

events:SetScript("OnUpdate", function(_, elapsed)
    if not booted then return end
    FinishCPUProfile()
    if not ns.DB().enabled then
        disabledLayoutAcc = disabledLayoutAcc + (elapsed or 0)
        if disabledLayoutAcc >= 0.1 then
            disabledLayoutAcc = 0
            Run("layout", FinishLayout)
        end
        return
    end
    elapsed = elapsed or 0
    local flyout = FlyoutShown()
    local glance = ns.Glancing() and true or false
    local moved = PointerMoved()
    local hud = ns.ConsumeHud()
    slowAcc = slowAcc + elapsed
    local slow = slowAcc >= 0.1
    if slow then
        if layoutPending or ns.UpdateLayoutPreview then Run("layout", FinishLayout) end
        slowAcc = 0
        ns.ForgetCursor()
    end
    local showAll = ns.ShowAll()
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
        Run(nil, UpdateFades, elapsed, rescan)
        wasHot = ns.FrameHot()
    end
    if slow then
        if not rescan and not wasHot then
            ns.NextFadeTick()
            Run("faders", ns.UpdateFaders, elapsed)
            Run("menu", ns.UpdateMenuButton, elapsed)
            if ns.FrameHot() then wasHot = true end
        end
        Run("bags", ns.UpdateBagSlots)
        if ns.ModernChat() then
            Run("input", ns.SyncVisibleEdits)
        end
    end
    if ns.ModernChat() then
        Run("bubbles", ns.UpdateChat, elapsed)
    end
    if type(ns.UpdateQuestNotice) == "function" then Run("quest notice", ns.UpdateQuestNotice, elapsed) end
    -- Range changes while you walk, with no focus or cursor change, so it cannot wait for a rescan.
    Run("range", ns.UpdateRange, elapsed)
    Run("smooth", ns.UpdateSmooth, elapsed)
    chromeAcc = chromeAcc + elapsed
    if chromeAcc < 1 then return end
    chromeAcc = 0
    Run("frame scan", ns.FindFaders, false)
    Run("swing", ns.ScanSwing)
    Run("bar buttons", ns.ForgetBarButtons)
    Run("world", ns.RefreshWorld)
    Run("menu", ns.RefreshChrome)
    if ns.ModernChat() then
        Run("chat", ns.StripAllChat)
    end
end)

for eventName in pairs(handlers) do
    pcall(events.RegisterEvent, events, eventName)
end

HookGlobal("UpdateMicroButtons", ns.RefreshChrome)
HookGlobal("FCF_SetWindowAlpha", ns.StripAllChat)
HookGlobal("FCF_SetWindowColor", ns.StripAllChat)
HookGlobal("FCF_DockUpdate", ns.StripAllChat)

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
        ns.PresetCommand(argument)
        return
    end
    msg = msg:lower()
    if msg == "profile" then
        StartCPUProfile()
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
        if db.enabled then ApplyAll() else RestoreAll() end
    end
    ns.Print(db.enabled and "enabled" or "disabled")
end
