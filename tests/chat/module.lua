-- Chat module (settings.modules.chat): off means Blizzard's chat chrome stays and no input history is
-- added or applied. Missing means on.
local h = ...

local TAB_H, EDIT_H = 24, 32

local function blizzardLayout()
    GeneralDockManager:SetSize(300, TAB_H)
    GeneralDockManager:ClearAllPoints()
    GeneralDockManager:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 3)
    for _, i in ipairs({ 1, 2 }) do
        local win = _G["ChatFrame" .. i]
        win:SetSize(300, 150)
        win.GetBottom = function() return 300 end
        _G["ChatFrame" .. i .. "EditBox"]:SetSize(300, EDIT_H)
    end
    ChatFrame2Tab:SetSize(80, TAB_H)
    ChatFrame2Tab:ClearAllPoints()
    ChatFrame2Tab:SetPoint("BOTTOMLEFT", ChatFrame2, "TOPLEFT", 0, 3)
    ChatFrame2Tab:Show()
end

local function points(frame)
    local out = {}
    for i = 1, frame:GetNumPoints() do out[i] = { frame:GetPoint(i) } end
    return out
end

local function sig(frame)
    local out = {}
    for i = 1, frame:GetNumPoints() do out[i] = table.concat({ tostring((select(1, frame:GetPoint(i)))),
        tostring((select(3, frame:GetPoint(i)))), tostring((select(5, frame:GetPoint(i)))) }, "/") end
    return table.concat(out, ";")
end

local function sig0(list)
    local out = {}
    for i, p in ipairs(list) do out[i] = table.concat({ tostring(p[1]), tostring(p[3]), tostring(p[5]) }, "/") end
    return table.concat(out, ";")
end

local function start(t, modules, char)
    QuietUIDB = { enabled = true }
    QuietUICharDB = char or {}
    QuietUICharDB.modules = modules
    blizzardLayout()
    local native = ChatFrame1:CreateFontString(nil, "ARTWORK")
    local before = { dock = points(GeneralDockManager), tab = points(ChatFrame2Tab), tabAlpha = ChatFrame2Tab._alpha }
    t.boot()
    return before, native
end

local function settle(t)
    for _ = 1, 20 do t.mock:tick(0.1) end
    t.mock:drain()
end

h.test("Chat on (missing): boot restyles the tabs and hides native text, so the chrome test below can fail", function(t)
    local A = t.assert
    local before, native = start(t, nil)
    settle(t)
    ChatFrame1:AddMessage("hello")
    A.ok(sig(ChatFrame2Tab) ~= sig0(before.tab), "tab was moved with Chat on")
    A.alpha(native, 0, "native text hidden with Chat on")
end)

h.test("Chat off: ApplyAll and the frame phases leave Blizzard's tabs, text and input chrome alone", function(t)
    local A, ns = t.assert, t.ns
    local before, native = start(t, { chat = false })
    ns.ApplyAll()
    ChatFrame1:AddMessage("hello")
    settle(t)
    A.deep(points(GeneralDockManager), before.dock, "dock points")
    A.deep(points(ChatFrame2Tab), before.tab, "tab points")
    A.eq(ChatFrame2Tab._alpha, before.tabAlpha, "tab alpha")
    A.alpha(native, 1, "native chat text stays visible")
    A.alpha(ChatFrame1EditBoxLeft, 1, "input chrome stays")
    A.alpha(ChatFrame1Background, 1, "window background stays")
end)

h.test("Chat off: the chat hooks do nothing when their globals run", function(t)
    local A = t.assert
    start(t, { chat = false })
    -- Blizzard lays its own chrome out again; a hook that ran would restyle it.
    blizzardLayout()
    local dock, tab = points(GeneralDockManager), points(ChatFrame2Tab)
    FCF_DockUpdate()
    FCF_SetTabPosition()
    FCF_RestorePositionAndDimensions()
    FCF_SetWindowAlpha(ChatFrame1)
    FCF_SetWindowColor(ChatFrame1)
    settle(t)
    A.deep(points(GeneralDockManager), dock, "dock points")
    A.deep(points(ChatFrame2Tab), tab, "tab points")
end)

h.test("Chat off: no input history is added, stored or applied", function(t)
    local A, ns = t.assert, t.ns
    start(t, { chat = false }, { chatHistory = { "one", "two" } })
    ns.ApplyAll()
    A.eq(ChatFrame1EditBox._history, nil, "stored lines are not put back into the input")
    A.eq(ChatFrame1EditBox:GetHistoryLines(), 32, "line limit untouched")
    ChatFrame1EditBox:AddHistoryLine("sent line")
    A.deep(QuietUICharDB.chatHistory, { "one", "two" }, "a sent line is not stored")
end)

h.test("Chat on (missing): stored history comes back and a sent line is stored", function(t)
    local A, ns = t.assert, t.ns
    start(t, nil, { chatHistory = { "one", "two" } })
    ns.ApplyAll()
    A.deep(ChatFrame1EditBox._history, { "one", "two" }, "replayed")
    ChatFrame1EditBox:AddHistoryLine("sent line")
    A.deep(QuietUICharDB.chatHistory, { "one", "two", "sent line" }, "stored")
end)

h.test("Chat turned off after history was bound: later lines are not stored", function(t)
    local A = t.assert
    start(t, nil)
    ChatFrame1EditBox:AddHistoryLine("while on")
    QuietUICharDB.modules = { chat = false }
    ChatFrame1EditBox:AddHistoryLine("after off")
    A.deep(QuietUICharDB.chatHistory, { "while on" }, "only the line sent while on")
end)
