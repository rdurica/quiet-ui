local _, ns = ...

-- The /quiet dump window: the report in a selected read-only box and the issue link.
-- Named so UISpecialFrames can close it on Escape; no saved point, it opens centred.

local Setup = ns.Setup

local WIDTH, HEIGHT, SIDE = 640, 440, 20
local NOTE = "Press Ctrl+C to copy the report, then open the link to create an issue."

-- The text is read-only: any change puts the original back.
local function Lock(box, close)
    local text = ""
    box.lock = function(value) text = value or "" end
    box:SetScript("OnTextChanged", function(self, user)
        if user and self:GetText() ~= text then self:SetText(text) end
    end)
    local function select() box:HighlightText() end
    local gained = box:GetScript("OnEditFocusGained")
    box:SetScript("OnEditFocusGained", function(self, ...)
        if gained then gained(self, ...) end
        select()
    end)
    box:SetScript("OnMouseUp", select)
    box:SetScript("OnEscapePressed", close)
end

local function Create()
    local win = CreateFrame("Frame", "QuietUIDump", UIParent)
    win:SetSize(WIDTH, HEIGHT)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:EnableMouse(true)
    win:Hide()
    local function close() win:Hide() end
    Setup.Window(win, "QuietUI report", close)

    local handle = CreateFrame("Frame", nil, win)
    handle:SetPoint("TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", -Setup.HEADER, 0)
    handle:SetHeight(Setup.HEADER)
    handle:SetFrameLevel(win:GetFrameLevel() + 10)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() win:StartMoving() end)
    handle:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)
    if type(win.SetMovable) == "function" then win:SetMovable(true) end
    if type(win.SetClampedToScreen) == "function" then win:SetClampedToScreen(true) end

    local inner = WIDTH - 2 * SIDE
    local note = Setup.Note(win, NOTE)
    note:SetWidth(inner)
    note:SetPoint("TOPLEFT", SIDE, -(Setup.HEADER + 14))

    local back = CreateFrame("Frame", nil, win)
    back:SetPoint("TOPLEFT", SIDE, -(Setup.HEADER + 40))
    back:SetSize(inner, HEIGHT - Setup.HEADER - 40 - 70)
    Setup.Control(back, Setup.Colors().track)
    local scroll = CreateFrame("ScrollFrame", nil, back)
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    local report = CreateFrame("EditBox", nil, scroll)
    report:SetMultiLine(true)
    report:SetFontObject("GameFontHighlight")
    report:SetAutoFocus(false)
    report:SetMaxLetters(0)
    report:SetWidth(inner - 12)
    report:SetHeight(HEIGHT)
    scroll:SetScrollChild(report)
    Lock(report, close)

    local link = Setup.Field(win, inner, 2000)
    link:SetPoint("BOTTOMLEFT", SIDE, 24)
    Lock(link, close)

    win.report, win.link = report, link
    return win
end

function Setup.ShowDump()
    local S = Setup.state
    S.dump = S.dump or Create()
    local win = S.dump
    local text, url = ns.Dump.Build(), ns.Dump.IssueURL()
    win.report.lock(text); win.report:SetText(text)
    win.link.lock(url); win.link:SetText(url)
    win:Show()
    ns.RaiseDialog(win)
    if UISpecialFrames then
        local listed
        for _, name in ipairs(UISpecialFrames) do if name == "QuietUIDump" then listed = true end end
        if not listed then UISpecialFrames[#UISpecialFrames + 1] = "QuietUIDump" end
    end
    win.report:SetFocus()
    win.report:HighlightText()
end
