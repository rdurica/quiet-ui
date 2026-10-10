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
local settleArmed = false
local rescanPending = false
local rescanMissed = false
local cpuProfile

local function StartCPUProfile()
    if type(debugprofilestop) ~= "function" then
        ns.Print("CPU timing is not available on this client.")
        return
    end
    cpuProfile = { started = GetTime(), sections = {}, smooth = {}, frames = 0 }
    ns.Print("Measuring QuietUI for 10 seconds. Keep playing in the same situation.")
end

local function ProfileRows(sections)
    local rows = {}
    for name, section in pairs(sections) do
        rows[#rows + 1] = { name = name, ms = section.ms, calls = section.calls }
    end
    table.sort(rows, function(a, b) return a.ms > b.ms end)
    return rows
end

local function PrintProfileRow(row, duration, prefix)
    ns.Print(string.format("%s%s: %.3f ms/s, %.3f ms/call (%d calls).",
        prefix or "", row.name, row.ms / duration, row.ms / row.calls, row.calls))
end

local function FinishCPUProfile()
    if not cpuProfile then return end
    cpuProfile.frames = cpuProfile.frames + 1
    local duration = GetTime() - cpuProfile.started
    if duration < 10 then return end
    local rows = ProfileRows(cpuProfile.sections)
    ns.Print(string.format("CPU timing: %.1f seconds, %d frames, preset %s; pending layout: %s.", duration,
        cpuProfile.frames, ns.ActivePreset and ns.ActivePreset() and ns.ActivePreset().name or "<no preset>",
        tostring(layoutPending or "none")))
    if ns.LayoutStatus then ns.Print(ns.LayoutStatus()) end
    for i = 1, math.min(8, #rows) do
        PrintProfileRow(rows[i], duration)
    end
    -- Details are included in the smooth total and do not consume the top-eight slots.
    for _, row in ipairs(ProfileRows(cpuProfile.smooth)) do
        PrintProfileRow(row, duration, "smooth / ")
    end
    cpuProfile = nil
end

local function RecordCPU(sections, label, started)
    local ms = math.max(0, debugprofilestop() - started)
    local section = sections[label]
    if not section then section = { ms = 0, calls = 0 }; sections[label] = section end
    section.ms, section.calls = section.ms + ms, section.calls + 1
end

local function Run(label, fn, ...)
    local profile = label and cpuProfile
    local started = profile and debugprofilestop()
    local ok, err = pcall(fn, ...)
    if profile then
        RecordCPU(profile.sections, label, started)
    end
    if not ok then ns.Report(label or "fades", err) end
end

local function ProfileSmooth(label, fn, ...)
    local profile = cpuProfile
    local started = debugprofilestop()
    local ok, err = pcall(fn, ...)
    RecordCPU(profile.smooth, label, started)
    if not ok then ns.Report(label, err) end
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
    if type(ns.RestoreHighlights) == "function" then ns.RestoreHighlights() end
    if type(ns.RestoreQuestMobs) == "function" then ns.RestoreQuestMobs() end
    if type(ns.RestoreParchment) == "function" then Run("parchment", ns.RestoreParchment) end
    ns.HideQuestCatcher()
    ns.HideRangeMark()
    -- Target and action bar events stop while off.
    if ns.ForgetRangeSlot then ns.ForgetRangeSlot() end
    if ns.ForgetRangePlate then ns.ForgetRangePlate() end
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
    if type(ns.ApplyHighlights) == "function" then ns.ApplyHighlights() end
    if type(ns.ApplyQuestMobs) == "function" then ns.ApplyQuestMobs() end
    if type(ns.ApplyParchment) == "function" then Run("parchment", ns.ApplyParchment) end
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
        settleArmed = true
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

local function Highlights(event, ...)
    if type(ns.HighlightsEvent) == "function" then ns.HighlightsEvent(event, ...) end
end

-- Own Run so an error here or in a neighbouring handler does not skip the other.
local function QuestMobs(event, ...)
    if type(ns.QuestMobsEvent) == "function" then Run("quest mobs", ns.QuestMobsEvent, event, ...) end
end

local function Parchment(event, ...)
    if type(ns.ParchmentEvent) == "function" then Run("parchment", ns.ParchmentEvent, event, ...) end
end

for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW",
    "ITEM_TEXT_READY" }) do
    local name = event
    handlers[name] = function(...) Parchment(name, ...) end
end

function handlers.ADDON_LOADED(name, ...)
    if name == ADDON then
        ns.DB()
    elseif booted then
        ns.RequestRescan()
        -- Blizzard quest, gossip and item text UIs may load on demand. Before boot the
        -- saved variables may not exist yet, and ApplyAll skins the windows at boot.
        Parchment("ADDON_LOADED", name, ...)
    end
end

function handlers.PLAYER_LOGIN()
    ns.DB()
    Boot()
end

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloading)
    ns.DB()
    if booted then
        ns.RequestRescan()
    else
        Boot()
    end
    if ns.DB().enabled and type(ns.QuestNoticeEvent) == "function" then
        ns.QuestNoticeEvent("PLAYER_ENTERING_WORLD", isInitialLogin, isReloading)
    end
    if ns.DB().enabled then
        Highlights("PLAYER_ENTERING_WORLD", isInitialLogin, isReloading)
        QuestMobs("PLAYER_ENTERING_WORLD", isInitialLogin, isReloading)
    end
    -- Boot usually armed it already; arm once if it was skipped.
    if ns.DB().enabled and (isInitialLogin or isReloading) and not settleArmed then
        settleArmed = true
        ArmLayoutSettle()
    end
end

function handlers.PLAYER_REGEN_DISABLED()
    ns.NoteCombat(true)
    ns.UpdateParty(0)
    UpdateFades(0)
    Highlights("PLAYER_REGEN_DISABLED")
end

function handlers.PLAYER_REGEN_ENABLED()
    ns.NoteCombat(false)
    ns.MarkCombatEnd()
    UpdateFades(0)
    ns.RefreshChrome()
    ns.EnsureLayout()
    Highlights("PLAYER_REGEN_ENABLED")
end

for _, event in ipairs({ "PLAYER_SOFT_INTERACT_CHANGED", "ZONE_CHANGED_NEW_AREA" }) do
    handlers[event] = function(...) Highlights(event, ...) end
end

function handlers.NAME_PLATE_UNIT_ADDED(...)
    Highlights("NAME_PLATE_UNIT_ADDED", ...)
    QuestMobs("NAME_PLATE_UNIT_ADDED", ...)
end

function handlers.UNIT_QUEST_LOG_CHANGED(...)
    QuestMobs("UNIT_QUEST_LOG_CHANGED", ...)
end

for _, event in ipairs({ "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE" }) do
    local name = event
    handlers[name] = function(...)
        if type(ns.QuestNoticeEvent) == "function" then ns.QuestNoticeEvent(name, ...) end
    end
end

local questLogUpdate = handlers.QUEST_LOG_UPDATE
function handlers.QUEST_LOG_UPDATE(...)
    questLogUpdate(...)
    QuestMobs("QUEST_LOG_UPDATE", ...)
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
    ns.ScanParty()
    ns.UpdateParty(0)
end

function handlers.PLAYER_TARGET_CHANGED()
    ns.RefreshWorld()
    ns.ForgetRangePlate()
end

function handlers.NAME_PLATE_UNIT_REMOVED(...)
    ns.ForgetRangePlate()
    Highlights("NAME_PLATE_UNIT_REMOVED", ...)
    QuestMobs("NAME_PLATE_UNIT_REMOVED", ...)
end

function handlers.ACTIONBAR_SLOT_CHANGED()
    ns.ForgetRangeSlot()
end

handlers.SPELLS_CHANGED = handlers.ACTIONBAR_SLOT_CHANGED

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

events:SetScript("OnEvent", function(_, event, ...)
    if booted and (event == "PLAYER_REGEN_ENABLED" or event == "EDIT_MODE_LAYOUTS_UPDATED") then
        Run("layout", FinishLayout)
    end
    local handler = handlers[event]
    if not handler then return end
    if not ALWAYS[event] and (not booted or not ns.DB().enabled) then
        -- A CVar restore deferred by combat must finish after /quiet off.
        if event == "PLAYER_REGEN_ENABLED" and booted then Run("highlights", Highlights, event, ...) end
        return
    end
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
    local flyout = ns.FlyoutOpen and ns.FlyoutOpen() or false
    local glance = ns.Glancing() and true or false
    local moved = PointerMoved()
    local hud = ns.ConsumeHud()
    slowAcc = slowAcc + elapsed
    local slow = slowAcc >= 0.1
    if slow then
        if layoutPending or (ns.LayoutPreviewActive and ns.LayoutPreviewActive()) then
            Run("layout", FinishLayout)
        end
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
    Run("smooth", ns.UpdateSmooth, elapsed, cpuProfile and ProfileSmooth or nil)
    chromeAcc = chromeAcc + elapsed
    if chromeAcc < 1 then return end
    chromeAcc = 0
    Run("frame scan", ns.FindFaders, false)
    Run("swing", ns.ScanSwing)
    if ns.BarChildrenChanged and ns.BarChildrenChanged() then
        Run("bar buttons", ns.ForgetBarButtons)
    end
    Run("world", ns.RefreshWorld)
    Run("menu", ns.RefreshChrome)
    if ns.ModernChat() then
        Run("chat", ns.StripAllChat)
    end
end)

-- Without these two the glow cannot follow the soft target, so say so once.
local HIGHLIGHT_EVENTS = { PLAYER_SOFT_INTERACT_CHANGED = true, NAME_PLATE_UNIT_ADDED = true }
for eventName in pairs(handlers) do
    local ok, err = pcall(events.RegisterEvent, events, eventName)
    if not ok and HIGHLIGHT_EVENTS[eventName] then ns.Report("highlights events", err) end
end

-- Hooked arguments are not ours to forward, except the chat frame.
HookGlobal("UpdateMicroButtons", function() ns.RefreshChrome() end)
HookGlobal("FCF_SetWindowAlpha", function(frame) ns.RestripChat(frame) end)
HookGlobal("FCF_SetWindowColor", function(frame) ns.RestripChat(frame) end)
HookGlobal("FCF_DockUpdate", function() ns.StripAllChat() end)

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
        if db.enabled then
            ApplyAll()
            if rescanMissed then ns.RequestRescan() end
        else
            RestoreAll()
        end
    end
    ns.Print(db.enabled and "enabled" or "disabled")
end
