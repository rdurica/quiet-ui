-- Run from the addon directory: lua tests/chat-animation.lua [runtime-directory] [--measure]
local root = arg[1] or '.'
local measure = arg[2] == '--measure'
local now, hovered, life, historyReads = 100, false, 0, 0
local function frame(parent)
    local f = { parent = parent, shown = true, width = 340, height = 360,
        alpha = 1, font = 'test', size = 14, flags = '', level = 1, scripts = {} }
    function f:IsForbidden() return false end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetAlpha() return self.alpha end
    function f:SetParent(p) self.parent = p end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetWidth(w) self.width = w end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetFont() return self.font, self.size, self.flags end
    function f:SetFont(font, size, flags) self.font, self.size, self.flags = font, size, flags end
    function f:SetText(text) self.textValue = text end
    function f:GetStringWidth() return #(self.textValue or '') * 7 end
    function f:GetStringHeight() return math.ceil(self:GetStringWidth() / self.width) * self.size end
    function f:GetFrameLevel() return self.level end
    function f:SetFrameLevel(level) self.level = level end
    function f:GetFrameStrata() return 'LOW' end
    function f:SetFrameStrata() end
    function f:CreateFontString() return frame(self) end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    for _, name in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'EnableMouse', 'SetTextColor',
        'SetJustifyH', 'SetJustifyV', 'SetWordWrap', 'SetNonSpaceWrap', 'SetHyperlinksEnabled' }) do
        f[name] = function() end
    end
    return f
end
UIParent = frame()
CreateFrame = function(_, _, parent) return frame(parent) end
GetTime = function() return now end
NUM_CHAT_WINDOWS = 1
QuietUIDB = { enabled = true }
local ns = {}
assert(loadfile(root .. '/Core.lua'))('QuietUI', ns)
ns.ModernChat = function() return true end
ns.ChatFade = function() return life end
ns.Hit = function() return hovered end
ns.PointerMoved = function() return true end
ns.MouseOver = function() return false end
assert(loadfile(root .. '/Chat.lua'))('QuietUI', ns)
local chat, stored = frame(UIParent), {}
ChatFrame1 = chat
chat._quietBubbles, chat._quietDirty = true, true
chat._quietCatcher, chat._quietLines, chat._quietPool = frame(UIParent), {}, {}
chat._quietByMsg = setmetatable({}, {
    __index = function(_, msg) historyReads = historyReads + 1; return stored[msg] end,
    __newindex = function(_, msg, bubble) stored[msg] = bubble end,
    __pairs = function() return next, stored, nil end,
})
for _ = 1, 20 do
    local bubble = frame(chat)
    bubble.text, bubble.links, bubble._quietNativeLinks = frame(bubble), {}, true
    chat._quietPool[#chat._quietPool + 1] = bubble
end
local function tick(elapsed)
    elapsed = elapsed or 1 / 60
    now = now + elapsed
    ns.UpdateChat(elapsed)
end
local function add(text, slide)
    local msg = { text = text, born = now, slide = slide and now or nil }
    chat._quietLines[#chat._quietLines + 1] = msg
    chat._quietDirty = true
    return msg
end
local function close(a, b, message) assert(math.abs(a - b) < 1e-8, message) end
for i = 1, 8 do add('Line ' .. i) end
tick()
assert(chat._quietNext == nil, 'Static chat must go idle')
local previous = chat._quietLines[8]
local incoming = add('Incoming message', true)
tick()
local moving = stored[incoming]
close(moving.x, -11.125, 'The new line must keep its original eased slide')
close(stored[previous].y, 10.3, 'Older lines must keep their original upward easing')
historyReads = 0
tick()
close(moving.x, -8.5, 'The second slide frame must retain its original position')
close(stored[previous].y, 15.13, 'The second stack frame must retain its original position')
for _ = 1, 8 do tick() end
print(('Slide/ease, 9 animation frames: history lookups=%d'):format(historyReads))
if not measure then assert(historyReads == 0, 'Animation-only frames must not rebuild the message stack') end
for _ = 1, 90 do tick() end
assert(chat._quietNext == nil, 'Finished movement must stop waking the layout')
close(moving.x, 4, 'The incoming line must finish at its original anchor')
close(stored[previous].y, 31, 'The old line must finish one row higher')
-- A single expiring line animates while the other eight stay settled.
life = 10
for _, msg in ipairs(chat._quietLines) do msg.born = now end
local expiring = chat._quietLines[4]
expiring.born = now - 9.5
chat._quietDirty = true
tick()
local fading = stored[expiring]
close(fading.alpha, 29 / 30, 'Natural fading must retain its original duration')
historyReads = 0
for _ = 1, 8 do tick() end
print(('One fading line, 8 animation frames: history lookups=%d'):format(historyReads))
if not measure then assert(historyReads == 0, 'One fading line must not rebuild all settled lines') end
for _ = 1, 25 do tick() end
assert(not fading.shown and not stored[expiring], 'Expired rows must be released and removed from the visible stack')
assert(#chat._quietLines == 9, 'Animation must preserve the full chat history')
hovered = true
tick()
assert(stored[expiring] and stored[expiring].alpha == 1, 'Hover must immediately restore expired history')
hovered = false
for _ = 1, 25 do tick() end
assert(not stored[expiring], 'Leaving chat must fade expired history away again')
chat._quietScroll, chat._quietDirty = 2, true
tick()
assert(stored[expiring], 'Scrolling must still reveal expired history')
chat._quietScroll, chat._quietDirty, life = 0, true, 0
chat.width = 118
incoming.text = 'AAAAAA BBBBBB CCCCCC'
tick()
assert(chat._quietNext == 0, 'Wrapped text must still request the shown-frame measurement')
tick()
assert(stored[incoming].height >= 38 and stored[incoming]._quietSizeKey, 'Animation must not bypass wrap verification')
chat.width, chat._quietDirty = 340, true
tick()
assert(stored[incoming].height == 24, 'Resize must invalidate the cached arrangement')
local burstFirst = add('First burst message', true)
tick(1 / 144)
local burstSecond = add('Second burst message', true)
tick(1 / 144)
assert(stored[burstFirst].y > 4 and stored[burstSecond].y == 4,
    'A new message during movement must retarget the older active bubbles')
chat.flags, chat._quietDirty = 'OUTLINE', true
tick(0.08)
assert(stored[burstFirst].text.flags == 'OUTLINE', 'Font changes during animation must rebuild cached sizes')
assert(stored[burstFirst].x < 4, 'A slow frame must retain the remaining slide animation')
tick(0.4)
close(stored[burstFirst].x, 4, 'A long frame must finish the slide without extra animation time')
close(stored[burstFirst].y, 31, 'A long frame must finish the stack movement without extra animation time')
local interrupting = add('Another incoming message', true)
tick()
chat.shown = false
tick()
for _, bubble in pairs(stored) do assert(not bubble.shown, 'Hidden chat must stop all active animations') end
chat.shown = true
tick()
assert(stored[interrupting], 'Reopened chat must rebuild its active message stack')
ns.RestoreChat()
tick()
assert(stored[interrupting], 'Restore/reapply must not animate stale released bubbles')
print('PASS cached animation preserves slide, upward easing, expiry, hover, scroll, wrapping, resize and restore')
