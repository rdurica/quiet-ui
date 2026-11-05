local _, ns = ...

-- The calendar (Blizzard_Calendar): CalendarFrame with its parchment plates, the weekday header, the filter
-- dropdown and the month grid of CalendarDayButton1..42, the day context menu and the event windows. They take the
-- shared window and dialog chrome; the plate and day art is held, quiet rules part the grid, today gets an accent
-- border, the selected day a faint wash and days outside the month a dim overlay. Event and holiday art on a day
-- stays. Every lookup is by name and an absent frame is skipped. The calendar joins the movable windows.

local Modern = ns.Modern
local Calendar = {}
Modern.Calendar = Calendar

local DAYS = 42
local COLUMNS = 7
local ROWS = DAYS / COLUMNS
local STROKE = 6
-- The loose calendar plates Blizzard names on the frame, the weekday plates and the month / year plates.
local PLATE_PARTS = { "TopLeft", "TopMiddle", "TopRight", "LeftTop", "LeftMiddle", "LeftBottom", "RightTop",
    "RightMiddle", "RightBottom", "BottomLeft", "BottomMiddle", "BottomRight" }
local TODAY_ART = { "CalendarTodayTextureGlow", "CalendarTodayTexture" }
local HEADER_TEXT = { "CalendarMonthName", "CalendarYearName" }
local DIALOGS = { "CalendarViewEventFrame", "CalendarCreateEventFrame", "CalendarViewHolidayFrame",
    "CalendarViewRaidFrame", "CalendarMassInviteFrame" }
local MENUS = { "CalendarDayContextMenu", "CalendarContextMenu" }
-- A faint light wash on the selected day and a darkening over a day outside the shown month.
local WASH = { 0.9, 0.9, 0.9, 0.2 }
local DIM = { 0, 0, 0, 0.4 }

-- The area applied to the calendar frames, or nil while off; hooks are inert without it.
local state = { skin = nil }
local hooked = {}

local function IsTexture(obj)
    return ns.Usable(obj) and type(obj.GetObjectType) == "function" and obj:GetObjectType() == "Texture"
end

local function Hold(skin, obj)
    if IsTexture(obj) and type(obj.SetAlpha) == "function" then skin:Hold(obj) end
end

local function HoldName(skin, name)
    Hold(skin, _G[name])
end

local function DayButton(index)
    return _G["CalendarDayButton" .. index]
end

local function EachDay(fn)
    for index = 1, DAYS do
        local button = DayButton(index)
        if ns.Usable(button) then fn(button, index) end
    end
end

-- Blizzard's day art: the background, the date plate, the shading of a day outside the month and the hover /
-- selection highlight. The event, pending-invite and holiday art is left alone.
local function HoldDay(skin, button)
    if type(button.GetNormalTexture) == "function" then
        local ok, texture = pcall(button.GetNormalTexture, button)
        if ok then Hold(skin, texture) end
    end
    if type(button.GetHighlightTexture) == "function" then
        local ok, texture = pcall(button.GetHighlightTexture, button)
        if ok then Hold(skin, texture) end
    end
    local date = button.DateFrame
    if ns.Usable(date) then
        Hold(skin, date.Background)
        Modern.Ink(skin, date.Date, Modern.Theme().text)
    end
    local dark = button.DarkFrame
    if ns.Usable(dark) then
        Hold(skin, dark.Top)
        Hold(skin, dark.Bottom)
    end
end

-- Two strokes meeting at the tip: a bare month chevron.
local function Chevron(button, dir)
    local angle = dir == "left" and 45 or -45
    return { Modern.GlyphLine(button, STROKE, 2, 0, 2, angle), Modern.GlyphLine(button, STROKE, 2, 0, -2, -angle) }
end

local function Filter(skin, frame)
    local filter = _G.CalendarFilterButton or frame.FilterButton
    if not ns.Usable(filter) then return end
    Hold(skin, filter.Background)
    skin:Panel(filter)
    skin:Border(filter, Modern.Theme().outline)
    Modern.Ink(skin, filter.Text, Modern.Theme().text)
end

local function Dialogs(skin)
    local themed = {}
    for _, name in ipairs(DIALOGS) do
        local window = _G[name]
        if ns.Usable(window) then
            Modern.Dialog(skin, window)
            themed[window] = true
        end
    end
    -- Older clients name the day menu CalendarContextMenu; the same frame answers to both.
    for _, name in ipairs(MENUS) do
        local menu = _G[name]
        if ns.Usable(menu) and not themed[menu] then
            Modern.Dialog(skin, menu)
            themed[menu] = true
        end
    end
    local invite = _G.CalendarCreateEventInviteList
    if ns.Usable(invite) then Hold(skin, invite.Background) end
end

local function InkNames(skin)
    local theme = Modern.Theme()
    for index = 1, COLUMNS do Modern.Ink(skin, _G["CalendarWeekday" .. index .. "Name"], theme.text) end
    for _, name in ipairs(HEADER_TEXT) do Modern.Ink(skin, _G[name], theme.text) end
end

-- Quiet rules between the columns and rows, anchored to the grid's own day buttons.
local function Grid(skin, frame)
    if not ns.Usable(DayButton(1)) then return end
    local theme = Modern.Theme()
    local rules = skin:Own(frame, "grid rules", function()
        local list = {}
        local function Vertical(top, bottom)
            if not ns.Usable(top) or not ns.Usable(bottom) then return end
            local line = frame:CreateTexture(nil, "OVERLAY")
            line:SetWidth(1)
            line:SetPoint("TOPRIGHT", top, "TOPRIGHT", 0, 0)
            line:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", 0, 0)
            list[#list + 1] = line
        end
        local function Horizontal(left, right)
            if not ns.Usable(left) or not ns.Usable(right) then return end
            local line = frame:CreateTexture(nil, "OVERLAY")
            line:SetHeight(1)
            line:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 0)
            line:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
            list[#list + 1] = line
        end
        for column = 1, COLUMNS - 1 do Vertical(DayButton(column), DayButton((ROWS - 1) * COLUMNS + column)) end
        for row = 1, ROWS - 1 do
            Horizontal(DayButton((row - 1) * COLUMNS + 1), DayButton(row * COLUMNS))
        end
        return list
    end)
    for _, line in ipairs(rules) do
        line:SetColorTexture(unpack(theme.wellEdge))
        line:Show()
    end
end

local function TodayButton()
    local today = _G.CalendarTodayFrame
    if not ns.Usable(today) or type(today.IsShown) ~= "function" or not today:IsShown() then return end
    if type(today.GetParent) ~= "function" then return end
    return today:GetParent()
end

-- A thin accent border inside today's day button; none while today is not in the shown month.
local function PaintToday(skin)
    local theme = Modern.Theme()
    local today = TodayButton()
    EachDay(function(button)
        local parts = skin:Own(button, "today border", function()
            local list = {}
            local function Line(vertical, pointA, xA, yA, pointB, xB, yB)
                local line = button:CreateTexture(nil, "OVERLAY")
                if vertical then line:SetWidth(1) else line:SetHeight(1) end
                line:SetPoint(pointA, button, pointA, xA, yA)
                line:SetPoint(pointB, button, pointB, xB, yB)
                list[#list + 1] = line
            end
            Line(false, "TOPLEFT", 2, -2, "TOPRIGHT", -2, -2)
            Line(false, "BOTTOMLEFT", 2, 2, "BOTTOMRIGHT", -2, 2)
            Line(true, "TOPLEFT", 2, -2, "BOTTOMLEFT", 2, 2)
            Line(true, "TOPRIGHT", -2, -2, "BOTTOMRIGHT", -2, 2)
            return list
        end)
        local on = button == today
        for _, line in ipairs(parts) do
            line:SetColorTexture(unpack(theme.accent))
            line:SetShown(on)
        end
    end)
end

-- A faint light wash on the selected day; Blizzard's selection art is held instead.
local function PaintSelection(skin)
    local frame = _G.CalendarFrame
    local selected = ns.Usable(frame) and frame.selectedDayButton
    EachDay(function(button)
        local wash = skin:Own(button, "selection wash", function()
            local texture = button:CreateTexture(nil, "BACKGROUND", nil, -6)
            texture:SetAllPoints(button)
            return texture
        end)
        local on = button == selected
        if on then
            wash:SetColorTexture(unpack(WASH))
            wash:Show()
            if type(button.GetHighlightTexture) == "function" then
                local ok, texture = pcall(button.GetHighlightTexture, button)
                if ok then Hold(skin, texture) end
            end
        else
            wash:Hide()
        end
    end)
end

-- Days outside the shown month are dimmed by an own overlay; the button's alpha stays Blizzard's.
local function PaintDays(skin)
    EachDay(function(button)
        local dim = skin:Own(button, "outside month", function()
            local texture = button:CreateTexture(nil, "OVERLAY", nil, 7)
            texture:SetAllPoints(button)
            return texture
        end)
        dim:SetColorTexture(unpack(DIM))
        local offset = button.monthOffset
        dim:SetShown(type(offset) == "number" and not ns.IsSecret(offset) and offset ~= 0)
    end)
end

local function Repaint(skin)
    if not skin then return end
    PaintDays(skin)
    PaintSelection(skin)
    PaintToday(skin)
end

-- Blizzard refills the grid on a month change and marks the selected day; the calendar re-applies its own marks
-- then and whenever the window shows. Set once; inert while the area is off.
local function Follow(skin)
    local frame = _G.CalendarFrame
    if not hooked.frame and ns.Usable(frame) and type(frame.HookScript) == "function" then
        hooked.frame = true
        pcall(frame.HookScript, frame, "OnShow", function()
            if state.skin then ns.Profiler.Run("modern calendar", Repaint, state.skin) end
        end)
    end
    local function Again()
        if state.skin then ns.Profiler.Run("modern calendar", Repaint, state.skin) end
    end
    if not hooked.update then hooked.update = pcall(hooksecurefunc, "CalendarFrame_Update", Again) end
    if not hooked.selected then hooked.selected = pcall(hooksecurefunc, "CalendarFrame_SetSelectedDay", Again) end
end

function Calendar.Apply(skin)
    local frame = _G.CalendarFrame
    if not ns.Usable(frame) or type(frame.CreateTexture) ~= "function" then return end
    state.skin = skin
    skin:Remember(frame, "modern calendar", function() state.skin = nil end)

    Modern.Window(skin, frame, "CalendarFrame")
    Modern.Header(skin, frame)
    for _, part in ipairs(PLATE_PARTS) do HoldName(skin, "CalendarFrame" .. part .. "Texture") end
    for index = 1, COLUMNS do HoldName(skin, "CalendarWeekday" .. index .. "Background") end
    HoldName(skin, "CalendarMonthBackground")
    HoldName(skin, "CalendarYearBackground")
    for _, name in ipairs(TODAY_ART) do HoldName(skin, name) end
    EachDay(function(button) HoldDay(skin, button) end)

    if ns.Usable(_G.CalendarCloseButton) then
        Modern.GlyphButton(skin, _G.CalendarCloseButton, "close", Modern.CrossParts, "danger")
    end
    Modern.GlyphButton(skin, _G.CalendarPrevMonthButton, "previous month", function(button)
        return Chevron(button, "left")
    end, "text")
    Modern.GlyphButton(skin, _G.CalendarNextMonthButton, "next month", function(button)
        return Chevron(button, "right")
    end, "text")

    Filter(skin, frame)
    Dialogs(skin)
    InkNames(skin)
    Grid(skin, frame)
    Repaint(skin)
    Follow(skin)
end
