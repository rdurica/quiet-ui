local _, ns = ...

-- Chat lines: channel tags, notice filter, history seed and the per-window binding.

local Chat = ns.Chat

-- Longer tags first, so [Raid Leader] is not cut down to [Raid].
local CHAT_TAGS = {
    { "Battleground Leader", "BL" },
    { "Instance Leader", "IL" },
    { "Raid Warning", "RW" },
    { "Raid Leader", "RL" },
    { "Party Leader", "PL" },
    { "Battleground", "BG" },
    { "Officer", "O" },
    { "Instance", "I" },
    { "Guild", "G" },
    { "Party", "P" },
    { "Raid", "R" },
}

local TAG_SHORT = {}
for i = 1, #CHAT_TAGS do
    TAG_SHORT[CHAT_TAGS[i][1]] = CHAT_TAGS[i][2]
end

local TIMESTAMPS = {
    "^%[%d%d?:%d%d:?%d*%s?[AaPp]?[Mm]?%]%s*",
    "^%d%d?:%d%d:?%d*%s?[AaPp]?[Mm]?%s+",
}

local function SkipCodes(text, pos)
    while true do
        local _, e = text:find("^|c%x%x%x%x%x%x%x%x", pos)
        if not e then _, e = text:find("^|r", pos) end
        if not e then _, e = text:find("^%s+", pos) end
        if not e then return pos end
        pos = e + 1
    end
end

-- Only the channel tag that opens the line: [2. Trade - English] becomes [2],
-- [Guild] becomes [G]. Brackets inside the message stay as typed.
local function ShortChannel(text)
    if not text:find("[", 1, true) then return text end
    local pos = SkipCodes(text, 1)
    for i = 1, #TIMESTAMPS do
        local _, e = text:find(TIMESTAMPS[i], pos)
        if e then
            pos = SkipCodes(text, e + 1)
            break
        end
    end
    local from, to = text:match("^|Hchannel:[^|]*|h%[()[^%]]*()%]|h", pos)
    if not from then from, to = text:match("^%[()[^%]]*()%]", pos) end
    if not from then return text end
    local inner = text:sub(from, to - 1)
    local short = inner:match("^(%d+)%.%s*%S") or TAG_SHORT[inner]
    if not short then return text end
    return text:sub(1, from - 1) .. short .. text:sub(to)
end

-- "Changed Channel: |Hchannel:%d|h[%s]|h" -> "Changed Channel:".
-- A missing global keeps the English lead from this client.
local NOTICE_SOURCES = {
    { "CHAT_YOU_CHANGED_NOTICE", "Changed Channel:" },
    { "CHAT_YOU_LEFT_NOTICE", "Left Channel:" },
    { "CHAT_SUSPENDED_NOTICE", "Left Channel:" },
    { "CHAT_YOU_JOINED_NOTICE", "Joined Channel:" },
}

local function NoticeLead(fmt, fallback)
    if type(fmt) ~= "string" then return fallback end
    local lead = fmt:match("^([^|%%]+)")
    if not lead then return fallback end
    lead = lead:gsub("%s+$", "")
    if lead == "" then return fallback end
    return lead
end

local NOTICE_LEADS = {}
do
    local seen = {}
    for i = 1, #NOTICE_SOURCES do
        local src = NOTICE_SOURCES[i]
        local lead = NoticeLead(_G[src[1]], src[2])
        if not seen[lead] then
            seen[lead] = true
            NOTICE_LEADS[#NOTICE_LEADS + 1] = lead
        end
    end
end

local function PlainLine(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h", "")
    text = text:gsub("|h", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("^%s*%[%d+:%d+:?%d*%]%s*", "")
    text = text:gsub("^%s*%d%d?:%d%d:%d%d%s+", "")
    text = text:gsub("^%s*%d%d?:%d%d%s+", "")
    return text:match("^%s*(.*)") or text
end

-- Zone notices shorten to "Changed Channel: [1]", which says nothing.
local function ChannelNotice(text)
    text = PlainLine(text)
    for i = 1, #NOTICE_LEADS do
        local lead = NOTICE_LEADS[i]
        if text:sub(1, #lead) == lead then return true end
    end
    return false
end

local function PushLine(frame, text, r, g, b, animate)
    -- A boss yell can be a secret string. Comparing or editing it throws.
    if type(text) ~= "string" then return end
    local secret = ns.IsSecret(text)
    if not secret then
        if text == "" then return end
        if ChannelNotice(text) then return end
        text = ShortChannel(text)
    end
    local lines = frame._quietLines
    if not lines then return end
    local now = GetTime()
    local entry = {
        text = text,
        secret = secret and true or nil,
        r = type(r) == "number" and r or 1,
        g = type(g) == "number" and g or 1,
        b = type(b) == "number" and b or 1,
        born = now,
        slide = animate and now or nil,
    }
    -- Always the newest entry. The client sometimes passes addToStart, which
    -- would pin a new line to the top of this stack.
    lines[#lines + 1] = entry
    local n = #lines
    local over = n - Chat.MaxLines(frame)
    if over > 0 then
        for i = 1, n - over do
            lines[i] = lines[i + over]
        end
        for i = n - over + 1, n do
            lines[i] = nil
        end
    end
    frame._quietDirty = true
end
-- Visible lines only, oldest first. Used when the frame will not give history back.
local function SeedFromRegions(frame)
    if not frame.GetNumRegions then return end
    local found = {}
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
            local text = region:GetText()
            if ns.IsSecret(text) or (type(text) == "string" and text ~= "") then
                local y = region.GetBottom and region:GetBottom()
                local r, g, b = 1, 1, 1
                if region.GetTextColor then
                    local cr, cg, cb = region:GetTextColor()
                    if type(cr) == "number" then
                        r, g, b = cr, cg, cb
                    end
                end
                found[#found + 1] = {
                    text = text,
                    y = type(y) == "number" and y or 0,
                    r = r, g = g, b = b,
                }
            end
        end
    end
    table.sort(found, function(a, b)
        return a.y > b.y
    end)
    for i = 1, #found do
        local line = found[i]
        PushLine(frame, line.text, line.r, line.g, line.b, false)
    end
end
local function BindBubbles(frame)
    if not frame or frame._quietBubbles or type(frame.AddMessage) ~= "function" then return end
    if not ns.Usable(frame) then return end
    frame._quietBubbles = true
    frame._quietLines = {}
    frame._quietPool = {}
    frame._quietByMsg = {}
    if type(frame.GetNumMessages) == "function" and type(frame.GetMessageInfo) == "function" then
        local ok, n = pcall(frame.GetNumMessages, frame)
        if ok and type(n) == "number" then
            for i = 1, n do
                local okLine, text, r, g, b = pcall(frame.GetMessageInfo, frame, i)
                if not okLine then break end
                PushLine(frame, text, r, g, b, false)
            end
        end
    end
    if #frame._quietLines == 0 then
        pcall(SeedFromRegions, frame)
    end
    Chat.TrackScroll(frame)
    local ok, err = pcall(hooksecurefunc, frame, "AddMessage", function(self, text, r, g, b)
        local bottom = Chat.AtBottom(self)
        if self._quietScrollHook and not bottom then
            self._quietScroll = (self._quietScroll or 0) + 1
        end
        PushLine(self, text, r, g, b, ns.DB().enabled and ns.Settings.ModernChat() and bottom)
        Chat.HideNativeText(self)
        if self._quietScrollHook then
            self._quietScroll = Chat.ClampScroll(self, self._quietScroll or 0)
        end
    end)
    if not ok then ns.Report("chat line", err) end
    if type(frame.Clear) == "function" then
        pcall(hooksecurefunc, frame, "Clear", function(self)
            if self._quietLines then ns.Wipe(self._quietLines) end
            self._quietScroll = 0
            self._quietDirty = true
        end)
    end
    Chat.EnsureCatcher(frame)
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    if frame.HookScript and not frame._quietWheel then
        frame._quietWheel = true
        frame:HookScript("OnMouseWheel", function(self, delta)
            if not ns.DB().enabled or not ns.Settings.ModernChat() then return end
            Chat.Wheel(self, delta)
        end)
    end
end
Chat.BindBubbles = BindBubbles
