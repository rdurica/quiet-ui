local _, ns = ...

-- The mailbox (Blizzard_MailFrame on Forever): MailFrame with the inbox and send pages, and OpenMailFrame for one
-- letter. Both take the dark window; the inbox parchment, the row frames, the stationery and the divider bars are
-- held, so rows, letters and invoices stand on the panel with light ink; inner panels and the money bar stand bare,
-- and the coin inputs are dark fields without a border. The page buttons become bare chevrons. Mail icons,
-- attachments, money and COD marks stay. A send slot shows the item as its NormalTexture, so it gets its own square
-- socket.

local Modern = ns.Modern
local Mail = {}
Modern.Mail = Mail

local ROWS = 7
local ATTACHMENTS = 16
-- Loose parchment and divider art, by file name.
local ART = { "ui-mailframebg", "mailitemborder", "ui-classtrainer-horizontalbar", "stationery" }
local STATIONERY = { "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight", "OpenStationeryBackgroundLeft",
    "OpenStationeryBackgroundRight", "InboxFrameBg" }
-- The divider bars: a named left half and an unnamed right half anchored to it.
local BARS = { "SendMailHorizontalBarLeft", "SendMailHorizontalBarLeft2" }
-- The bar under the player's money: bare, so the coins are text on the panel.
local MONEY_BARS = { "SendMailMoneyInset", "SendMailMoneyBg" }
local COINS = { SendMailMoneyGold = true, SendMailMoneySilver = true, SendMailMoneyCopper = true }

local bare = setmetatable({}, { __mode = "k" })    -- inner panels: art held, no border
local styled = setmetatable({}, { __mode = "k" })  -- send slot -> journal while applied
local hooked = setmetatable({}, { __mode = "k" })

local function Hold(skin, texture)
    if ns.Usable(texture) and type(texture.SetAlpha) == "function" then skin:Hold(texture) end
end

local function Divider(skin, bar)
    if not ns.Usable(bar) then return end
    Hold(skin, bar)
    local parent = type(bar.GetParent) == "function" and bar:GetParent()
    if not ns.Usable(parent) or type(parent.GetRegions) ~= "function" then return end
    for _, region in ipairs({ parent:GetRegions() }) do
        if region ~= bar and type(region.GetNumPoints) == "function" and type(region.GetPoint) == "function" then
            for index = 1, region:GetNumPoints() do
                if select(2, region:GetPoint(index)) == bar then
                    Hold(skin, region)
                    break
                end
            end
        end
    end
end

local function Shown(texture)
    return ns.Usable(texture) and type(texture.IsShown) == "function" and texture:IsShown() and true or false
end

-- A send slot: border in the colour Blizzard gives IconBorder (uncommon and up), the socket colours while empty.
local function PaintSlot(button)
    local skin = styled[button]
    if not skin then return end
    local theme = Modern.Theme()
    local normal = type(button.GetNormalTexture) == "function" and button:GetNormalTexture()
    local filled = ns.Usable(normal) and type(normal.GetTexture) == "function" and normal:GetTexture() ~= nil
    if ns.Usable(normal) and filled then skin:Icon(normal) end
    local border, color = button.IconBorder, nil
    if filled and Shown(border) and type(border.GetVertexColor) == "function" then
        local r, g, b = border:GetVertexColor()
        if type(r) == "number" and not ns.IsSecret(r) and not (r > 0.9 and g > 0.9 and b > 0.9) then color = { r, g, b, 1 } end
    end
    skin:Panel(button, filled and theme.track or theme.well)
    skin:Border(button, color or (filled and theme.border or theme.wellEdge))
end

local function SendSlot(skin, button)
    if not ns.Usable(button) or type(button.CreateTexture) ~= "function" then return end
    styled[button] = skin
    skin:Remember(button, "modern mail slot", function() styled[button] = nil end)
    -- The slot art is the one BACKGROUND texture; the item icon is the button's NormalTexture and stays.
    if type(button.GetRegions) == "function" then
        for _, region in ipairs({ button:GetRegions() }) do
            if type(region.GetDrawLayer) == "function" and region:GetDrawLayer() == "BACKGROUND"
                and not skin:Owns(button, region) then
                Hold(skin, region)
            end
        end
    end
    Hold(skin, button.IconBorder)
    PaintSlot(button)
    if hooked[button] then return end
    hooked[button] = true
    local function Again() ns.Profiler.Run("modern mail", PaintSlot, button) end
    for _, method in ipairs({ "SetNormalTexture", "ClearNormalTexture" }) do
        if type(button[method]) == "function" then pcall(hooksecurefunc, button, method, Again) end
    end
    local border = button.IconBorder
    for _, method in ipairs({ "SetVertexColor", "Show", "Hide", "SetShown" }) do
        if ns.Usable(border) and type(border[method]) == "function" then pcall(hooksecurefunc, border, method, Again) end
    end
end

-- Inbox rows lose their frame and stand bare; their spacing keeps them apart.
local function Rows(skin)
    for index = 1, ROWS do
        local row = _G["MailItem" .. index]
        if ns.Usable(row) then Modern.Character.HoldArt(skin, row) end
    end
end

-- The inbox and letter insets would draw a second box inside the window; three bordered coin boxes in a row are
-- busy, so they keep only their dark field.
local function Particular(skin, frame)
    local name = type(frame.GetName) == "function" and frame:GetName()
    if name and COINS[name] then
        Modern.Shapes.Field(skin, frame, true)
        skin:Panel(frame)
        return true
    end
    if ns.Usable(rawget(frame, "NineSlice")) and not Modern.Shapes.IsField(frame) then bare[frame] = true end
    return false
end

local OPTIONS = { bare = bare, shape = Particular }

local function Letter(skin, frame)
    local theme = Modern.Theme()
    for _, name in ipairs(MONEY_BARS) do
        local bar = _G[name]
        if ns.Usable(bar) then
            bare[bar] = true
            if type(bar.GetObjectType) == "function" and bar:GetObjectType() == "Texture" then
                Hold(skin, bar)
            else
                Modern.WindowChrome(skin, bar)
                Modern.Character.HoldArt(skin, bar)
            end
        end
    end
    for _, name in ipairs(STATIONERY) do Hold(skin, _G[name]) end
    for _, name in ipairs(BARS) do Divider(skin, _G[name]) end
    Modern.Shapes.HoldArt(skin, frame, ART)
    Modern.Shapes.Walk(skin, frame, OPTIONS)
    Modern.InkTree(skin, frame, { tone = theme.text, plain = true })
end

local function Skin(skin, frame)
    -- Flat: the inset would sink a darker box under the rows and the letter.
    Modern.Window(skin, frame, nil, nil, true)
    Modern.Header(skin, frame)
    Letter(skin, frame)
    if frame == _G.MailFrame then
        Rows(skin)
        local inbox = _G.InboxFrame
        Modern.PageArrows(skin, _G.InboxPrevPageButton or inbox and inbox.PrevPageButton,
            _G.InboxNextPageButton or inbox and inbox.NextPageButton)
        for index = 1, ATTACHMENTS do SendSlot(skin, _G["SendMailAttachment" .. index]) end
        -- The letter body is an edit box with the parchment ink.
        Modern.Ink(skin, _G.SendMailBodyEditBox, Modern.Theme().text, true)
    end
end

function Mail.Apply(skin)
    Modern.Shapes.Keep(skin, _G.MailFrame, "mail", Skin, OPTIONS)
    Modern.Shapes.Keep(skin, _G.OpenMailFrame, "mail", Skin, OPTIONS)
end
