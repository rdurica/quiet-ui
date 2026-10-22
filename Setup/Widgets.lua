local _, ns = ...

-- Buttons, check boxes, steppers, fields, help, sections and the select menu.
local Setup = ns.Setup
local draft = Setup.draft

function Setup.PaintBox(box, on)
    if not box then return end
    if box.SetChecked then box:SetChecked(on and true or false) end
    if box.check then
        if on then box.check:Show() else box.check:Hide() end
    end
end

function Setup.ButtonText(button, text)
    if button.label then button.label:SetText(text) end
    if button.SetText then button:SetText(text) end
end

-- With a template and no onClick the template keeps its own OnClick.
function Setup.Button(parent, text, onClick, template)
    local button = CreateFrame("Button", nil, parent, template)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", -8, 0)
    if type(button.SetFontString) == "function" then button:SetFontString(button.label) end
    Setup.Control(button)
    Setup.Hover(button)
    button:SetSize(128, 26)
    Setup.ButtonText(button, text)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

-- A button that opens a list: left-aligned choice and a chevron on the right.
function Setup.Selector(parent, text, onClick)
    local button = Setup.Button(parent, text, onClick)
    button.label:SetJustifyH("LEFT")
    button.label:SetPoint("LEFT", 10, 0)
    button.label:SetPoint("RIGHT", -32, 0)
    for _, part in ipairs({ { -20, -45 }, { -15, 45 } }) do
        local line = button:CreateTexture(nil, "OVERLAY")
        line:SetSize(7, 2)
        line:SetPoint("CENTER", button, "RIGHT", part[1], 0)
        if type(line.SetRotation) == "function" then pcall(line.SetRotation, line, math.rad(part[2])) end
        line:SetColorTexture(unpack(Setup.Colors().glyph))
    end
    return button
end

-- Modernize's checkbox: a dark square with an accent mark when checked. The row around it takes the click and turns
-- the box edge accent under the mouse.
function Setup.CheckMark(parent)
    local box = CreateFrame("CheckButton", nil, parent)
    box:SetSize(16, 16)
    box:EnableMouse(false)
    Setup.Control(box, Setup.Colors().track)
    box.check = box:CreateTexture(nil, "ARTWORK")
    box.check:SetPoint("TOPLEFT", 4, -4)
    box.check:SetPoint("BOTTOMRIGHT", -4, 4)
    box.check:SetColorTexture(unpack(Setup.Colors().accent))
    box.check:Hide()
    parent:HookScript("OnEnter", function(self)
        local enabled = type(self.IsEnabled) ~= "function" or self:IsEnabled()
        if enabled then Setup.EdgeColor(box, Setup.Colors().accent) end
    end)
    parent:HookScript("OnLeave", function() Setup.EdgeColor(box, Setup.Colors().border) end)
    return box
end

function Setup.Choice(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(Setup.CONTENT_W, 24)
    button.box = Setup.CheckMark(button)
    button.box:SetPoint("LEFT", 2, 0)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("LEFT", button.box, "RIGHT", 10, 0)
    button.label:SetPoint("RIGHT", 0, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function Setup.Mini(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    Setup.Control(button)
    Setup.Hover(button)
    button:SetScript("OnClick", onClick)
    return button
end

-- Modernize's scroll arrow: a bare accent chevron, light under the mouse.
function Setup.Arrow(parent, up, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(24, 24)
    local angle = up and 45 or -45
    local lines = { ns.Modern.GlyphLine(button, 6, 2, -2, 0, angle), ns.Modern.GlyphLine(button, 6, 2, 2, 0, -angle) }
    local function Paint(color)
        for _, line in ipairs(lines) do line:SetColorTexture(unpack(color)) end
    end
    Paint(Setup.Colors().accent)
    button:SetScript("OnEnter", function() Paint(Setup.Colors().text) end)
    button:SetScript("OnLeave", function() Paint(Setup.Colors().accent) end)
    button:SetScript("OnClick", onClick)
    return button
end

function Setup.TargetBox(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(44, 24)
    button.box = Setup.CheckMark(button)
    button.box:SetPoint("CENTER")
    button:SetScript("OnClick", onClick)
    button:HookScript("OnEnter", function(self)
        if self.mode and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Controlled by Group " .. self.group .. ": "
                .. (self.mode == "hover" and "Only on hover" or "Always visible"))
            GameTooltip:Show()
        end
    end)
    button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
    return button
end

function Setup.Stepper(parent, label, onDelta)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 24)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    row.plus = Setup.Mini(row, "+", function() onDelta(1) end)
    row.minus = Setup.Mini(row, "-", function() onDelta(-1) end)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetWidth(72)
    row.value:SetJustifyH("CENTER")
    row.plus:SetPoint("RIGHT", 0, 0)
    row.value:SetPoint("RIGHT", row.plus, "LEFT", -4, 0)
    row.minus:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
    return row
end

-- A text field: dark fill, thin edge, accent edge while typing. Enter and Escape only leave it.
function Setup.Field(parent, width, letters)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 24)
    box:SetFontObject("GameFontHighlight")
    box:SetAutoFocus(false)
    box:SetMaxLetters(letters)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetJustifyH("LEFT")
    Setup.Control(box, Setup.Colors().track)
    box:SetScript("OnEditFocusGained", function(self) Setup.EdgeColor(self, Setup.Colors().accent) end)
    box:SetScript("OnEditFocusLost", function(self) Setup.EdgeColor(self, Setup.Colors().border) end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function FieldRow(parent, label)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 24)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    return row
end

-- Empty means bar 1. Escape only leaves the field, so the window stays open.
function Setup.SpellField(parent)
    local row = FieldRow(parent, "Spell")
    local box = Setup.Field(row, 180, 48)
    box:SetPoint("RIGHT", 0, 0)
    local hint = Setup.Muted(box:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
    hint:SetPoint("LEFT", 8, 0)
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
    box:HookScript("OnEditFocusGained", ShowHint)
    box:HookScript("OnEditFocusLost", ShowHint)
    ShowHint(box)
    row.edit = box
    return row
end

function Setup.PercentField(parent, label, key)
    local row = FieldRow(parent, label)
    local box = Setup.Field(row, 72, 16)
    box:SetPoint("RIGHT", 0, 0)
    box:SetScript("OnTextChanged", function(self) draft[key] = self:GetText() or "" end)
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

-- Modernize's section header: an accent title on a strip that spans the row. Column titles may sit on it.
Setup.SECTION = 22

function Setup.Section(parent, text, help)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, Setup.SECTION)
    Setup.Strip(row)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 10, 0)
    row.label:SetText(text)
    row.label:SetTextColor(unpack(Setup.Colors().accent))
    if help then row.help = Setup.Help(row, row.label, text, help) end
    return row
end

function Setup.Body(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetWidth(Setup.CONTENT_W)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text)
    return label
end

-- Secondary text: grey, under a row or at the end of a page.
function Setup.Note(parent, text)
    return Setup.Muted(Setup.Body(parent, text))
end

-- A column title on a section's strip; `section` owns it, so the strip does not cover it.
function Setup.ColumnLabel(section, text)
    local label = Setup.Muted(section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    label:SetText(text)
    return label
end

function Setup.SelectMenu(owner, key, anchor, entries)
    local menu = owner[key]
    if menu and menu:IsShown() then menu:Hide(); return end
    if not menu then
        menu = CreateFrame("Frame", nil, owner)
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel(owner:GetFrameLevel() + 60)
        Setup.Fill(menu, Setup.Solid(Setup.Colors().bg), "BACKGROUND", -8)
        Setup.Edge(menu, Setup.Colors().outline)
        menu:EnableMouse(true)
        menu.items = {}
        owner[key] = menu
    end
    for _, item in ipairs(menu.items) do item:Hide() end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    local width = math.max(300, anchor:GetWidth() or 0)
    menu:SetSize(width, 12 + 28 * math.min(#entries, 8))
    if not menu.scroll then
        menu.scroll = CreateFrame("ScrollFrame", nil, menu)
        menu.scroll:SetPoint("TOPLEFT", 6, -6)
        menu.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        menu.content = CreateFrame("Frame", nil, menu.scroll)
        menu.content:SetWidth(width - 12)
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
            item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            item.label:SetPoint("LEFT", 18, 0)
            item.label:SetPoint("RIGHT", -8, 0)
            item.label:SetJustifyH("LEFT")
            -- The chosen entry is a strip, like the selected tab.
            Setup.Strip(item)
            Setup.Hover(item)
            menu.items[index] = item
        end
        item:SetSize(width - 12, 26)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
        Setup.ButtonText(item, entry.name)
        local theme = Setup.Colors()
        if entry.selected then
            item.fill:Show(); item.mark:Show()
        else
            item.fill:Hide(); item.mark:Hide()
        end
        item.label:SetTextColor(unpack(entry.selected and theme.accent or theme.text))
        item:SetScript("OnClick", function() menu:Hide(); entry.select() end)
        item:Show()
    end
    menu:Show()
end
