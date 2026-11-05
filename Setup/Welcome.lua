local _, ns = ...

-- The welcome: choose Classic or Modern, once per character. Same flat window as setup, without a close:
-- a card selects, Choose answers.

local Setup = ns.Setup
local S = Setup.state

local CARD_W, IMAGE_H, SIDE = 300, 150, 20
local WIDTH = CARD_W * 2 + SIDE * 3
local CARD_TOP = Setup.HEADER + 52
local CARD_H = IMAGE_H + 64
local HEIGHT = CARD_TOP + CARD_H + 16 + 26 + 50

local CHOICES = {
    {
        key = "classic",
        title = "Classic",
        text = "Blizzard's own look, just quieter. Bars and frames fade until you need them.",
        image = "Interface\\AddOns\\QuietUI\\Media\\welcome-classic.tga",
    },
    {
        key = "modern",
        title = "Modern (experimental)",
        text = "Flat graphite windows and slim unit frames, one dark look across every panel. Still experimental.",
        image = "Interface\\AddOns\\QuietUI\\Media\\welcome-modern.tga",
    },
}

local function Current()
    return ns.Settings.Modernize() and "modern" or "classic"
end

local function Choose(key)
    ns.Settings.CharDB().welcomed = true
    local settings = ns.Settings.Effective()
    local stored = type(settings.modernize) == "table" and settings.modernize or nil
    if key == "modern" then
        stored = stored or {}
        stored.enabled = true
        settings.modernize = stored
    elseif stored then
        stored.enabled = nil
        if next(stored) == nil then settings.modernize = nil end
    end
end

-- A changed look reloads, so it is complete at once; the same look only closes, and the layout prompt follows.
-- ReloadUI from addon code is blocked on this client, so Choose is a secure button running /reload while the
-- selection changes the look; PreClick saves the choice first.
local function Answered(frame, reloads)
    frame:Hide()
    if frame.changes and not reloads then
        ns.Print("type /reload to finish the new look")
    end
    if not frame.changes then ns.Layout.Ensure() end
end

local function ChooseButton(frame)
    local button = Setup.Button(frame, "Choose", nil, "SecureActionButtonTemplate")
    if type(button.SetAttribute) ~= "function" then
        button:SetScript("OnClick", function()
            if not frame.selected then return end
            Choose(frame.selected)
            local reloads = frame.changes and type(ReloadUI) == "function"
            Answered(frame, reloads)
            if reloads then ReloadUI() end
        end)
        return button
    end
    if type(button.RegisterForClicks) == "function" then button:RegisterForClicks("AnyUp", "AnyDown") end
    button:SetScript("PreClick", function()
        if frame.selected then Choose(frame.selected) end
    end)
    button:SetScript("PostClick", function()
        Answered(frame, button:GetAttribute("type") == "macro")
    end)
    return button
end

-- Only a look that changes runs /reload. Attributes are locked in combat; then chat asks for /reload.
local function ArmReload(frame)
    frame.changes = frame.selected ~= nil and frame.selected ~= Current()
    local button = frame.choose
    if type(button.SetAttribute) ~= "function" or InCombatLockdown() then return end
    button:SetAttribute("macrotext", "/reload")
    button:SetAttribute("type", frame.changes and "macro" or nil)
end

-- The chosen card keeps the accent edge; Choose waits for one.
local function Select(frame, key)
    frame.selected = key
    for cardKey, card in pairs(frame.cards) do
        Setup.EdgeColor(card, cardKey == key and Setup.Colors().accent or Setup.Colors().border)
    end
    if key then frame.choose:Enable() else frame.choose:Disable() end
    ArmReload(frame)
end

local function Card(frame, choice, x)
    local card = CreateFrame("Button", nil, frame)
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("TOPLEFT", x, -CARD_TOP)
    Setup.Hover(card)
    Setup.Edge(card)
    card:SetScript("OnClick", function() Select(frame, choice.key) end)
    card.image = card:CreateTexture(nil, "ARTWORK")
    card.image:SetPoint("TOPLEFT", 1, -1)
    card.image:SetPoint("TOPRIGHT", -1, -1)
    card.image:SetHeight(IMAGE_H)
    card.image:SetTexture(choice.image)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.title:SetPoint("TOPLEFT", card.image, "BOTTOMLEFT", 10, -10)
    card.title:SetText(choice.title)
    card.title:SetTextColor(unpack(Setup.Colors().accent))
    card.text = Setup.Muted(card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"))
    card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
    card.text:SetWidth(CARD_W - 20)
    card.text:SetJustifyH("LEFT")
    card.text:SetText(choice.text)
    return card
end

local function CreateWelcome()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", 0, 60)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    Setup.Window(frame, "Welcome to |cff8fd4c8QuietUI|r")
    frame.intro = Setup.Body(frame, "Pick the look you like. Both keep the screen quiet: fewer frames, the same game.")
    frame.intro:SetWidth(WIDTH - SIDE * 2)
    frame.intro:SetJustifyH("CENTER")
    frame.intro:SetPoint("TOP", 0, -(Setup.HEADER + 18))
    frame.cards = {}
    for i, choice in ipairs(CHOICES) do
        frame.cards[choice.key] = Card(frame, choice, SIDE + (i - 1) * (CARD_W + SIDE))
    end
    frame.choose = ChooseButton(frame)
    frame.choose:SetWidth(200)
    frame.choose:SetPoint("TOP", 0, -(CARD_TOP + CARD_H + 16))
    frame.note = Setup.Note(frame, "")
    frame.note:SetWidth(WIDTH - SIDE * 2)
    frame.note:SetJustifyH("CENTER")
    frame.note:SetPoint("BOTTOM", 0, 18)
    frame:Hide()
    return frame
end

function Setup.WelcomeOpen()
    return S.welcome ~= nil and S.welcome:IsShown()
end

local NOTE = "Everything can be changed later in /quiet setup."

-- The choice goes into the effective settings, so a shared preset changes for every character that uses it.
local function Note()
    local preset = ns.Settings.ActivePreset()
    if not preset then return NOTE end
    return 'This changes preset "' .. preset.name .. '" for every character that uses it.\n' .. NOTE
end

-- Once per character, also after an update. Known players see their current look selected.
function Setup.Welcome()
    local db = ns.DB()
    -- An earlier build kept the answer on the account.
    db.welcomed = nil
    if ns.Settings.CharDB().welcomed then return end
    S.welcome = S.welcome or CreateWelcome()
    local known = ns.Settings.Modernize() or db.layoutHash ~= nil or ns.Settings.ActivePreset() ~= nil
    S.welcome.note:SetText(Note())
    Select(S.welcome, known and Current() or nil)
    S.welcome:Show()
    ns.RaiseDialog(S.welcome)
end
