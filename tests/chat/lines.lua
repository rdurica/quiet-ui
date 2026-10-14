-- Chat line handling: the recursive text walk only runs for new structure, channel and guild
-- tags are shortened in the line prefix only, and the history keeps the newest 128 lines.
local h = ...

-- Text of every bubble of the window, in creation order.
local function shownTexts(chat)
    local out = {}
    for _, child in ipairs(chat._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" and child._shown then
                out[#out + 1] = region._text
            end
        end
    end
    return out
end

local function visible(text)
    return (text:gsub("|H.-|h", ""):gsub("|h", ""))
end

local function has(list, text)
    for _, v in ipairs(list) do
        if visible(tostring(v)) == text then return true end
    end
    return false
end

-- Binds the window with one native container holding one FontString, like the client does.
local function bound(t)
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 0 }
    local chat = ChatFrame1
    local container = CreateFrame("Frame", nil, chat)
    local first = container:CreateFontString()
    t.ns.Chat.StripAll()
    return chat, container, first
end

-- Enumerations of regions, or of children below the window root: the recursive text walk.
local function walkCounter(t, chat)
    local mock = t.mock
    return function()
        return mock.calls.GetRegions + (mock.calls.GetChildren - (chat._calls.GetChildren or 0))
    end
end

h.test("A new line without new regions or children skips the recursive text walk", function(t)
    local chat = bound(t)
    local walks = walkCounter(t, chat)
    chat:AddMessage("warm up")
    local before = walks()
    chat:AddMessage("plain line")
    t.assert.eq(walks() - before, 0, "Unchanged chat structure still walked the tree")
end)

h.test("A new FontString triggers the walk and is held at alpha 0", function(t)
    local A = t.assert
    local chat, container = bound(t)
    local walks = walkCounter(t, chat)
    chat:AddMessage("settle")
    local added = container:CreateFontString()
    local before = walks()
    chat:AddMessage("line with a new font string")
    A.ok(walks() > before, "A new FontString region did not trigger the text walk")
    A.eq(added:GetAlpha(), 0, "The new FontString was not hidden")
    added:SetAlpha(1)
    A.eq(added:GetAlpha(), 0, "The new FontString was not held at alpha 0")
end)

local function shown(t, text)
    local chat = bound(t)
    chat:AddMessage(text)
    t.ns.Chat.Update(1 / 60)
    return shownTexts(chat)
end

h.test("Guild tag shortens only in the line prefix", function(t)
    local texts = shown(t, "|Hchannel:GUILD|h[Guild]|h Name: ahoj [Guild] svete")
    t.assert.ok(has(texts, "[G] Name: ahoj [Guild] svete"), "Got " .. table.concat(texts, " / "))
end)

h.test("Numbered channel shortens only after the timestamp", function(t)
    local texts = shown(t, "[12:00] [2. Trade - City] Name: prodam [1. foo]")
    t.assert.ok(has(texts, "[12:00] [2] Name: prodam [1. foo]"), "Got " .. table.concat(texts, " / "))
end)

h.test("A line without brackets passes unchanged", function(t)
    local text = "Name: hello 1. Trade - City (Guild) world"
    local texts = shown(t, text)
    t.assert.ok(has(texts, text), "Got " .. table.concat(texts, " / "))
end)

h.test("Capacity keeps the newest 128 lines in order", function(t)
    local A = t.assert
    local chat = bound(t)
    chat.scrollOffset = 0
    function chat:GetScrollOffset() return self.scrollOffset end
    for i = 1, 129 do chat:AddMessage("line " .. i) end
    -- Scrolled to the oldest retained row, line 1 has been dropped and line 2 is first.
    for _, offset in ipairs({ 0, 1, 50, 127, 300 }) do
        chat.scrollOffset, chat._quietDirty = offset, true
        t.ns.Chat.Update(1 / 60)
        local want = "line " .. (129 - math.min(offset, 127))
        local texts = shownTexts(chat)
        A.ok(has(texts, want), "Offset " .. offset .. " should show " .. want .. ": " .. table.concat(texts, " / "))
        A.falsy(has(texts, "line 1"), "The 129th line must have pushed out line 1")
    end
end)
