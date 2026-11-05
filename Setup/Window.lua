local _, ns = ...

-- The window: chrome, tabs, pages host and the preset dialog.
-- The frame is named so UISpecialFrames can close it on Escape.
-- The window keeps the tallest page, so switching tabs does not resize it.

local Setup = ns.Setup
local S = Setup.state

local TABS = {
    { id = "general", label = "General", height = 224 },
    { id = "visible", label = "Visible", height = 300 },
    { id = "bars", label = "Bars", height = 370 },
    { id = "groups", label = "Groups", height = 416 },
    { id = "player", label = "Player", height = 352 },
    { id = "chat", label = "Misc.", height = 260 },
    { id = "modern", label = "Modern", height = 310 },
    { id = "info", label = "Info", height = 200 },
}

-- Tabs in a sidebar on the left, pages right of it, actions in a footer under the pages.
local WIDTH, SIDEBAR, PAD, FOOTER, TAB_H = 940, 184, 28, 60, 34
local CONTENT_X = SIDEBAR + PAD
local PAGE_Y = -(Setup.HEADER + 20)
local BUTTON_Y = 17

local function MaxPage()
    local max = 0
    for _, info in ipairs(TABS) do
        if info.height > max then max = info.height end
    end
    return max
end

local function TabButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SIDEBAR - 16, TAB_H)
    Setup.Strip(button)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("LEFT", 14, 0)
    button.label:SetText(text)
    Setup.Hover(button)
    button:SetScript("OnClick", onClick)
    return button
end

-- The selected tab is a strip with an accent mark; the others are plain grey text.
function Setup.PaintTabs(frame)
    for _, tab in ipairs(frame.tabs) do
        if tab.id == frame.page then
            tab.fill:Show(); tab.mark:Show()
            tab.label:SetTextColor(unpack(Setup.Colors().accent))
        else
            tab.fill:Hide(); tab.mark:Hide()
            tab.label:SetTextColor(0.8, 0.8, 0.8)
        end
    end
end

local function Page(parent, id, height)
    local page = CreateFrame("Frame", nil, parent)
    page.id = id
    page:SetSize(Setup.CONTENT_W, height)
    page:SetPoint("TOPLEFT", CONTENT_X, PAGE_Y)
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

function Setup.PresetDialog(owner, title, text, accept)
    local dialog = owner.presetDialog
    if not dialog then
        local blocker = CreateFrame("Frame", nil, owner)
        blocker:SetAllPoints(owner)
        blocker:SetFrameLevel(owner:GetFrameLevel() + 75)
        blocker:EnableMouse(true)
        local width, side = 440, 20
        dialog = CreateFrame("Frame", nil, blocker)
        dialog:SetSize(width, 196)
        dialog:SetPoint("CENTER")
        dialog:SetFrameLevel(owner:GetFrameLevel() + 80)
        dialog:EnableMouse(true)
        Setup.Window(dialog, "Shared preset", function() dialog:Hide() end)
        dialog.blocker = blocker
        dialog:SetScript("OnHide", function() blocker:Hide() end)
        dialog.body = Setup.Body(dialog, "")
        dialog.body:SetWidth(width - 2 * side)
        dialog.body:SetPoint("TOPLEFT", side, -(Setup.HEADER + 18))
        dialog.edit = Setup.Field(dialog, width - 2 * side, 64)
        dialog.edit:SetPoint("TOPLEFT", side, -(Setup.HEADER + 66))
        dialog.edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog.edit:SetScript("OnEnterPressed", function() dialog.yes:GetScript("OnClick")() end)
        dialog.yes = Setup.Button(dialog, "Confirm", function() end)
        dialog.yes:SetPoint("BOTTOMRIGHT", -side, 16)
        dialog.no = Setup.Button(dialog, "Cancel", function() dialog:Hide() end)
        dialog.no:SetPoint("BOTTOMLEFT", side, 16)
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

local function Footer(widget)
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
    -- Save is the main action: accent edge and label.
    Setup.EdgeColor(widget.save, Setup.Colors().accent)
    widget.save.label:SetTextColor(unpack(Setup.Colors().accent))
    for _, button in ipairs({ widget.reset, widget.import, widget.save }) do
        button:SetFrameLevel(widget:GetFrameLevel() + 20)
    end
    widget.reset:SetPoint("BOTTOMLEFT", CONTENT_X, BUTTON_Y)
    widget.import:SetPoint("BOTTOMLEFT", CONTENT_X + widget.reset:GetWidth() + 8, BUTTON_Y)
    widget.save:SetPoint("BOTTOMRIGHT", -PAD, BUTTON_Y)
end

-- The header band drags the window; the point is kept account-wide in setupPoint.
local function Place(widget)
    local saved = ns.DB().setupPoint
    widget:ClearAllPoints()
    if type(saved) == "table" and type(saved[3]) == "number" and type(saved[4]) == "number" then
        widget:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        widget:SetPoint("CENTER")
    end
end

local function Movable(widget)
    if type(widget.SetMovable) ~= "function" or type(widget.StartMoving) ~= "function" then return end
    widget:SetMovable(true)
    if type(widget.SetClampedToScreen) == "function" then widget:SetClampedToScreen(true) end
    local handle = CreateFrame("Frame", nil, widget)
    handle:SetPoint("TOPLEFT", 0, 0)
    handle:SetPoint("TOPRIGHT", -Setup.HEADER, 0)
    handle:SetHeight(Setup.HEADER)
    handle:SetFrameLevel(widget:GetFrameLevel() + 10)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() widget:StartMoving() end)
    handle:SetScript("OnDragStop", function()
        widget:StopMovingOrSizing()
        local point, _, relativePoint, x, y = widget:GetPoint(1)
        if point and not ns.IsSecret(x) and not ns.IsSecret(y) then
            ns.DB().setupPoint = { point, relativePoint, x, y }
        end
        -- StartMoving marks the frame user placed; the saved point is the only position source.
        if type(widget.SetUserPlaced) == "function" then pcall(widget.SetUserPlaced, widget, false) end
    end)
    widget.dragHandle = handle
end

local function CreateSetup()
    local widget = CreateFrame("Frame", "QuietUISetup", UIParent)
    widget:SetSize(WIDTH, -PAGE_Y + MaxPage() + FOOTER + 12)
    widget:SetFrameStrata("DIALOG")
    widget:EnableMouse(true)
    widget:Hide()
    Setup.Window(widget, "QuietUI", function() widget:Hide() end)
    Movable(widget)
    EnsureEscape(widget)

    -- The sidebar sinks a step below the panel, like the insets of a Modernize window.
    local side = widget:CreateTexture(nil, "BACKGROUND", nil, -6)
    side:SetPoint("TOPLEFT", 1, -(Setup.HEADER + 1))
    side:SetPoint("BOTTOMLEFT", 1, 1)
    side:SetWidth(SIDEBAR - 1)
    side:SetColorTexture(unpack(Setup.Colors().sunk))
    Setup.Rule(widget, { "TOPLEFT", SIDEBAR, -(Setup.HEADER + 1) }, { "BOTTOMLEFT", SIDEBAR, 1 })
    Setup.Rule(widget, { "BOTTOMLEFT", SIDEBAR, FOOTER }, { "BOTTOMRIGHT", -1, FOOTER })

    widget.tabs = {}
    widget.pages = {}
    for index, info in ipairs(TABS) do
        local id = info.id
        local tab = TabButton(widget, info.label, function()
            ShowPage(widget, id)
        end)
        tab.id = id
        tab:SetFrameLevel(widget:GetFrameLevel() + 20)
        tab:SetPoint("TOPLEFT", 8, -(Setup.HEADER + 12) - (index - 1) * (TAB_H + 2))
        widget.tabs[#widget.tabs + 1] = tab
        widget.pages[#widget.pages + 1] = Page(widget, id, info.height)
    end

    for index, info in ipairs(TABS) do
        Setup.Pages[info.id](widget, widget.pages[index])
    end

    Footer(widget)
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
    Place(S.frame)
    S.frame:Show()
    ns.RaiseDialog(S.frame)
    ShowPage(S.frame, S.frame.page or "general")
end
