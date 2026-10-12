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

h.test("Tab alpha is left to Blizzard", function(t)
    local ns, A = t.ns, t.assert
    setup(t)
    local tabs = { GeneralDockManager, ChatFrame1Tab, ChatFrame2Tab }
    for _, f in ipairs(tabs) do f._alpha = 0.4; f._calls.SetAlpha = 0 end
    ns.StripAllChat()
    FCF_SetTabPosition(ChatFrame2, 0)
    FCF_DockUpdate()
    ns.RestoreChat()
    for _, f in ipairs(tabs) do
        A.eq(f._calls.SetAlpha or 0, 0, f:GetName() .. ": QuietUI called SetAlpha")
        A.eq(f._alpha, 0.4, f:GetName() .. ": alpha changed")
    end
    -- Blizzard changing the alpha is not fought.
    ChatFrame2Tab:SetAlpha(1)
    FCF_SetTabPosition(ChatFrame2, 0)
    A.eq(ChatFrame2Tab._alpha, 1, "tab alpha was held")
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
