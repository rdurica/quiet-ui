-- Run from the addon directory: lua tests/chat-review.lua
local unpack = table.unpack or unpack
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end

local walks = 0
local function obj(kind, parent)
    local o = { kind = kind, parent = parent, alpha = 1, shown = true, regions = {}, children = {} }
    function o:IsForbidden() return false end
    function o:GetObjectType() return self.kind end
    function o:GetAlpha() return self.alpha end
    function o:SetAlpha(a) self.alpha = a end
    function o:IsShown() return self.shown end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:GetParent() return self.parent end
    function o:GetName() return nil end
    function o:GetNumRegions() return #self.regions end
    function o:GetNumChildren() return #self.children end
    -- Enumerating regions or a non-root child's children is the recursive text walk.
    function o:GetRegions() walks = walks + 1; return unpack(self.regions) end
    function o:GetChildren()
        if self.kind ~= 'ChatRoot' then walks = walks + 1 end
        return unpack(self.children)
    end
    for _, name in ipairs({ 'EnableMouse', 'EnableMouseWheel', 'SetScript', 'HookScript',
        'ClearAllPoints', 'SetPoint', 'SetAllPoints' }) do o[name] = function() end end
    return o
end

hooksecurefunc = function(target, name, hook)
    local original = target[name]
    target[name] = function(self, ...)
        local r = { original(self, ...) }
        hook(self, ...)
        return unpack(r)
    end
end
UIParent = obj('Frame')
CreateFrame = function(_, _, parent) return obj('Frame', parent) end
GetTime = function() return 100 end
NUM_CHAT_WINDOWS = 1
QuietUIDB = { enabled = true }
local ns = {}
assert(loadfile('Core.lua'))('QuietUI', ns)
assert(loadfile('Chat.lua'))('QuietUI', ns)
ns.ModernChat = function() return true end
ns.HideTextures, ns.HideBackground, ns.Mute = function() end, function() end, function() end

local chat = obj('ChatRoot', UIParent)
local container = obj('Frame', chat)
chat.children = { container }
local first = obj('FontString', container)
container.regions = { first }
function chat:AddMessage() end
function chat:GetMaxLines() return 128 end
ChatFrame1 = chat
ns.StripAllChat()
assert(chat._quietLines, 'StripAllChat did not bind chat bubbles')

local function Visible(text)
    return (text:gsub('|H.-|h', ''):gsub('|h', ''))
end
local function Last()
    local lines = chat._quietLines
    return lines[#lines].text
end

test('A new line without new regions or children skips the recursive text walk', function()
    chat:AddMessage('warm up')
    walks = 0
    chat:AddMessage('plain line')
    assert(walks == 0, 'Unchanged chat structure still walked the tree: ' .. walks .. ' enumerations')
end)

test('A new FontString triggers the walk and is held at alpha 0', function()
    chat:AddMessage('settle')
    local added = obj('FontString', container)
    container.regions[#container.regions + 1] = added
    walks = 0
    chat:AddMessage('line with a new font string')
    assert(walks > 0, 'A new FontString region did not trigger the text walk')
    assert(added.alpha == 0, 'The new FontString was not hidden')
    added:SetAlpha(1)
    assert(added.alpha == 0, 'The new FontString was not held at alpha 0')
end)

test('Guild tag shortens only in the line prefix', function()
    chat:AddMessage('|Hchannel:GUILD|h[Guild]|h Name: ahoj [Guild] svete')
    local got = Visible(Last())
    assert(got == '[G] Name: ahoj [Guild] svete', 'Got ' .. got)
end)

test('Numbered channel shortens only after the timestamp', function()
    chat:AddMessage('[12:00] [2. Trade - City] Name: prodam [1. foo]')
    local got = Visible(Last())
    assert(got == '[12:00] [2] Name: prodam [1. foo]', 'Got ' .. got)
end)

test('A line without brackets passes unchanged', function()
    local text = 'Name: hello 1. Trade - City (Guild) world'
    chat:AddMessage(text)
    assert(Last() == text, 'Got ' .. Last())
end)

test('Capacity keeps the newest 128 lines in order', function()
    for i = 1, 129 do chat:AddMessage('line ' .. i) end
    local lines = chat._quietLines
    assert(#lines == 128, 'Kept ' .. #lines .. ' lines')
    for i = 1, 128 do
        assert(lines[i].text == 'line ' .. (i + 1), 'Wrong line at ' .. i .. ': ' .. lines[i].text)
    end
end)

if failures > 0 then
    error(failures .. ' chat review test(s) failed')
end
