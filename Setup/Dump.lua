local _, ns = ...

-- The /quiet dump window: the issue link (step 1) and the report in a read-only box (step 2).
-- Named so UISpecialFrames can close it on Escape; no saved point, it opens centred.

local Setup = ns.Setup

local WIDTH, HEIGHT, SIDE = 640, 440, 20
local STEP1 = "1. Click the link, press Ctrl+C, and open it in your browser."
local STEP2 = "2. Click the report, press Ctrl+C, and paste it into the issue."

-- The text is read-only: any change puts the original back.
local function Lock(box, close)
    local function selectAll() box:HighlightText() end
    local text = ""
    box.lock = function(value) text = value or "" end
    box:SetScript("OnTextChanged", function(self, user)
        if user and self:GetText() ~= text then
            if type(self.IsInIMECompositionMode) == "function" and self:IsInIMECompositionMode() then return end
            self:SetText(text)
            selectAll()
        end
    end)
    local gained = box:GetScript("OnEditFocusGained")
    box:SetScript("OnEditFocusGained", function(self, ...)
        if gained then gained(self, ...) end
        selectAll()
    end)
    box:SetScript("OnMouseUp", selectAll)
    box:SetScript("OnEscapePressed", close)
end

local LINE = 14

local function Range(scroll)
    local range = type(scroll.GetVerticalScrollRange) == "function" and scroll:GetVerticalScrollRange()
    return type(range) == "number" and range > 0 and range or 0
end

local function ScrollTo(scroll, value)
    scroll:SetVerticalScroll(math.max(0, math.min(Range(scroll), value)))
end

-- Wheel scrolling, the cursor kept in view and a box as tall as its text.
local function Scrollable(scroll, report, measure)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        ScrollTo(self, self:GetVerticalScroll() - delta * LINE * 3)
    end)
    report:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local top, view = -(tonumber(y) or 0), scroll:GetHeight() or 0
        local offset = scroll:GetVerticalScroll()
        if top < offset then
            ScrollTo(scroll, top)
        elseif view > 0 and top + (tonumber(height) or LINE) > offset + view then
            ScrollTo(scroll, top + (tonumber(height) or LINE) - view)
        end
    end)
    report.fit = function()
        measure:SetText(report:GetText())
        report:SetHeight(math.max(scroll:GetHeight() or 0, (measure:GetStringHeight() or 0) + LINE))
    end
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
    local step1 = Setup.Muted(win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    step1:SetPoint("TOPLEFT", SIDE, -(Setup.HEADER + 14))
    step1:SetText(STEP1)

    local link = Setup.Field(win, inner, 2000)
    link:SetPoint("TOPLEFT", SIDE, -(Setup.HEADER + 34))
    Lock(link, close)

    local step2 = Setup.Muted(win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    step2:SetPoint("TOPLEFT", SIDE, -(Setup.HEADER + 72))
    step2:SetText(STEP2)

    local back = CreateFrame("Frame", nil, win)
    back:SetPoint("TOPLEFT", SIDE, -(Setup.HEADER + 92))
    back:SetSize(inner, HEIGHT - Setup.HEADER - 92 - 24)
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
    -- The box has no text insets, so the measure wraps at the same width.
    local measure = scroll:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    measure:SetWidth(inner - 12)
    measure:Hide()
    Scrollable(scroll, report, measure)
    Lock(report, close)
    local gained, lost = report:GetScript("OnEditFocusGained"), report:GetScript("OnEditFocusLost")
    report:SetScript("OnEditFocusGained", function(self, ...)
        Setup.EdgeColor(back, Setup.Colors().accent)
        if gained then gained(self, ...) end
    end)
    report:SetScript("OnEditFocusLost", function(self, ...)
        Setup.EdgeColor(back, Setup.Colors().border)
        if lost then lost(self, ...) end
    end)

    win.report, win.link = report, link
    return win
end

function Setup.ShowDump()
    local S = Setup.state
    S.dump = S.dump or Create()
    local win = S.dump
    local text, url = ns.Dump.Build(), ns.Dump.IssueURL()
    win.report.lock(text); win.report:SetText(text)
    win.report.fit()
    win.report:GetParent():SetVerticalScroll(0)
    win.link.lock(url); win.link:SetText(url)
    win:Show()
    ns.RaiseDialog(win)
    if UISpecialFrames then
        local listed
        for _, name in ipairs(UISpecialFrames) do if name == "QuietUIDump" then listed = true end end
        if not listed then UISpecialFrames[#UISpecialFrames + 1] = "QuietUIDump" end
    end
    win.link:SetFocus()
    win.link:HighlightText()
end
