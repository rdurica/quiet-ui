local _, ns = ...

-- The add/update prompt for the shipped layout.

local Layout = ns.Layout
local S = Layout.state

------------------------------------------------------------------------------
-- Prompt. Own frame instead of StaticPopup, which spreads taint.
-- Same character frame as setup, with a gear instead of the player portrait.
------------------------------------------------------------------------------
local CHROME = {
    portrait = { width = 400, side = 26, textY = -96, buttonY = 18, height = 188 },
    gold = { width = 420, side = 28, titleY = -26, textY = -56, buttonY = 28, height = 166 },
    flat = { width = 380, side = 16, titleY = -14, textY = -40, buttonY = 16, height = 132 },
}

local function PortraitRegion(widget)
    if widget.PortraitContainer and widget.PortraitContainer.portrait then
        return widget.PortraitContainer.portrait
    end
    return widget.portrait
end

local function TextureShown(texture)
    return texture and texture.GetTexture and texture:GetTexture()
end

-- Gear, same order as the minimap button. The character frame needs an icon in the circle.
local function ApplyGearPortrait(widget)
    if widget.SetPortraitAtlas then
        local ok = pcall(widget.SetPortraitAtlas, widget, "mechagon-projects")
        if ok and TextureShown(PortraitRegion(widget)) then return end
    end
    if widget.SetPortraitToAsset then
        local ok = pcall(widget.SetPortraitToAsset, widget, "Interface\\Icons\\INV_Misc_Gear_01")
        if ok and TextureShown(PortraitRegion(widget)) then return end
    end
    local texture = PortraitRegion(widget)
    if not texture then return end
    if texture.SetAtlas then
        local ok, result = pcall(texture.SetAtlas, texture, "mechagon-projects")
        if ok and result then return end
    end
    if type(SetPortraitToTexture) == "function" then
        local ok = pcall(SetPortraitToTexture, texture, "Interface\\Icons\\INV_Misc_Gear_01")
        if ok and TextureShown(texture) then return end
    end
    if not texture:SetTexture("Interface\\Icons\\INV_Misc_Gear_01") then
        texture:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    end
end

-- The template close hides the frame without an answer. Only the two buttons decide.
local function HideClose(widget)
    local close = widget.CloseButton or widget.closeButton
    if close and close.Hide then close:Hide() end
end

local function SetButtonLabel(button, text)
    if button.label then
        button.label:SetText(text)
        return
    end
    if button.SetText then button:SetText(text) end
end

local function CreatePrompt()
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameTemplate")
    local kind = "flat"
    if ok and frame and ns.PortraitChrome(frame) then
        kind = "portrait"
        frame._quietGear = true
        ns.ApplyTitle(frame, "QuietUI")
        ApplyGearPortrait(frame)
        HideClose(frame)
    else
        if not (ok and frame) then
            frame = ns.Backdropped("Frame", nil, UIParent)
        end
        if ns.DialogGoldWindow(frame) then kind = "gold"
        else ns.Flat(frame, 1) end
    end
    ns.DialogBackground(frame)
    local metrics = CHROME[kind]
    frame:ClearAllPoints()
    frame:SetSize(metrics.width, metrics.height)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    if kind ~= "portrait" then
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetText("|cff8fd4c8QuietUI|r")
        frame.title:SetPoint("TOP", 0, metrics.titleY)
    end
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", 0, metrics.textY)
    frame.text:SetWidth(metrics.width - metrics.side * 2)
    frame.text:SetJustifyH("CENTER")
    frame.yes = ns.Setup.Button(frame, "Add", function()
        frame:Hide()
        if InCombatLockdown() then
            ns.Print("layout can not change in combat, /reload after combat to try again")
            return
        end
        local okWrite, err = pcall(Layout.Write)
        if okWrite then
            Layout.MarkAnswered()
        else
            ns.Report("layout", err)
        end
    end)
    frame.no = ns.Setup.Button(frame, "Not now", function()
        frame:Hide()
        Layout.MarkAnswered()
    end)
    local level = frame:GetFrameLevel() + 20
    frame.yes:SetFrameLevel(level)
    frame.no:SetFrameLevel(level)
    frame.no:SetPoint("BOTTOMLEFT", metrics.side, metrics.buttonY)
    frame.yes:SetPoint("BOTTOMRIGHT", -metrics.side, metrics.buttonY)
    frame:Hide()
    return frame
end

local function Ask(text, yesLabel)
    local prompt = S.prompt or CreatePrompt()
    S.prompt = prompt
    if prompt._quietGear then ApplyGearPortrait(prompt) end
    prompt.text:SetText(text)
    SetButtonLabel(prompt.yes, yesLabel)
    prompt:Show()
    ns.RaiseDialog(prompt)
end

-- Returns true once the check could run, so it is not repeated this session.
function Layout.Check()
    if ns.DB().layoutHash == Layout.ShippedHash() then return true end
    local info = Layout.Load()
    if not info then return false end
    Layout.ReadShipped()
    if Layout.Find(info.layouts) then
        Ask("The " .. Layout.NAME .. " layout has changed. Update yours?", "Update")
    else
        Ask("Add the " .. Layout.NAME .. " layout and switch to it?", "Add")
    end
    return true
end
