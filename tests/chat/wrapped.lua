-- Wrapped history, scrolling, hover, resizing, secret text and line spacing all settle
-- on the real rendered height, and a settled chat stops measuring.
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

-- Three 60px words total 200px with spaces, but need three rows at 100px.
local function scenarioChat(t, scenario)
    local ns = t.ns
    QuietUIDB = { enabled = true }
    QuietUICharDB = { chatFade = 0 }
    local stats = { reads = 0, widthReads = 0 }
    if scenario == "secret" then
        issecretvalue = function(v) return v == SECRET end
    end

    local create = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local frame = create(kind, name, parent, template)
        local makeFont = frame.CreateFontString
        frame.CreateFontString = function(self, ...)
            local fs = makeFont(self, ...)
            function fs:GetFont() return "test", 14, "" end
            function fs:GetStringWidth()
                if self._w >= 8000 then return 200 end
                return #tostring(self._text) * 6
            end
            function fs:GetStringHeight()
                stats.reads = stats.reads + 1
                if scenario == "secret" and stats.reads == 1 then return 0 end
                return self._w >= 200 and 14 or 42
            end
            function fs:GetNumLines() return self._w >= 200 and 1 or 3 end
            function fs:GetLineHeight() return 14 end
            function fs:GetSpacing() return scenario == "spacing" and 2 or 0 end
            return fs
        end
        -- Manual link rectangles are out of scope here.
        frame.SetHyperlinksEnabled = false
        return frame
    end

    local chat = ChatFrame1
    chat:SetSize(scenario == "resize" and 318 or 118, 200)
    function chat:GetFont() return "test", 14, "" end
    function chat:ScrollUp() self.scrollOffset = (self.scrollOffset or 0) + 1 end
    local getWidth = chat.GetWidth
    function chat:GetWidth() stats.widthReads = stats.widthReads + 1; return getWidth(self) end
    -- History the client already holds when the addon binds the window.
    chat:AddMessage(scenario == "secret" and SECRET or TEXT)
    if scenario == "scroll" then chat:AddMessage("newer line") end
    ns.StripAllChat()
    if scenario == "scroll" then chat:ScrollUp() end
    if scenario == "hover" then
        local found = 0
        for _, f in ipairs(t.mock.frames) do
            if f._parent == UIParent and f._kind == "Frame" and f._scripts.OnMouseWheel then
                f:SetMouseOver(true)
                found = found + 1
            end
        end
        t.assert.ok(found >= 1, "hover catcher exists")
    end
    return chat, stats
end

for _, scenario in ipairs({ "history", "scroll", "hover", "resize", "secret", "spacing" }) do
    h.test("Chat verifies wrapped history and resized bubbles before going idle: " .. scenario, function(t)
        local ns, A = t.ns, t.assert
        local chat, stats = scenarioChat(t, scenario)
        ns.UpdateChat(1 / 60)
        local bubble = bubbles(chat)[1]
        A.ok(bubble, scenario .. ": no bubble was laid out")
        if scenario == "resize" then
            A.ok(bubble:GetHeight() > 0, "resize: single row was laid out")
            chat:SetSize(118, 200)
            chat:GetScript("OnSizeChanged")(chat)
            ns.UpdateChat(1 / 60)
        end
        ns.UpdateChat(1 / 60)
        if scenario == "secret" then
            ns.UpdateChat(1 / 60)
        end
        A.ok(bubble:GetHeight() >= 52, scenario .. ": last row remains clipped " .. bubble:GetHeight() .. " w" .. bubble:GetWidth())
        if scenario == "secret" then
            A.eq(bubble:GetHeight(), 52, "secret: zero height must not stay cached")
        end
        -- Settled: further frames neither wake the layout nor measure the text again.
        local reads, widths = stats.reads, stats.widthReads
        for _ = 1, (scenario == "spacing") and 600 or 3 do ns.UpdateChat(1 / 60) end
        A.eq(stats.reads, reads, scenario .. ": idle chat remeasured text")
        A.eq(stats.widthReads, widths, scenario .. ": settled chat keeps waking")
    end)
end
