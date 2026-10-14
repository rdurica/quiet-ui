-- Native chat text and wheel stay untouched when Modern chat or the addon is off,
-- and the traversal of native regions is a single pass.
local h = ...

-- Frames the layout created under a chat window that carry a text region, in creation order.
local function bubbles(chat)
    local out = {}
    for _, child in ipairs(chat._children) do
        for _, region in ipairs(child._regions) do
            if region._kind == "FontString" then out[#out + 1] = child break end
        end
    end
    return out
end

local function nativeChat(t)
    local chat = ChatFrame1
    chat:SetSize(300, 200)
    local font = chat:CreateFontString(nil, "ARTWORK")
    chat.scrolled = 0
    function chat:ScrollUp() self.scrolled = self.scrolled + 1 end
    return chat, font
end

h.test("Native chat stays visible after addon or Modern chat is disabled", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    local chat, font = nativeChat(t)
    ns.Chat.StripAll()
    local wheel = chat:GetScript("OnMouseWheel")
    wheel(chat, 1)
    A.eq(chat.scrolled, 1, "Active chat wheel must work")
    chat:AddMessage("enabled")
    A.alpha(font, 0)
    QuietUICharDB.chat = false
    font:SetAlpha(1)
    chat:AddMessage("modern chat off")
    wheel(chat, 1)
    A.eq(chat.scrolled, 1, "Wheel hook remained active with Modern chat off")
    A.alpha(font, 1, "AddMessage hid native text with Modern chat off")
    QuietUICharDB.chat = nil
    QuietUIDB.enabled = false
    font:SetAlpha(1)
    chat:AddMessage("addon off")
    wheel(chat, 1)
    A.eq(chat.scrolled, 1, "Wheel hook remained active with addon off")
    A.alpha(font, 1, "AddMessage hid native text with addon off")
    -- History was still collected while disabled: the three lines show up once re-enabled.
    QuietUIDB.enabled = true
    ns.Chat.Update(1 / 60)
    A.eq(#bubbles(chat), 3, "History must still be collected while disabled")
end)

h.test("Native chat traversal reads each region and child list once", function(t)
    local ns, A = t.ns, t.assert
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    local chat = ChatFrame1
    for _ = 1, 8 do
        chat:CreateFontString(nil, "ARTWORK")
        CreateFrame("Frame", nil, chat)
    end
    ns.Chat.StripAll()
    chat._calls.GetRegions, chat._calls.GetChildren = 0, 0
    chat:AddMessage("hello")
    A.eq(chat._calls.GetRegions or 0, 1, "Region list reads")
    A.eq(chat._calls.GetChildren or 0, 1, "Child list reads")
end)
