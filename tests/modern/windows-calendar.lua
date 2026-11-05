-- The Modern calendar (Blizzard_Calendar, Windows area): window chrome, the bare month grid, the today accent border,
-- the selected day wash, out-of-month dimming, untouched event art, the event windows and the saved, movable point.
local h = ...
local L = h.lib("modern")
local W = h.lib("modern-windows")
local R = h.lib("modern-windows-retail")
local C = h.lib("modern-calendar")

local function same(color, want)
    return color ~= nil and color[1] == want[1] and color[2] == want[2] and color[3] == want[3]
end

local function own(button, before)
    local list = {}
    for _, object in ipairs(C.added(button, before)) do list[#list + 1] = object end
    return list
end

-- Day buttons marked with the accent border.
local function hasAccent(button, theme)
    for _, object in ipairs(C.all(button)) do
        if object._shown ~= false and same(object._color, theme.accent) then return true end
    end
    return false
end

local function markedDays(c, theme)
    local marked = 0
    for _, button in ipairs(c.days) do
        if hasAccent(button, theme) then marked = marked + 1 end
    end
    return marked
end

-- An own faint light wash on a day button (Blizzard's selection highlight is held instead).
local function hasWash(button)
    for _, region in ipairs(C.all(button)) do
        local color = region._color
        if region._shown ~= false and region._layer ~= "HIGHLIGHT" and color and color[4] and color[4] <= 0.3
            and color[1] >= 0.5 and color[2] >= 0.5 and color[3] >= 0.5 then
            return true
        end
    end
    return false
end

-- An own dimming overlay, or dimmed date ink, on a day outside the month. Blizzard's own shadings are excluded.
local function dimmed(button, theme)
    for _, region in ipairs(C.all(button)) do
        local color = region._color
        if region._shown ~= false and region._layer ~= "HIGHLIGHT" and color
            and not same(color, theme.wellEdge) and not same(color, theme.accent) then
            local dark = color[1] <= 0.5 and color[2] <= 0.5 and color[3] <= 0.5
            if dark or (color[4] and color[4] <= 0.7) then return true end
        end
    end
    local date = button.DateFrame.Date
    local r, _, _, a = date:GetTextColor()
    return r < 0.9 or (a and a < 0.9) or (date._alpha and date._alpha < 0.9)
end

local function unmarked(c, theme)
    for _, button in ipairs(c.days) do
        if hasAccent(button, theme) then return button end
    end
end

h.test("loading Blizzard_Calendar gives the calendar the dark window, header hairline, bare chevrons and filter", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    W.enable(ns)    -- Modernize is on before the calendar addon exists
    local c = C.build()
    local before = L.snapshot(C.all(c.frame))
    ns.Modern.AddonLoaded("Blizzard_Calendar")
    local theme = ns.Modern.Theme()

    A.ok(W.isDark(c.frame), "the calendar is a graphite panel")
    A.eq(C.visibleArt(c, R, c.frame), "", "window, weekday, day and today art are all held")
    for _, texture in ipairs(c.art) do
        A.alpha(texture, 0, "art is held at alpha 0, not hidden: " .. tostring(texture._label))
    end
    A.eq(C.hiddenKeep(c, R, c.frame), "", "weekday names, day numbers, month and year names and filter text stay")

    local band, hairline = 0, 0
    for _, region in ipairs(c.frame._regions) do
        if region._shown ~= false and region._gradient and region._gradient[1] == "VERTICAL"
            and region._gradient[2][1] == theme.strip[1] then
            band = band + 1
        end
        if region._shown ~= false and region._h == 1 and same(region._color, theme.accent) then hairline = hairline + 1 end
    end
    A.eq(band, 1, "a title band a step above the panel")
    A.eq(hairline, 1, "the gold hairline under the title band")

    for _, texture in ipairs(c.closeArt) do A.ok(R.invisible(texture, c.frame), "the close art is held") end
    local cross = 0
    for _, region in ipairs(own(c.close, before)) do
        if region._shown ~= false and same(region._color, theme.glyph) then cross = cross + 1 end
    end
    A.eq(cross, 2, "the close button is a bare grey cross")

    for _, chevron in ipairs({ c.prev, c.next }) do
        local lines = 0
        for _, region in ipairs(own(chevron, before)) do
            if region._shown ~= false and same(region._color, theme.glyph) then lines = lines + 1 end
        end
        A.ok(lines >= 1, (chevron:GetName() or "chevron") .. " is a bare grey chevron")
    end
    for _, texture in ipairs(c.prevArt) do A.ok(R.invisible(texture, c.frame), "the previous month art is held") end
    for _, texture in ipairs(c.nextArt) do A.ok(R.invisible(texture, c.frame), "the next month art is held") end

    A.ok(R.invisible(c.filter.Background, c.frame), "the filter dropdown loses its plate")
    A.ok(W.isDark(c.filter), "the filter dropdown becomes a dark field")
    A.ok(not R.invisible(c.filter.Text, c.frame), "the filter text stays")
    A.eq(#mock.printed, 0, "nothing reported")
end)

h.test("the grid is bare, quiet rules part the days, and the today accent border follows the month", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = C.build()
    local before = L.snapshot(C.all(c.frame))
    W.enable(ns)
    local theme = ns.Modern.Theme()

    local rules = 0
    for _, object in ipairs(C.added(c.frame, before)) do
        if object._shown ~= false and same(object._color, theme.wellEdge) then rules = rules + 1 end
    end
    A.ok(rules >= 2, "quiet rules part the rows and columns")

    local today = C.todayButton(c)
    A.ok(today, "the fixture marks today")
    A.ok(hasAccent(today, theme), "today's day button has an accent border")
    A.eq(markedDays(c, theme), 1, "only today's button is marked")

    C.showMonth(c, 1)
    A.eq(C.todayButton(c), nil, "today is not in the next month")
    A.eq(unmarked(c, theme), nil, "the accent border leaves no day when today is not shown")

    C.showMonth(c, 0)
    local back = C.todayButton(c)
    A.ok(back, "today is back")
    A.ok(hasAccent(back, theme), "the accent border is on today's button again")
    A.eq(markedDays(c, theme), 1, "and on no other day")
end)

h.test("the selected day gets a faint light wash and Blizzard's selection texture is held", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = C.build()
    local selected = C.select(c, 20)    -- day 18, not today
    W.enable(ns)

    A.alpha(selected:GetHighlightTexture(), 0, "Blizzard's selected-day texture is held")
    A.ok(hasWash(selected), "a faint light wash shows on the selected day")
    A.falsy(hasWash(c.days[21]), "a plain day gets no wash")
    ns.Modern.Restore()
    A.alpha(selected:GetHighlightTexture(), 0.6, "restore brings Blizzard's selection texture back")
    A.falsy(hasWash(selected), "restore removes the wash")
end)

h.test("days outside the shown month are dimmed without changing the day button's alpha", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = C.build()
    local outside = c.days[41]    -- a day of the next month
    local inside = c.days[5]      -- a day of the shown month
    A.eq(outside.monthOffset, 1, "the fixture has a day after the month")
    A.eq(inside.monthOffset, 0, "the fixture has a day in the month")
    W.enable(ns)
    local theme = ns.Modern.Theme()

    A.alpha(outside, 1, "the button alpha is unchanged")
    A.ok(dimmed(outside, theme), "a day outside the month is dimmed")
    A.falsy(dimmed(inside, theme), "a day in the month is not dimmed")
    ns.Modern.Restore()
    A.falsy(dimmed(outside, theme), "restore removes the dimming")
    A.alpha(outside, 1, "the button alpha was never touched")
end)

h.test("event textures, holiday art and event text on a day are not held or retextured", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = C.build()
    local day = C.eventsOn(c, c.days[17])
    local art = L.snapshot(c.eventArt)
    local keep = L.snapshot(c.eventKeep)
    W.enable(ns)
    A.deep(L.diff(art), {}, "event and holiday art on a day is untouched")
    A.deep(L.diff(keep), {}, "event text on a day stays")
    A.ok(not R.invisible(day.EventTexture, c.frame), "the event texture stays visible")
    ns.Modern.Restore()
    A.deep(L.diff(art), {}, "restore never touches event art")
end)

h.test("the event windows, the invite list and the day menu take the Modern dialog look", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = C.build()
    for _, window in ipairs(c.dialogs) do window:Show() end
    W.enable(ns)

    for _, window in ipairs(c.dialogs) do
        local name = window:GetName()
        A.ok(W.isDark(window), name .. " is a dark window")
        for _, texture in ipairs(window._chrome) do
            A.ok(R.invisible(texture, window), name .. " art is held")
        end
        A.ok(not R.invisible(window._header, window), name .. " title stays")
    end
    A.ok(R.invisible(c.invite.Background, c.invite), "the invite list stands bare")
    A.ok(not R.invisible(c.inviteRow.Name, c.invite), "invite names stay")
    A.eq(#t.mock.printed, 0, "nothing reported")
end)

h.test("dragging the calendar title saves windowPoints.CalendarFrame and the point returns on the next show", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = C.build()
    W.enable(ns)

    A.ok(L.handle(c.frame), "the calendar has a title drag handle")
    L.drag(c.frame, "CENTER", "CENTER", 11, -12)
    A.deep(QuietUICharDB.windowPoints.CalendarFrame, { "CENTER", "CENTER", 11, -12 })

    L.blizzardPoint(c.frame, "TOPLEFT", 15, -80)
    c.frame:Hide()
    c.frame:Show()
    A.deep(W.point(c.frame), { "CENTER", "CENTER", 11, -12 }, "the saved point is put back on the next show")

    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(W.point(c.frame), { "TOPLEFT", "TOPLEFT", 15, -80 }, "the area off returns Blizzard's point")
    A.deep(QuietUICharDB.windowPoints.CalendarFrame, { "CENTER", "CENTER", 11, -12 }, "the saved point remains")
end)

h.test("in combat the calendar does not move and the saved point waits for combat to end", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    QuietUICharDB = {}
    t.boot()
    W.area(ns, "windows")
    local c = C.build()
    W.enable(ns)
    QuietUICharDB.windowPoints = { CalendarFrame = { "CENTER", "CENTER", 10, 20 } }

    mock.state.combat = true
    L.blizzardPoint(c.frame, "TOPLEFT", 15, -80)
    local setPoints, clears = 0, 0
    local setPoint, clearPoints = c.frame.SetPoint, c.frame.ClearAllPoints
    c.frame.SetPoint = function(self, ...) setPoints = setPoints + 1; return setPoint(self, ...) end
    c.frame.ClearAllPoints = function(self, ...) clears = clears + 1; return clearPoints(self, ...) end
    c.frame:Hide()
    c.frame:Show()
    A.eq(setPoints, 0, "no point is set in combat")
    A.eq(clears, 0, "no point is cleared in combat")
    A.deep(W.point(c.frame), { "TOPLEFT", "TOPLEFT", 15, -80 })

    local handle = L.handle(c.frame)
    A.ok(handle, "the calendar has a title drag handle")
    local startFn = handle._scripts.OnDragStart or handle._scripts.OnMouseDown
    startFn(handle)
    A.eq(c.frame:IsMoving(), false, "a drag in combat does not start")

    mock.state.combat = false
    mock:fire("PLAYER_REGEN_ENABLED")
    A.deep(W.point(c.frame), { "CENTER", "CENTER", 10, 20 }, "the saved point applies when combat ends")
end)

h.test("the Windows area off or Modernize off restores the calendar and hides every own region", function(t)
    local A, ns = t.assert, t.ns
    W.area(ns, "windows")
    local c = C.build()
    for _, window in ipairs(c.dialogs) do window:Show() end
    C.eventsOn(c, c.days[17])
    C.select(c, 20)
    local before = L.snapshot(C.all(c.frame))
    local events = L.snapshot(c.eventArt)
    W.enable(ns)
    A.ok(W.isDark(c.frame), "the calendar is skinned before restore")
    local added = C.added(c.frame, before)

    QuietUICharDB.modernize.windows = false
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "the Windows area off restores every texture, alpha, colour, point and text")
    A.deep(L.diff(events), {}, "event art is untouched by restore")
    A.ok(C.hidden(added), "QuietUI's own regions and handle are hidden")

    W.enable(ns)
    A.ok(W.isDark(c.frame), "the calendar skins again")
    QuietUICharDB.modernize.enabled = false
    ns.Modern.Apply()
    A.deep(L.diff(before), {}, "Modernize off restores every texture, alpha, colour, point and text")
    A.ok(C.hidden(C.added(c.frame, before)), "every own region is hidden again")
end)

h.test("a client without one of the calendar frames skips it without reporting", function(t)
    local A, ns, mock = t.assert, t.ns, t.mock
    W.area(ns, "windows")
    W.enable(ns)
    ns.Modern.AddonLoaded("Blizzard_Calendar")
    A.eq(#mock.printed, 0, "no calendar at all is skipped quietly")

    local c = C.build()
    _G.CalendarViewEventFrame = nil
    _G.CalendarViewHolidayFrame = nil
    _G.CalendarViewRaidFrame = nil
    _G.CalendarMassInviteFrame = nil
    _G.CalendarDayContextMenu = nil
    _G.CalendarContextMenu = nil
    for index = 3, 42 do _G["CalendarDayButton" .. index] = nil end
    ns.Modern.AddonLoaded("Blizzard_Calendar")
    A.ok(W.isDark(c.frame), "the window still skins")
    A.eq(#mock.printed, 0, "missing day buttons, event windows and the day menu are skipped quietly")
end)
