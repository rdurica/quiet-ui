-- The Forever calendar (Blizzard_Calendar), shaped after the Blizzard calendar frame dump: CalendarFrame with its
-- loose top / side / bottom art, the weekday header (art plus names), the month and year plates and names, the
-- previous / next month buttons, the filter dropdown and the close button. The grid is CalendarDayButton1..42, each
-- with `day` and `monthOffset`, its normal and date-plate art, the highlight texture Blizzard uses for the selected
-- day, the dark frame of a day outside the month and the event, pending-invite and holiday textures. The view event,
-- create / edit event (with its invite list), holiday, raid and mass invite windows and the day menu are dialogs
-- (DialogBorderDarkTemplate and DialogHeaderTemplate). The month state comes from C_Calendar / C_DateAndTime (the
-- classic CalendarGetMonth / CalendarGetDate read the same data). `CalendarFrame_Update` refills the grid, as
-- Blizzard does when the month changes.
local C = {}

local DAYS = 42
local WEEKDAYS = 7
local FIRST_WEEKDAY = 3 -- 1 = Sunday; two days of the previous month lead the grid
local TODAY = { weekday = 7, month = 11, monthDay = 14, year = 2026 }
local MONTHS = {
    [-1] = { month = 10, year = 2026, firstWeekday = 6, numDays = 31 },
    [0] = { month = 11, year = 2026, firstWeekday = FIRST_WEEKDAY, numDays = 30 },
    [1] = { month = 12, year = 2026, firstWeekday = 1, numDays = 31 },
}

local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge",
    "LeftEdge", "RightEdge", "Center" }

local function label(file)
    return (tostring(file):gsub("^.*\\", ""))
end

local function texture(parent, file, layer, name)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture("Interface\\" .. file)
    t:SetAlpha(0.9)
    t._label = label(file)
    if name then
        _G[name] = t
        t.GetName = function() return name end
    end
    return t
end

local function text(parent, value, name)
    local f = parent:CreateFontString(nil, "OVERLAY")
    f:SetText(value or "")
    f:SetTextColor(1, 1, 1, 1)
    if name then
        _G[name] = f
        f.GetName = function() return name end
    end
    return f
end

-- Button art set through the getters GlyphButton holds.
local function buttonArt(button, files, art)
    local list = {}
    for getter, file in pairs(files) do
        local t = texture(button, "Buttons\\" .. file,
            getter == "GetHighlightTexture" and "HIGHLIGHT" or "ARTWORK")
        button[getter] = function() return t end
        list[#list + 1] = t
        art[#art + 1] = t
    end
    return list
end

-- A dialog window: DialogBorderDarkTemplate (nine pieces and its own Bg) and DialogHeaderTemplate (three pieces and
-- its text), the shape Modern.Dialog knows.
local function dialog(c, name, parent)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(320, 500)
    frame._chrome = {}
    local function keep(part)
        c.art[#c.art + 1] = part
        frame._chrome[#frame._chrome + 1] = part
        return part
    end
    frame.Border = CreateFrame("Frame", nil, frame)
    for _, key in ipairs(NINE) do
        frame.Border[key] = keep(texture(frame.Border, "DialogFrame\\UI-DialogBox-Border", "BORDER"))
    end
    frame.Border.Bg = keep(texture(frame.Border, "DialogFrame\\UI-DialogBox-Background", "BACKGROUND"))
    frame.Header = CreateFrame("Frame", nil, frame)
    for _, key in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do
        frame.Header[key] = keep(texture(frame.Header, "FrameGeneral\\UI-Frame-DiamondMetal-Header-" .. key))
    end
    frame.Header.Text = text(frame.Header, name)
    frame.Header.Text:SetPoint("CENTER", frame.Header, "CENTER", 0, 0)
    frame._header = frame.Header.Text
    c.dialogs[#c.dialogs + 1] = frame
    frame:Hide()
    return frame
end

local function dayButton(c, index, parent)
    local button = CreateFrame("Button", "CalendarDayButton" .. index, parent)
    button:SetSize(91, 91)
    button.base = {}
    local function base(region)
        button.base[region] = true
        return region
    end
    local normal = base(texture(button, "Calendar\\CalendarBackground", "ARTWORK"))
    button.GetNormalTexture = function() return normal end
    c.art[#c.art + 1] = normal
    local highlight = base(texture(button, "Calendar\\Highlights", "HIGHLIGHT"))
    highlight:SetAlpha(0)
    button.GetHighlightTexture = function() return highlight end

    button.EventTexture = base(texture(button, "Calendar\\EventTexture", "BORDER"))
    button.EventTexture:Hide()
    button.EventBackgroundTexture = base(texture(button, "Calendar\\CalendarEventBackground", "ARTWORK"))
    button.EventBackgroundTexture:Hide()
    button.PendingInviteTexture = base(texture(button, "Calendar\\EventNotification", "OVERLAY"))
    button.PendingInviteTexture:Hide()
    button.OverlayFrame = CreateFrame("Frame", nil, button)
    button.OverlayFrame.Texture = base(texture(button.OverlayFrame, "Calendar\\HolidaySequence", "BACKGROUND"))
    button.OverlayFrame:Hide()

    button.DateFrame = CreateFrame("Frame", nil, button)
    button.DateFrame.Background = base(texture(button.DateFrame, "Calendar\\DateBackgrounds", "BORDER"))
    c.art[#c.art + 1] = button.DateFrame.Background
    button.DateFrame.Date = base(text(button.DateFrame, ""))
    c.keep[#c.keep + 1] = button.DateFrame.Date

    button.DarkFrame = CreateFrame("Frame", nil, button)
    button.DarkFrame.Top = base(texture(button.DarkFrame, "Calendar\\CalendarShadows", "OVERLAY"))
    button.DarkFrame.Bottom = base(texture(button.DarkFrame, "Calendar\\CalendarShadows", "OVERLAY"))
    c.art[#c.art + 1] = button.DarkFrame.Top
    c.art[#c.art + 1] = button.DarkFrame.Bottom
    button.DarkFrame:Hide()

    button.MoreEventsButton = CreateFrame("Button", nil, button)
    button.MoreEventsButton.normal = base(texture(button.MoreEventsButton, "Calendar\\MoreArrow", "ARTWORK"))
    button.MoreEventsButton.GetNormalTexture = function() return button.MoreEventsButton.normal end

    local event = CreateFrame("Button", "CalendarDayButton" .. index .. "EventButton1", button)
    event.Black = texture(event, "Calendar\\EventHighlight", "ARTWORK")
    event.Text1 = text(event, "")
    event.Text2 = text(event, "")
    event:Hide()
    button.EventButton1 = event
    return button
end

-- Month info for the viewed month plus `offset` (Blizzard's C_Calendar.GetMonthInfo).
local function monthInfo(state, offset)
    local key = state.offset + (offset or 0)
    local m = state.months[key] or state.months[state.offset]
    local prev = state.months[key - 1] or m
    return { month = m.month, year = m.year, firstWeekday = m.firstWeekday, numDays = m.numDays,
        numDaysInPrevMonth = prev.numDays }
end

local function updateGrid(c)
    local state = c.state
    local info = monthInfo(state, 0)
    local frame = c.frame
    frame.viewedMonth, frame.viewedYear = info.month, info.year
    local today = state.today
    c.todayFrame:Hide()
    c.todayButton = nil
    for index, button in ipairs(c.days) do
        local day, offset
        if index < info.firstWeekday then
            offset = -1
            day = monthInfo(state, -1).numDays - (info.firstWeekday - 1 - index)
        elseif index < info.firstWeekday + info.numDays then
            offset = 0
            day = index - info.firstWeekday + 1
        else
            offset = 1
            day = index - (info.firstWeekday + info.numDays) + 1
        end
        button.day, button.monthOffset = day, offset
        button.dark = offset ~= 0 or nil
        button.DateFrame.Date:SetText(day)
        if offset == 0 then button.DarkFrame:Hide() else button.DarkFrame:Show() end
    end
    if info.month == today.month and info.year == today.year then
        local button = c.days[info.firstWeekday - 1 + today.monthDay]
        if button then
            c.todayFrame:SetParent(button)
            c.todayFrame:ClearAllPoints()
            c.todayFrame:SetPoint("CENTER", button, "CENTER")
            c.todayFrame:Show()
            c.todayButton = button
        end
    end
end

-- Build the calendar. Call after the Modernize settings are on (or before: the frames simply appear later, as when
-- Blizzard_Calendar loads on demand), then hand the frames to the area through Modern.AddonLoaded.
function C.build()
    local c = { art = {}, keep = {}, dialogs = {}, days = {}, eventArt = {}, eventKeep = {} }
    local frame = CreateFrame("Frame", "CalendarFrame", UIParent)
    frame:SetSize(659, 624)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 15, -80)
    c.frame = frame

    -- Window chrome: a NineSlice, a Bg and the loose calendar plates.
    frame.NineSlice = CreateFrame("Frame", nil, frame)
    for _, key in ipairs(NINE) do
        frame.NineSlice[key] = texture(frame.NineSlice, "FrameGeneral\\NineSlice-" .. key, "BORDER")
        c.art[#c.art + 1] = frame.NineSlice[key]
    end
    frame.Bg = texture(frame, "FrameGeneral\\UI-Background-Rock", "BACKGROUND")
    frame.TopTileStreaks = texture(frame, "FrameGeneral\\TopTileStreaks", "BORDER")
    c.art[#c.art + 1] = frame.Bg
    c.art[#c.art + 1] = frame.TopTileStreaks
    for _, part in ipairs({ "TopLeft", "TopMiddle", "TopRight", "LeftTop", "LeftMiddle", "LeftBottom", "RightTop",
        "RightMiddle", "RightBottom", "BottomLeft", "BottomMiddle", "BottomRight" }) do
        c.art[#c.art + 1] = texture(frame, "Calendar\\CalendarFrame", "BORDER",
            "CalendarFrame" .. part .. "Texture")
    end

    -- Weekday header, month and year plates.
    for index = 1, WEEKDAYS do
        c.art[#c.art + 1] = texture(frame, "Calendar\\CalendarBackground", "BACKGROUND",
            "CalendarWeekday" .. index .. "Background")
        c.keep[#c.keep + 1] = text(frame, "Day " .. index, "CalendarWeekday" .. index .. "Name")
    end
    c.art[#c.art + 1] = texture(frame, "Calendar\\CalendarBackground", "OVERLAY", "CalendarMonthBackground")
    c.keep[#c.keep + 1] = text(frame, "November", "CalendarMonthName")
    c.art[#c.art + 1] = texture(frame, "Calendar\\CalendarBackground", "ARTWORK", "CalendarYearBackground")
    c.keep[#c.keep + 1] = text(frame, "2026", "CalendarYearName")

    c.todayFrame = CreateFrame("Frame", "CalendarTodayFrame", frame)
    c.art[#c.art + 1] = texture(c.todayFrame, "Calendar\\CurrentDay", "OVERLAY", "CalendarTodayTextureGlow")
    c.art[#c.art + 1] = texture(c.todayFrame, "Calendar\\CurrentDay", "BORDER", "CalendarTodayTexture")
    c.todayFrame:Hide()

    -- Title-bar controls.
    c.close = CreateFrame("Button", "CalendarCloseButton", frame)
    c.closeArt = buttonArt(c.close, { GetNormalTexture = "UI-Panel-MinimizeButton-Up",
        GetPushedTexture = "UI-Panel-MinimizeButton-Down", GetDisabledTexture = "UI-Panel-MinimizeButton-Disabled",
        GetHighlightTexture = "UI-Common-MouseHilight" }, c.art)
    c.prev = CreateFrame("Button", "CalendarPrevMonthButton", frame)
    c.prevArt = buttonArt(c.prev, { GetNormalTexture = "UI-SpellbookIcon-PrevPage-Up",
        GetPushedTexture = "UI-SpellbookIcon-PrevPage-Down",
        GetDisabledTexture = "UI-SpellbookIcon-PrevPage-Disabled",
        GetHighlightTexture = "UI-Common-MouseHilight" }, c.art)
    c.next = CreateFrame("Button", "CalendarNextMonthButton", frame)
    c.nextArt = buttonArt(c.next, { GetNormalTexture = "UI-SpellbookIcon-NextPage-Up",
        GetPushedTexture = "UI-SpellbookIcon-NextPage-Down",
        GetDisabledTexture = "UI-SpellbookIcon-NextPage-Disabled",
        GetHighlightTexture = "UI-Common-MouseHilight" }, c.art)

    c.filter = CreateFrame("DropdownButton", "CalendarFilterButton", frame)
    frame.FilterButton = c.filter
    c.filter.Background = texture(c.filter, "FrameGeneral\\common-dropdown-textholder", "BACKGROUND")
    c.art[#c.art + 1] = c.filter.Background
    c.filter.Arrow = texture(c.filter, "FrameGeneral\\common-dropdown-a-button", "OVERLAY")
    c.filter.Text = text(c.filter, "All Events")
    c.keep[#c.keep + 1] = c.filter.Text

    -- The month grid.
    for index = 1, DAYS do c.days[index] = dayButton(c, index, frame) end

    -- The event windows and the day menu.
    dialog(c, "CalendarViewEventFrame", frame)
    dialog(c, "CalendarViewHolidayFrame", frame)
    dialog(c, "CalendarViewRaidFrame", frame)
    dialog(c, "CalendarMassInviteFrame", frame)
    local create = dialog(c, "CalendarCreateEventFrame", frame)
    local menu = dialog(c, "CalendarDayContextMenu", frame)
    -- Older clients name the day menu CalendarContextMenu; the same frame answers to both.
    _G.CalendarContextMenu = menu
    c.menu = menu
    local list = CreateFrame("Frame", "CalendarCreateEventInviteList", create)
    list.Background = texture(list, "Tooltips\\UI-Tooltip-Background", "BACKGROUND")
    c.art[#c.art + 1] = list.Background
    list.ScrollBox = CreateFrame("Frame", nil, list)
    list.ScrollBar = CreateFrame("Frame", nil, list)
    local row = CreateFrame("Button", nil, list.ScrollBox)
    row.Background = texture(row, "FriendsFrame\\UI-FriendsFrame-HighlightBar", "HIGHLIGHT")
    row.Name = text(row, "Merisa")
    c.invite, c.inviteRow = list, row
    c.inviteKeep = { row.Name }

    -- Month state the calendar API reads.
    local state = { offset = 0, months = MONTHS, today = TODAY, selectedButton = nil }
    c.state = state
    c.today = TODAY
    _G.C_Calendar = _G.C_Calendar or {}
    C_Calendar.GetMonthInfo = function(offset) return monthInfo(state, offset) end
    C_Calendar.GetDate = function() return TODAY.weekday, TODAY.month, TODAY.monthDay, TODAY.year end
    C_Calendar.GetNumDayEvents = function() return 0 end
    C_Calendar.GetDayEvent = function() return nil end
    C_Calendar.GetEventIndex = function() return nil end
    C_Calendar.ContextMenuGetEventIndex = function() return nil end
    _G.C_DateAndTime = { GetCurrentCalendarTime = function()
        return { weekday = TODAY.weekday, month = TODAY.month, monthDay = TODAY.monthDay, year = TODAY.year,
            hour = 12, minute = 0 }
    end }
    _G.CalendarGetMonth = function(offset)
        local info = monthInfo(state, offset)
        return info.month, info.year, info.firstWeekday, info.numDays, info.numDaysInPrevMonth
    end
    _G.CalendarGetDate = function() return TODAY.weekday, TODAY.month, TODAY.monthDay, TODAY.year end

    _G.CalendarFrame_SetSelectedDay = function(button)
        frame.selectedDayButton = button
        if button then button:GetHighlightTexture():SetAlpha(0.6) end
    end
    _G.CalendarFrame_Update = function() updateGrid(c) end
    updateGrid(c)
    return c
end

-- Show the month `offset` months from today's, as the previous / next month buttons do.
function C.showMonth(c, offset)
    c.state.offset = offset
    CalendarFrame_Update()
end

-- Select a day button, as a click does (Blizzard's CalendarFrame_SetSelectedDay).
function C.select(c, index)
    local button = c.days[index]
    c.state.selectedButton = button
    CalendarFrame_SetSelectedDay(button)
    return button
end

-- Give a day an event, a pending invite and holiday art, so a test can prove they stay.
function C.eventsOn(c, button)
    local all = { button.EventTexture, button.EventBackgroundTexture, button.PendingInviteTexture,
        button.OverlayFrame.Texture }
    for _, t in ipairs(all) do
        t:SetTexture("Interface\\Calendar\\EventArt")
        c.eventArt[#c.eventArt + 1] = t
    end
    button.EventTexture:Show()
    button.EventBackgroundTexture:Show()
    button.PendingInviteTexture:Show()
    button.OverlayFrame:Show()
    button.MoreEventsButton:Show()
    button.EventButton1:Show()
    button.EventButton1.Text1:SetText("Raid")
    button.EventButton1.Text2:SetText("20:00")
    c.eventKeep[#c.eventKeep + 1] = button.EventButton1.Text1
    c.eventKeep[#c.eventKeep + 1] = button.EventButton1.Text2
    return button
end

-- Today's day button, as Blizzard marks it by parenting CalendarTodayFrame; nil when today is not in the shown month.
function C.todayButton(c)
    return c.todayFrame:IsShown() and c.todayFrame:GetParent() or nil
end

-- Every frame and region at or under root.
function C.all(root, out)
    out = out or {}
    out[#out + 1] = root
    for _, region in ipairs(root._regions) do C.all(region, out) end
    for _, child in ipairs(root._children) do C.all(child, out) end
    return out
end

-- Objects under root that did not exist in a previous L.snapshot (QuietUI's own regions and handles).
function C.added(root, snapshot)
    local list = {}
    for _, object in ipairs(C.all(root)) do
        if not snapshot[object] then list[#list + 1] = object end
    end
    return list
end

function C.hidden(list)
    for _, object in ipairs(list) do
        if object._shown then return false, (object._label or object._name or object._kind) end
    end
    return true
end

-- Comma list of the labels of `art` still visible ("" when all are held), for a readable failure.
function C.visible(list, R, stop)
    local names = {}
    for _, texture in ipairs(list) do
        if not R.invisible(texture, stop) then names[#names + 1] = texture._label end
    end
    return table.concat(names, ",")
end

function C.visibleArt(c, R, stop)
    return C.visible(c.art, R, stop)
end

function C.hiddenKeep(c, R, stop)
    local names = {}
    for _, object in ipairs(c.keep) do
        if R.invisible(object, stop) then names[#names + 1] = object._label or tostring(object._text) end
    end
    return table.concat(names, ",")
end

return C
