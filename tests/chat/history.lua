-- Sent chat lines are kept per character and walked with Alt+Up and Alt+Down.
local h = ...

local function setup()
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
end

h.test("A sent line is stored once, newest last", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ns.Chat.ApplyHistory()
    ChatFrame1EditBox:AddHistoryLine("hello")
    ChatFrame1EditBox:AddHistoryLine("hello")
    ChatFrame1EditBox:AddHistoryLine("/dance")
    ChatFrame1EditBox:AddHistoryLine("")
    A.deep(QuietUICharDB.chatHistory, { "hello", "/dance" }, "repeats and empty lines skipped")
end)

h.test("History keeps the last 50 lines", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ns.Chat.ApplyHistory()
    for i = 1, 60 do ChatFrame1EditBox:AddHistoryLine("line " .. i) end
    local list = QuietUICharDB.chatHistory
    A.eq(#list, 50, "capped")
    A.eq(list[1], "line 11", "oldest dropped")
    A.eq(list[50], "line 60", "newest kept")
end)

h.test("Stored lines come back into the input after a reload", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatHistory = { "one", "two" } }
    ns.Chat.ApplyHistory()
    A.deep(ChatFrame1EditBox._history, { "one", "two" }, "replayed oldest first")
    A.deep(QuietUICharDB.chatHistory, { "one", "two" }, "replay is not stored again")
end)

h.test("A line sent in one window reaches the other inputs", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ns.Chat.ApplyHistory()
    ChatFrame2EditBox:AddHistoryLine("party pull")
    A.deep(ChatFrame1EditBox._history, { "party pull" }, "shared history")
    A.deep(QuietUICharDB.chatHistory, { "party pull" }, "stored once")
end)

h.test("History works without Modern chat, and restore puts the line limit back", function(t)
    local ns, A = t.ns, t.assert
    setup()
    QuietUICharDB.chat = false
    ns.Chat.ApplyHistory()
    A.ok(ChatFrame1EditBox:GetHistoryLines() >= 50, "room for the stored lines")
    ns.Chat.RestoreHistory()
    A.eq(ChatFrame1EditBox:GetHistoryLines(), 32, "line limit back")
end)

h.test("Lines sent while QuietUI is off are not stored", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ns.Chat.ApplyHistory()
    QuietUIDB.enabled = false
    ChatFrame1EditBox:AddHistoryLine("quiet off")
    A.deep(QuietUICharDB.chatHistory, {}, "nothing stored")
end)

h.test("An input without history methods is left alone", function(t)
    local ns, A = t.ns, t.assert
    setup()
    ChatFrame1EditBox._absent = { AddHistoryLine = true, GetHistoryLines = true, SetHistoryLines = true }
    A.noThrow(function() ns.Chat.ApplyHistory() end, "apply")
    A.noThrow(function() ns.Chat.RestoreHistory() end, "restore")
end)
