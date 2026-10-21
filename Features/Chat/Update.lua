local _, ns = ...

-- Per-frame update and the chat feature registration.

local Chat = ns.Chat

-- Hover is read again only after the pointer moves (or every 0.1 s, for frames moving under it).
-- Chat reads the cursor itself, so the answer does not depend on the order of the frame phases.
function Chat.PointerStill()
    local state = Chat.state
    if type(GetCursorPosition) ~= "function" then
        state.pointerStill = false
        return false
    end
    local x, y = GetCursorPosition()
    state.pointerStill = x == state.pointerX and y == state.pointerY
    state.pointerX, state.pointerY = x, y
    return state.pointerStill
end

-- A still pointer with nothing easing runs a full pass every CALM_FOR seconds (the periodic hover
-- and catcher reads). A dirty window, a due bubble, a tab starting to flash, a window shown or
-- hidden, or an input box changing focus runs one at once.
local CALM_FOR = 0.1

-- The shown windows and tabs, kept by each full pass. Fields on Blizzard frames are slow to read
-- on this client, so the calm check reads these few instead of every window.
local live, liveTabs = {}, {}

local function Easing(obj, want)
    return obj ~= nil and (obj._quietSecret ~= nil or obj._quietAlpha ~= want)
end

-- The reason and list index a full pass is needed now, or nil.
local function Pending(now)
    for i = 1, #live do
        local frame = live[i]
        if frame._quietDirty then return "dirty", i end
        local wake = frame._quietNext
        if wake == 0 or (type(wake) == "number" and wake > 0 and now >= wake) then return "wake", i end
    end
    for i = 1, #liveTabs do
        local tab = liveTabs[i]
        if (tab.alerting and true or false) ~= (tab._quietAlerting or false) then return "tab", i end
    end
end

-- After a full pass: pending, or an input box still easing.
local function Busy(now)
    local reason, index = Pending(now)
    if reason then return reason, index end
    for i = 1, Chat.ChatCount() do
        local edit = Chat.Window(i, "EditBox")
        local want = edit and edit._quietWant
        if want ~= nil and (Easing(edit, want) or Easing(edit._quietHeader, want) or Easing(edit._quietPlate, want)) then
            return "edit", i
        end
    end
end

-- A window was shown or hidden, or an input box changed focus: the next frame runs a full pass.
function Chat.Wake()
    Chat.state.calmUntil = nil
end

function Chat.Update(elapsed)
    if not ns.DB().enabled or not ns.Settings.ModernChat() then return end
    local now = GetTime()
    local still = Chat.PointerStill()
    local state = Chat.state
    local lap = ns.Profiler.Clock()
    if still and state.calmUntil and now < state.calmUntil then
        local reason, index = Pending(now)
        if not reason then
            ns.Profiler.Lap("chat / calm", lap)
            return
        end
        if lap then lap = ns.Profiler.Lap("chat / woken: " .. reason .. " " .. index, lap) end
    elseif lap then
        lap = ns.Profiler.Lap(not still and "chat / pointer moved" or state.calmUntil and "chat / periodic"
            or "chat / not calm", lap)
    end
    ns.Wipe(live)
    ns.Wipe(liveTabs)
    for i = 1, Chat.ChatCount() do
        Chat.EaseEdit(Chat.Window(i, "EditBox"), elapsed)
        local tab = Chat.Window(i, "Tab")
        if tab and ns.Usable(tab) and tab:IsShown() then liveTabs[#liveTabs + 1] = tab end
        local frame = Chat.Window(i)
        if frame and frame._quietBubbles then
            if not ns.Usable(frame) or not frame.IsShown or not frame:IsShown() then
                if frame._quietShown ~= false then
                    Chat.HideActive(frame)
                    if frame._quietCatcher then frame._quietCatcher:Hide() end
                    frame._quietShown, frame._quietHover = false, false
                    frame._quietCatcherAt = nil
                end
            else
                live[#live + 1] = frame
                if frame._quietShown == false then frame._quietDirty = true end
                -- Anchors follow the chat automatically; only stacking needs a periodic refresh.
                if frame._quietDirty or not frame._quietCatcherAt or now >= frame._quietCatcherAt then
                    Chat.PlaceCatcher(frame)
                    frame._quietCatcherAt = now + 0.1
                end
                -- A still pointer keeps the hover; it is checked again at most every 0.1 s.
                if not still or frame._quietDirty or not frame._quietHoverAt or now >= frame._quietHoverAt then
                    frame._quietHoverAt = now + 0.1
                    local hot = Chat.FrameHot(frame) or Chat.TabRowHot(frame, i)
                    if hot ~= frame._quietHover then
                        frame._quietHover = hot
                        frame._quietDirty = true
                    end
                end
                local wake = frame._quietNext
                if frame._quietDirty or wake == 0 or (type(wake) == "number" and wake > 0 and now >= wake) then
                    Chat.LayoutFrame(frame, elapsed)
                end
            end
        end
    end
    local tabsEasing = Chat.FadeTabs(elapsed)
    local reason, index = Busy(now)
    state.calmUntil = not tabsEasing and not reason and now + CALM_FOR or nil
    if lap then
        ns.Profiler.Lap(tabsEasing and "chat / pass, tabs easing" or reason and ("chat / pass, stays: " .. reason
            .. " " .. index) or "chat / pass", lap)
    end
end
ns.Feature({
    name = "chat",
    -- No gate: apply also takes the chrome off again when Modern chat is switched off.
    apply = function()
        if ns.Settings.ModernChat() then Chat.StripAll() else Chat.Restore() end
    end,
    restore = function() Chat.Restore() end,
    frame = function(elapsed)
        if ns.Settings.ModernChat() then Chat.Update(elapsed) end
    end,
    tick = function()
        if ns.Settings.ModernChat() then Chat.SyncVisibleEdits() end
    end,
    rescan = function(deep)
        if not deep and ns.Settings.ModernChat() then Chat.StripAll() end
    end,
    events = {
        UPDATE_CHAT_WINDOWS = function() Chat.StripAll(true) end,
        UPDATE_FLOATING_CHAT_WINDOWS = function() Chat.StripAll(true) end,
    },
    hooks = {
        -- Hooked arguments are not ours to forward, except the chat frame.
        FCF_SetWindowAlpha = function(frame) Chat.Restrip(frame) end,
        FCF_SetWindowColor = function(frame) Chat.Restrip(frame) end,
        FCF_DockUpdate = function() Chat.StripAll() end,
        FCF_SetTabPosition = function() Chat.StripAll() end,
        FCF_RestorePositionAndDimensions = function() Chat.StripAll() end,
        FCF_OpenTemporaryWindow = function() Chat.StripAll() end,
    },
})
