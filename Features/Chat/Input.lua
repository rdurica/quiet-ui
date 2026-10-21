local _, ns = ...

-- Chat keeps its text and drops the chrome. Each line is drawn as its own
-- bubble; the input shows only while it has focus. No ChatFrame_OpenChat:
-- Enter stays a Blizzard binding.

ns.Chat = ns.Chat or {}
local Chat = ns.Chat
-- Private to Features/Chat: state that several files read and write.
Chat.state = Chat.state or {}

local EDIT_PARTS = {
    "Left", "Mid", "Right", "Middle",
    "FocusLeft", "FocusMid", "FocusRight", "FocusMiddle",
    "left", "mid", "right", "middle",
    "focusLeft", "focusMid", "focusRight", "focusMiddle",
}
-- Whisper tabs open temporary windows past NUM_CHAT_WINDOWS (ChatFrame11+), listed in
-- CHAT_FRAMES. The highest one seen is kept, so Chat.Restore still reaches a closed one.
local temporaryMax = 0

local function NoteTemporary()
    if type(CHAT_FRAMES) ~= "table" then return end
    for _, name in ipairs(CHAT_FRAMES) do
        local n = type(name) == "string" and tonumber(name:match("^ChatFrame(%d+)$"))
        if n and n > temporaryMax then temporaryMax = n end
    end
end
Chat.NoteTemporary = NoteTemporary

local function ChatCount()
    local n = NUM_CHAT_WINDOWS or 10
    return temporaryMax > n and temporaryMax or n
end
Chat.ChatCount = ChatCount

-- Per-frame paths look windows up by index; the global names are built once.
local names = { [""] = {}, Tab = {}, EditBox = {} }

function Chat.Window(i, part)
    local list = names[part or ""]
    local name = list[i]
    if not name then
        name = "ChatFrame" .. i .. (part or "")
        list[i] = name
    end
    return _G[name]
end
------------------------------------------------------------------------------
-- Input box
------------------------------------------------------------------------------
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
Chat.TintRound = TintRound

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
Chat.UsableNumber = UsableNumber

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
    local plate = ns.Backdropped("Frame", nil, parent)
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

-- The unfocused field is invisible but shown; it lets clicks through to the tabs.
local function HoldEditMouse(edit, focused)
    if not edit.EnableMouse then return end
    if edit._quietMouse == nil and edit.IsMouseEnabled then
        edit._quietMouse = edit:IsMouseEnabled() and true or false
    end
    pcall(edit.EnableMouse, edit, focused and true or false)
end

local function ReleaseEditMouse(edit)
    if edit._quietMouse == nil then return end
    pcall(edit.EnableMouse, edit, edit._quietMouse)
    edit._quietMouse = nil
end

local function SyncEdit(edit)
    if not ns.DB().enabled or not ns.Settings.ModernChat() then
        ReleaseEditMouse(edit)
        edit._quietAlpha = nil
        if edit._quietPlate then
            edit._quietPlate._quietAlpha = nil
            edit._quietPlate:SetAlpha(0)
        end
        return
    end
    local focused = edit._quietFocus or (edit.HasFocus and edit:HasFocus())
    local want = focused and 1 or 0
    if edit._quietWant ~= want then Chat.Wake() end
    edit._quietWant = want
    HoldEditMouse(edit, focused)
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
Chat.BindEdit = BindEdit

-- Focus events can be missed, so visible input boxes are checked every frame.
function Chat.SyncVisibleEdits()
    if not ns.DB().enabled or not ns.Settings.ModernChat() then return end
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
            ReleaseEditMouse(edit)
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
Chat.RestoreEdits = RestoreEdits
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
Chat.EaseEdit = EaseEdit
