-- A whisper tab opens a temporary window past NUM_CHAT_WINDOWS (ChatFrame11+), listed in
-- CHAT_FRAMES. Modern chat treats it like any other window and restores it as well.
local h = ...

local function openWhisper()
    local cf = CreateFrame("ScrollingMessageFrame", "ChatFrame11", UIParent)
    cf.GetID = function() return 11 end
    cf.GetNumMessages = function() return 0 end
    cf.SetFading = function() end
    cf.isDocked = 1
    ChatFrame11 = cf
    ChatFrame11Tab = CreateFrame("Button", "ChatFrame11Tab", UIParent)
    ChatFrame11Tab:Show()
    ChatFrame11Tab._alpha = 0.6
    ChatFrame11EditBox = CreateFrame("EditBox", "ChatFrame11EditBox", cf)
    ChatFrame11EditBox:Show()
    ChatFrame11EditBox:EnableMouse(true)
    CHAT_FRAMES[#CHAT_FRAMES + 1] = "ChatFrame11"
    FCF_OpenTemporaryWindow("WHISPER", "Zoria")
end

local function setup()
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
end

h.test("A temporary whisper window gets Modern chat", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ns.StripAllChat()
    openWhisper()
    ns.SyncVisibleEdits()
    ns.UpdateChat(1)
    A.near(ChatFrame11Tab._alpha, 0, 0.01, "whisper tab hidden like the others")
    A.falsy(ChatFrame11EditBox:IsMouseEnabled(), "whisper input lets clicks through")
end)

h.test("A whisper tab with a new message stays visible", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ns.StripAllChat()
    openWhisper()
    ChatFrame11Tab.alerting = true
    ns.UpdateChat(1)
    A.near(ChatFrame11Tab._alpha, 1, 0.01, "alerting whisper tab visible")
end)

h.test("Restore reaches a temporary window, even after it closed", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ns.StripAllChat()
    openWhisper()
    ns.SyncVisibleEdits()
    ns.UpdateChat(1)
    CHAT_FRAMES[#CHAT_FRAMES] = nil -- Blizzard drops a closed temporary window from the list
    QuietUICharDB.chat = false
    ns.RestoreChat()
    A.near(ChatFrame11Tab._alpha, 0.6, 0.01, "whisper tab alpha back")
    A.ok(ChatFrame11EditBox:IsMouseEnabled(), "whisper input mouse back")
end)
