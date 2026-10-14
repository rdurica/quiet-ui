-- Chat animation: slide-in and upward easing keep their curve, animation-only frames do not
-- rebuild the stack, and fading, hover, scroll, wrapping, resize, hide and restore still work.
local h = ...

local function bubbles(chat)
    local out = {}
    for _, child in ipairs(chat._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" then out[#out + 1] = child break end
        end
    end
    return out
end

local function label(b)
    for _, region in ipairs(b._regions) do
        if region._kind == "FontString" then return region end
    end
end

-- The shown bubble that currently carries `text`.
local function row(chat, text)
    for _, b in ipairs(bubbles(chat)) do
        if b:IsShown() and label(b)._text == text then return b end
    end
end

local function x(b) local p = b._points[#b._points]; return p[4] end
local function y(b) local p = b._points[#b._points]; return p[5] end

local function catcherOf(mock)
    for _, f in ipairs(mock.frames) do
        if f._parent == UIParent and f._kind == "Frame" and f._scripts.OnMouseWheel then return f end
    end
end

-- 340x360 window, 14px font, text 7px per character that wraps by the row width.
local function setup(t, fade, lines, bornAt)
    local ns, mock = t.ns, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = fade }
    local state = { fadeReads = 0, flags = "", size = 14 }
    local create = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        local makeFont = frame.CreateFontString
        frame.CreateFontString = function(self, ...)
            local fs = makeFont(self, ...)
            function fs:GetStringWidth() return #(self._text or "") * 7 end
            function fs:GetUnboundedStringWidth() return 0 end
            function fs:GetStringHeight()
                local size = self._font and self._font[2] or 14
                return math.ceil(self:GetStringWidth() / self._w) * size
            end
            return fs
        end
        return frame
    end
    local chat = ChatFrame1
    chat:SetSize(340, 360)
    chat.scrollOffset = 0
    function chat:GetScrollOffset() return self.scrollOffset end
    function chat:GetFont() return "test", state.size, state.flags end
    for i = 1, lines or 0 do
        if bornAt then mock.now = bornAt(i) end
        chat:AddMessage("Line " .. i)
    end
    local read = ns.Settings.ChatFade
    ns.Settings.ChatFade = function() state.fadeReads = state.fadeReads + 1; return read() end
    ns.Chat.StripAll()
    local function tick(elapsed)
        elapsed = elapsed or 1 / 60
        mock.now = mock.now + elapsed
        ns.Chat.Update(elapsed)
    end
    return chat, state, tick
end

-- Counts the placements and alpha writes of the bubbles that exist now.
local function watch(chat)
    local n = 0
    for _, b in ipairs(bubbles(chat)) do
        for _, name in ipairs({ "SetPoint", "SetAlpha" }) do
            local fn = b[name]
            b[name] = function(...) n = n + 1; return fn(...) end
        end
    end
    return function() return n end
end

-- A rebuild of the message stack sizes every row again: it reads each row's font and sets
-- its frame level. Animation-only frames do neither.
local function watchRebuilds(chat)
    local n = 0
    for _, b in ipairs(bubbles(chat)) do
        local level = b.SetFrameLevel
        b.SetFrameLevel = function(...) n = n + 1; return level(...) end
        local fs = label(b)
        local font = fs.GetFont
        fs.GetFont = function(...) n = n + 1; return font(...) end
    end
    return function() return n end
end

local function near(A, actual, expected, msg)
    A.near(actual, expected, 1e-8, msg)
end

h.test("A new line slides in and older lines ease up without rebuilding the stack", function(t)
    local A = t.assert
    local chat, _, tick = setup(t, 0, 8)
    tick()
    local previous = row(chat, "Line 8")
    A.eq(y(previous), 4, "precondition: the newest old line sits at the bottom")
    local work = watch(chat)
    local before = work()
    for _ = 1, 3 do tick() end
    A.eq(work(), before, "Static chat must go idle")
    chat:AddMessage("Incoming message")
    tick()
    local moving = row(chat, "Incoming message")
    near(A, x(moving), -11.125, "The new line must keep its original eased slide")
    near(A, y(previous), 10.3, "Older lines must keep their original upward easing")
    local rebuilds = watchRebuilds(chat)
    tick()
    near(A, x(moving), -8.5, "The second slide frame must retain its original position")
    near(A, y(previous), 15.13, "The second stack frame must retain its original position")
    for _ = 1, 8 do tick() end
    A.eq(rebuilds(), 0, "Animation-only frames must not rebuild the message stack")
    chat:GetScript("OnSizeChanged")(chat)
    tick()
    A.ok(rebuilds() > 0, "precondition: a relayout is visible to the probe")
    for _ = 1, 90 do tick() end
    near(A, x(moving), 4, "The incoming line must finish at its original anchor")
    near(A, y(previous), 31, "The old line must finish one row higher")
    local settled = work()
    for _ = 1, 3 do tick() end
    A.eq(work(), settled, "Finished movement must stop waking the layout")
end)

-- Line 4 is the only one about to expire; the other eight are born one second later.
local function fading(t)
    local mock = t.mock
    local born = mock.now
    local chat, state, tick = setup(t, 10)
    for i = 1, 9 do
        mock.now = i == 4 and born or born + 1
        chat:AddMessage("Line " .. i)
    end
    for _ = 1, 120 do tick() end
    mock.now = born + 9.5
    return chat, state, tick, born
end

h.test("One fading line animates while the settled lines are not rebuilt", function(t)
    local A = t.assert
    local chat, _, tick = fading(t)
    tick()
    near(A, row(chat, "Line 4"):GetAlpha(), 29 / 30, "Natural fading must retain its original duration")
    local rebuilds = watchRebuilds(chat)
    for _ = 1, 8 do tick() end
    A.eq(rebuilds(), 0, "One fading line must not rebuild all settled lines")
    for _ = 1, 25 do tick() end
    A.falsy(row(chat, "Line 4"), "Expired rows must be released and removed from the visible stack")
    A.ok(row(chat, "Line 5") and row(chat, "Line 9"), "The newer lines stay in the stack")
end)

h.test("Expired history returns on hover and on scroll, and fades away on leaving", function(t)
    local A, mock = t.assert, t.mock
    local chat, _, tick = fading(t)
    for _ = 1, 34 do tick() end
    A.falsy(row(chat, "Line 4"), "precondition: Line 4 expired")
    local catcher = catcherOf(mock)
    catcher:SetMouseOver(true)
    mock.state.cursor = { 10, 10 }
    tick()
    local back = row(chat, "Line 4")
    A.ok(back and back:GetAlpha() == 1, "Hover must immediately restore expired history")
    catcher:SetMouseOver(false)
    mock.state.cursor = { 20, 20 }
    for _ = 1, 25 do tick() end
    A.falsy(row(chat, "Line 4"), "Leaving chat must fade expired history away again")
    chat.scrollOffset = 2
    chat:GetScript("OnSizeChanged")(chat)
    tick()
    A.ok(row(chat, "Line 4"), "Scrolling must still reveal expired history")
end)

h.test("Wrapped text keeps its shown-frame check and a resize invalidates the arrangement", function(t)
    local A = t.assert
    local chat, _, tick = setup(t, 0, 2)
    tick()
    chat:SetSize(118, 360)
    chat:GetScript("OnSizeChanged")(chat)
    chat:AddMessage("AAAAAA BBBBBB CCCCCC")
    tick(); tick(); tick()
    local wrapped = row(chat, "AAAAAA BBBBBB CCCCCC")
    A.ok(wrapped and wrapped:GetHeight() >= 38, "Animation must not bypass wrap verification")
    chat:SetSize(340, 360)
    chat:GetScript("OnSizeChanged")(chat)
    tick(); tick()
    A.eq(wrapped:GetHeight(), 24, "Resize must invalidate the cached arrangement")
end)

h.test("A message during movement retargets the active bubbles and long frames finish them", function(t)
    local A = t.assert
    local chat, state, tick = setup(t, 0, 3)
    tick()
    chat:AddMessage("First burst message")
    tick(1 / 144)
    chat:AddMessage("Second burst message")
    tick(1 / 144)
    local first, second = row(chat, "First burst message"), row(chat, "Second burst message")
    A.ok(y(first) > 4 and y(second) == 4, "A new message during movement must retarget the older active bubbles")
    state.flags = "OUTLINE"
    chat:GetScript("OnSizeChanged")(chat)
    tick(0.08)
    A.eq(label(first)._font[3], "OUTLINE", "Font changes during animation must rebuild cached sizes")
    A.ok(x(first) < 4, "A slow frame must retain the remaining slide animation")
    tick(0.4)
    near(A, x(first), 4, "A long frame must finish the slide without extra animation time")
    near(A, y(first), 31, "A long frame must finish the stack movement without extra animation time")
end)

h.test("Hidden chat stops animating and reopened or restored chat shows its stack again", function(t)
    local A = t.assert
    local chat, _, tick = setup(t, 0, 3)
    tick()
    chat:AddMessage("Another incoming message")
    tick()
    chat:Hide()
    tick()
    for _, b in ipairs(bubbles(chat)) do A.falsy(b:IsShown(), "Hidden chat must stop all active animations") end
    chat:Show()
    tick()
    A.ok(row(chat, "Another incoming message"), "Reopened chat must rebuild its active message stack")
    t.ns.Chat.Restore()
    tick()
    A.ok(row(chat, "Another incoming message"), "Restore/reapply must not animate stale released bubbles")
end)
