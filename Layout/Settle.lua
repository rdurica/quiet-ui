local _, ns = ...

-- Layout settling after login, combat and Edit Mode, and the layout feature.
-- Select once per enable, restore on disable. Both wait out combat and login.
-- With Force QuietUI layout off, the active Edit Mode layout stays as it is.

local Layout = ns.Layout
local S = Layout.state

function Layout.CheckStartupPreset()
    if not S.presetCheckPending then return true end
    if Layout.ValidatePresetInterface and not Layout.ValidatePresetInterface() then return false end
    S.presetCheckPending = false
    return true
end

-- First boot: validate the active preset's layout before the first apply.
function Layout.ArmStartupPreset()
    S.presetCheckPending = true
end

-- A layout job or a preview is waiting for the next slow tick.
function Layout.Busy()
    return S.pending ~= nil or Layout.PreviewActive()
end

function Layout.Pending()
    return S.pending
end

function Layout.Finish()
    if not Layout.CheckStartupPreset() then return end
    if S.finishing then return end
    if Layout.UpdatePreview and Layout.UpdatePreview() then return end
    if S.pending == "select" and not ns.Settings.ForceQuietLayout() then
        S.pending = nil
        return
    end
    if S.pending ~= "select" and S.pending ~= "restore" then return end
    S.finishing = true
    local job = S.pending
    local select = ns.Settings.ActivePreset and ns.Settings.ActivePreset() and Layout.SelectPreset or Layout.SelectQuiet
    local fn = job == "select" and select or Layout.RestorePrevious
    local ok, done = pcall(fn)
    S.finishing = false
    if not ok then
        S.pending = nil
        if job == "select" then S.chosen = true end
        ns.Report("layout", done)
    elseif done then
        S.pending = nil
        if job == "select" then S.chosen = true end
    end
end

-- A new character applies the default preset after login. Keep selecting until that settles.
function Layout.ArmSettle()
    if not ns.DB().enabled or not ns.Settings.ForceQuietLayout() then return end
    S.settleToken = S.settleToken + 1
    local token = S.settleToken
    S.chosen = false
    S.pending = "select"
    local now = type(GetTime) == "function" and GetTime() or 0
    S.settleUntil = now + 10
    Layout.Finish()
    if not (C_Timer and C_Timer.After) then return end
    for _, delay in ipairs({ 1, 3, 6 }) do
        C_Timer.After(delay, function()
            if token ~= S.settleToken or not ns.DB().enabled or not ns.Settings.ForceQuietLayout() then return end
            if type(GetTime) == "function" and GetTime() > S.settleUntil then return end
            S.chosen = false
            S.pending = "select"
            Layout.Finish()
        end)
    end
end

-- Boot arms the first settle; the login event arms it once if boot skipped it.
function Layout.BootSettle()
    S.armed = true
    Layout.ArmSettle()
end

function Layout.SettingsChanged()
    S.settleToken = S.settleToken + 1
    S.settleUntil = 0
    S.chosen = false
    if S.pending ~= "restore" then S.pending = nil end
end

-- The core restore is done: a waiting layout restore may finish now.
function Layout.FinishRestore()
    if S.pending == "restore" then Layout.Finish() end
end

-- Registers last of the features: it restores first of them but finishes after RestoreAlpha.
ns.Feature({
    name = "layout",
    apply = function()
        if ns.Settings.ForceQuietLayout() then
            if not S.chosen then
                S.pending = "select"
                Layout.Finish()
            end
        else
            -- A later Save with force on selects again. previousLayout stays.
            S.chosen = false
            S.pending = nil
        end
        Layout.Ensure()
    end,
    restore = function()
        Layout.CancelPreview()
        S.settleToken = S.settleToken + 1
        S.settleUntil = 0
        S.chosen = false
        if ns.Settings.ForceQuietLayout() or ns.Settings.CharDB().presetLayoutManaged then
            S.pending = "restore"
        else
            S.pending = nil
        end
    end,
    -- These also arrive while off: a layout job waits for combat or Edit Mode to end.
    always = { "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED" },
    events = {
        PLAYER_REGEN_ENABLED = function()
            Layout.Finish()
            if ns.DB().enabled then Layout.Ensure() end
        end,
        EDIT_MODE_LAYOUTS_UPDATED = function()
            Layout.Finish()
            if not ns.DB().enabled then return end
            Layout.Ensure()
            if not ns.Settings.ForceQuietLayout() then return end
            if type(GetTime) == "function" and GetTime() > S.settleUntil then return end
            S.chosen = false
            S.pending = "select"
            Layout.Finish()
        end,
        PLAYER_ENTERING_WORLD = function(isInitialLogin, isReloading)
            -- Boot usually armed it already; arm once if it was skipped.
            if (isInitialLogin or isReloading) and not S.armed then
                Layout.BootSettle()
            end
        end,
    },
})
