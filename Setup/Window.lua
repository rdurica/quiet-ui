local _, ns = ...

-- The window: chrome, tabs, pages host and the preset dialog.
-- The frame is named so UISpecialFrames can close it on Escape.
-- The window keeps the tallest page, so switching tabs does not resize it.

local Setup = ns.Setup
local S = Setup.state
local draft = Setup.draft

local TABS = {
    { id = "general", label = "General", height = 224 },
    { id = "visible", label = "Visible", height = 262 },
    { id = "bars", label = "Bars", height = 308 },
    { id = "groups", label = "Groups", height = 320 },
    { id = "player", label = "Player", height = 306 },
    { id = "chat", label = "Misc.", height = 320 },
    { id = "info", label = "Info", height = 148 },
}

-- Portrait frame needs room under the portrait. Gold dialog needs room inside the thick edge.
local CHROME = {
    portrait = { width = 612, side = 26, tabY = -74, pageY = -102, footer = 52, buttonY = 16 },
    gold = { width = 636, side = 38, tabY = -56, pageY = -88, footer = 64, buttonY = 28, titleY = -30, closeX = -18, closeY = -16 },
    flat = { width = 592, side = 16, tabY = -40, pageY = -76, footer = 52, buttonY = 16, titleY = -14, closeX = -10, closeY = -10 },
}

local function MaxPage()
    local max = 0
    for _, info in ipairs(TABS) do
        if info.height > max then max = info.height end
    end
    return max
end

local function TabButton(parent, text, width, onClick)
    local button = ns.Backdropped("Button", nil, parent)
    button:SetSize(width, 22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    Setup.SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.15)
    button:SetScript("OnClick", onClick)
    return button
end

local function Page(parent, id, height, metrics)
    local page = CreateFrame("Frame", nil, parent)
    page.id = id
    page:SetSize(Setup.CONTENT_W, height)
    page:SetPoint("TOPLEFT", metrics.side, metrics.pageY)
    page:SetFrameLevel(parent:GetFrameLevel() + 20)
    page:Hide()
    return page
end

local function ShowPage(widget, id)
    if widget.presetMenu then widget.presetMenu:Hide() end
    if widget.layoutMenu then widget.layoutMenu:Hide() end
    widget.page = id
    for _, page in ipairs(widget.pages) do
        if page.id == id then page:Show() else page:Hide() end
    end
    Setup.Paint()
end

local function EnsureEscape(widget)
    local name = widget:GetName()
    if not name or not UISpecialFrames then return end
    for _, entry in ipairs(UISpecialFrames) do
        if entry == name then return end
    end
    UISpecialFrames[#UISpecialFrames + 1] = name
end

local function ApplyPortrait(widget)
    pcall(function()
        if widget.SetPortraitToUnit then
            widget:SetPortraitToUnit("player")
            return
        end
        if type(SetPortraitTexture) ~= "function" then return end
        local texture = widget.portrait
        if not texture and widget.PortraitContainer then
            texture = widget.PortraitContainer.portrait
        end
        if texture then
            SetPortraitTexture(texture, "player")
        end
    end)
end

local function CloseButton(parent, metrics)
    local button = ns.Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    button:SetPoint("TOPRIGHT", metrics.closeX, metrics.closeY)
    button:SetFrameLevel(parent:GetFrameLevel() + 20)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText("X")
    Setup.SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", function()
        parent:Hide()
    end)
    return button
end

function Setup.PresetDialog(owner, title, text, accept)
    local dialog = owner.presetDialog
    if not dialog then
        local blocker = CreateFrame("Frame", nil, owner)
        blocker:SetAllPoints(owner)
        blocker:SetFrameLevel(owner:GetFrameLevel() + 75)
        blocker:EnableMouse(true)
        local ok, widget = pcall(CreateFrame, "Frame", nil, blocker, "PortraitFrameTemplate")
        local side, bodyY, editY, buttonY = 26, -96, -154, 18
        if ok and widget and ns.PortraitChrome(widget) then
            dialog = widget
            ns.ApplyTitle(dialog, "Shared preset")
            ApplyPortrait(dialog)
            dialog:SetSize(420, 244)
        else
            dialog = ok and widget or ns.Backdropped("Frame", nil, blocker)
            if ns.DialogGoldWindow(dialog) then
                side, bodyY, editY, buttonY = 28, -56, -114, 28
                dialog:SetSize(420, 214)
            else
                ns.Flat(dialog, 1)
                side, bodyY, editY, buttonY = 16, -40, -98, 16
                dialog:SetSize(380, 186)
            end
            dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            dialog.title:SetText("Shared preset")
            dialog.title:SetPoint("TOP", 0, -26)
        end
        ns.DialogBackground(dialog)
        dialog.blocker = blocker
        dialog:SetScript("OnHide", function() blocker:Hide() end)
        dialog:SetPoint("CENTER")
        dialog:SetFrameLevel(owner:GetFrameLevel() + 80)
        dialog:EnableMouse(true)
        local close = dialog.CloseButton or dialog.closeButton
        if close then close:SetScript("OnClick", function() dialog:Hide() end) end
        dialog.body = Setup.Body(dialog, "")
        local contentWidth = (side == 16 and 380 or 420) - 2 * side
        dialog.body:SetWidth(contentWidth)
        dialog.body:SetPoint("TOPLEFT", side, bodyY)
        dialog.edit = ns.Backdropped("EditBox", nil, dialog)
        if not ns.GoldEdge(dialog.edit) then ns.Flat(dialog.edit, 1) end
        dialog.edit:SetSize(contentWidth, 24)
        dialog.edit:SetPoint("TOPLEFT", side, editY)
        dialog.edit:SetFontObject("GameFontHighlightSmall")
        dialog.edit:SetAutoFocus(false)
        dialog.edit:SetMaxLetters(64)
        dialog.edit:SetTextInsets(6, 6, 0, 0)
        dialog.edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog.edit:SetScript("OnEnterPressed", function() dialog.yes:GetScript("OnClick")() end)
        dialog.yes = Setup.Button(dialog, "Confirm", function() end)
        dialog.yes:SetPoint("BOTTOMRIGHT", -side, buttonY)
        dialog.no = Setup.Button(dialog, "Cancel", function() dialog:Hide() end)
        dialog.no:SetPoint("BOTTOMLEFT", side, buttonY)
        owner.presetDialog = dialog
    end
    dialog.body:SetText(title)
    if text ~= nil then dialog.edit:SetText(text); dialog.edit:Show() else dialog.edit:Hide() end
    dialog.yes:SetScript("OnClick", function()
        local ok, err = accept(dialog.edit:GetText())
        if ok then dialog:Hide(); Setup.Paint() else dialog.body:SetText(err) end
    end)
    if owner.presetMenu then owner.presetMenu:Hide() end
    if owner.layoutMenu then owner.layoutMenu:Hide() end
    dialog.blocker:Show()
    dialog:Show()
    if text ~= nil then dialog.edit:SetFocus(); dialog.edit:HighlightText() end
end

local function CreateSetup()
    local ok, widget = pcall(CreateFrame, "Frame", "QuietUISetup", UIParent, "PortraitFrameTemplate")
    local kind = "flat"
    if ok and widget and ns.PortraitChrome(widget) then
        kind = "portrait"
        widget._quietPortrait = true
        ns.ApplyTitle(widget, "QuietUI")
        ApplyPortrait(widget)
    else
        if not (ok and widget) then
            widget = ns.Backdropped("Frame", "QuietUISetup", UIParent)
        end
        if ns.DialogGoldWindow(widget) then
            kind = "gold"
        else
            ns.Flat(widget, 0.9)
        end
    end
    local metrics = CHROME[kind]
    widget:ClearAllPoints()
    widget:SetSize(metrics.width, -metrics.pageY + MaxPage() + metrics.footer)
    widget:SetPoint("CENTER")
    widget:SetFrameStrata("DIALOG")
    ns.DialogBackground(widget)
    widget:EnableMouse(true)
    widget:Hide()
    EnsureEscape(widget)

    if kind ~= "portrait" then
        widget.title = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        widget.title:SetText("QuietUI")
        widget.title:SetPoint("TOP", 0, metrics.titleY)
        widget.close = CloseButton(widget, metrics)
    end

    widget.tabs = {}
    widget.pages = {}
    -- Keep every tab on one centered row.
    local tabW, gap = 68, 4
    local total = #TABS * tabW + (#TABS - 1) * gap
    local x = -total / 2
    for _, info in ipairs(TABS) do
        local id = info.id
        local tab = TabButton(widget, info.label, tabW, function()
            ShowPage(widget, id)
        end)
        tab.id = id
        tab:SetFrameLevel(widget:GetFrameLevel() + 20)
        tab:SetPoint("TOP", widget, "TOP", x + tabW / 2, metrics.tabY)
        x = x + tabW + gap
        widget.tabs[#widget.tabs + 1] = tab
        widget.pages[#widget.pages + 1] = Page(widget, id, info.height, metrics)
    end

    for index, info in ipairs(TABS) do
        Setup.Pages[info.id](widget, widget.pages[index])
    end

    widget.reset = Setup.Button(widget, "Reset default", function()
        if ns.Layout.CancelPreview then ns.Layout.CancelPreview() end
        ns.Settings.ActivatePreset(nil, {})
        Setup.LoadSavedDraft()
        Setup.Paint()
        if ns.Layout.SettingsChanged then ns.Layout.SettingsChanged() end
        if ns.ApplyAll then ns.ApplyAll() end
    end)
    widget.import = Setup.Button(widget, "Import layout", function()
        ns.Layout.Force()
    end)
    widget.save = Setup.Button(widget, "Save", function()
        Setup.Write()
    end)
    widget.reset:SetFrameLevel(widget:GetFrameLevel() + 20)
    widget.import:SetFrameLevel(widget:GetFrameLevel() + 20)
    widget.save:SetFrameLevel(widget:GetFrameLevel() + 20)

    widget.reset:SetPoint("BOTTOMLEFT", metrics.side, metrics.buttonY)
    widget.import:SetPoint("BOTTOM", 0, metrics.buttonY)
    widget.save:SetPoint("BOTTOMRIGHT", -metrics.side, metrics.buttonY)
    widget:SetScript("OnHide", function()
        if ns.Layout.CancelPreview then ns.Layout.CancelPreview() end
        for _, key in ipairs({ "presetMenu", "layoutMenu", "presetDialog" }) do
            if widget[key] then widget[key]:Hide() end
        end
    end)
    ShowPage(widget, "general")
    return widget
end

function Setup.Refresh()
    if not S.frame or not S.frame:IsShown() then return end
    for _, key in ipairs({ "presetMenu", "layoutMenu", "presetDialog" }) do
        if S.frame[key] then S.frame[key]:Hide() end
    end
    Setup.LoadSavedDraft()
    Setup.Paint()
end

function Setup.Show()
    if ns.Layout.CancelPreview then ns.Layout.CancelPreview() end
    S.frame = S.frame or CreateSetup()
    Setup.LoadSavedDraft()
    if S.frame._quietPortrait then
        ApplyPortrait(S.frame)
    end
    S.frame:Show()
    ns.RaiseDialog(S.frame)
    ShowPage(S.frame, S.frame.page or "general")
end
