-- Run from the addon directory: lua tests/chat-performance.lua [runtime-directory]
local root = arg[1] or '.'
local now, widthReads, levelReads, fadeReads = 100, 0, 0, 0
local hovered, life = false, 0
local function frame(parent)
    local f = { parent = parent, shown = true, width = 118, height = 200,
        alpha = 1, font = 'test', size = 14, flags = '', level = 1, strata = 'LOW' }
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
    function f:GetStringWidth() widthReads = widthReads + 1; return 200 * self.size / 14 end
    function f:GetStringHeight() return self.width >= 200 * self.size / 14 and self.size or self.size * 3 end
    function f:GetFrameLevel() levelReads = levelReads + 1; return self.level end
    function f:SetFrameLevel(level) self.level = level end
    function f:GetFrameStrata() return self.strata end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:CreateFontString() return frame(self) end
    for _, name in ipairs({ 'ClearAllPoints', 'SetPoint', 'SetAllPoints', 'EnableMouse',
        'SetTextColor', 'SetJustifyH', 'SetJustifyV', 'SetWordWrap', 'SetNonSpaceWrap',
        'SetHyperlinksEnabled' }) do f[name] = function() end end
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
ns.ChatFade = function() fadeReads = fadeReads + 1; return life end
ns.Hit = function() return hovered end
ns.PointerMoved = function() return true end
ns.MouseOver = function() return false end
assert(loadfile(root .. '/Chat.lua'))('QuietUI', ns)

local chat = frame(UIParent)
ChatFrame1 = chat
chat._quietBubbles, chat._quietDirty = true, true
chat._quietCatcher = frame(UIParent)
chat._quietPool = {}
local msg = { text = 'AAAAAA BBBBBB CCCCCC', born = now }
local bubble = frame(chat)
bubble.text, bubble.msg, bubble.chat = frame(bubble), msg, chat
bubble.links, bubble._quietNativeLinks = {}, true
bubble._y = 4
chat._quietLines, chat._quietByMsg = { msg }, { [msg] = bubble }
local function tick()
    now = now + 1 / 60
    ns.UpdateChat(1 / 60)
end

tick()
assert(chat._quietNext == 0, 'Wrapped text must wait for a shown-frame height measurement')
tick()
assert(bubble.height == 52 and chat._quietNext == nil, 'Wrapped text must settle without clipping')
print(('Wrapped chat measurement: width reads=%d'):format(widthReads))
assert(widthReads == 1, 'The shown-frame height pass must reuse the measured text width')
chat.width, chat._quietDirty = 318, true
tick()
assert(bubble.height == 24 and widthReads == 1, 'Resize must reuse unwrapped width and fit one row')
chat.size, chat._quietDirty = 28, true
tick(); tick()
assert(widthReads == 2 and bubble.height == 94, 'Font size changes must invalidate text width')
chat.flags, chat._quietDirty = 'OUTLINE', true
tick(); tick()
assert(widthReads == 3, 'Font flags must invalidate text width')
msg.text, chat._quietDirty = 'Changed text', true
tick(); tick()
assert(widthReads == 4, 'Changed message text must invalidate text width')
local reads = widthReads
msg.secret, msg.text, chat._quietDirty = true, { secret = true }, true
tick(); tick()
assert(widthReads == reads, 'Secret text must never enter the unwrapped measurement cache')
print('PASS chat reuses text widths while preserving wrapping, resize, font changes and secret text')

levelReads = 0
for _ = 1, 60 do tick() end
print(('Settled chat, 60 frames: frame-level reads=%d'):format(levelReads))
assert(levelReads <= 12, 'Settled catchers must not read frame levels on every frame')
hovered = true
tick()
assert(chat._quietHover, 'Hover must reveal chat on the next frame')
hovered = false
tick()
assert(not chat._quietHover, 'Leaving chat must be noticed on the next frame')
chat.level, chat._quietDirty = 8, true
tick()
assert(chat._quietCatcher.level == 9, 'A dirty layout must refresh catcher stacking immediately')
chat.strata = 'HIGH'
for _ = 1, 8 do tick() end
assert(chat._quietCatcher.strata == 'HIGH', 'Catcher stacking must also refresh without a dirty event')
chat.shown = false
tick()
assert(not chat._quietCatcher.shown and not bubble.shown, 'Hidden chat must release visible overlays')
chat.level, chat.shown = 12, true
tick(); tick()
assert(chat._quietCatcher.level == 13 and bubble.shown, 'Reopened chat must immediately restore its layout')
print('PASS chat catcher polling preserves immediate hover, stacking, hide and reopen')

life = 10
msg.secret, msg.text, msg.born = nil, 'Timed message', now
chat._quietDirty = true
fadeReads = 0
tick()
assert(fadeReads == 1, 'A layout must read the fade setting once for all its lines')
tick()
now = msg.born + 9.5
tick()
assert(bubble.alpha > 0 and bubble.alpha < 1 and chat._quietNext == 0, 'Scheduled fade must animate every frame')
for _ = 1, 40 do tick() end
assert(not bubble.shown, 'Expired lines must leave the bottom view')
hovered = true
tick(); tick()
assert(bubble.shown and bubble.alpha == 1, 'Hover must restore expired history immediately')
hovered = false
for _ = 1, 30 do tick() end
assert(not bubble.shown, 'Leaving history must finish its fade')
ns.RestoreChat()
tick(); tick()
assert(chat._quietCatcher.shown, 'Restore and reapply must refresh the catcher immediately')
print('PASS chat shares layout timing and preserves timed fade, expired history and restore')
