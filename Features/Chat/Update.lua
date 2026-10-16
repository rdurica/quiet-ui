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

function Chat.Update(elapsed)
    if not ns.DB().enabled or not ns.Settings.ModernChat() then return end
    local now = GetTime()
    local still = Chat.PointerStill()
    for i = 1, Chat.ChatCount() do
        Chat.EaseEdit(Chat.Window(i, "EditBox"), elapsed)
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
    Chat.FadeTabs(elapsed)
end
ns.Feature({
    name = "chat",
    -- No gate: apply also takes the chrome off again when Modern chat is switched off.
    apply = function()
        if ns.Settings.ModernChat() then Chat.StripAll() else Chat.Restore() end
    end,
    restore = function() Chat.Restore() end,
    frame = function(elapsed)
        if ns.Settings.ModernChat() then ns.Profiler.Run("bubbles", Chat.Update, elapsed) end
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
