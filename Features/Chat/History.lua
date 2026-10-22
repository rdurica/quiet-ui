local _, ns = ...

-- Sent lines survive reload and relog. The input box keeps its own native history,
-- walked with Alt+Up and Alt+Down.

local Chat = ns.Chat

local MAX_LINES = 50

-- Lines written back into a box must not be stored again by the hook.
local replaying = false
local bound = {}

local function Call(edit, method, ...)
    if type(edit[method]) ~= "function" then return false end
    return pcall(edit[method], edit, ...)
end

local function Replay(edit, line)
    replaying = true
    Call(edit, "AddHistoryLine", line)
    replaying = false
end

local function Store(source, line)
    if replaying or not ns.DB().enabled or type(line) ~= "string" or ns.IsSecret(line) or line == "" then return end
    local list = ns.Settings.ChatHistory()
    if list[#list] == line then return end
    list[#list + 1] = line
    while #list > MAX_LINES do table.remove(list, 1) end
    for i = 1, #bound do
        if bound[i] ~= source then Replay(bound[i], line) end
    end
end

local function BindHistory(edit)
    if edit._quietHistory or type(edit.AddHistoryLine) ~= "function" then return end
    if not pcall(hooksecurefunc, edit, "AddHistoryLine", Store) then return end
    edit._quietHistory = true
    bound[#bound + 1] = edit
    if type(edit.GetHistoryLines) == "function" then
        local ok, n = pcall(edit.GetHistoryLines, edit)
        if ok and type(n) == "number" and n < MAX_LINES and Call(edit, "SetHistoryLines", MAX_LINES) then
            edit._quietHistoryLines = n
        end
    end
    local list = ns.Settings.ChatHistory()
    for i = 1, #list do Replay(edit, list[i]) end
end
Chat.BindHistory = BindHistory

function Chat.ApplyHistory()
    if not ns.DB().enabled then return end
    for i = 1, Chat.ChatCount() do
        local edit = Chat.Window(i, "EditBox")
        if edit and ns.Usable(edit) then BindHistory(edit) end
    end
end

-- The stored lines stay; only the line limit goes back.
function Chat.RestoreHistory()
    for i = 1, Chat.ChatCount() do
        local edit = Chat.Window(i, "EditBox")
        if edit and edit._quietHistoryLines then
            Call(edit, "SetHistoryLines", edit._quietHistoryLines)
            edit._quietHistoryLines = nil
        end
    end
end
