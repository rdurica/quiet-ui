local _, ns = ...

-- Chat keeps its text and drops the chrome. Each line is drawn as its own
-- bubble; the input shows only while it has focus. No ChatFrame_OpenChat:
-- Enter stays a Blizzard binding.

local CHAT_CHROME = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameToggleVoiceSelfMuteButton",
    "ChatFrameToggleVoiceSelfDeafButton",
    "TextToSpeechButton",
    "QuickJoinToastButton",
    "FriendsMicroButton",
}

local CHAT_BUTTON_SUFFIX = {
    "ButtonFrame",
    "ButtonFrameUpButton",
    "ButtonFrameDownButton",
    "ButtonFrameBottomButton",
    "ButtonFrameMinimizeButton",
    "MinimizeButton",
}

local TAB_SUFFIX = {
    "Left", "Middle", "Right",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "Glow",
}

local TAB_KEYS = {
    "leftTexture", "middleTexture", "rightTexture",
    "Left", "Middle", "Right",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "HighlightTexture", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "glow", "Glow",
}

local EDIT_PARTS = {
    "Left", "Mid", "Right", "Middle",
    "FocusLeft", "FocusMid", "FocusRight", "FocusMiddle",
    "left", "mid", "right", "middle",
    "focusLeft", "focusMid", "focusRight", "focusMiddle",
}

local PAD = 5
local GAP = 3
local SLIDE_X = 18
local SLIDE_TIME = 0.2
local FADE_OUT = 0.5
local FADE_UI = 0.3
local MAX_LINKS = 12

local stripping = false
local chromeStripped = false
local measureWide
local copyBox

local function ChatCount()
    return NUM_CHAT_WINDOWS or 10
end

local function Wipe(t)
    if type(wipe) == "function" then
        wipe(t)
        return
    end
    for k in pairs(t) do
        t[k] = nil
    end
end

local function StripTab(tab)
    if not tab or not ns.DB().enabled or not ns.ModernChat() then return end
    local marked = ns.MarkingChat
    ns.MarkingChat = true
    ns.HideTextures(tab)
    local name = ns.FrameName(tab)
    if name then
        for _, suffix in ipairs(TAB_SUFFIX) do
            ns.ForceTextureHidden(_G[name .. suffix])
        end
    end
    for _, key in ipairs(TAB_KEYS) do
        ns.ForceTextureHidden(tab[key])
    end
    if not tab._quietClick and tab.HookScript then
        tab._quietClick = true
        tab:HookScript("OnClick", function()
            if ns.DB().enabled and ns.ModernChat() then StripTab(tab) end
        end)
    end
    ns.MarkingChat = marked
end

------------------------------------------------------------------------------
-- Input box
------------------------------------------------------------------------------
local function Backdropped(kind, name, parent)
    local ok, widget = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and widget then return widget end
    return CreateFrame(kind, name, parent)
end

local ROUND_TEX = "Interface\\AddOns\\QuietUI\\Media\\round"
local ROUND_CUT = 10 / 32
local ROUND_PX = 6

local function MakeRound(parent)
    if parent._quietRound then return end
    local c = ROUND_CUT
    local s = ROUND_PX
    local function piece(x0, x1, y0, y1)
        local tex = parent:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture(ROUND_TEX)
        tex:SetTexCoord(x0, x1, y0, y1)
        return tex
    end
    local tl = piece(0, c, 0, c)
    local tr = piece(1 - c, 1, 0, c)
    local bl = piece(0, c, 1 - c, 1)
    local br = piece(1 - c, 1, 1 - c, 1)
    local top = piece(c, 1 - c, 0, c)
    local bottom = piece(c, 1 - c, 1 - c, 1)
    local left = piece(0, c, c, 1 - c)
    local right = piece(1 - c, 1, c, 1 - c)
    local mid = piece(c, 1 - c, c, 1 - c)
    tl:SetPoint("TOPLEFT")
    tr:SetPoint("TOPRIGHT")
    bl:SetPoint("BOTTOMLEFT")
    br:SetPoint("BOTTOMRIGHT")
    tl:SetSize(s, s)
    tr:SetSize(s, s)
    bl:SetSize(s, s)
    br:SetSize(s, s)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    mid:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
    mid:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    parent._quietRound = { tl, tr, bl, br, top, bottom, left, right, mid }
end

local function TintRound(parent, r, g, b, a)
    MakeRound(parent)
    for i = 1, #parent._quietRound do
        parent._quietRound[i]:SetVertexColor(r, g, b, a)
    end
end

local function Flat(widget, alpha)
    if not widget then return end
    if widget.SetBackdrop then
        pcall(function()
            widget:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            widget:SetBackdropColor(0.05, 0.05, 0.05, alpha or 0.92)
            widget:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
        end)
        return
    end
    if widget.CreateTexture and not widget._quietFill then
        local fill = widget:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        fill:SetVertexColor(0.05, 0.05, 0.05, alpha or 0.92)
        widget._quietFill = fill
    end
end

local function HideEditChrome(edit)
    ns.HideTextures(edit)
    local name = ns.FrameName(edit)
    if name then
        for _, suffix in ipairs(EDIT_PARTS) do
            ns.ForceTextureHidden(_G[name .. suffix])
        end
    end
    for _, key in ipairs(EDIT_PARTS) do
        ns.ForceTextureHidden(edit[key])
    end
    if edit._quietHeader then
        ns.HideTextures(edit._quietHeader)
    end
    if edit.SetBackdropColor then
        pcall(edit.SetBackdropColor, edit, 0, 0, 0, 0)
    end
    if edit.SetBackdropBorderColor then
        pcall(edit.SetBackdropBorderColor, edit, 0, 0, 0, 0)
    end
end

local function PadEdit(edit)
    if edit._quietPadded or not edit.SetTextInsets then return end
    if not edit._quietInsets and edit.GetTextInsets then
        local ok, left, right, top, bottom = pcall(edit.GetTextInsets, edit)
        if ok then
            edit._quietInsets = { left or 0, right or 0, top or 0, bottom or 0 }
        end
    end
    edit._quietPadded = true
    pcall(edit.SetTextInsets, edit, 4, 4, 0, 0)
end

local function UsableNumber(n)
    return type(n) == "number" and not ns.IsSecret(n)
end

-- One point only: a second corner on the edit box stretches the height.
local function PlacePlate(edit)
    local plate = edit._quietPlate
    if not plate then return end
    local header = edit._quietHeader
    local line = (header and header ~= edit and header.GetBottom) and header or edit
    local fontSize = 14
    if edit.GetFont then
        local _, size = edit:GetFont()
        if type(size) == "number" and size > 2 and size < 48 then
            fontSize = size
        end
    end
    local left = line.GetLeft and line:GetLeft()
    local right = edit.GetRight and edit:GetRight()
    local width
    if UsableNumber(left) and UsableNumber(right) and right > left then
        width = (right - left) + 12
    else
        local editW = edit.GetWidth and edit:GetWidth()
        width = (UsableNumber(editW) and editW or 200) + 48
    end
    -- The frame edge sits under the glyphs, so the plate is lifted by one line.
    -- A few extra pixels keep the letters off the top and bottom edges.
    local h = fontSize + 12
    plate:ClearAllPoints()
    plate:SetSize(width, h)
    plate:SetPoint("LEFT", line, "BOTTOMLEFT", -6, fontSize + 1)
end

local function EnsurePlate(edit)
    if edit._quietPlate then return edit._quietPlate end
    local parent = edit.GetParent and edit:GetParent()
    if not parent then return nil end
    local plate = Backdropped("Frame", nil, parent)
    plate:EnableMouse(false)
    TintRound(plate, 0.05, 0.05, 0.05, 0.72)
    plate:SetAlpha(0)
    ns.Remember(plate)
    ns.EnsureAlphaHook(plate)
    ns.NoteChat(plate)
    edit._quietPlate = plate
    return plate
end

local function ChatOf(edit)
    local name = ns.FrameName(edit)
    if name then
        local chatName = name:match("^(ChatFrame%d+)")
        local chat = chatName and _G[chatName]
        if chat then return chat end
    end
    return edit.GetParent and edit:GetParent()
end

-- Focused field sits above the bubbles. The plate stays just behind the field.
local function StackPlate(edit, focused)
    local plate = edit._quietPlate
    if not plate then return end
    local chat = ChatOf(edit)
    if not chat then return end
    local base = ((chat.GetFrameLevel and chat:GetFrameLevel()) or 0) + 2
    local editLevel = focused and (base + 5) or base
    pcall(plate.SetFrameLevel, plate, focused and (base + 4) or base)
    pcall(edit.SetFrameLevel, edit, editLevel)
    if edit._quietHeader and edit._quietHeader.SetFrameLevel then
        pcall(edit._quietHeader.SetFrameLevel, edit._quietHeader, editLevel)
    end
end

local function SyncEdit(edit)
    if not ns.DB().enabled or not ns.ModernChat() then
        edit._quietAlpha = nil
        if edit._quietPlate then
            edit._quietPlate._quietAlpha = nil
            edit._quietPlate:SetAlpha(0)
        end
        return
    end
    local focused = edit._quietFocus or (edit.HasFocus and edit:HasFocus())
    edit._quietWant = focused and 1 or 0
    PadEdit(edit)
    HideEditChrome(edit)
    EnsurePlate(edit)
    PlacePlate(edit)
    StackPlate(edit, focused)
    if edit._quietPlate then
        edit._quietPlate._quietWant = edit._quietWant
    end
end

local function SetFocus(edit, focused)
    edit._quietFocus = focused
    SyncEdit(edit)
end

local function BindEdit(edit)
    if not edit or edit._quietEdit or not edit.HookScript then return end
    edit._quietEdit = true
    ns.Remember(edit)
    ns.EnsureAlphaHook(edit)
    ns.NoteChat(edit)
    edit:HookScript("OnEditFocusGained", function(self) SetFocus(self, true) end)
    edit:HookScript("OnEditFocusLost", function(self) SetFocus(self, false) end)
    edit:HookScript("OnShow", SyncEdit)
    local name = ns.FrameName(edit)
    local header = name and _G[name .. "Header"]
    if not header then
        header = edit.header or edit.Header
    end
    if header and header.SetAlpha and header.GetParent and header:GetParent() ~= edit then
        ns.Remember(header)
        ns.EnsureAlphaHook(header)
        ns.NoteChat(header)
        edit._quietHeader = header
    end
    SyncEdit(edit)
end

-- Focus events can be missed, so visible input boxes are checked every frame.
function ns.SyncVisibleEdits()
    if not ns.DB().enabled or not ns.ModernChat() then return end
    for i = 1, ChatCount() do
        local edit = _G["ChatFrame" .. i .. "EditBox"]
        if edit and edit._quietEdit and edit:IsShown() then
            local focused = edit.HasFocus and edit:HasFocus() and true or false
            if focused then
                if not edit._quietFocus or edit._quietWant ~= 1 then
                    edit._quietFocus = true
                    SyncEdit(edit)
                end
                StackPlate(edit, true)
                PlacePlate(edit)
            elseif edit._quietFocus or edit._quietWant ~= 0 then
                SetFocus(edit, false)
            else
                StackPlate(edit, false)
            end
        end
    end
end

local function RestoreEdits()
    for i = 1, ChatCount() do
        local edit = _G["ChatFrame" .. i .. "EditBox"]
        if edit then
            if edit._quietInsets and edit.SetTextInsets then
                pcall(edit.SetTextInsets, edit, edit._quietInsets[1], edit._quietInsets[2], edit._quietInsets[3], edit._quietInsets[4])
            end
            edit._quietPadded = nil
            edit._quietFocus = nil
            ns.ReleaseAlpha(edit)
            if edit._quietHeader then
                ns.ReleaseAlpha(edit._quietHeader)
            end
            if edit._quietPlate then
                edit._quietPlate._quietAlpha = nil
                edit._quietPlate._quietApplying = true
                edit._quietPlate:SetAlpha(0)
                edit._quietPlate._quietApplying = false
            end
        end
    end
end

------------------------------------------------------------------------------
-- Bubbles. Native lines stay so scroll and history keep working; their alpha
-- is held at 0 so the text is not drawn twice.
------------------------------------------------------------------------------
local function ScrollOffset(frame)
    if type(frame.GetScrollOffset) == "function" then
        local ok, offset = pcall(frame.GetScrollOffset, frame)
        if ok and type(offset) == "number" and not ns.IsSecret(offset) then
            return offset
        end
    end
    if type(frame.scrollOffset) == "number" then
        return frame.scrollOffset
    end
    return frame._quietScroll or 0
end

local function AtBottom(frame)
    if type(frame.AtBottom) == "function" then
        local ok, at = pcall(frame.AtBottom, frame)
        if ok then return not not at end
    end
    return ScrollOffset(frame) < 1
end

local function ClampScroll(frame, value)
    if value < 0 then return 0 end
    local max = frame._quietLines and #frame._quietLines or 0
    if value > max then return max end
    return value
end

local function TrackScroll(frame)
    if frame._quietScrollHook then return end
    frame._quietScrollHook = true
    local native = type(frame.GetScrollOffset) == "function"
    if not native then
        frame._quietScroll = 0
    end
    local function hook(name, fn)
        if type(frame[name]) ~= "function" then return end
        pcall(hooksecurefunc, frame, name, function(self)
            self._quietDirty = true
            if fn then fn(self) end
        end)
    end
    if native then
        hook("ScrollUp")
        hook("ScrollDown")
        hook("PageUp")
        hook("PageDown")
        hook("ScrollToBottom")
    else
        hook("ScrollUp", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) + 1)
        end)
        hook("ScrollDown", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) - 1)
        end)
        hook("PageUp", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) + 10)
        end)
        hook("PageDown", function(self)
            self._quietScroll = ClampScroll(self, (self._quietScroll or 0) - 10)
        end)
        hook("ScrollToBottom", function(self)
            self._quietScroll = 0
        end)
    end
    if frame.HookScript then
        frame:HookScript("OnSizeChanged", function(self)
            self._quietDirty = true
        end)
    end
end

local function MaxLines(frame)
    if type(frame.GetMaxLines) == "function" then
        local ok, n = pcall(frame.GetMaxLines, frame)
        if ok and type(n) == "number" and n > 1 then return math.floor(n) end
    end
    return 128
end

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

-- [2. Trade - English] becomes [2], [Guild] becomes [G].
local function ShortChannel(text)
    text = text:gsub("%[(%d+)%.%s*[^%]]+%]", "[%1]")
    for i = 1, #CHAT_TAGS do
        text = text:gsub("%[" .. CHAT_TAGS[i][1] .. "%]", "[" .. CHAT_TAGS[i][2] .. "]")
    end
    return text
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
    local cap = MaxLines(frame)
    while #lines > cap do
        table.remove(lines, 1)
    end
    frame._quietDirty = true
end

local function HoldFont(frame, fs)
    if not fs or not fs.SetAlpha or not fs.GetObjectType then return end
    if fs:GetObjectType() ~= "FontString" then return end
    local saved = frame._quietFontAlpha
    if not saved then
        saved = {}
        frame._quietFontAlpha = saved
    end
    if saved[fs] == nil then
        local alpha = fs.GetAlpha and fs:GetAlpha()
        if ns.IsSecret(alpha) or type(alpha) ~= "number" or alpha < 0.05 then alpha = 1 end
        saved[fs] = alpha
    end
    -- Chat fade writes alpha back after OnUpdate. Hold 0 the same way textures do.
    if not fs._quietHoldHook then
        fs._quietHoldHook = true
        pcall(hooksecurefunc, fs, "SetAlpha", function(self, alpha)
            if self._quietApplying or not ns.DB().enabled then return end
            if ns.ModernChat and not ns.ModernChat() then return end
            if type(alpha) == "number" and not ns.IsSecret(alpha) and alpha < 0.01 then return end
            self._quietApplying = true
            self:SetAlpha(0)
            self._quietApplying = false
        end)
    end
    local alpha = fs:GetAlpha()
    if ns.IsSecret(alpha) or type(alpha) ~= "number" or alpha >= 0.01 then
        fs._quietApplying = true
        fs:SetAlpha(0)
        fs._quietApplying = false
    end
end

local function SkipChild(child)
    if not child or child._quietBubble or child._quietPlate or child._quietEdit then
        return true
    end
    local name = child.GetName and child:GetName()
    if type(name) == "string" and (name:find("EditBox", 1, true) or name:find("Tab", 1, true)) then
        return true
    end
    return false
end

local function Forbidden(obj)
    if not obj or not obj.IsForbidden then return false end
    local ok, forbidden = pcall(obj.IsForbidden, obj)
    return ok and forbidden or false
end

-- A previous build shrank this font to hide the native lines and the client
-- stored that size. Put a normal size back once, without hooking SetFont.
local function RepairTinyFont(frame)
    if frame._quietFontRepaired or not frame.GetFont or not frame.SetFont then return end
    frame._quietFontRepaired = true
    local ok, font, size, flags = pcall(frame.GetFont, frame)
    if not ok or type(size) ~= "number" or size > 2 then return end
    pcall(frame.SetFont, frame, font or "Fonts\\FRIZQT__.TTF", 14, flags or "")
end

local function HideNativeText(frame)
    if not ns.DB().enabled or not ns.ModernChat() then return end
    local function walk(obj, depth)
        if not obj or depth > 5 or Forbidden(obj) then return end
        if obj.GetNumRegions then
            local regions = { obj:GetRegions() }
            for i = 1, #regions do
                local region = regions[i]
                if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                    HoldFont(frame, region)
                end
            end
        end
        if not obj.GetNumChildren then return end
        local children = { obj:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if ns.Usable(child) and not SkipChild(child) then
                walk(child, depth + 1)
            end
        end
    end
    pcall(walk, frame, 0)
end

local function RestoreFonts(frame)
    local saved = frame._quietFontAlpha
    if saved then
        for fs, alpha in pairs(saved) do
            if fs then
                if fs.SetAlpha then
                    fs._quietApplying = true
                    fs:SetAlpha(alpha or 1)
                    fs._quietApplying = false
                end
            end
        end
    end
    frame._quietFontAlpha = nil
end

local function Wheel(frame, delta)
    if not frame or type(delta) ~= "number" then return end
    if delta > 0 and type(frame.ScrollUp) == "function" then
        pcall(frame.ScrollUp, frame)
    elseif delta < 0 and type(frame.ScrollDown) == "function" then
        pcall(frame.ScrollDown, frame)
    end
end

local function StripCodes(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function PlainText(text)
    if type(text) ~= "string" then return "" end
    text = text:gsub("|H.-|h(.-)|h", function(display)
        return StripCodes(display)
    end)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|n", "\n")
    return text
end

local function TextureWidth(spec)
    local w = tonumber(spec:match(":(%d+)"))
    if w and w > 0 then return w end
    return 16
end

local function AddPlain(segs, chunk)
    local pos = 1
    while pos <= #chunk do
        local space, finish = chunk:find("%s+", pos)
        if space == pos then
            segs[#segs + 1] = { text = chunk:sub(space, finish) }
            pos = finish + 1
        else
            local wordEnd = (space or (#chunk + 1)) - 1
            local word = chunk:sub(pos, wordEnd)
            if word ~= "" then
                segs[#segs + 1] = { text = word }
            end
            pos = wordEnd + 1
        end
    end
end

local function Segments(text)
    local segs = {}
    if type(text) ~= "string" or text == "" then return segs end
    local i = 1
    local n = #text
    local guard = 0
    while i <= n and guard <= n do
        guard = guard + 1
        local rest = text:sub(i)
        local start = i
        local color = rest:match("^|c%x%x%x%x%x%x%x%x")
        if color then
            i = i + 10
        elseif rest:sub(1, 2) == "|r" or rest:sub(1, 2) == "|n" then
            if rest:sub(1, 2) == "|n" then
                segs[#segs + 1] = { br = true }
            end
            i = i + 2
        elseif rest:sub(1, 1) == "\n" then
            segs[#segs + 1] = { br = true }
            i = i + 1
        else
            local link, display = rest:match("^|H(.-)|h(.-)|h")
            if link then
                i = i + #("|H" .. link .. "|h" .. display .. "|h")
                segs[#segs + 1] = { link = link, text = StripCodes(display) }
            else
                local tex = rest:match("^|T(.-)|t")
                if tex then
                    i = i + #tex + 4
                    segs[#segs + 1] = { text = "", width = TextureWidth(tex) }
                else
                    local pipe = rest:find("|", 2, true)
                    local nl = rest:find("\n", 2, true)
                    local stop
                    if pipe and nl then
                        stop = math.min(pipe, nl)
                    else
                        stop = pipe or nl
                    end
                    local chunk = stop and rest:sub(1, stop - 1) or rest
                    if chunk ~= "" then
                        AddPlain(segs, chunk)
                    end
                    i = i + #chunk
                end
            end
        end
        if i <= start then i = start + 1 end
    end
    return segs
end

-- A hidden font string reports 0. Alpha 0 still lays the text out.
-- The host is wider than a chat line so the unwrapped width is not clipped.
local function EnsureMeasure()
    if measureWide then return measureWide end
    local host = CreateFrame("Frame", nil, UIParent)
    host:SetAlpha(0)
    host:EnableMouse(false)
    host:SetSize(8192, 64)
    host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 4000)
    host:Show()
    measureWide = host:CreateFontString(nil, "OVERLAY")
    measureWide:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    measureWide:SetJustifyH("LEFT")
    measureWide:SetJustifyV("TOP")
    if measureWide.SetWordWrap then measureWide:SetWordWrap(false) end
    if measureWide.SetNonSpaceWrap then measureWide:SetNonSpaceWrap(false) end
    measureWide:SetWidth(8000)
    return measureWide
end

local function PrepareProbe(fs, probe)
    local font, size, flags = fs:GetFont()
    pcall(probe.SetFont, probe, font or "Fonts\\FRIZQT__.TTF", size or 12, flags or "")
    if fs.GetSpacing and probe.SetSpacing then
        local spacing = fs:GetSpacing()
        if type(spacing) == "number" then
            probe:SetSpacing(spacing)
        end
    end
    return probe
end

-- Wrap stays off, so a long line is not reported as the width of its first row.
local function UnboundedWidth(fs, text)
    local probe = PrepareProbe(fs, EnsureMeasure())
    probe:SetWidth(8000)
    probe:SetText(text or "")
    local wide = 0
    local w = probe:GetStringWidth()
    if type(w) == "number" and not ns.IsSecret(w) and w > 0 then wide = w end
    if probe.GetUnboundedStringWidth then
        local ok, uw = pcall(probe.GetUnboundedStringWidth, probe)
        if ok and type(uw) == "number" and not ns.IsSecret(uw) and uw > wide then
            wide = uw
        end
    end
    return wide
end

local function OpenLink(chat, link, text, button)
    if type(link) ~= "string" or link == "" then return end
    if type(SetItemRef) == "function" then
        if pcall(SetItemRef, link, text, button, chat) then return end
    end
    if type(ChatFrame_OnHyperlinkShow) == "function" then
        pcall(ChatFrame_OnHyperlinkShow, chat, link, text, button)
    end
end

-- Trade links can open the profession window even through GameTooltip.
local TOOLTIP_LINKS = {
    item = true, spell = true, enchant = true, quest = true,
    achievement = true, currency = true,
}

local function ShowLinkTip(button, link, display)
    link = link or button.link
    display = display or button.display
    if not GameTooltip or not GameTooltip.SetOwner then return end
    GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
    local shown = false
    local kind = type(link) == "string" and link:match("^([^:]+):")
    if GameTooltip.SetHyperlink and TOOLTIP_LINKS[kind] then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    end
    if not shown and GameTooltip.SetText then
        pcall(GameTooltip.SetText, GameTooltip, display or "", 1, 1, 1)
    end
    if GameTooltip.Show then GameTooltip:Show() end
end

local function HideTip()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

local function HideCopyBox()
    if not copyBox then return end
    local anchor = copyBox.anchor
    copyBox.anchor = nil
    copyBox._quietStick = nil
    copyBox:Hide()
    if anchor and anchor.chat then anchor.chat._quietDirty = true end
end

local function EnsureCopyBox()
    if copyBox then return copyBox end
    local box = Backdropped("EditBox", nil, UIParent)
    copyBox = box
    pcall(function()
        box:SetFrameStrata("DIALOG")
        box:SetSize(220, 24)
        box:SetAutoFocus(false)
        local font = ChatFontNormal or GameFontHighlight
        if font and box.SetFontObject then
            box:SetFontObject(font)
        end
        if box.SetTextInsets then box:SetTextInsets(6, 6, 2, 2) end
        if box.SetClampedToScreen then box:SetClampedToScreen(true) end
        box:EnableMouse(true)
    end)
    box:Hide()
    Flat(box, 0.94)
    box:SetScript("OnEscapePressed", function(self)
        self._quietStick = nil
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self._quietStick = nil
        self:ClearFocus()
    end)
    -- The click that opens the box also drops focus.
    box:SetScript("OnEditFocusLost", function(self)
        if self._quietStick and GetTime() < self._quietStick then
            local function refocus()
                if not self:IsShown() then return end
                self:SetFocus()
                self:HighlightText()
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, refocus)
            end
            return
        end
        local anchor = self.anchor
        self:Hide()
        if anchor and anchor.chat then anchor.chat._quietDirty = true end
    end)
    copyBox = box
    return box
end

-- A secure global pops ADDON_ACTION_BLOCKED when an addon calls it. pcall does not stop that.
local function InsecureGlobal(name)
    if type(_G[name]) ~= "function" then return nil end
    if type(issecurevariable) == "function" and issecurevariable(name) then return nil end
    return _G[name]
end

local function WriteClipboard(text)
    local copy = InsecureGlobal("CopyToClipboard")
    if copy and pcall(copy, text) then return true end
    if not C_System or type(C_System.SetClipboard) ~= "function" then return false end
    if type(issecurevariable) == "function" and issecurevariable(C_System, "SetClipboard") then
        return false
    end
    return pcall(C_System.SetClipboard, text)
end

local function ShowCopyBox(anchor, text)
    local box = EnsureCopyBox()
    box.anchor = anchor
    box._quietStick = GetTime() + 0.2
    box:ClearAllPoints()
    local width = 220
    if anchor.GetWidth then
        local w = anchor:GetWidth()
        if type(w) == "number" and not ns.IsSecret(w) then
            width = math.max(180, math.min(420, w))
        end
    end
    box:SetSize(width, 24)
    box:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    box:SetText(text)
    box:Show()
    if anchor.chat then anchor.chat._quietDirty = true end
    local function focus()
        if not box:IsShown() then return end
        box:SetFocus()
        box:HighlightText()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, focus)
    else
        focus()
    end
end

local function CopyLine(bubble)
    local msg = bubble.msg
    if not msg or msg.secret then return end
    local text = PlainText(msg.text)
    if text == "" then return end
    if WriteClipboard(text) then return end
    ShowCopyBox(bubble, text)
end

local function AddRect(button, x, y, w, h, r, g, b, a)
    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetSize(w, h)
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
    tex:SetVertexColor(r, g, b, a or 0.9)
    return tex
end

local function MakeLink(bubble)
    local button = CreateFrame("Button", nil, bubble)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouseWheel(true)
    button:SetScript("OnClick", function(self, buttonName)
        OpenLink(bubble.chat, self.link, self.display, buttonName)
    end)
    button:SetScript("OnEnter", function(self)
        ShowLinkTip(self)
    end)
    button:SetScript("OnLeave", HideTip)
    button:SetScript("OnMouseWheel", function(_, delta)
        Wheel(bubble.chat, delta)
    end)
    button:Hide()
    return button
end

-- The renderer knows the exact link bounds, including wrapped and indented rows.
local function BindBubbleLinks(bubble)
    if type(bubble.SetHyperlinksEnabled) ~= "function" then return end
    local ok = pcall(function()
        bubble:SetHyperlinksEnabled(true)
        bubble:SetScript("OnHyperlinkEnter", function(self, link, text)
            if self.msg and not self.msg.secret then ShowLinkTip(self, link, text) end
        end)
        bubble:SetScript("OnHyperlinkLeave", HideTip)
        bubble:SetScript("OnHyperlinkClick", function(self, link, text, button)
            if self.msg and not self.msg.secret then
                OpenLink(self.chat, link, text, button)
            end
        end)
    end)
    bubble._quietNativeLinks = ok
end

local function PlaceLinks(bubble, msg, inner)
    local links = bubble.links
    if bubble._quietNativeLinks then
        pcall(bubble.SetHyperlinksEnabled, bubble, msg ~= nil and not msg.secret)
        for i = 1, #links do links[i]:Hide() end
        return
    end
    if not msg or msg.secret then
        for i = 1, #links do
            links[i]:Hide()
        end
        return
    end
    local count = 0
    local segs = Segments(msg.text or "")
    local lineH = 14
    if bubble.text.GetLineHeight then
        local ok, h = pcall(bubble.text.GetLineHeight, bubble.text)
        if ok and type(h) == "number" and h > 0 then lineH = h end
    elseif bubble.text.GetFont then
        local _, size = bubble.text:GetFont()
        if type(size) == "number" and size > 0 then lineH = size end
    end
    if bubble.text.GetSpacing then
        local spacing = bubble.text:GetSpacing()
        if type(spacing) == "number" then lineH = lineH + spacing end
    end
    local x, y = 0, 0
    for i = 1, #segs do
        if count >= MAX_LINKS then break end
        local seg = segs[i]
        if seg.br then
            x, y = 0, y + lineH
        else
            local w = seg.width or UnboundedWidth(bubble.text, seg.text or "")
            local token = seg.text or ""
            if x > 0 and x + w > inner and token:match("%S") then
                x, y = 0, y + lineH
            end
            if x == 0 and token ~= "" and not token:match("%S") then
                w = 0
            end
            if seg.link and w > 0 then
                count = count + 1
                local button = links[count]
                if not button then
                    button = MakeLink(bubble)
                    links[count] = button
                end
                button.link = seg.link
                button.display = seg.text
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", bubble.text, "TOPLEFT", x, -y)
                button:SetSize(math.max(4, math.min(w, inner)), lineH)
                button:Show()
            end
            x = x + w
        end
    end
    for i = count + 1, #links do
        links[i]:Hide()
    end
end

local function ApplyFont(bubble, chat)
    pcall(function()
        local font, size, flags
        if chat.GetFont then
            font, size, flags = chat:GetFont()
        end
        if type(size) ~= "number" or size <= 2 then
            font = font or "Fonts\\FRIZQT__.TTF"
            size = 14
        end
        if font then
            bubble.text:SetFont(font, size, flags)
        end
        if chat.GetShadowOffset and bubble.text.SetShadowOffset then
            local x, y = chat:GetShadowOffset()
            if type(x) == "number" and type(y) == "number" then
                bubble.text:SetShadowOffset(x, y)
            end
        end
        if chat.GetShadowColor and bubble.text.SetShadowColor then
            local r, g, b, a = chat:GetShadowColor()
            if type(r) == "number" then
                bubble.text:SetShadowColor(r, g, b, a or 1)
            end
        end
        if chat.GetSpacing and bubble.text.SetSpacing then
            local spacing = chat:GetSpacing()
            if type(spacing) == "number" then
                bubble.text:SetSpacing(spacing)
            end
        end
        if chat.GetIndentedWordWrap and bubble.text.SetIndentedWordWrap then
            bubble.text:SetIndentedWordWrap(chat:GetIndentedWordWrap())
        end
    end)
end

local function SizeBubble(bubble, msg, maxW)
    local font, size, flags = bubble.text:GetFont()
    -- A secret string cannot be concatenated into the cache key.
    local tail = msg.secret and tostring(msg) or (msg.text or "")
    local fontKey = tostring(font) .. ":" .. tostring(size) .. ":" .. tostring(flags)
    local key = fontKey .. ":" .. math.floor(maxW) .. ":" .. tail
    if bubble._quietSizeKey == key and bubble.h then
        return bubble.h
    end
    bubble._quietSizeKey = nil
    local innerMax = math.max(8, maxW - PAD * 2)
    if msg.secret then
        local lineH = type(size) == "number" and size or 14
        if bubble.text.GetSpacing then
            local spacing = bubble.text:GetSpacing()
            if type(spacing) == "number" and spacing > 0 then lineH = lineH + spacing end
        end
        local canRead = bubble:IsShown() and bubble._quietLaid == key
        bubble.text:SetWidth(innerMax)
        bubble.text:SetText(msg.text)
        bubble.text:SetTextColor(msg.r or 1, msg.g or 1, msg.b or 1, 1)
        bubble._quietLaid = key
        local measured = 0
        if canRead and bubble.text.GetStringHeight then
            local ok, h = pcall(bubble.text.GetStringHeight, bubble.text)
            if ok and type(h) == "number" and not ns.IsSecret(h) and h > 0 then
                measured = h
            end
        end
        local th = measured > 0 and measured or lineH * 4
        if canRead and measured > 0 then
            bubble._quietSizeKey = key
        end
        bubble.inner = innerMax
        bubble.h = th + PAD * 2
        bubble:SetSize(innerMax + PAD * 2, bubble.h)
        PlaceLinks(bubble, msg, innerMax)
        return bubble.h
    end
    local text = msg.text or ""
    local wide = msg.wide
    if msg._quietWidthFont ~= fontKey or msg._quietWidthText ~= text or not wide or wide <= 0 then
        wide = UnboundedWidth(bubble.text, text)
        if wide > 0 then
            msg.wide = wide
            msg._quietWidthFont, msg._quietWidthText = fontKey, text
        elseif msg._quietWidthFont == fontKey and msg._quietWidthText == text then
            wide = msg.wide or 0
        end
    end
    -- A width that matches the text exactly still wraps the last word.
    local SLACK = 8
    local fits = wide > 0 and wide + SLACK <= innerMax
    local inner = innerMax
    if fits then
        inner = math.max(8, wide + SLACK)
    end
    local lineH = type(size) == "number" and size or 14
    if bubble.text.GetSpacing then
        local spacing = bubble.text:GetSpacing()
        if type(spacing) == "number" and spacing > 0 then lineH = lineH + spacing end
    end
    local rows = 1
    if not fits and wide > inner + 0.5 then
        rows = math.ceil(wide / inner)
    end
    -- Read the bubble only after it was shown with this same text. A fresh
    -- string reports one short line, the row is shown, then it grows and the
    -- top message is dropped and put back every frame.
    local canRead = bubble:IsShown() and bubble._quietLaid == key
    bubble.text:SetWidth(inner)
    bubble.text:SetText(text)
    bubble.text:SetTextColor(msg.r or 1, msg.g or 1, msg.b or 1, 1)
    bubble._quietLaid = key
    local measured, lines = 0, 0
    if canRead and not fits then
        local h = bubble.text:GetStringHeight()
        if type(h) == "number" and not ns.IsSecret(h) and h > 0 then measured = h end
        if bubble.text.GetNumLines then
            local ok, n = pcall(bubble.text.GetNumLines, bubble.text)
            if ok and type(n) == "number" and not ns.IsSecret(n) and n >= 1 then
                lines = math.floor(n)
            end
        end
        if bubble.text.GetLineHeight then
            local ok, lh = pcall(bubble.text.GetLineHeight, bubble.text)
            if ok and type(lh) == "number" and not ns.IsSecret(lh) and lh > lineH then
                lineH = lh
            end
        end
        if lines > rows then rows = lines end
    end
    local th = math.max(rows, 1) * lineH
    if not fits and measured > th then th = measured end
    -- A line that fits stays one row. Only a real wrap may keep a taller size.
    if fits then
        th = lineH
        msg.h = th
    elseif type(msg.h) == "number" and msg.h > th then
        th = msg.h
    else
        msg.h = th
    end
    -- Spacing and conservative row estimates can exceed the rendered height.
    local trusted = fits or (canRead and measured > 0)
    if trusted then
        bubble._quietSizeKey = key
    end
    bubble.inner = inner
    bubble.h = th + PAD * 2
    bubble:SetSize(inner + PAD * 2, bubble.h)
    PlaceLinks(bubble, msg, inner)
    return bubble.h
end

local function RaiseCopy(icon, bubble)
    if icon.SetFrameStrata then
        pcall(icon.SetFrameStrata, icon, "DIALOG")
    end
    if icon.SetFrameLevel and bubble.GetFrameLevel then
        pcall(icon.SetFrameLevel, icon, (bubble:GetFrameLevel() or 1) + 20)
    end
end

local function ShowCopy(bubble, hot)
    local icon = bubble.copy
    if not icon then return end
    if not hot or not bubble:IsShown() or (bubble.msg and bubble.msg.secret) then
        if icon:IsShown() then
            icon:EnableMouse(false)
            icon:Hide()
        end
        return
    end
    RaiseCopy(icon, bubble)
    icon:Show()
    icon:EnableMouse(true)
    icon:SetAlpha(0.85)
end

local function EnterBubble(bubble)
    bubble._quietSettle = (bubble._quietSettle or 0) + 1
    bubble._quietHot = true
    ShowCopy(bubble, true)
    if bubble.chat then bubble.chat._quietDirty = true end
end

-- OnLeave fires while the pointer is still crossing to the icon. Recheck after it lands.
local function SettleHot(bubble)
    if not bubble then return end
    bubble._quietSettle = (bubble._quietSettle or 0) + 1
    local token = bubble._quietSettle
    local function apply()
        if bubble._quietSettle ~= token then return end
        local icon = bubble.copy
        local hot = ns.MouseOver(bubble) or (icon and icon:IsShown() and ns.MouseOver(icon))
        bubble._quietHot = hot and true or false
        ShowCopy(bubble, bubble._quietHot)
        if bubble.chat then bubble.chat._quietDirty = true end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.12, apply)
    else
        apply()
    end
end

local function SlideX(msg, now)
    if not msg.slide then return 0 end
    local age = now - msg.slide
    if age < 0 or age >= SLIDE_TIME then return 0 end
    local t = age / SLIDE_TIME
    local k = 1 - (1 - t) * (1 - t)
    return -SLIDE_X * (1 - k)
end

local function ChatLife()
    local life = 10
    if ns.ChatFade then life = ns.ChatFade() end
    if type(life) ~= "number" then return 10 end
    return life
end

-- 0 hides the line. The last half second fades it. A missing interval stays at 10.
local function LineAlpha(msg, life, now)
    if life <= 0 or not msg.born then return 1 end
    local left = life - (now - msg.born)
    if left <= 0 then return 0 end
    if left >= FADE_OUT then return 1 end
    return left / FADE_OUT
end

local function Approach(current, goal, elapsed, duration)
    local step = (elapsed or 0) / duration
    if math.abs(goal - current) <= step then return goal end
    if goal > current then return current + step end
    return current - step
end

-- Keeps this line up, including the copy box.
local function BubbleHeld(bubble)
    if not bubble then return false end
    if bubble._quietHot then return true end
    return copyBox and copyBox:IsShown() and copyBox.anchor == bubble or false
end

-- Above the chat frame, under the bubbles. This client does not deliver the wheel
-- to a pass-through or motion-only frame, so the catcher keeps the mouse.
local function EnsureCatcher(frame)
    if frame._quietCatcher then return frame._quietCatcher end
    local ok, box = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not box then return end
    if box.EnableMouse then box:EnableMouse(true) end
    if type(box.SetMouseMotionEnabled) == "function" then
        pcall(box.SetMouseMotionEnabled, box, true)
    end
    if type(box.SetMouseClickEnabled) == "function" then
        pcall(box.SetMouseClickEnabled, box, true)
    end
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta)
        Wheel(frame, delta)
    end)
    box:Hide()
    frame._quietCatcher = box
    return box
end

local function PlaceCatcher(frame)
    local box = frame._quietCatcher
    if not box then return end
    if not ns.Usable(frame) or not frame.IsShown or not frame:IsShown() then
        box:Hide()
        return
    end
    if box._quietSpan ~= frame then
        box:SetParent(UIParent)
        box:ClearAllPoints()
        box:SetAllPoints(frame)
        box._quietSpan = frame
    end
    local strata = frame.GetFrameStrata and frame:GetFrameStrata()
    if type(strata) == "string" and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = frame.GetFrameLevel and frame:GetFrameLevel() or 0
    if type(level) ~= "number" then level = 0 end
    if box._quietAnchor ~= level then
        box:SetFrameLevel(level + 1)
        box._quietAnchor = level
        frame._quietDirty = true
    end
    if not box:IsShown() then box:Show() end
end

-- The block, a bubble, or the copy icon. The copy box alone does not count.
-- A still pointer does not need another pass over every bubble.
local function FrameHot(frame)
    local box = frame._quietCatcher
    if box and box:IsShown() and ns.Hit(box) then return true end
    local byMsg = frame._quietByMsg
    if not byMsg then return false end
    local moved = not ns.PointerMoved or ns.PointerMoved()
    if not moved then
        local anyHot = false
        for _, bubble in pairs(byMsg) do
            if bubble._quietHot then
                anyHot = true
                break
            end
        end
        if not anyHot then return false end
    end
    for _, bubble in pairs(byMsg) do
        local over = bubble:IsShown() and ns.MouseOver(bubble)
        if bubble._quietHot or over then return true end
    end
    return false
end

local function Ease(current, target, elapsed)
    local t = math.min(1, (elapsed or 0) * 14)
    local y = current + (target - current) * t
    if math.abs(target - y) < 0.5 then return target end
    return y
end

local function ReleaseBubble(frame, bubble)
    if copyBox and copyBox.anchor == bubble then
        HideCopyBox()
    end
    bubble._quietHot = false
    ShowCopy(bubble, false)
    bubble:Hide()
    bubble:SetAlpha(1)
    bubble.msg = nil
    bubble._y = nil
    bubble._quietSizeKey = nil
    bubble._quietLaid = nil
    bubble._quietPX = nil
    bubble._quietPY = nil
    bubble._quietPA = nil
    bubble._quietLevel = nil
    bubble._quietFontStamp = nil
    bubble._quietTargetY = nil
    bubble._quietPendingAlpha, bubble._quietPendingGoal, bubble._quietPendingHeld = nil, nil, nil
    frame._quietPool[#frame._quietPool + 1] = bubble
end

local function CreateBubble(frame)
    local bubble = CreateFrame("Frame", nil, frame)
    bubble._quietBubble = true
    bubble.chat = frame
    bubble.links = {}
    BindBubbleLinks(bubble)
    bubble:EnableMouse(true)
    bubble:EnableMouseWheel(true)
    local level = (frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 2
    if type(level) ~= "number" then level = 2 end
    pcall(bubble.SetFrameLevel, bubble, level)
    if bubble.SetClipsChildren then bubble:SetClipsChildren(true) end
    bubble:SetScript("OnMouseWheel", function(_, delta)
        Wheel(frame, delta)
    end)
    bubble:SetScript("OnEnter", function(self)
        EnterBubble(self)
    end)
    bubble:SetScript("OnLeave", function(self)
        SettleHot(self)
    end)
    TintRound(bubble, 0, 0, 0, 0.48)
    local text = bubble:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOPLEFT", bubble, "TOPLEFT", PAD, -PAD)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if text.SetWordWrap then text:SetWordWrap(true) end
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(false) end
    bubble.text = text
    local icon = CreateFrame("Button", nil, UIParent)
    icon:SetSize(12, 12)
    -- Overlap the bubble and grow the hit box so the pointer never crosses a dead gap.
    icon:SetPoint("LEFT", bubble, "RIGHT", -6, 0)
    if icon.SetHitRectInsets then
        icon:SetHitRectInsets(-8, -8, -10, -10)
    end
    icon:RegisterForClicks("LeftButtonUp")
    icon:SetAlpha(0)
    icon:EnableMouse(false)
    icon.bubble = bubble
    icon:SetScript("OnClick", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() CopyLine(bubble) end)
        else
            CopyLine(bubble)
        end
    end)
    icon:SetScript("OnEnter", function(self)
        if self.bubble then EnterBubble(self.bubble) end
        if self.front then self.front:SetVertexColor(0.95, 0.75, 0.25, 1) end
    end)
    icon:SetScript("OnLeave", function(self)
        if self.front then self.front:SetVertexColor(0.9, 0.9, 0.9, 0.85) end
        SettleHot(self.bubble)
    end)
    icon:SetScript("OnMouseWheel", function(_, delta)
        Wheel(frame, delta)
    end)
    AddRect(icon, 4, 1, 5, 7, 0.45, 0.45, 0.45, 0.85)
    icon.front = AddRect(icon, 1, 4, 5, 7, 0.9, 0.9, 0.9, 0.85)
    bubble.copy = icon
    bubble:Hide()
    return bubble
end

local function AcquireBubble(frame)
    local pool = frame._quietPool
    local bubble = pool[#pool]
    if bubble then
        pool[#pool] = nil
        return bubble
    end
    return CreateBubble(frame)
end

local function HideActive(frame)
    frame._quietDirty = true
    frame._quietNext, frame._quietFadeAt, frame._quietLayoutPending = 0, nil, nil
    local animations = frame._quietAnimations
    if animations then
        for i = #animations, 1, -1 do animations[i] = nil end
    end
    local byMsg = frame._quietByMsg
    if not byMsg then return end
    for msg, bubble in pairs(byMsg) do
        byMsg[msg] = nil
        ReleaseBubble(frame, bubble)
    end
end

local function FontStamp(frame)
    local font, size, flags
    if frame.GetFont then
        local ok, f, s, fl = pcall(frame.GetFont, frame)
        if ok then font, size, flags = f, s, fl end
    end
    return tostring(font) .. "\0" .. tostring(size) .. "\0" .. tostring(flags)
end

local function BubbleAlpha(known, msg, fading, reveal, life, now, elapsed)
    local held = known and BubbleHeld(known)
    local natural = fading and not held and LineAlpha(msg, life, now) or 1
    local goal = (reveal or held) and 1 or natural
    local current = known and known._quietPA
    if type(current) ~= "number" or goal >= current then
        current = goal
    elseif current > goal + 0.02 then
        current = Approach(current, goal, elapsed, FADE_UI)
    else
        current = goal
    end
    return current, goal, held
end

local function PaintBubble(frame, bubble, x, y, alpha)
    if bubble._quietPX ~= x or bubble._quietPY ~= y then
        bubble:ClearAllPoints()
        bubble:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, y)
        bubble._quietPX, bubble._quietPY = x, y
    end
    if bubble._quietPA ~= alpha then
        bubble:SetAlpha(alpha)
        bubble._quietPA = alpha
    end
    if not bubble:IsShown() then bubble:Show() end
end

local function BubbleSchedule(bubble, goal, held, fading, reveal, life, now)
    local msg = bubble.msg
    local animated = (msg.slide and now - msg.slide < SLIDE_TIME)
        or math.abs(bubble._quietPA - goal) > 0.01 or bubble._y ~= bubble._quietTargetY
    local fadeAt
    if not reveal and fading and life > 0 and msg.born and not held then
        local at = msg.born + life - FADE_OUT
        if now < at - 0.02 then fadeAt = at
        else animated = true end
    end
    return animated, fadeAt
end

local function AnimateFrame(frame, elapsed, now)
    local animations = frame._quietAnimations
    if not animations or #animations == 0 then return false end
    local fading = frame._quietOffset == 0
    local reveal = fading and frame._quietHover
    local life = frame._quietLife
    local count = #animations
    -- A disappearing row changes the stack. Decide before moving any other row.
    for i = 1, count do
        local bubble = animations[i]
        local msg = bubble.msg
        local current, goal, held = BubbleAlpha(bubble, msg, fading, reveal, life, now, elapsed)
        local sliding = msg.slide and now - msg.slide < SLIDE_TIME
        if current <= 0.01 and goal <= 0 and not sliding then return false end
        bubble._quietPendingAlpha, bubble._quietPendingGoal, bubble._quietPendingHeld = current, goal, held
    end
    local n, fadeAt = 0, frame._quietFadeAt
    for i = 1, count do
        local bubble = animations[i]
        local current, goal, held = bubble._quietPendingAlpha, bubble._quietPendingGoal, bubble._quietPendingHeld
        bubble._quietPendingAlpha, bubble._quietPendingGoal, bubble._quietPendingHeld = nil, nil, nil
        bubble._y = Ease(bubble._y, bubble._quietTargetY, elapsed)
        PaintBubble(frame, bubble, 4 + SlideX(bubble.msg, now), bubble._y, current)
        local animated, wake = BubbleSchedule(bubble, goal, held, fading, reveal, life, now)
        if animated then n = n + 1; animations[n] = bubble end
        if wake and (not fadeAt or wake < fadeAt) then fadeAt = wake end
    end
    for i = n + 1, count do animations[i] = nil end
    frame._quietFadeAt = fadeAt
    frame._quietNext = n > 0 and 0 or fadeAt
    return true
end

local function LayoutFrame(frame, elapsed)
    if not ns.Usable(frame) or not frame._quietLines then return end
    if not frame.IsShown or not frame:IsShown() then
        if frame._quietShown ~= false then
            frame._quietShown = false
            HideActive(frame)
        end
        return
    end
    if frame._quietShown == false then
        frame._quietDirty = true
    end
    frame._quietShown = true
    local width = frame.GetWidth and frame:GetWidth()
    local height = frame.GetHeight and frame:GetHeight()
    if type(width) ~= "number" or ns.IsSecret(width) or width < 40 then return end
    if type(height) ~= "number" or ns.IsSecret(height) or height < 20 then return end
    local lines = frame._quietLines
    local offset = math.floor(ScrollOffset(frame))
    if offset < 0 then offset = 0 end
    local maxOffset = math.max(0, #lines - 1)
    if offset > maxOffset then offset = maxOffset end
    local life = ChatLife()
    local now = GetTime()
    local restack = frame._quietDirty or frame._quietW ~= width or frame._quietH ~= height
        or frame._quietOffset ~= offset or frame._quietLife ~= life
    local due = frame._quietNext == 0 or (type(frame._quietNext) == "number" and frame._quietNext > 0 and now >= frame._quietNext)
    if not restack and not due then return end
    if not restack and not frame._quietLayoutPending and (not frame._quietFadeAt or now < frame._quietFadeAt)
        and AnimateFrame(frame, elapsed, now) then return end
    frame._quietDirty = nil
    frame._quietW, frame._quietH = width, height
    frame._quietOffset = offset
    frame._quietLife = life
    RepairTinyFont(frame)
    local byMsg = frame._quietByMsg
    -- Only the bottom view drops old lines. Hover shows the page that fits; scrolling walks the rest.
    local fading = offset == 0
    local reveal = fading and frame._quietHover
    local index = #lines - offset
    local y = 4
    local seen = frame._quietSeen
    if not seen then
        seen = {}
        frame._quietSeen = seen
    else
        for key in pairs(seen) do
            seen[key] = nil
        end
    end
    local stack = frame._quietStack
    if not stack then
        stack = {}
        frame._quietStack = stack
    end
    local stackN = 0
    local fontStamp = frame._quietFont
    if restack or not fontStamp then
        fontStamp = FontStamp(frame)
        frame._quietFont = fontStamp
    end
    local animations = frame._quietAnimations
    if not animations then animations = {}; frame._quietAnimations = animations end
    local animatedN, fadeAt, measure, dropped = 0, nil, false, false
    local guard = 0
    while index >= 1 and guard < 40 do
        guard = guard + 1
        local msg = lines[index]
        local known = byMsg[msg]
        local current, goal, held = BubbleAlpha(known, msg, fading, reveal, life, now, elapsed)
        local place = true
        local sliding = msg.slide and now - msg.slide < SLIDE_TIME
        if current <= 0.01 and goal <= 0 and not sliding then
            place = false
            if not known then break end
            dropped = true
        end
        if place then
            local bubble = known or AcquireBubble(frame)
            local h = bubble.h
            if bubble.msg ~= msg or not h or not bubble._quietSizeKey or restack then
                if bubble._quietFontStamp ~= fontStamp then
                    ApplyFont(bubble, frame)
                    bubble._quietFontStamp = fontStamp
                    bubble._quietSizeKey = nil
                end
                h = SizeBubble(bubble, msg, width - 8)
            end
            if y > 4 and y + h > height - 2 then
                if not known then
                    ReleaseBubble(frame, bubble)
                end
                break
            end
            byMsg[msg] = bubble
            seen[msg] = true
            stackN = stackN + 1
            stack[stackN] = bubble
            local target = y
            bubble._quietTargetY = target
            if bubble.msg ~= msg or bubble._y == nil then
                bubble._y = target
            else
                bubble._y = Ease(bubble._y, target, elapsed)
            end
            bubble.msg = msg
            bubble.chat = frame
            PaintBubble(frame, bubble, 4 + SlideX(msg, now), bubble._y, current)
            -- Wrapped text needs a shown frame before its height can be trusted.
            if not bubble._quietSizeKey then measure = true end
            local animated, wake = BubbleSchedule(bubble, goal, held, fading, reveal, life, now)
            if animated then animatedN = animatedN + 1; animations[animatedN] = bubble end
            if wake and (not fadeAt or wake < fadeAt) then fadeAt = wake end
            y = y + h + GAP
        end
        index = index - 1
    end
    for i = stackN + 1, #stack do
        stack[i] = nil
    end
    -- Same level, newest raised last so it stays above the lines it pushes up.
    if restack then
        local level = (frame:GetFrameLevel() or 0) + 2
        for i = stackN, 1, -1 do
            local bubble = stack[i]
            bubble._quietLevel = level
            pcall(bubble.SetFrameLevel, bubble, level)
        end
    end
    for i = animatedN + 1, #animations do animations[i] = nil end
    -- Revisit a released history gap before continuing the remaining animations.
    frame._quietLayoutPending = measure or (dropped and animatedN > 0)
    frame._quietFadeAt = fadeAt
    frame._quietNext = (frame._quietLayoutPending or animatedN > 0) and 0 or fadeAt
    for msg, bubble in pairs(byMsg) do
        if not seen[msg] then
            byMsg[msg] = nil
            ReleaseBubble(frame, bubble)
        end
    end
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
    TrackScroll(frame)
    local ok, err = pcall(hooksecurefunc, frame, "AddMessage", function(self, text, r, g, b)
        local bottom = AtBottom(self)
        if self._quietScrollHook and not bottom then
            self._quietScroll = (self._quietScroll or 0) + 1
        end
        PushLine(self, text, r, g, b, ns.DB().enabled and ns.ModernChat() and bottom)
        HideNativeText(self)
        if self._quietScrollHook then
            self._quietScroll = ClampScroll(self, self._quietScroll or 0)
        end
    end)
    if not ok then ns.Report("chat line", err) end
    if type(frame.Clear) == "function" then
        pcall(hooksecurefunc, frame, "Clear", function(self)
            if self._quietLines then Wipe(self._quietLines) end
            self._quietScroll = 0
            self._quietDirty = true
        end)
    end
    EnsureCatcher(frame)
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    if frame.HookScript and not frame._quietWheel then
        frame._quietWheel = true
        frame:HookScript("OnMouseWheel", function(self, delta)
            if not ns.DB().enabled or not ns.ModernChat() then return end
            Wheel(self, delta)
        end)
    end
end

local function EaseEdit(edit, elapsed)
    if not edit or not edit._quietEdit or edit._quietWant == nil then return end
    local show = edit._quietWant == 1
    ns.EaseAlpha(edit, show, elapsed)
    if edit._quietHeader then
        ns.EaseAlpha(edit._quietHeader, show, elapsed)
    end
    if edit._quietPlate then
        ns.EaseAlpha(edit._quietPlate, show, elapsed)
    end
end

function ns.UpdateChat(elapsed)
    if not ns.DB().enabled or not ns.ModernChat() then return end
    local now = GetTime()
    for i = 1, ChatCount() do
        EaseEdit(_G["ChatFrame" .. i .. "EditBox"], elapsed)
        local frame = _G["ChatFrame" .. i]
        if frame and frame._quietBubbles then
            if not ns.Usable(frame) or not frame.IsShown or not frame:IsShown() then
                if frame._quietShown ~= false then
                    HideActive(frame)
                    if frame._quietCatcher then frame._quietCatcher:Hide() end
                    frame._quietShown, frame._quietHover = false, false
                    frame._quietCatcherAt = nil
                end
            else
                if frame._quietShown == false then frame._quietDirty = true end
                -- Anchors follow the chat automatically; only stacking needs a periodic refresh.
                if frame._quietDirty or not frame._quietCatcherAt or now >= frame._quietCatcherAt then
                    PlaceCatcher(frame)
                    frame._quietCatcherAt = now + 0.1
                end
                local hot = FrameHot(frame)
                if hot ~= frame._quietHover then
                    frame._quietHover = hot
                    frame._quietDirty = true
                end
                local wake = frame._quietNext
                if frame._quietDirty or wake == 0 or (type(wake) == "number" and wake > 0 and now >= wake) then
                    LayoutFrame(frame, elapsed)
                end
            end
        end
    end
end

function ns.RestoreChat()
    HideCopyBox()
    RestoreEdits()
    ns.ReleaseChatHold()
    chromeStripped = false
    for i = 1, ChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame and frame._quietBubbles then
            frame._quietStripped = nil
            frame._quietHover = false
            frame._quietCatcherAt = nil
            if frame._quietCatcher then frame._quietCatcher:Hide() end
            HideActive(frame)
            RestoreFonts(frame)
        elseif frame then
            frame._quietStripped = nil
        end
    end
end

------------------------------------------------------------------------------
-- Chat windows
------------------------------------------------------------------------------
local function MarkStripped(frame)
    if not frame then return end
    if frame._quietLines and #frame._quietLines > 0 then
        HideNativeText(frame)
    end
    frame._quietStripped = true
    frame._quietDirty = true
end

local function StripChat(frame)
    if not frame or not ns.DB().enabled then return end
    ns.HideTextures(frame)
    local name = ns.FrameName(frame)
    ns.HideBackground(frame.Background or (name and _G[name .. "Background"]))
    if frame.NineSlice then
        ns.HideTextures(frame.NineSlice)
    end
    ns.Mute(frame.ScrollBar)
    ns.Mute(frame.ScrollToBottomButton)
    ns.Mute(frame.buttonFrame)
    ns.Mute(frame.TextToSpeechButton)
    if not name then
        BindBubbles(frame)
        MarkStripped(frame)
        return
    end
    for _, suffix in ipairs(CHAT_BUTTON_SUFFIX) do
        ns.Mute(_G[name .. suffix])
    end
    StripTab(_G[name .. "Tab"])
    BindEdit(_G[name .. "EditBox"])
    BindBubbles(frame)
    MarkStripped(frame)
end

local function StripDock()
    local dock = GeneralDockManager
    if not dock then return end
    ns.HideTextures(dock)
    ns.HideBackground(dock.Background or _G.GeneralDockManagerBackground)
end

function ns.StripAllChat(force)
    if stripping or not ns.DB().enabled or not ns.ModernChat() then return end
    stripping = true
    ns.MarkingChat = true
    if force then chromeStripped = false end
    local ok, err = pcall(function()
        for i = 1, ChatCount() do
            local frame = _G["ChatFrame" .. i]
            if frame and (force or not frame._quietStripped) then
                StripChat(frame)
            end
        end
        if not chromeStripped then
            for _, name in ipairs(CHAT_CHROME) do
                ns.Mute(_G[name])
            end
            StripDock()
            chromeStripped = true
        end
    end)
    ns.MarkingChat = false
    stripping = false
    if not ok then ns.Report("chat", err) end
end
