-- Run from the addon directory: lua tests/chat-links.lua
local function upvalue(fn, name)
    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error('Missing helper: ' .. name)
end

local ns = {}
assert(loadfile('Chat.lua'))('QuietUI', ns)
local layout = upvalue(ns.UpdateChat, 'LayoutFrame')
local size = upvalue(layout, 'SizeBubble')
local makeLink = upvalue(upvalue(size, 'PlaceLinks'), 'MakeLink')

CreateFrame = function()
    local button = { scripts = {} }
    function button:RegisterForClicks() end
    function button:EnableMouseWheel() end
    function button:Hide() end
    function button:SetScript(name, fn) self.scripts[name] = fn end
    return button
end

local hyperlinks, opened, shown, hidden = {}, {}, 0, 0
GameTooltip = {
    SetOwner = function() end,
    SetHyperlink = function(_, link) hyperlinks[#hyperlinks + 1] = link end,
    SetText = function(_, text) assert(text == '[Tailoring]') end,
    Show = function() shown = shown + 1 end,
    Hide = function() hidden = hidden + 1 end,
}
SetItemRef = function(link, text, button, chat)
    opened[#opened + 1] = { link, text, button, chat }
end

local chat = {}
local button = makeLink({ chat = chat })
button.display = '[Tailoring]'
for _, kind in ipairs({ 'trade', 'garrtrade', 'player', 'unknown' }) do
    button.link = kind .. ':123'
    button.scripts.OnEnter(button)
    assert(#hyperlinks == 0, kind .. ' hover dispatched a hyperlink')
    assert(#opened == 0, kind .. ' hover opened a link')
    button.scripts.OnLeave(button)
end
assert(shown == 4 and hidden == 4, 'Plain hover tooltip did not show and hide')

button.link = 'trade:123'
button.scripts.OnClick(button, 'LeftButton')
assert(#opened == 1, 'Profession click did not open the link')
assert(opened[1][1] == button.link and opened[1][2] == button.display)
assert(opened[1][3] == 'LeftButton' and opened[1][4] == chat)

for _, kind in ipairs({ 'item', 'spell', 'enchant', 'quest', 'achievement', 'currency' }) do
    button.link = kind .. ':123'
    button.scripts.OnEnter(button)
    assert(hyperlinks[#hyperlinks] == button.link, kind .. ' tooltip was lost')
end
assert(#hyperlinks == 6 and #opened == 1)
print('PASS Chat link hover keeps profession links click-only and preserves tooltips')
