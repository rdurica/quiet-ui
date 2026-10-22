local _, ns = ...

-- The add/update prompt for the shipped layout.

local Layout = ns.Layout
local S = Layout.state

------------------------------------------------------------------------------
-- Prompt. Own frame instead of StaticPopup, which spreads taint.
-- Same flat window as setup, without a close: only the two buttons answer.
------------------------------------------------------------------------------
local WIDTH, HEIGHT, SIDE = 420, 150, 20

local function SetButtonLabel(button, text)
    if button.label then
        button.label:SetText(text)
        return
    end
    if button.SetText then button:SetText(text) end
end

local function CreatePrompt()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    ns.Setup.Window(frame, "|cff8fd4c8QuietUI|r")
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", 0, -(ns.Setup.HEADER + 22))
    frame.text:SetWidth(WIDTH - SIDE * 2)
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
    frame.no:SetPoint("BOTTOMLEFT", SIDE, 16)
    frame.yes:SetPoint("BOTTOMRIGHT", -SIDE, 16)
    frame:Hide()
    return frame
end

local function Ask(text, yesLabel)
    local prompt = S.prompt or CreatePrompt()
    S.prompt = prompt
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
