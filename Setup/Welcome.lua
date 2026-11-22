local _, ns = ...

-- The welcome: choose Classic or Modern, or Custom modules, once per character. Same flat window as setup,
-- without a close: a card selects, Choose answers; Custom opens a second screen of module checkboxes.

local Setup = ns.Setup
local S = Setup.state

local CARD_W, IMAGE_H, SIDE = 300, 150, 20
local WIDTH = CARD_W * 2 + SIDE * 3
local CARD_TOP = Setup.HEADER + 52
local CARD_H = IMAGE_H + 64
local CUSTOM_H = 40
local ACTION_Y = CARD_TOP + CARD_H + 16 + CUSTOM_H + 12
local HEIGHT = ACTION_Y + 26 + 50
local ROW_STEP = 44

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

local CLASSIC = { chat = true, fading = true, helpers = true, layout = true, modernize = false }
local MODERN = { chat = true, fading = true, helpers = true, layout = true, modernize = true }

-- Modernize on is Modern, the Classic set is Classic, any other set selects no card.
local function Current()
    if ns.Settings.Modernize() then return "modern" end
    if Setup.SameModules(Setup.ActiveModules(), CLASSIC) then return "classic" end
end

-- The answer goes into the effective settings. The old Modern chat and Modernize flags are gone with it.
local function Write(set)
    ns.Settings.CharDB().welcomed = true
    local settings = ns.Settings.Effective()
    settings.chat = nil
    if type(settings.modernize) == "table" then
        settings.modernize.enabled = nil
        if next(settings.modernize) == nil then settings.modernize = nil end
    end
    settings.modules = Setup.StoredModules(set)
    if ns.Registry.booted then ns.Registry.Sync() end
end

-- A changed set reloads, so it is complete at once; the same set only closes, and the layout prompt follows.
-- The click saves the answer first (see Setup.ReloadButton); the old set is restored first, out of combat.
local function Answered(frame, button, reloads)
    frame:Hide()
    if button.changes and not reloads then
        ns.Print("type /reload to finish the new modules")
    end
    if not button.changes and ns.Settings.Module("layout") then ns.Layout.Ensure() end
end

-- Not handled when the answer waits: Custom Save does not change modules in combat.
local function Commit(frame, button)
    local set = button.source(frame)
    if not set then return false end
    button.changes = not Setup.SameModules(Setup.ActiveModules(), set)
    local combat = InCombatLockdown()
    if button.changes and combat and button.strict then
        ns.Print("Leave combat to change modules.")
        return false
    end
    if button.changes and not combat and ns.DB().enabled and ns.RestoreAll then ns.RestoreAll() end
    Write(set)
    return true, button.changes
end

local function ChooseButton(frame, text, source, strict)
    local button
    button = Setup.ReloadButton(frame, text, function() return Commit(frame, button) end, function(reloads)
        Answered(frame, button, reloads)
    end)
    button.source, button.strict = source, strict
    return button
end

local function SelectedSet(frame)
    if frame.selected == "modern" then return MODERN end
    if frame.selected == "classic" then return CLASSIC end
end

-- The chosen card keeps the accent edge; Choose waits for one.
local function Select(frame, key)
    frame.selected = key
    for cardKey, card in pairs(frame.cards) do
        Setup.EdgeColor(card, cardKey == key and Setup.Colors().accent or Setup.Colors().border)
    end
    if key then frame.choose:Enable() else frame.choose:Disable() end
end

local function CustomSet(frame) return frame.custom end

-- Save waits for a checked module.
local function PaintCustom(frame)
    for _, row in ipairs(frame.moduleRows) do Setup.PaintBox(row.button.box, frame.custom[row.key]) end
    if Setup.AnyModule(frame.custom) then frame.save:Enable() else frame.save:Disable() end
end

local function BuildCustom(frame)
    frame.moduleRows = {}
    for i, info in ipairs(Setup.MODULES) do
        local key = info.key
        local button = Setup.Choice(frame, info.label, function()
            frame.custom[key] = not frame.custom[key]
            PaintCustom(frame)
        end)
        button:SetWidth(WIDTH - SIDE * 2)
        button:SetPoint("TOPLEFT", SIDE, -(CARD_TOP + (i - 1) * ROW_STEP))
        local note = Setup.Note(frame, info.text)
        note:SetWidth(WIDTH - SIDE * 2 - 28)
        note:SetPoint("TOPLEFT", SIDE + 28, -(CARD_TOP + (i - 1) * ROW_STEP + 22))
        frame.moduleRows[i] = { key = key, button = button, note = note }
    end
    frame.back = Setup.Button(frame, "Back", function() frame.showScreen(frame, false) end)
    frame.back:SetWidth(120)
    frame.back:SetPoint("TOP", -70, -ACTION_Y)
    frame.save = ChooseButton(frame, "Save", CustomSet, true)
    frame.save:SetWidth(120)
    frame.save:SetPoint("TOP", 70, -ACTION_Y)
end

local function ShowScreen(frame, custom)
    -- The second screen is built on first use.
    if custom and not frame.moduleRows then BuildCustom(frame) end
    for _, card in pairs(frame.cards) do
        if custom then card:Hide() else card:Show() end
    end
    for _, part in ipairs({ frame.customButton, frame.choose }) do
        if custom then part:Hide() else part:Show() end
    end
    for _, row in ipairs(frame.moduleRows or {}) do
        if custom then row.button:Show(); row.note:Show() else row.button:Hide(); row.note:Hide() end
    end
    for _, part in ipairs({ frame.back, frame.save }) do
        if part then
            if custom then part:Show() else part:Hide() end
        end
    end
    frame.intro:SetText(custom and "Turn on the parts of QuietUI you want. The UI reloads when you save."
        or "Pick the look you like. Both keep the screen quiet: fewer frames, the same game.")
    if custom then
        frame.custom = { chat = true, fading = false, helpers = false, layout = false, modernize = false }
        PaintCustom(frame)
    end
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
    frame.showScreen = ShowScreen
    frame.customButton = Setup.Button(frame, "Custom: choose which parts of QuietUI to turn on", function()
        ShowScreen(frame, true)
    end)
    frame.customButton:SetSize(WIDTH - SIDE * 2, CUSTOM_H)
    frame.customButton:SetPoint("TOP", 0, -(CARD_TOP + CARD_H + 16))
    frame.choose = ChooseButton(frame, "Choose", SelectedSet)
    frame.choose:SetWidth(200)
    frame.choose:SetPoint("TOP", 0, -ACTION_Y)
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
    ShowScreen(S.welcome, false)
    Select(S.welcome, known and Current() or nil)
    S.welcome:Show()
    ns.RaiseDialog(S.welcome)
end
