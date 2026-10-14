local _, ns = ...

-- Buttons, check boxes, steppers, fields, help, sections and the select menu.
local Setup = ns.Setup
local draft = Setup.draft

function Setup.SkinSmall(button, gold)
    if gold == nil then gold = true end
    if not gold or not ns.GoldEdge(button) then ns.Flat(button, 1) end
    ns.DialogBackground(button)
    -- Texture edges also work when SetBackdrop is unavailable.
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = button:CreateTexture(nil, "BORDER")
        if gold then line:SetColorTexture(0.75, 0.6, 0.28, 0.95)
        else line:SetColorTexture(0.85, 0.85, 0.85, 0.35) end
        if edge == "TOP" or edge == "BOTTOM" then
            line:SetHeight(1)
            line:SetPoint(edge .. "LEFT", 0, 0)
            line:SetPoint(edge .. "RIGHT", 0, 0)
        else
            line:SetWidth(1)
            line:SetPoint("TOP" .. edge, 0, 0)
            line:SetPoint("BOTTOM" .. edge, 0, 0)
        end
    end
    if button.label and button.label.SetTextColor then
        if gold then button.label:SetTextColor(0.95, 0.75, 0.25)
        else button.label:SetTextColor(0.9, 0.9, 0.9) end
    end
    if type(button.HookScript) == "function" then
        button:HookScript("OnEnable", function(self) self:SetAlpha(1) end)
        button:HookScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    end
end

function Setup.PaintBox(box, on)
    if not box then return end
    if box.SetChecked then
        box:SetChecked(on and true or false)
        return
    end
    if not box.check then return end
    if on then box.check:Show() else box.check:Hide() end
end

function Setup.ButtonText(button, text)
    if button.label then button.label:SetText(text) end
    if button.SetText then button:SetText(text) end
end

function Setup.Button(parent, text, onClick)
    local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not ok or not button then
        button = ns.Backdropped("Button", nil, parent)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label:SetPoint("CENTER")
        if type(button.SetFontString) == "function" then button:SetFontString(button.label) end
        Setup.SkinSmall(button, false)
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    elseif type(button.GetFontString) == "function" then
        button.label = button:GetFontString()
    end
    button:SetSize(112, 22)
    Setup.ButtonText(button, text)
    button:SetScript("OnClick", onClick)
    return button
end

function Setup.CheckMark(parent)
    -- The loose checkbox textures draw only the tick on this client. The template keeps the box.
    local ok, box = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if ok and box and box.SetChecked then
        box:SetSize(22, 22)
        box:EnableMouse(false)
        if box.Text then box.Text:Hide() end
        local text = box.GetFontString and box:GetFontString()
        if text then text:Hide() end
        return box
    end
    box = parent:CreateTexture(nil, "ARTWORK")
    box:SetSize(20, 20)
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box.check = parent:CreateTexture(nil, "OVERLAY")
    box.check:SetAllPoints(box)
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:Hide()
    return box
end

function Setup.Choice(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(Setup.CONTENT_W, 22)
    button.box = Setup.CheckMark(button)
    button.box:SetPoint("LEFT", 0, 0)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button.box, "RIGHT", 4, 0)
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.12)
    button:SetScript("OnClick", onClick)
    return button
end

function Setup.Mini(parent, text, onClick)
    local button = ns.Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    Setup.SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

function Setup.TargetBox(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(44, 22)
    button.box = Setup.CheckMark(button)
    button.box:SetPoint("CENTER")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        if self.mode and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Controlled by Group " .. self.group .. ": "
                .. (self.mode == "hover" and "Only on hover" or "Always visible"))
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
    return button
end

function Setup.Stepper(parent, label, onDelta)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    row.plus = Setup.Mini(row, "+", function() onDelta(1) end)
    row.minus = Setup.Mini(row, "-", function() onDelta(-1) end)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetWidth(44)
    row.value:SetJustifyH("CENTER")
    row.plus:SetPoint("RIGHT", 0, 0)
    row.value:SetPoint("RIGHT", row.plus, "LEFT", -4, 0)
    row.minus:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
    return row
end

-- Empty means bar 1. Escape only leaves the field, so the window stays open.
function Setup.SpellField(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText("Spell")
    local box = ns.Backdropped("EditBox", nil, row)
    box:SetSize(144, 22)
    box:SetPoint("RIGHT", 0, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetMaxLetters(48)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetJustifyH("LEFT")
    if box.SetTextColor then box:SetTextColor(1, 0.95, 0.8, 1) end
    local gold = ns.GoldEdge(box)
    if not gold then ns.Flat(box, 0.9) end
    box._quietGold = gold and true or false
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText("Bar 1")
    box.hint = hint
    local function ShowHint(self)
        local text = self:GetText() or ""
        if text == "" and not self:HasFocus() then
            hint:Show()
        else
            hint:Hide()
        end
    end
    box:SetScript("OnTextChanged", function(self)
        draft.rangeSpell = self:GetText() or ""
        ShowHint(self)
    end)
    box:SetScript("OnEditFocusGained", function(self)
        ShowHint(self)
        if self._quietGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 0.86, 0.4, 1)
        end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        ShowHint(self)
        if self._quietGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95)
        end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ShowHint(box)
    row.edit = box
    return row
end

function Setup.PercentField(parent, label, key)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    local box = ns.Backdropped("EditBox", nil, row)
    box:SetSize(72, 22)
    box:SetPoint("RIGHT", 0, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetMaxLetters(16)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetJustifyH("LEFT")
    if not ns.GoldEdge(box) then ns.Flat(box, 0.9) end
    box:SetScript("OnTextChanged", function(self) draft[key] = self:GetText() or "" end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.edit = box
    return row
end

function Setup.Help(parent, label, title, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(18, 18)
    button:SetPoint("LEFT", label, "RIGHT", 4, 0)
    button:SetNormalTexture("Interface\\Common\\help-i")
    button:SetHighlightTexture("Interface\\Common\\help-i")
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    button:SetScript("OnHide", function(self)
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return button
end

function Setup.Section(parent, text, help)
    -- Gold title only. The old group-indicator bar is the classic paperdoll and collides with the column titles.
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 16)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("TOPLEFT", 0, 0)
    row.label:SetText(text)
    if help then row.help = Setup.Help(row, row.label, text, help) end
    return row
end

function Setup.Body(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetWidth(Setup.CONTENT_W)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text)
    return label
end

function Setup.ColumnLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    return label
end

function Setup.SelectMenu(owner, key, anchor, entries)
    local menu = owner[key]
    if menu and menu:IsShown() then menu:Hide(); return end
    if not menu then
        menu = ns.Backdropped("Frame", nil, owner)
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel(owner:GetFrameLevel() + 60)
        ns.Flat(menu, 1)
        ns.DialogBackground(menu)
        if menu.SetBackdropBorderColor then menu:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.7) end
        menu:EnableMouse(true)
        menu.items = {}
        owner[key] = menu
    end
    for _, item in ipairs(menu.items) do item:Hide() end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    menu:SetSize(300, 12 + 28 * math.min(#entries, 8))
    if not menu.scroll then
        menu.scroll = CreateFrame("ScrollFrame", nil, menu)
        menu.scroll:SetPoint("TOPLEFT", 6, -6)
        menu.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        menu.content = CreateFrame("Frame", nil, menu.scroll)
        menu.content:SetWidth(288)
        menu.scroll:SetScrollChild(menu.content)
        menu.scroll:EnableMouseWheel(true)
        menu.scroll:SetScript("OnMouseWheel", function(_, delta)
            menu.offset = math.max(0, math.min(menu.maximum or 0, (menu.offset or 0) - delta * 28))
            menu.scroll:SetVerticalScroll(menu.offset)
        end)
    end
    menu.content:SetHeight(math.max(28, #entries * 28))
    menu.maximum = math.max(0, (#entries - 8) * 28)
    menu.offset = 0
    menu.scroll:SetVerticalScroll(0)
    for index, entry in ipairs(entries) do
        local item = menu.items[index]
        if not item then
            item = CreateFrame("Button", nil, menu.content)
            item:RegisterForClicks("LeftButtonUp")
            item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            item.label:SetPoint("LEFT", 18, 0)
            item.label:SetPoint("RIGHT", -8, 0)
            item.label:SetJustifyH("LEFT")
            item.selected = item:CreateTexture(nil, "BACKGROUND")
            item.selected:SetAllPoints()
            item.selected:SetColorTexture(0.95, 0.75, 0.25, 0.12)
            item.mark = item:CreateTexture(nil, "ARTWORK")
            item.mark:SetSize(2, 14)
            item.mark:SetPoint("LEFT", 6, 0)
            item.mark:SetColorTexture(0.95, 0.75, 0.25, 1)
            local hover = item:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(0.95, 0.75, 0.25, 0.16)
            menu.items[index] = item
        end
        item:SetSize(288, 26)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
        Setup.ButtonText(item, entry.name)
        if entry.selected then
            item.selected:Show()
            item.mark:Show()
            item.label:SetTextColor(0.95, 0.75, 0.25)
        else
            item.selected:Hide()
            item.mark:Hide()
            item.label:SetTextColor(0.9, 0.9, 0.9)
        end
        item:SetScript("OnClick", function() menu:Hide(); entry.select() end)
        item:Show()
    end
    menu:Show()
end
