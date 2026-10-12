-- Modern chat puts the chat tabs below the chat, under the input strip, and restores them.
-- Contract used here (anchor relationships, not exact strings):
--   * "below": a point on the tab/dock whose relativeTo is the chat window, with the tab's
--     own point on its TOP side, the window point on its BOTTOM side, and a y offset equal
--     to minus the window's edit box height (the input keeps its place under the chat).
--   * clamp: when the window bottom minus strip and tab height falls under UIParent's
--     bottom, the tab is anchored to UIParent with BOTTOM points on both sides, and the
--     edit box draws over it (higher strata, or same strata and higher frame level).
--   * originals: the points Blizzard set are restored verbatim.
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

local function drawsOver(top, under)
    local a, b = STRATA[top:GetFrameStrata()] or 0, STRATA[under:GetFrameStrata()] or 0
    return a > b or (a == b and top:GetFrameLevel() > under:GetFrameLevel())
end

h.test("Docked tabs sit below ChatFrame1 under the input strip", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    ns.StripAllChat()
    assertBelow(A, GeneralDockManager, ChatFrame1, "GeneralDockManager")
end)

h.test("An undocked window's tab sits below that window under its input strip", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    ns.StripAllChat()
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "ChatFrame2Tab")
end)

h.test("Blizzard re-anchoring an undocked tab above is undone", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    ns.StripAllChat()
    local function blizzardAbove()
        ChatFrame2Tab:ClearAllPoints()
        ChatFrame2Tab:SetPoint("BOTTOMLEFT", ChatFrame2, "TOPLEFT", 0, 3)
    end
    blizzardAbove()
    FCF_SetTabPosition(ChatFrame2, 0)
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "after FCF_SetTabPosition")
    blizzardAbove()
    FCF_DockUpdate()
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "after FCF_DockUpdate")
    GeneralDockManager:ClearAllPoints()
    GeneralDockManager:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 3)
    FCF_RestorePositionAndDimensions(ChatFrame1)
    assertBelow(A, GeneralDockManager, ChatFrame1, "dock after FCF_RestorePositionAndDimensions")
end)

h.test("Tabs below the screen bottom clamp to it and the focused input draws over them", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    blizzardLayout(t, 10) -- 10 - strip - tab height is under UIParent's bottom (0)
    ns.StripAllChat()
    for _, pair in ipairs({ { GeneralDockManager, ChatFrame1EditBox }, { ChatFrame2Tab, ChatFrame2EditBox } }) do
        local tab, edit = pair[1], pair[2]
        local p, relPoint = pointTo(tab, UIParent)
        A.ok(p ~= nil, tab:GetName() .. " not anchored to UIParent")
        A.ok(p:find("BOTTOM", 1, true), tab:GetName() .. " own point " .. tostring(p) .. " not BOTTOM")
        A.ok(relPoint:find("BOTTOM", 1, true), tab:GetName() .. " screen point " .. tostring(relPoint) .. " not BOTTOM")
        A.ok(drawsOver(edit, tab), edit:GetName() .. " must draw over " .. tab:GetName())
    end
end)

-- Tabs show only on hover (the tab row) or while a tab flashes for new messages.
-- elapsed 1 is past the fade-out, so a hidden tab reaches 0.
h.test("Tabs are hidden until hovered", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    for _, f in ipairs({ ChatFrame1Tab, ChatFrame2Tab }) do f:Show(); f._alpha = 0.4 end
    GeneralDockManager:Show()
    ns.StripAllChat()
    ns.UpdateChat(1)
    A.near(ChatFrame1Tab._alpha, 0, 0.01, "docked tab hidden")
    A.near(ChatFrame2Tab._alpha, 0, 0.01, "undocked tab hidden")
    -- Blizzard's own fade does not bring it back.
    ChatFrame1Tab:SetAlpha(0.4)
    A.near(ChatFrame1Tab._alpha, 0, 0.01, "Blizzard alpha held off")
    GeneralDockManager:SetMouseOver(true)
    ns.UpdateChat(0.01)
    A.near(ChatFrame1Tab._alpha, 1, 0.01, "dock hover shows the tabs")
    A.near(ChatFrame2Tab._alpha, 1, 0.01, "dock hover shows every tab")
    GeneralDockManager:SetMouseOver(false)
    ns.UpdateChat(1)
    A.near(ChatFrame1Tab._alpha, 0, 0.01, "hidden again after hover")
    ChatFrame2Tab:SetMouseOver(true)
    ns.UpdateChat(0.01)
    A.near(ChatFrame2Tab._alpha, 1, 0.01, "tab hover shows it")
end)

h.test("A tab with new messages stays visible", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    for _, f in ipairs({ ChatFrame1Tab, ChatFrame2Tab }) do f:Show() end
    ns.StripAllChat()
    ChatFrame2Tab.alerting = true
    ns.UpdateChat(1)
    A.near(ChatFrame2Tab._alpha, 1, 0.01, "alerting tab visible")
    A.near(ChatFrame1Tab._alpha, 0, 0.01, "quiet tab hidden")
    ChatFrame2Tab.alerting = false
    ns.UpdateChat(1)
    A.near(ChatFrame2Tab._alpha, 0, 0.01, "hidden once read")
end)

h.test("Restore gives the tabs their alpha back", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    ChatFrame2Tab:Show(); ChatFrame2Tab._alpha = 0.4
    ns.StripAllChat()
    ns.UpdateChat(1)
    QuietUICharDB.chat = false
    ns.RestoreChat()
    A.near(ChatFrame2Tab._alpha, 0.4, 0.01, "original alpha back")
    ChatFrame2Tab:SetAlpha(0.7)
    A.near(ChatFrame2Tab._alpha, 0.7, 0.01, "Blizzard alpha not held after restore")
end)

h.test("Modern chat off restores the original dock and tab points", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    ns.StripAllChat()
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "moved")
    QuietUICharDB.chat = false
    ns.RestoreChat()
    A.deep(snapshot(GeneralDockManager), dock0, "dock points")
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab points")
    -- With Modern chat off a Blizzard re-anchor is left alone.
    FCF_SetTabPosition(ChatFrame2, 0)
    FCF_DockUpdate()
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab points after hooks")
end)

h.test("Disabling QuietUI restores the original dock and tab points", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    ns.StripAllChat()
    assertBelow(A, GeneralDockManager, ChatFrame1, "moved")
    QuietUIDB.enabled = false
    ns.ApplyAll() -- disabled: ApplyAll falls through to RestoreAll
    A.deep(snapshot(GeneralDockManager), dock0, "dock points")
    A.deep(snapshot(ChatFrame2Tab), tab0, "tab points")
end)

h.test("Re-enabling after a restore moves tabs below again and keeps Blizzard's points as originals", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    local dock0, tab0 = snapshot(GeneralDockManager), snapshot(ChatFrame2Tab)
    for _ = 1, 2 do
        QuietUIDB.enabled = true
        QuietUICharDB.chat = nil
        ns.StripAllChat(true)
        assertBelow(A, GeneralDockManager, ChatFrame1, "dock")
        assertBelow(A, ChatFrame2Tab, ChatFrame2, "tab")
        ns.RestoreChat()
        A.deep(snapshot(GeneralDockManager), dock0, "dock originals after cycle")
        A.deep(snapshot(ChatFrame2Tab), tab0, "tab originals after cycle")
    end
end)

h.test("Missing Blizzard tab functions and tabs do not break placement", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    FCF_SetTabPosition, FCF_RestorePositionAndDimensions, FCF_DockUpdate = nil, nil, nil
    ChatFrame3Tab = nil
    A.noThrow(function() ns.StripAllChat(true) end)
    assertBelow(A, GeneralDockManager, ChatFrame1, "dock")
    assertBelow(A, ChatFrame2Tab, ChatFrame2, "tab")
    A.noThrow(function() ns.RestoreChat() end)
    t.mock:drain()
    A.notPrinted(t.mock, "error (shown once)")
end)

-- Blizzard sizes the dock by anchoring both of its sides to ChatFrame1; with only one
-- point left it has no width and FCF_DockUpdate hides every tab as overflow.
local function spansWindow(A, frame, rel, msg)
    local left, right
    for i = 1, frame:GetNumPoints() do
        local p, r = frame:GetPoint(i)
        if r == rel and p:find("LEFT", 1, true) then left = true end
        if r == rel and p:find("RIGHT", 1, true) then right = true end
    end
    A.ok(left and right, msg .. ": needs a LEFT and a RIGHT point for its width")
end

h.test("The moved dock keeps its width from both sides of the window", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    ChatFrame1.GetLeft = function() return 20 end
    ChatFrame1.GetRight = function() return 320 end
    ns.StripAllChat()
    assertBelow(A, GeneralDockManager, ChatFrame1, "dock")
    spansWindow(A, GeneralDockManager, ChatFrame1, "dock below")
    ns.RestoreChat()
    blizzardLayout(t, 10)
    ChatFrame1.GetLeft = function() return 20 end
    ChatFrame1.GetRight = function() return 320 end
    ns.StripAllChat()
    spansWindow(A, GeneralDockManager, UIParent, "clamped dock")
end)

-- The unfocused input is invisible but still shown; it must not take clicks meant for
-- the tabs (a click there would open the last whisper).
h.test("The unfocused input lets clicks through to the tabs", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    local edit = ChatFrame1EditBox
    edit:Show()
    edit:EnableMouse(true)
    ns.StripAllChat()
    ns.SyncVisibleEdits()
    A.falsy(edit:IsMouseEnabled(), "unfocused input takes the mouse")
    edit:SetFocus()
    ns.SyncVisibleEdits()
    A.ok(edit:IsMouseEnabled(), "focused input must take the mouse")
    edit:ClearFocus()
    ns.SyncVisibleEdits()
    A.falsy(edit:IsMouseEnabled(), "input still takes the mouse after losing focus")
    ns.RestoreChat()
    A.ok(edit:IsMouseEnabled(), "restore gives the input its mouse back")
end)

-- Clicking a tab leaves the pointer on the tab row; that row counts as the chat block's
-- hover, so the selected window shows its lines, including faded ones.
h.test("Hovering the tab row shows the window's faded lines", function(t)
    local A, mock = t.assert, t.mock
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
