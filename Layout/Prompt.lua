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
        local okWrite, err = pcall(frame.action)
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

local function Ask(text, yesLabel, action)
    local prompt = S.prompt or CreatePrompt()
    S.prompt = prompt
    prompt.text:SetText(text)
    prompt.action = action
    SetButtonLabel(prompt.yes, yesLabel)
    prompt:Show()
    ns.RaiseDialog(prompt)
end

-- The layout is on the account, the active layout per character.
local function Switch()
    local info = Layout.Load()
    local index = info and Layout.Find(info.layouts)
    if not index then error("the " .. Layout.NAME .. " layout is missing") end
    C_EditMode.SetActiveLayout(Layout.PresetCount() + index)
end

-- A new layout version asks once per account; a character that has not answered yet asks for itself.
-- Returns true once the check could run, so it is not repeated this session.
function Layout.Check()
    local hash = Layout.ShippedHash()
    if ns.Settings.CharDB().layoutHash == hash then return true end
    local info = Layout.Load()
    if not info then return false end
    Layout.ReadShipped()
    local index = Layout.Find(info.layouts)
    if not index then
        Ask("Add the " .. Layout.NAME .. " layout and switch to it?", "Add", Layout.Write)
    elseif ns.DB().layoutHash ~= hash then
        Ask("The " .. Layout.NAME .. " layout has changed. Update yours?", "Update", Layout.Write)
    elseif info.activeLayout == Layout.PresetCount() + index then
        Layout.MarkAnswered()
    else
        Ask("Switch to the " .. Layout.NAME .. " layout?", "Switch", Switch)
    end
    return true
end
