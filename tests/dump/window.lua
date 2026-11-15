-- The /quiet dump report window: the report in a selected read-only box, the issue link, Escape and the cross.
-- Expectations come from what ns.Dump returns (QuietUIDB.lastDump, IssueURL), never from report internals.
local h = ...

local NOTE = "Press Ctrl+C to copy the report, then open the link to create an issue."
local LINK_NOTE = "Issue link: click it, press Ctrl+C and paste it into your browser."
local INFO = "Found a bug? Type /quiet dump and send the report."

local function start(t)
    QuietUICharDB = { welcomed = true }
    t.boot()
    t.assert.ok(t.ns.Dump and t.ns.Dump.Build and t.ns.Dump.IssueURL, "dependency: ns.Dump.Build / IssueURL (Core)")
end

local function open(t)
    SlashCmdList.QUIETUI("dump")
    return t.mock:findByName("QuietUIDump")
end

local function within(frame, root)
    local p = frame
    while p do
        if p == root then return true end
        p = p._parent
    end
    return false
end

-- The report box and the link field: the two edit boxes of the window.
local function fields(t, win)
    local report, link
    for _, f in ipairs(t.mock.frames) do
        if f._kind == "EditBox" and within(f, win) then
            if tostring(f:GetText()):find("^https://") then link = f else report = f end
        end
    end
    return report, link
end

local function allHighlighted(box)
    local sel = box._highlight
    if not sel then return false end
    if sel.n == 0 then return true end
    local last = sel[2]
    return sel[1] == 0 and (last == nil or last == -1 or last >= #box:GetText())
end

local function texts(t, win)
    local out = {}
    for _, f in ipairs(t.mock.frames) do
        if f._kind == "FontString" and within(f, win) and f._text ~= "" then out[#out + 1] = f end
    end
    return out
end

h.test("/quiet dump opens QuietUIDump with the report, all of it highlighted and the box focused", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    A.ok(win and win:IsShown(), "the QuietUIDump window is open")
    local report = fields(t, win)
    A.ok(report, "the window has a report box")
    A.type(QuietUIDB.lastDump, "string")
    A.ok(#QuietUIDB.lastDump > 0, "the report has text")
    A.eq(report:GetText(), QuietUIDB.lastDump, "the box shows the report")
    A.ok(allHighlighted(report), "all report text is highlighted")
    A.ok(report:HasFocus(), "the report box has focus")
end)

h.test("The saved copy equals the text in the window, on every open", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local report = fields(t, win)
    A.eq(QuietUIDB.lastDump, report:GetText())
    win:Hide()
    QuietUIDB.lastDump = "stale"
    win = open(t)
    report = fields(t, win)
    A.ne(QuietUIDB.lastDump, "stale", "the dump writes lastDump again")
    A.eq(report:GetText(), QuietUIDB.lastDump)
end)

h.test("Each open rebuilds the report", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local first = fields(t, win):GetText()
    win:Hide()
    QuietUICharDB.chatFade = 33
    win = open(t)
    local report = fields(t, win)
    A.ne(report:GetText(), first, "a changed setting shows in the next report")
    A.ok(report:GetText():find("33", 1, true), "the new value is in the report")
    A.ok(report:IsVisible() and report:HasFocus() and allHighlighted(report), "the reopened box is selected and focused")
end)

h.test("The link field holds the prefilled GitHub issue link", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local _, link = fields(t, win)
    A.ok(link, "the window has a link field")
    A.eq(link:GetText(), t.ns.Dump.IssueURL())
    A.eq(link:GetText():find("https://github.com/rdurica/quiet-ui/issues/new?title=Bug%3A%20&body=", 1, true), 1, "link shape")
end)

h.test("Typing into the report box leaves its text unchanged", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local report = fields(t, win)
    local original = report:GetText()
    A.type(report._scripts.OnTextChanged, "function", "the box puts its text back on change")
    report:SetText(original .. "x")
    report._scripts.OnTextChanged(report, true)
    A.eq(report:GetText(), original, "an added letter is undone")
    report:SetText("replaced")
    report._scripts.OnTextChanged(report, true)
    A.eq(report:GetText(), original, "a replaced text is undone")
    report:SetText("")
    report._scripts.OnTextChanged(report, true)
    A.eq(report:GetText(), original, "a deleted text is undone")
end)

h.test("Typing into the link field leaves the link unchanged", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local _, link = fields(t, win)
    local original = link:GetText()
    A.type(link._scripts.OnTextChanged, "function", "the field puts its text back on change")
    link:SetText(original .. "x")
    link._scripts.OnTextChanged(link, true)
    A.eq(link:GetText(), original)
end)

h.test("Clicking or focusing the link field highlights the whole link", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local _, link = fields(t, win)
    link._highlight = nil
    local ran = false
    for _, script in ipairs({ "OnMouseDown", "OnMouseUp", "OnEditFocusGained" }) do
        if link._scripts[script] then
            link._highlight = nil
            link._scripts[script](link, "LeftButton")
            ran = true
            A.ok(allHighlighted(link), script .. " highlights the whole link")
        end
    end
    A.ok(ran, "the link field reacts to a click or focus")
end)

h.test("Clicking the report box highlights all of its text again", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local report = fields(t, win)
    local ran = false
    for _, script in ipairs({ "OnMouseDown", "OnMouseUp", "OnEditFocusGained" }) do
        if report._scripts[script] then
            report._highlight = nil
            report._scripts[script](report, "LeftButton")
            ran = true
            A.ok(allHighlighted(report), script .. " highlights the whole report")
        end
    end
    A.ok(ran, "the report box reacts to a click or focus")
end)

h.test("Escape (UISpecialFrames) and the close cross close the window", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    A.contains(UISpecialFrames, "QuietUIDump", "Escape closes the window")
    open(t)
    local n = 0
    for _, name in ipairs(UISpecialFrames) do if name == "QuietUIDump" then n = n + 1 end end
    A.eq(n, 1, "opening again registers the name once")
    A.ok(win.close, "the window has a close cross")
    win.close:Click()
    A.falsy(win:IsShown(), "the cross closes the window")
    win = open(t)
    A.ok(win:IsShown(), "it opens again")
end)

h.test("Opening and closing the window changes no frame alpha and no setting", function(t)
    local A = t.assert
    start(t)
    local alphas = {}
    for _, f in ipairs(t.mock.frames) do alphas[f] = f._alpha end
    local function copy(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, x in pairs(v) do out[k] = copy(x) end
        return out
    end
    local db, char = copy(QuietUIDB), copy(QuietUICharDB)
    db.lastDump = nil
    local win = open(t)
    win.close:Click()
    for f, alpha in pairs(alphas) do A.eq(f._alpha, alpha, "alpha of an existing frame") end
    local after = copy(QuietUIDB)
    after.lastDump = nil
    A.deep(after, db, "QuietUIDB changes only through lastDump")
    A.deep(copy(QuietUICharDB), char, "QuietUICharDB is untouched")
end)

h.test("The window carries the grey note about Ctrl+C and the link", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local note
    for _, f in ipairs(texts(t, win)) do
        if f._text == NOTE then note = f end
    end
    A.ok(note, "the note is on the window")
    local r, g, b = note:GetTextColor()
    A.ok(r == g and g == b and r < 1, "the note is grey")
end)

h.test("The Info tab tells how to report a bug", function(t)
    local A = t.assert
    start(t)
    t.ns.Setup.Show()
    local setup = t.mock:findByName("QuietUISetup")
    local found
    for _, f in ipairs(t.mock.frames) do
        if f._kind == "FontString" and within(f, setup) and f._text == INFO then found = f end
    end
    A.ok(found, "the Info tab has the sentence")
end)

h.test("The report scrolls with the mouse wheel, clamped to its range", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local report = fields(t, win)
    local scroll = report:GetParent()
    A.ok(scroll._scripts.OnMouseWheel, "the scroll frame handles the wheel")
    scroll._vrange = 100
    scroll._scripts.OnMouseWheel(scroll, -1)
    local down = scroll:GetVerticalScroll()
    A.ok(down > 0, "wheel down scrolls, got " .. tostring(down))
    scroll._scripts.OnMouseWheel(scroll, -1000)
    A.eq(scroll:GetVerticalScroll(), 100, "clamped to the range")
    scroll._scripts.OnMouseWheel(scroll, 1000)
    A.eq(scroll:GetVerticalScroll(), 0, "clamped at the top")
end)

h.test("After a user change the whole text is highlighted again", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local report, link = fields(t, win)
    for _, box in ipairs({ report, link }) do
        local original = box:GetText()
        box._highlight = nil
        box:SetText(original .. "x")
        box._scripts.OnTextChanged(box, true)
        A.eq(box:GetText(), original, "the text is put back")
        A.ok(allHighlighted(box), "the put-back text is selected again")
    end
end)

h.test("The link field has a muted label on the window", function(t)
    local A = t.assert
    start(t)
    local win = open(t)
    local label
    for _, f in ipairs(texts(t, win)) do
        if f._text == LINK_NOTE then label = f end
    end
    A.ok(label, "the link label is on the window")
    local r, g, b = label:GetTextColor()
    A.ok(r == g and g == b and r < 1, "the label is muted")
end)
