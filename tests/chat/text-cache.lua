-- Chat reuses measured text widths, refreshes catcher stacking only when needed, and
-- shares one fade lookup per layout while timed lines fade, expire and reveal on hover.
local h = ...

local TEXT = "AAAAAA BBBBBB CCCCCC"
local SECRET = "SECRET " .. TEXT

local function bubbles(chat)
    local out = {}
    for _, child in ipairs(chat._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" then out[#out + 1] = child break end
        end
    end
    return out
end

-- The chat catcher is the UIParent child that takes the mouse wheel.
local function catcherOf(mock)
    for _, f in ipairs(mock.frames) do
        if f._parent == UIParent and f._kind == "Frame" and f._scripts.OnMouseWheel then return f end
    end
end

-- Three 60px words total 200px at font size 14, so the width is a 200 * size / 14 reading.
-- Only reads of the wide measuring string count: that is the unwrapped width lookup.
local function fixture(t, width)
    local ns, mock = t.ns, t.mock
    local state = { widthReads = 0, size = 14, flags = "" }
    local create = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        local makeFont = frame.CreateFontString
        frame.CreateFontString = function(self, ...)
            local fs = makeFont(self, ...)
            function fs:GetStringWidth()
                if self._w >= 8000 then state.widthReads = state.widthReads + 1 end
                return 200 * (self._font and self._font[2] or 14) / 14
            end
            function fs:GetUnboundedStringWidth() return 0 end
            function fs:GetStringHeight()
                local size = self._font and self._font[2] or 14
                return self._w >= 200 * size / 14 and size or size * 3
            end
            return fs
        end
        return frame
    end
    local chat = ChatFrame1
    chat:SetSize(width, 200)
    function chat:GetFont() return "test", state.size, state.flags end
    chat:AddMessage(TEXT)
    ns.Chat.StripAll()
    local function tick()
        mock.now = mock.now + 1 / 60
        ns.Chat.Update(1 / 60)
    end
    local function changed()
        chat:GetScript("OnSizeChanged")(chat)
    end
    return chat, state, tick, changed
end

h.test("Chat reuses text widths across wrapping, resize, font changes and new text", function(t)
    local A = t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 0 }
    local chat, state, tick, changed = fixture(t, 118)
    tick()
    local bubble = bubbles(chat)[1]
    A.ok(bubble, "no bubble was laid out")
    tick()
    A.eq(bubble:GetHeight(), 52, "Wrapped text must settle without clipping")
    A.eq(state.widthReads, 1, "The shown-frame height pass must reuse the measured text width")
    chat:SetSize(318, 200)
    changed()
    tick()
    A.eq(bubble:GetHeight(), 24, "Resize must fit one row")
    A.eq(state.widthReads, 1, "Resize must reuse the unwrapped width")
    state.size = 28
    changed()
    tick(); tick()
    A.eq(bubble:GetHeight(), 94, "Bigger font must wrap again")
    A.eq(state.widthReads, 2, "Font size changes must invalidate text width")
    state.flags = "OUTLINE"
    changed()
    tick(); tick()
    A.eq(state.widthReads, 3, "Font flags must invalidate text width")
    chat:AddMessage("Changed text")
    tick(); tick()
    A.eq(state.widthReads, 4, "A message with new text must be measured")
end)

h.test("Secret text never enters the unwrapped width measurement", function(t)
    local A = t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 0 }
    local chat, state, tick = fixture(t, 118)
    tick(); tick()
    local reads = state.widthReads
    issecretvalue = function(v) return v == SECRET end
    chat:AddMessage(SECRET)
    tick(); tick()
    A.eq(state.widthReads, reads, "Secret text was measured for its unwrapped width")
end)

h.test("Settled catchers do not read frame levels every frame and follow the chat stacking", function(t)
    local A, mock = t.assert, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 0 }
    local chat, _, tick, changed = fixture(t, 118)
    tick(); tick()
    local catcher = catcherOf(mock)
    A.ok(catcher, "precondition: the chat has a catcher")
    local reads = 0
    for _, f in ipairs({ chat, catcher }) do
        local get = f.GetFrameLevel
        f.GetFrameLevel = function(self) reads = reads + 1; return get(self) end
    end
    for _ = 1, 60 do tick() end
    A.ok(reads <= 12, "Settled catchers read frame levels " .. reads .. " times in 60 frames")
    chat:SetFrameLevel(8)
    changed()
    tick()
    A.eq(catcher:GetFrameLevel(), 9, "A dirty layout must refresh catcher stacking immediately")
    chat:SetFrameStrata("HIGH")
    for _ = 1, 8 do tick() end
    A.eq(catcher:GetFrameStrata(), "HIGH", "Catcher stacking must also refresh without a dirty event")
    chat:Hide()
    tick()
    A.falsy(catcher:IsShown(), "Hidden chat must release its catcher")
    A.falsy(bubbles(chat)[1]:IsShown(), "Hidden chat must release visible overlays")
    chat:SetFrameLevel(12)
    chat:Show()
    tick(); tick()
    A.eq(catcher:GetFrameLevel(), 13, "Reopened chat must restore catcher stacking")
    A.ok(catcher:IsShown() and bubbles(chat)[1]:IsShown(), "Reopened chat must restore its layout")
end)

h.test("Hover reveals chat on the next frame and leaving is noticed on the next", function(t)
    local A, mock = t.assert, t.mock
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 10 }
    local chat, _, tick = fixture(t, 118)
    tick(); tick()
    mock.now = mock.now + 9.5
    for _ = 1, 40 do tick() end
    local bubble = bubbles(chat)[1]
    A.falsy(bubble:IsShown(), "precondition: the expired line left the bottom view")
    local catcher = catcherOf(mock)
    catcher:SetMouseOver(true)
    mock.state.cursor = { 10, 10 }
    tick()
    A.ok(bubble:IsShown() and bubble:GetAlpha() == 1, "Hover must restore expired history on the next frame")
    catcher:SetMouseOver(false)
    mock.state.cursor = { 20, 20 }
    for _ = 1, 30 do tick() end
    A.falsy(bubble:IsShown(), "Leaving chat must fade the history away again")
end)

h.test("A layout reads the fade setting once and timed lines fade, expire and restore", function(t)
    local A, mock, ns = t.assert, t.mock, t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 10 }
    local chat, _, tick = fixture(t, 318)
    tick(); tick()
    local bubble = bubbles(chat)[1]
    local read = ns.Settings.ChatFade
    local fadeReads = 0
    ns.Settings.ChatFade = function() fadeReads = fadeReads + 1; return read() end
    chat:GetScript("OnSizeChanged")(chat)
    tick()
    A.eq(fadeReads, 1, "A layout must read the fade setting once for all its lines")
    mock.now = mock.now + 9.5
    tick()
    A.ok(bubble:GetAlpha() > 0 and bubble:GetAlpha() < 1, "Scheduled fade must animate: " .. bubble:GetAlpha())
    for _ = 1, 40 do tick() end
    A.falsy(bubble:IsShown(), "Expired lines must leave the bottom view")
    ns.Chat.Restore()
    tick(); tick()
    A.ok(catcherOf(mock):IsShown(), "Restore and reapply must refresh the catcher immediately")
end)

h.test("A still pointer reads chat and tab hover at most every 0.1 s instead of every frame", function(t)
    local A, mock, ns = t.assert, t.mock, t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 10 }
    local _, _, tick = fixture(t, 118)
    tick(); tick()
    local reads = 0
    local over = ns.MouseOver
    ns.MouseOver = function(...) reads = reads + 1; return over(...) end
    for i = 1, 60 do
        mock.state.cursor = { i, i }
        tick()
    end
    local moving = reads
    reads = 0
    for _ = 1, 60 do tick() end
    A.ok(moving > 0, "a moving pointer reads hover")
    A.ok(reads * 4 <= moving, "a still pointer reads hover far less often: " .. reads .. " vs " .. moving)
    ns.MouseOver = over
end)
