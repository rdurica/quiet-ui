local _, ns = ...

-- Chrome stripping per window, restore and re-strip.

local Chat = ns.Chat

local CHAT_CHROME = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameToggleVoiceSelfMuteButton",
    "ChatFrameToggleVoiceSelfDeafButton",
    "TextToSpeechButton",
    "QuickJoinToastButton",
    "FriendsMicroButton",
}

local CHAT_BUTTON_SUFFIX = {
    "ButtonFrame",
    "ButtonFrameUpButton",
    "ButtonFrameDownButton",
    "ButtonFrameBottomButton",
    "ButtonFrameMinimizeButton",
    "MinimizeButton",
}

local TAB_SUFFIX = {
    "Left", "Middle", "Right",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "Glow",
}

local TAB_KEYS = {
    "leftTexture", "middleTexture", "rightTexture",
    "Left", "Middle", "Right",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "HighlightTexture", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "glow", "Glow",
}

local stripping = false
local chromeStripped = false
local function StripTab(tab)
    if not tab or not ns.DB().enabled or not ns.Settings.ModernChat() then return end
    local marked = ns.MarkingChat
    ns.MarkingChat = true
    ns.HideTextures(tab)
    local name = ns.FrameName(tab)
    if name then
        for _, suffix in ipairs(TAB_SUFFIX) do
            ns.ForceTextureHidden(_G[name .. suffix])
        end
    end
    for _, key in ipairs(TAB_KEYS) do
        ns.ForceTextureHidden(tab[key])
    end
    if not tab._quietClick and tab.HookScript then
        tab._quietClick = true
        tab:HookScript("OnClick", function()
            if ns.DB().enabled and ns.Settings.ModernChat() then StripTab(tab) end
        end)
    end
    ns.MarkingChat = marked
end
function Chat.Restore()
    Chat.RestoreTabs()
    Chat.HideCopyBox()
    Chat.RestoreEdits()
    ns.ReleaseChatHold()
    chromeStripped = false
    for i = 1, Chat.ChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame and frame._quietBubbles then
            frame._quietStripped = nil
            frame._quietHover = false
            frame._quietCatcherAt = nil
            frame._quietTextSig = nil
            if frame._quietCatcher then frame._quietCatcher:Hide() end
            Chat.HideActive(frame)
            Chat.RestoreFonts(frame)
        elseif frame then
            frame._quietStripped = nil
        end
    end
end

------------------------------------------------------------------------------
-- Chat windows
------------------------------------------------------------------------------
local function MarkStripped(frame)
    if not frame then return end
    if frame._quietLines and #frame._quietLines > 0 then
        Chat.HideNativeText(frame, true)
    end
    frame._quietStripped = true
    frame._quietDirty = true
end

local function StripChat(frame)
    if not frame or not ns.DB().enabled then return end
    ns.HideTextures(frame)
    local name = ns.FrameName(frame)
    ns.HideBackground(frame.Background or (name and _G[name .. "Background"]))
    if frame.NineSlice then
        ns.HideTextures(frame.NineSlice)
    end
    ns.Bars.Mute(frame.ScrollBar)
    ns.Bars.Mute(frame.ScrollToBottomButton)
    ns.Bars.Mute(frame.buttonFrame)
    ns.Bars.Mute(frame.TextToSpeechButton)
    if not name then
        Chat.BindBubbles(frame)
        MarkStripped(frame)
        return
    end
    for _, suffix in ipairs(CHAT_BUTTON_SUFFIX) do
        ns.Bars.Mute(_G[name .. suffix])
    end
    StripTab(_G[name .. "Tab"])
    Chat.BindEdit(_G[name .. "EditBox"])
    Chat.BindBubbles(frame)
    MarkStripped(frame)
end

local function StripDock()
    local dock = GeneralDockManager
    if not dock then return end
    ns.HideTextures(dock)
    ns.HideBackground(dock.Background or _G.GeneralDockManagerBackground)
end

function Chat.StripAll(force)
    if stripping or not ns.DB().enabled or not ns.Settings.ModernChat() then return end
    stripping = true
    ns.MarkingChat = true
    if force then chromeStripped = false end
    Chat.NoteTemporary()
    local ok, err = pcall(function()
        for i = 1, Chat.ChatCount() do
            local frame = _G["ChatFrame" .. i]
            if frame and (force or not frame._quietStripped) then
                StripChat(frame)
            end
        end
        if not chromeStripped then
            for _, name in ipairs(CHAT_CHROME) do
                ns.Bars.Mute(_G[name])
            end
            StripDock()
            chromeStripped = true
        end
    end)
    ns.MarkingChat = false
    stripping = false
    Chat.PlaceTabs()
    if not ok then ns.Report("chat", err) end
end

-- Blizzard rewrote one window's alpha or color; strip only that window.
-- Only windows Update and Restore walk.
local function OwnChatFrame(frame)
    for i = 1, Chat.ChatCount() do
        if _G["ChatFrame" .. i] == frame then return true end
    end
    return false
end

function Chat.Restrip(frame)
    if stripping or not ns.Usable(frame) or not OwnChatFrame(frame) or not ns.DB().enabled
        or not ns.Settings.ModernChat() then return end
    stripping = true
    ns.MarkingChat = true
    local ok, err = pcall(StripChat, frame)
    ns.MarkingChat = false
    stripping = false
    Chat.PlaceTabs()
    if not ok then ns.Report("chat", err) end
end
