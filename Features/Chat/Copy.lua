local _, ns = ...

-- Copy icon, clipboard and the fallback copy box.

local Chat = ns.Chat
local state = Chat.state

local function HideCopyBox()
    if not state.copyBox then return end
    local anchor = state.copyBox.anchor
    state.copyBox.anchor = nil
    state.copyBox._quietStick = nil
    state.copyBox:Hide()
    if anchor and anchor.chat then anchor.chat._quietDirty = true end
end
Chat.HideCopyBox = HideCopyBox

local function EnsureCopyBox()
    if state.copyBox then return state.copyBox end
    local box = ns.Backdropped("EditBox", nil, UIParent)
    state.copyBox = box
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
    ns.Flat(box, 0.94)
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
    state.copyBox = box
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
    local text = Chat.PlainText(msg.text)
    if text == "" then return end
    if WriteClipboard(text) then return end
    ShowCopyBox(bubble, text)
end
Chat.CopyLine = CopyLine

local function AddRect(button, x, y, w, h, r, g, b, a)
    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetSize(w, h)
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", x, -y)
    tex:SetVertexColor(r, g, b, a or 0.9)
    return tex
end
Chat.AddRect = AddRect
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
Chat.ShowCopy = ShowCopy

local function EnterBubble(bubble)
    bubble._quietSettle = (bubble._quietSettle or 0) + 1
    bubble._quietHot = true
    ShowCopy(bubble, true)
    if bubble.chat then bubble.chat._quietDirty = true end
end
Chat.EnterBubble = EnterBubble

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
Chat.SettleHot = SettleHot
-- Keeps this line up, including the copy box.
local function BubbleHeld(bubble)
    if not bubble then return false end
    if bubble._quietHot then return true end
    return state.copyBox and state.copyBox:IsShown() and state.copyBox.anchor == bubble or false
end
Chat.BubbleHeld = BubbleHeld
