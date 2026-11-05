-- chatTabs = "top": Modern chat leaves the tabs at Blizzard's own points above the chat.
local h = ...

local EDIT_H, TAB_H, WINDOW_BOTTOM = 32, 24, 300
local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
    FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

-- Blizzard's own layout: dock and undocked tab sit above their window.
local function blizzardLayout(t, bottom)
    local dock = GeneralDockManager
    dock:SetSize(300, TAB_H)
    dock:ClearAllPoints()
    dock:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 3)
    for _, i in ipairs({ 1, 2 }) do
        local win = _G["ChatFrame" .. i]
        win:SetSize(300, 150)
        win.GetBottom = function() return bottom or WINDOW_BOTTOM end
        _G["ChatFrame" .. i .. "EditBox"]:SetSize(300, EDIT_H)
    end
    local tab = ChatFrame2Tab
    tab:SetSize(80, TAB_H)
    tab:ClearAllPoints()
    tab:SetPoint("BOTTOMLEFT", ChatFrame2, "TOPLEFT", 0, 3)
end

local function snapshot(frame)
    local out = {}
    for i = 1, frame:GetNumPoints() do out[i] = { frame:GetPoint(i) } end
    return out
end

local function pointTo(frame, target)
    for i = 1, frame:GetNumPoints() do
        local p, rel, relPoint, x, y = frame:GetPoint(i)
        if rel == target then return p, relPoint, x or 0, y or 0 end
    end
end

local function assertBelow(A, frame, window, msg)
    local p, relPoint, _, y = pointTo(frame, window)
    A.ok(p ~= nil, msg .. ": not anchored to its window")
    A.ok(p:sub(1, 3) == "TOP", msg .. ": own point " .. tostring(p) .. " is not on the TOP side")
    A.ok(relPoint:sub(1, 6) == "BOTTOM", msg .. ": window point " .. tostring(relPoint) .. " is not BOTTOM")
    A.near(y, -EDIT_H, 0.5, msg .. ": y offset must be minus the edit box height")
end

local function setup(t)
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    blizzardLayout(t)
end

local function top()
    QuietUICharDB.chatTabs = "top"
end

h.test("Without chatTabs docked and undocked tabs sit below their window", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    ns.Chat.StripAll()
    assertBelow(A, GeneralDockManager, ChatFrame1, "dock")
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "tab")
end)

h.test("Top keeps Blizzard's points for the dock and undocked tabs", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    top()
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    ns.Chat.StripAll()
    A.deep(snapshot(GeneralDockManager), dock0, "dock points")
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab points")
end)

h.test("Top does not undo Blizzard re-anchoring the tabs", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    top()
    ns.Chat.StripAll()
    ChatFrame2Tab:ClearAllPoints()
    ChatFrame2Tab:SetPoint("BOTTOMLEFT", ChatFrame2, "TOPLEFT", 40, 9)
    local tab1 = snapshot(ChatFrame2Tab)
    FCF_SetTabPosition(ChatFrame2, 0)
    FCF_DockUpdate()
    A.deep(snapshot(ChatFrame2Tab), tab1, "tab after hooks")
    GeneralDockManager:ClearAllPoints()
    GeneralDockManager:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 5, 7)
    local dock1 = snapshot(GeneralDockManager)
    FCF_RestorePositionAndDimensions(ChatFrame1)
    A.deep(snapshot(GeneralDockManager), dock1, "dock after restore position")
end)

h.test("Top: tabs hidden until hovered and a flashing tab stays visible", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    top()
    for _, f in ipairs({ ChatFrame1Tab, ChatFrame2Tab }) do f:Show(); f._alpha = 0.4 end
    GeneralDockManager:Show()
    ns.Chat.StripAll()
    ns.Chat.Update(1)
    A.near(ChatFrame1Tab._alpha, 0, 0.01, "docked tab hidden")
    A.near(ChatFrame2Tab._alpha, 0, 0.01, "undocked tab hidden")
    GeneralDockManager:SetMouseOver(true)
    t.mock.state.cursor = { 41, 41 } -- hover comes with a moved pointer
    ns.Chat.Update(0.01)
    A.near(ChatFrame1Tab._alpha, 1, 0.01, "tab row hover shows the tabs")
    GeneralDockManager:SetMouseOver(false)
    t.mock.state.cursor = { 42, 42 } -- hover comes with a moved pointer
    ns.Chat.Update(1)
    ChatFrame2Tab.alerting = true
    ns.Chat.Update(1)
    A.near(ChatFrame2Tab._alpha, 1, 0.01, "alerting tab visible")
    A.near(ChatFrame1Tab._alpha, 0, 0.01, "quiet tab hidden")
end)

h.test("Top: hovering the tab row shows the window's faded lines", function(t)
    local A, mock = t.assert, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatTabs = "top" }
    t.boot()
    local events = mock:eventFrame("PLAYER_LOGIN")
    local function tick(elapsed) events._scripts.OnUpdate(events, elapsed) end
    GeneralDockManager:Show()
    local before = #mock.frames
    ChatFrame1:AddMessage("old line", 1, 1, 1)
    tick(1 / 60)
    local bubble
    for i = before + 1, #mock.frames do
        local f = mock.frames[i]
        if f._parent == ChatFrame1 and f._scripts.OnEnter then bubble = f break end
    end
    A.ok(bubble, "precondition: a chat line created a bubble")
    mock:advance(20)
    tick(1)
    tick(1)
    A.falsy(bubble:IsShown() and (bubble._alpha or 1) > 0.01, "precondition: the line faded")
    GeneralDockManager:SetMouseOver(true)
    mock.state.cursor = { 10, 10 }
    tick(1 / 60)
    tick(1 / 60)
    A.ok(bubble:IsShown() and (bubble._alpha or 1) > 0.5, "tab row hover shows the faded line")
end)

h.test("Switching Bottom to Top returns the tabs to Blizzard's points", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    ns.Chat.StripAll()
    assertBelow(A, GeneralDockManager, ChatFrame1, "dock below")
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "tab below")
    top()
    ns.Chat.StripAll(true)
    A.deep(snapshot(GeneralDockManager), dock0, "dock back at Blizzard's points")
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab back at Blizzard's points")
end)

h.test("Switching Top to Bottom moves the tabs below and keeps Blizzard's points as originals", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    top()
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    ns.Chat.StripAll()
    QuietUICharDB.chatTabs = nil
    ns.Chat.StripAll(true)
    assertBelow(A, GeneralDockManager, ChatFrame1, "dock below")
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "tab below")
    QuietUICharDB.chat = false
    ns.Chat.Restore()
    A.deep(snapshot(GeneralDockManager), dock0, "dock originals")
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab originals")
end)

h.test("Top then Modern chat off restores points and tab alpha", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    top()
    ChatFrame2Tab:Show(); ChatFrame2Tab._alpha = 0.4
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    ns.Chat.StripAll()
    ns.Chat.Update(1)
    QuietUICharDB.chat = false
    ns.Chat.Restore()
    A.deep(snapshot(GeneralDockManager), dock0, "dock points")
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab points")
    A.near(ChatFrame2Tab._alpha, 0.4, 0.01, "original alpha back")
end)

h.test("Top then disabling QuietUI restores points and tab alpha", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    top()
    ChatFrame2Tab:Show(); ChatFrame2Tab._alpha = 0.4
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    ns.Chat.StripAll()
    ns.Chat.Update(1)
    QuietUIDB.enabled = false
    ns.ApplyAll()
    A.deep(snapshot(GeneralDockManager), dock0, "dock points")
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab points")
    A.near(ChatFrame2Tab._alpha, 0.4, 0.01, "original alpha back")
end)
