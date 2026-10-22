local _, ns = ...

-- The first-run welcome: choose Classic or Modern. Same flat window as setup, without a close:
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
        title = "Modern",
        text = "Flat graphite windows and slim unit frames. One clean, dark look across every panel.",
        image = "Interface\\AddOns\\QuietUI\\Media\\welcome-modern.tga",
    },
}

local function Choose(key)
    ns.DB().welcomed = true
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

-- Either choice reloads, so the look is complete at once and the layout prompt follows. ReloadUI from addon code
-- is blocked on this client, so Choose is a secure button running /reload; PreClick saves the choice first.
local function ChooseButton(frame)
    local button = Setup.Button(frame, "Choose", nil, "SecureActionButtonTemplate")
    if type(button.SetAttribute) ~= "function" then
        button:SetScript("OnClick", function()
            if not frame.selected then return end
            Choose(frame.selected)
            frame:Hide()
            if type(ReloadUI) == "function" then ReloadUI() end
        end)
        return button
    end
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", "/reload")
    if type(button.RegisterForClicks) == "function" then button:RegisterForClicks("AnyUp", "AnyDown") end
    button:SetScript("PreClick", function()
        if frame.selected then Choose(frame.selected) end
    end)
    button:SetScript("PostClick", function() frame:Hide() end)
    return button
end

-- The chosen card keeps the accent edge; Choose waits for one.
local function Select(frame, key)
    frame.selected = key
    for cardKey, card in pairs(frame.cards) do
        Setup.EdgeColor(card, cardKey == key and Setup.Colors().accent or Setup.Colors().border)
    end
    if key then frame.choose:Enable() else frame.choose:Disable() end
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
    Select(frame, nil)
    frame.note = Setup.Note(frame, "Everything can be changed later in /quiet setup.")
    frame.note:SetWidth(WIDTH - SIDE * 2)
    frame.note:SetJustifyH("CENTER")
    frame.note:SetPoint("BOTTOM", 0, 18)
    frame:Hide()
    return frame
end

function Setup.WelcomeOpen()
    return S.welcome ~= nil and S.welcome:IsShown()
end

-- Once per account, on a fresh install only: an account that already answered the layout prompt has used QuietUI.
function Setup.Welcome()
    local db = ns.DB()
    if db.welcomed then return end
    if db.layoutHash ~= nil then
        db.welcomed = true
        return
    end
    S.welcome = S.welcome or CreateWelcome()
    S.welcome:Show()
    ns.RaiseDialog(S.welcome)
end
